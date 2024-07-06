#! /usr/bin/env luajit
local gl = require 'gl'
local vec3d = require 'vec-ffi.vec3d'
local sphericalHarmonics = require 'sphericalharmonics'
local glCallOrRun = require 'gl.call'

local lmax = tonumber(arg[1]) or 3

local idiv = 360
local jdiv = 180

local SHApp = require 'glapp.orbit'():subclass()

SHApp.title = 'Spherical Harmonics Graph'
SHApp.viewDist = lmax

function SHApp:initGL(...)
	gl.glEnable(gl.GL_DEPTH_TEST)
	gl.glEnable(gl.GL_COLOR_MATERIAL)
	gl.glColorMaterial(gl.GL_FRONT_AND_BACK, gl.GL_DIFFUSE)
	gl.glEnable(gl.GL_LIGHTING)
	gl.glEnable(gl.GL_LIGHT0)
end

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

local list = {}
function SHApp:update()
	SHApp.super.update(self)
	gl.glClear(gl.GL_COLOR_BUFFER_BIT + gl.GL_DEPTH_BUFFER_BIT)

	glCallOrRun(list, function()
		for l=0,lmax do
			for m=-l,l do
				print('building l='..l..' m='..m)
				gl.glPushMatrix()
				gl.glTranslatef(m,lmax/2-l,0)
				--gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE)
				for i=0,idiv-1 do
					gl.glBegin(gl.GL_TRIANGLE_STRIP)
					for j=0,jdiv do
						for iofs=0,1 do
							local vsrc = vtx(l,m,i+iofs,j)
							if vsrc.Y >= 0 then
								gl.glColor3f(1,0,0)
							else
								gl.glColor3f(0,1,1)
							end
							gl.glNormal3f(normal(l,m,i+iofs,j):unpack())
							gl.glVertex3f(vsrc.vec:unpack())
						end
					end
					gl.glEnd()
				end
				gl.glPopMatrix()
			end
		end
	end)
end

return SHApp():run()
