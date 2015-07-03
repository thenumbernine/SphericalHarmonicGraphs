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

--[[ [l][m]
return {
	[0] = {
		[0] = build(1/2 * sqrt(1/pi), 0, constant(1)),
	},
	[1] = {
		[-1] = build(1/2 * sqrt(3/(2*pi)), -1, sin),
		[0] = build(1/2 * sqrt(3/pi), 0, cos),
		[1] = build(-1/2 * sqrt(3/(2*pi)), 1, sin),
	},
	[2] = {
		[-2] = build(1/4 * sqrt(15/(2*pi)), -2, sin*sin),
		[-1] = build(1/2 * sqrt(15/(2*pi)), -1, sin*cos),
		[0] = build(1/4 * sqrt(5/pi), 0, 3*cos^2-1),
		[1] = build(-1/2 * sqrt(15/(2*pi)), 1, sin*cos),
		[2] = build(1/4 * sqrt(15/(2*pi)), 2, sin*sin),
	},
}
--]]

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

