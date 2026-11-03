# Replays every scenario against the current CrossesController and compares it
# with what the original controller did. Needs no Rails or database:
#
#   ruby test/characterization/run.rb
require 'minitest/autorun'
require_relative 'harness'

load File.join(ROOT, 'app/controllers/crosses_controller.rb')

class CrossesControllerCharacterizationTest < Minitest::Test
  GOLDEN = JSON.parse(File.read(File.join(__dir__, 'golden.json')))
  ACTUAL = JSON.parse(JSON.generate(Harness.scenarios))

  def test_covers_the_same_scenarios
    assert_equal GOLDEN.keys, ACTUAL.keys
  end

  GOLDEN.each_key do |name|
    define_method("test_#{name}") do
      assert_equal GOLDEN[name], ACTUAL[name]
    end
  end
end
