#! /usr/bin/env luajit

local cmdline = require 'ext.cmdline'.validate{
	l = {desc='how many l levels to build'},
	gl = {desc='which gl backend to use'},
}(...)

local template = require 'template'
local table = require 'ext.table'
local tolua = require 'ext.tolua'
local gl = require 'gl.setup'(cmdline.gl or 'OpenGL')
local GLProgram = require 'gl.program'
local GLSceneObject = require 'gl.sceneobject'

local lmax = tonumber(cmdline.l) or 3

local idiv = 360
local jdiv = 180

local SHApp = require 'glapp.orbit'():subclass()
SHApp.title = 'Spherical Harmonics Graph'
SHApp.viewDist = lmax

function SHApp:initGL(...)
	program = GLProgram{
		version = 'latest',
		precision = 'best',
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

require 'ext.timer'('building meshes', function()

	-- save our multithread parameters up front
	local lms = table()
	for l=0,lmax do
		for m=-l,l do
			lms:insert{l,m}
		end
	end

	local pool = require 'thread.pool'{
		initcode = template([[
local table = require 'ext.table'
local vec3d = require 'vec-ffi.vec3d'
local sphericalHarmonics = require 'sphericalharmonics'

local idiv = <?=idiv?>
local jdiv = <?=jdiv?>
local lmax = <?=lmax?>
local lms = <?=lms?>
lmresults = {}	-- make one per-worker, indexes will be 1..#lms
]],			{
				idiv = idiv,
				jdiv = jdiv,
				lmax = lmax,
				lms = tolua(lms),
			}),
		code = [[
local l, m = table.unpack(lms[tonumber(task)+1])

-- put cache here so we can parallelize l & m
-- cache needs to be reset between jobs anyways

local vtxcache = {}
local function vtx(i,j)
	vtxcache[i] = vtxcache[i] or {}
	if vtxcache[i][j] then return vtxcache[i][j] end

	local phi = i/idiv*2*math.pi
	local theta = j/jdiv*math.pi
	local Y = sphericalHarmonics.real(l, m, theta, phi)
	local r = math.abs(Y)
	local x = r * math.sin(theta) * math.cos(phi)
	local y = r * math.sin(theta) * math.sin(phi)
	local z = r * math.cos(theta)
	local c = {Y=Y, vec=vec3d(x,y,z)}
	vtxcache[i][j] = c
	return c
end

local normalcache = {}
local function normal(i,j)
	normalcache[i] = normalcache[i] or {}
	local c = normalcache[i][j]
	if not c then
		local ip = vec3d(vtx(i+1,j).vec)
		local im = vec3d(vtx(i-1,j).vec)
		local jp = vec3d(vtx(i,j+1).vec)
		local jm = vec3d(vtx(i,j-1).vec)
		c = -(ip-im):cross(jp-jm):normalize()
		normalcache[i][j] = c
	end
	return c
end



local vofs = vec3d(m,lmax/2-l,0)

local colors = table()
local vertexes = table()
local normals = table()

for j=0,jdiv do
	for i=0,idiv do
		local vsrc = vtx(i,j)
		if vsrc.Y >= 0 then
			colors:append{1,0,0}
		else
			colors:append{0,1,1}
		end
		normals:append{normal(i,j):unpack()}
		vertexes:append{(vsrc.vec + vofs):unpack()}
	end
end

local indexes = table()
for i=0,idiv-1 do
	local index = table()
	indexes:insert(index)
	for j=0,jdiv do
		for iofs=0,1 do
			index:insert((i + iofs) + (idiv + 1) * j)
		end
	end
end

lmresults[tonumber(task)+1] = {
	colors = colors,
	vertexes = vertexes,
	normals = normals,
	indexes = indexes,
}
]],
	}

	-- cycle thread pool across all our lms
	pool:cycle(#lms)

	-- recombine each worker's "lmresults" into a single table
	local lmresults = table()
	for _,worker in ipairs(pool) do
		local lmresults_lm = worker.thread.lua[[return lmresults]]
		for i,results in pairs(lmresults_lm) do
			assert(not lmresults[i])	-- no 2 threads should have done the same work
			lmresults[i] = results
		end
	end

	-- get segfault-on-exit if I don't manually close this ...
	pool:closed()

	sceneobjs = table()
	for lm,results in ipairs(lmresults) do
		local l, m = table.unpack(lms[lm])
		local colors = results.colors
		local vertexes = results.vertexes
		local normals = results.normals
		local indexes = results.indexes
		sceneobjs:insert(GLSceneObject{
			program = program,
			vertexes = {
				data = vertexes,
				count = #vertexes / 3,
				dim = 3,
			},
			geometries = table.mapi(indexes, function(index)
				return {
					mode = gl.GL_TRIANGLE_STRIP,
					indexes = {
						data = index,
					},
				}
			end),
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
end)

	--gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE)
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
