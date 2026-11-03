# Records what a given version of CrossesController does for every scenario:
#
#   git show <rev>:app/controllers/crosses_controller.rb > /tmp/old_controller.rb
#   ruby test/characterization/generate_golden.rb /tmp/old_controller.rb
require_relative 'harness'

load ARGV.fetch(0)
out = ARGV[1] || File.join(__dir__, 'golden.json')
File.write(out, JSON.pretty_generate(Harness.scenarios))
puts "wrote #{out}"
