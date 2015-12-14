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
end
