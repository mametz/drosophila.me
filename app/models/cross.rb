class Cross < ApplicationRecord
  MAX_GENERATIONS = 100

  belongs_to :user
  belongs_to :male_fly, class_name: "Fly", optional: true
  belongs_to :female_fly, class_name: "Fly", optional: true
  belongs_to :parent, class_name: "Cross", optional: true
  has_many :children, class_name: "Cross", foreign_key: :parent_id, dependent: :nullify, inverse_of: :parent
  has_many :flies, dependent: :nullify

  scope :recent, -> { order(crossdate: :desc, id: :desc) }

  before_validation { self.slug ||= SecureRandom.hex }

  validates :crossdate, presence: true
  validates :slug, uniqueness: true

  def to_param
    slug
  end

  def visible_to?(viewer)
    shared? || owned_by?(viewer)
  end

  def owned_by?(viewer)
    viewer.present? && user_id == viewer.id
  end

  def balancer_list
    balancers.split(";").map(&:strip)
  end

  def lethal_list
    lethal.split(";").map(&:strip)
  end

  def progeny
    flies.where.not(id: [ male_fly_id, female_fly_id ].compact).order(:id)
  end

  def viable_progeny
    progeny.reject { |fly| fly.genotype.lethal?(balancer_list, lethal_list) }
  end

  # Oldest first, including this cross. The depth limit keeps a parent loop in
  # old data from running forever.
  def lineage
    rows = self.class.connection.select_rows(self.class.sanitize_sql_array([ <<~SQL.squish, id, MAX_GENERATIONS ]))
      WITH RECURSIVE chain AS (
        SELECT id, parent_id, 1 AS depth FROM crosses WHERE id = ?
        UNION ALL
        SELECT crosses.id, crosses.parent_id, chain.depth + 1
        FROM crosses JOIN chain ON crosses.id = chain.parent_id
        WHERE chain.depth < ?
      )
      SELECT id FROM chain ORDER BY depth DESC
    SQL
    ids = rows.flatten.map(&:to_i).uniq
    by_id = self.class.where(id: ids).includes(:user, :male_fly, :female_fly).index_by(&:id)
    ids.filter_map { |cross_id| by_id[cross_id] }
  end

  def copy_for(new_owner)
    transaction do
      copy = self.class.create!(user: new_owner, parent: parent, description: description, balancers: balancers,
                                lethal: lethal, crossdate: crossdate)
      male = Fly.from_chromosomes(male_fly.chromosomes, cross: copy).tap(&:save!)
      female = Fly.from_chromosomes(female_fly.chromosomes, cross: copy).tap(&:save!)
      progeny.each { |fly| Fly.from_chromosomes(fly.chromosomes, cross: copy).save! }
      copy.update!(male_fly: male, female_fly: female)
      copy
    end
  end
end
