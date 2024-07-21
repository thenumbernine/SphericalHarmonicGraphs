package = "SphericalHarmonicGraphs"
version = "dev-1"
source = {
	url = "git+https://github.com/thenumbernine/SphericalHarmonicGraphs"
}
description = {
	summary = [[graphs of spherical harmonic basis functions]],
	detailed = [[graphs of spherical harmonic basis functions]],
	homepage = "https://github.com/thenumbernine/SphericalHarmonicGraphs",
	license = "MIT"
}
dependencies = {
	"lua >= 5.1"
}
build = {
	type = "builtin",
	modules = {
		["SphericalHarmonicGraphs.associatedlegendre"] = "associatedlegendre.lua",
		["SphericalHarmonicGraphs.factorial"] = "factorial.lua",
		["SphericalHarmonicGraphs.plot_associatedlegendre"] = "plot_associatedlegendre.lua",
		["SphericalHarmonicGraphs.run"] = "run.lua",
		["SphericalHarmonicGraphs.sphericalharmonics"] = "sphericalharmonics.lua"
	}
}
