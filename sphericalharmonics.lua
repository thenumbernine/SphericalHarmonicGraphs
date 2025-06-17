local factorial = require 'SphericalHarmonicGraphs.factorial'
local associatedLegendre = require 'SphericalHarmonicGraphs.associatedlegendre'

local function complexSphericalHarmonics(l, m, theta, phi)
	local P = associatedLegendre(l,m,math.cos(theta))
	local N = math.sqrt( (2*l+1)/(4*math.pi) * factorial(l-m)/factorial(l+m)  )
	return math.cos(m * phi) * N * P, math.sin(m * phi) * N * P
end

local function realSphericalHarmonics(l, m, theta, phi)
	if m < 0 then
		local _, im = complexSphericalHarmonics(l, math.abs(m), theta, phi)
		return math.sqrt(2) * (-1)^m * im
	end
	local re, _ = complexSphericalHarmonics(l, m, theta, phi)
	if m == 0 then
		return re
	else
		return math.sqrt(2) * (-1)^m * re
	end
end

return {
	real = realSphericalHarmonics,
	complex = complexSphericalHarmonics,
}
