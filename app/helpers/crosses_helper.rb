module CrossesHelper
	def chromosomeMath(input)
		out = "\\["
		input.each do |chr|
			if chr.size > 1 
				out = out + "\\dfrac"
				chr.each do |n|
					out = out + " {" + n + "}"
				end
			else
				chr.each do |n|
					out = out + n
				end
			end
		end
		out = out + "\\]"
		return out
	end

	def cleanChromosome(input)
		out = ""
		input.each do |chr|
			if chr.size > 1 
				counter = 0
				chr.each do |n|
					out = out + n
					if counter == 0
						out = out + "/"
					end
					counter = 1
				end
			else
				chr.each do |n|
					out = out + n
				end
			end
		end
		return out
	end

	def checkLetality(input,balancers,lethal)
		death = false
		input.each do |chr|
			if chr.size > 1
				up = chr.to_a[0].split(',')
				down = chr.to_a[1].split(',')

				up.each do |u|
					down.each do |d|
						if u == d
							balancers.each do |b|
								if u == b
									death = true
								end
							end
							lethal.each do |l|
								if u == l
									death = true
								end
							end
						end
					end
				end
			else
				n = chr.to_a
				balancers.each do |b|
						if n[0] == b
							death = true
						end
				end
				lethal.each do |b|
						if n[0] == b
							death = true
						end
				end
			end
		end

		return death

	end
end
