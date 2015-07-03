require 'ext.meta'

local pi = math.pi
local sqrt = math.sqrt
local cos = math.cos
local sin = math.sin

function constant(x)
	return function() return x end
end

function build(r, cphi, thetaFunc)
	return function(theta, phi)
		return
			r * thetaFunc(theta) * cos(cphi * phi),
			r * thetaFunc(theta) * sin(cphi * phi)
	end
end

local factorial = require 'factorial'
local associatedLegendre = require 'associatedlegendre'

return setmetatable({}, {__index=function(_,l)
	return setmetatable({}, {__index=function(_,m)
		return function(theta, phi)
			local P = associatedLegendre(l,m,math.cos(theta))
			local N = math.sqrt( (2*l+1)/(4*math.pi) * factorial(l-m)/factorial(l+m)  )
			return math.cos(m * phi) * N * P, math.sin(m * phi) * N * P
		end
	end})
end})

