# Runs CrossesController actions with Rails stubbed out and an in-memory store,
# so the same scenarios can be replayed against any version of the controller.
require 'set'
require 'date'
require 'json'
require 'securerandom'

ROOT = File.expand_path('../..', __dir__)
load File.join(ROOT, 'lib/core_ext/string.rb')
%w(genotype cross_calculator punnett_square).each { |f| require File.join(ROOT, 'app/models', f) }

class Record
  attr_accessor :id

  def self.store; @store ||= []; end
  def self.reset; @store = []; end

  def self.attrs(*names)
    attr_accessor(*names)
    const_set(:NAMES, names)
  end

  def initialize(values = {})
    values.each { |k, v| public_send("#{k}=", v) }
  end

  def save
    unless id
      self.class.store << self
      self.id = self.class.store.size
    end
    true
  end

  def update(values)
    values.each { |k, v| public_send("#{k}=", v) }
    true
  end

  def to_golden
    self.class::NAMES.map { |n| [n.to_s, Golden.dump(public_send(n))] }.to_h.merge('id' => id)
  end
end

class Fly < Record
  attrs :chr1, :chr2, :chr3, :chr4, :cross_id

  def self.find(id)
    store.find { |f| f.id == id.to_i } || raise(KeyError, "no fly #{id}")
  end

  # The controller only ever asks for "progeny of this cross".
  def self.where(_sql, cross_id, male_id, female_id)
    store.select { |f| f.cross_id == cross_id && f.id != male_id && f.id != female_id }
  end
end

class Cross < Record
  attrs :male_id, :female_id, :link, :lethal, :balancers, :description, :parent, :user_id, :crossdate

  # Integer columns, as Active Record would cast them.
  %w(male_id female_id parent).each do |column|
    define_method("#{column}=") do |value|
      instance_variable_set("@#{column}", value.nil? ? nil : value.to_i)
    end
  end

  def friendly_id; link; end

  def self.find(key)
    store.find { |c| c.link == key.to_s || c.id.to_s == key.to_s } || raise(KeyError, "no cross #{key}")
  end
end

class FakeParams
  def initialize(values); @values = values.map { |k, v| [k.to_s, v] }.to_h; end
  def [](key); @values[key.to_s]; end
  def require(_); self; end
  def permit(*); self; end
end

class FakeFormat
  def html; yield; end
  def json; end
end

class ApplicationController
  def self.before_action(*); end
  attr_accessor :params, :outcome

  def respond_to; yield FakeFormat.new; end
  def redirect_to(target, opts = {}); @outcome = { 'redirect' => target.is_a?(Record) ? target.id : target, 'notice' => opts[:notice] }; end
  def render(*); @outcome = { 'render' => true }; end
  def current_user; Struct.new(:id).new(1); end
  def user_signed_in?; true; end
  def request; Struct.new(:original_url).new('http://test/'); end
  def short_path(id); "/#{id}"; end
  def stocks_path; '/stocks'; end
  def crosses_url; '/crosses'; end
  def root_url; '/'; end
end

module Golden
  SKIP = %w(@params @outcome @random_string @current_url @cross @flym @flyf @c_flym @c_flyf @c_cross @old_cross).freeze

  def self.dump(value)
    case value
    when Set then { 'set' => value.to_a.map { |v| dump(v) } }
    when Array then value.map { |v| dump(v) }
    when Date then value.iso8601
    when Record then value.to_golden
    else value
    end
  end

  def self.controller_state(controller)
    names = controller.instance_variables.map(&:to_s) - SKIP
    names.sort.map { |n| [n, dump(controller.instance_variable_get(n))] }.to_h
  end
end

