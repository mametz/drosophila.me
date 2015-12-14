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
end
