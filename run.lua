#! /usr/bin/env luajit

local cmdline = require 'ext.cmdline'.validate{
	l = {desc='how many l levels to build'},
	gl = {desc='which gl backend to use'},
}(...)

local table = require 'ext.table'
local gl = require 'gl.setup'(cmdline.gl or 'OpenGL')
local vec3d = require 'vec-ffi.vec3d'
local sphericalHarmonics = require 'sphericalharmonics'

local lmax = tonumber(cmdline.l) or 3

local idiv = 360
local jdiv = 180

local SHApp = require 'glapp.orbit'():subclass()
SHApp.viewUseBuiltinMatrixMath = true
SHApp.title = 'Spherical Harmonics Graph'
SHApp.viewDist = lmax

local vtx
do
	local cache = {}
	vtx = function(l,m,i,j)
		cache[l] = cache[l] or {}
		cache[l][m] = cache[l][m] or {}
		cache[l][m][i] = cache[l][m][i] or {}
		if cache[l][m][i][j] then return cache[l][m][i][j] end

		local phi = i/idiv*2*math.pi
		local theta = j/jdiv*math.pi
		local Y = sphericalHarmonics.real(l, m, theta, phi)
		local r = math.abs(Y)
		local x = r * math.sin(theta) * math.cos(phi)
		local y = r * math.sin(theta) * math.sin(phi)
		local z = r * math.cos(theta)
		local c = {Y=Y, vec=vec3d(x,y,z)}
		cache[l][m][i][j] = c
		return c
	end
end

local normal
do
	local cache = {}
	normal = function(l,m,i,j)
		cache[l] = cache[l] or {}
		cache[l][m] = cache[l][m] or {}
		cache[l][m][i] = cache[l][m][i] or {}
		local c = cache[l][m][i][j]
		if not c then
			local ip = vec3d(vtx(l,m,i+1,j).vec)
			local im = vec3d(vtx(l,m,i-1,j).vec)
			local jp = vec3d(vtx(l,m,i,j+1).vec)
			local jm = vec3d(vtx(l,m,i,j-1).vec)
			c = -(ip-im):cross(jp-jm):normalize()
			cache[l][m][i][j] = c
		end
		return c
	end
end

function SHApp:initGL(...)
	program = require 'gl.program'{
		version = 'latest',
		header = 'precision highp float;',
		vertexCode = [[
in vec3 vertex, normal, color;
uniform mat4 projMat, mvMat;
out vec3 colorv, normalv;
void main() {
	vec4 worldposv = mvMat * vec4(vertex, 1.);
	colorv = color;
	normalv = normalize((mvMat * vec4(normal, 0.)).xyz);
	gl_Position = projMat * worldposv;
}
]],
		fragmentCode = [[
in vec3 normalv, colorv;
out vec4 fragColor;
void main() {
	fragColor = vec4(max(.1, abs(normalv.z)) * colorv, 1.);
}
]],
	}:useNone()

	sceneobjs = table()
	for l=0,lmax do
		for m=-l,l do
			print('building l='..l..' m='..m)
			local vofs = vec3d(m,lmax/2-l,0)
			--gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE)
			for i=0,idiv-1 do

				local colors = table()
				local vertexes = table()
				local normals = table()
				
				for j=0,jdiv do
					for iofs=0,1 do
						local vsrc = vtx(l,m,i+iofs,j)
						if vsrc.Y >= 0 then
							colors:append{1,0,0}
						else
							colors:append{0,1,1}
						end
						normals:append{normal(l,m,i+iofs,j):unpack()}
						vertexes:append{(vsrc.vec + vofs):unpack()}
					end
				end

				sceneobjs:insert(require 'gl.sceneobject'{
					program = program,
					vertexes = {
						data = vertexes,
						count = #vertexes / 3,
						dim = 3,
					},
					geometry = {
						mode = gl.GL_TRIANGLE_STRIP,
					},
					attrs = {
						color = {
							buffer = {
								data = colors,
								count = #colors / 3,
								dim = 3,
							},
						},
						normal = {
							buffer = {
								data = normals,
								count = #normals / 3,
								dim = 3,
							},
						},
					},
				})
			end
		end
	end
	
	gl.glEnable(gl.GL_DEPTH_TEST)
end

function SHApp:update()
	SHApp.super.update(self)
	gl.glClear(bit.bor(gl.GL_COLOR_BUFFER_BIT, gl.GL_DEPTH_BUFFER_BIT))
	for _,obj in ipairs(sceneobjs) do
		obj.uniforms.mvMat = self.view.mvMat.ptr
		obj.uniforms.projMat = self.view.projMat.ptr
		obj:draw()
	end
end

return SHApp():run()
