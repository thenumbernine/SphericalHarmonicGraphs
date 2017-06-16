local symmath = require 'symmath'
local factorial = require 'factorial'

local associatedLegendre
do
	local cache = {}
	associatedLegendre = function(l,m,x)
		if not cache[l] then cache[l] = {} end
		if cache[l][m] then return cache[l][m](x) end

		local P
		do
			local x = symmath.var'x'
			P = (x^2-1)^l
			for i=1,l+m do
				P = P:diff(x):simplify()
			end
			P = (P * (-1)^m / (2^l * factorial(l)) * (1 - x^2)^(m/2))
				:simplify():compile{{x=x}}
		end	
		
		cache[l][m] = P
		
		return P(x)
	end
end

return associatedLegendre