module Harness
  module_function

  def reset
    Fly.reset
    Cross.reset
    @hex = 0
    SecureRandom.define_singleton_method(:hex) { Harness.next_hex }
  end

  def next_hex
    @hex += 1
    "hex#{@hex}"
  end

  def attempt
    yield
  rescue NoMethodError, TypeError, ArgumentError, KeyError => e
    { 'error' => e.class.name }
  end

  def run_action(action, id)
    controller = CrossesController.new
    controller.params = FakeParams.new(id: id)
    attempt do
      controller.send(:set_cross)
      controller.send(action)
      Golden.controller_state(controller)
    end
  end

  def run_create(values)
    controller = CrossesController.new
    controller.params = FakeParams.new(values.merge(values))
    attempt do
      controller.send(:create)
      { 'outcome' => controller.outcome, 'cross' => controller.instance_variable_get(:@cross)&.to_golden }
    end
  end

  # A cross and its parent flies written straight to the store, skipping the
  # normalization create does. Old rows may hold anything.
  def seed(male, female, balancers: 'CyO;TM3', lethal: 'CyO/CyO')
    cross = Cross.new(link: "seed#{Cross.store.size + 1}", balancers: balancers, lethal: lethal, user_id: 1,
                      crossdate: Date.new(2015, 11, 1))
    cross.save
    m = Fly.new(chr1: male[0], chr2: male[1], chr3: male[2], chr4: male[3], cross_id: cross.id)
    f = Fly.new(chr1: female[0], chr2: female[1], chr3: female[2], chr4: female[3], cross_id: cross.id)
    m.save
    f.save
    cross.update(male_id: m.id, female_id: f.id)
    cross
  end

  def date_params
    { 'crossdate(1i)' => '2015', 'crossdate(2i)' => '11', 'crossdate(3i)' => '1' }
  end

  def founder_params(male, female)
    date_params.merge(description: 'test', balancers: 'CyO;TM3', lethal: 'CyO/CyO',
                      m_X: male[0], m_II: male[1], m_III: male[2], m_IV: male[3],
                      f_X: female[0], f_II: female[1], f_III: female[2], f_IV: female[3])
  end

  def flies_of(cross_id)
    Fly.store.select { |f| f.cross_id == cross_id }.map(&:to_golden)
  end

  GENOTYPES = {
    'wild'           => ['+/+', '+/+', '+/+', '+/+'],
    'hemizygous'     => ['+/-', '+/+', '+/+', '+/+'],
    'white'          => ['w', '+/+', '+/+', '+/+'],
    'white_y'        => ['w/Y', '+/+', '+/+', '+/+'],
    'y_white'        => ['Y/w', '+/+', '+/+', '+/+'],
    'w1118'          => ['w^{1118}/w^{1118}', '+/+', '+/+', '+/+'],
    'x_het'          => ['w/+', '+/+', '+/+', '+/+'],
    'second_balancer'=> ['+/+', 'Cy/CyO', '+/+', '+/+'],
    'third_balancer' => ['+/+', '+/+', 'Sb/TM3', '+/+'],
    'double_balancer'=> ['w/w', 'Sp/CyO', 'Sb/TM6B', '+/+'],
    'gal4_uas'       => ['w/w', 'P\\{GAL4\\}/+', 'P\\{UAS\\}', '+/+'],
    'fourth_only'    => ['+/+', '+/+', '+/+', 'ey/+'],
    'all_four'       => ['w/+', 'Cy/+', 'Sb/+', 'ey/+'],
    'three_alleles'  => ['a/b/c', '+/+', '+/+', '+/+'],
    'empty'          => ['', '+/+', '+/+', '+/+'],
    'y_only'         => ['Y', '+/+', '+/+', '+/+']
  }.freeze

  def scenarios
    results = {}
    GENOTYPES.each do |male_name, male|
      GENOTYPES.each do |female_name, female|
        key = "#{male_name} x #{female_name}"

        reset
        cross = seed(male, female)
        results["seeded: #{key}"] = %i(show chromosome punnett).map { |a| [a.to_s, run_action(a, cross.link)] }.to_h

        reset
        created = run_create(founder_params(male, female))
        flies = created['error'] ? [] : flies_of(created['cross']['id'])
        results["founder: #{key}"] = { 'create' => created, 'flies' => flies }
      end
    end
    results.merge(follow_on_scenarios)
  end

  # Crosses set up from the progeny of an earlier cross or from a stock.
  def follow_on_scenarios
    results = {}
    male = ['w/+', 'Cy/+', '+/+', '+/+']
    female = ['w/w', '+/+', 'Sb/+', '+/+']
    selected = { X: 'w/w', II: 'Cy', III: '+/+', IV: '+/+' }
    chosen_m = { m_X: 'w/-', m_II: 'Cy', m_III: '+/+', m_IV: '+/+' }
    chosen_f = { f_X: 'w', f_II: '+/+', f_III: 'Sb/+', f_IV: '+/+' }

    cases = {
      'new male'             => ->(m, _f) { { male_id: 'new', female_id: m.to_s }.merge(selected) },
      'new wild male'        => ->(m, _f) { { male_id: 'new', female_id: m.to_s }.merge(selected).merge(X: '+/+') },
      'new female'           => ->(m, _f) { { male_id: m.to_s, female_id: 'new' }.merge(selected) },
      'existing flies'       => ->(m, f) { { male_id: m.to_s, female_id: f.to_s } },
      'both from chromosomes'=> ->(_m, _f) { { male_id: 'male_chr_s', female_id: 'female_chr_s' }.merge(chosen_m).merge(chosen_f) },
      'male from chromosomes'=> ->(_m, f) { { male_id: 'male_chr_s', female_id: f.to_s }.merge(chosen_m) },
      'female from chromosomes' => ->(m, _f) { { male_id: m.to_s, female_id: 'female_chr_s' }.merge(chosen_f) },
      'new male, female from chromosomes' => ->(_m, _f) { { male_id: 'new', female_id: 'female_chr_s' }.merge(selected).merge(chosen_f) },
      'missing male'         => ->(_m, f) { { female_id: f.to_s } },
      'missing female'       => ->(m, _f) { { male_id: m.to_s } },
      'missing chromosomes'  => ->(_m, _f) { { male_id: 'male_chr_s', female_id: 'female_chr_s', m_X: 'w/-' } }
    }

    ['parent', 'stock'].each do |source|
      cases.each do |name, build|
        reset
        parent = seed(male, female)
        base = date_params.merge(description: 'next', balancers: 'CyO', lethal: 'CyO/CyO', link: "child",
                                 parent: source == 'parent' ? parent.id.to_s : 'stock')
        created = run_create(base.merge(build.call(parent.male_id, parent.female_id)))
        flies = created['error'] || created['cross'].nil? ? [] : flies_of(created['cross']['id'])
        views = created['error'] || created['cross'].nil? ? {} : %i(show chromosome punnett).map { |a| [a.to_s, run_action(a, created['cross']['link'])] }.to_h
        results["#{source}: #{name}"] = { 'create' => created, 'flies' => flies, 'views' => views }
      end
    end
    results
  end
end
