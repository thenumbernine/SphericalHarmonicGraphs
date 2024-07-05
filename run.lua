#! /usr/bin/env luajit
local gl = require 'gl'
local GLApp = require 'glapp'
local quat = require 'vec.quat'
local vec3 = require 'vec.vec3'
local sphericalHarmonics = require 'sphericalharmonics'

local lmax = tonumber(arg[1]) or 3

local idiv = 360
local jdiv = 180

local angle = quat()
--	* quat():fromAngleAxis(0,0,1,180)
--	* quat():fromAngleAxis(1,0,0,90)


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
		if cache[l][m][i][j] then return unpack(cache[l][m][i][j]) end
		
		local phi = i/idiv*2*math.pi
		local theta = j/jdiv*math.pi
		local Y = sphericalHarmonics.real(l, m, theta, phi)
		local r = math.abs(Y)	
		local x = r * math.sin(theta) * math.cos(phi)
		local y = r * math.sin(theta) * math.sin(phi)
		local z = r * math.cos(theta)
		local c = {Y,x,y,z}
		cache[l][m][i][j] = c
		return unpack(c)
	end
end

local normal
do
	local cache = {}
	normal = function(l,m,i,j)
		cache[l] = cache[l] or {}
		cache[l][m] = cache[l][m] or {}
		cache[l][m][i] = cache[l][m][i] or {}
		if cache[l][m][i][j] then return unpack(cache[l][m][i][j]) end
		
		local ip = vec3(select(2, vtx(l,m,i+1,j)))
		local im = vec3(select(2, vtx(l,m,i-1,j)))
		local jp = vec3(select(2, vtx(l,m,i,j+1)))
		local jm = vec3(select(2, vtx(l,m,i,j-1)))
		local c = -vec3.cross(ip-im,jp-jm):normalize()
		cache[l][m][i][j] = c
		return unpack(c)
	end
end

local list
function SHApp:update()
	SHApp.super.update(self)
	gl.glClear(gl.GL_COLOR_BUFFER_BIT + gl.GL_DEPTH_BUFFER_BIT)
	
	if not list then
		list = gl.glGenLists(1)
		gl.glNewList(list, gl.GL_COMPILE_AND_EXECUTE)
	
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
							local Y, x, y, z = vtx(l,m,i+iofs,j)
							if Y >= 0 then
								gl.glColor3f(1,0,0)
							else
								gl.glColor3f(0,1,1)
							end
							gl.glNormal3f(normal(l,m,i+iofs,j))
							gl.glVertex3f(x,y,z)
						end
					end
					gl.glEnd()
				end
				gl.glPopMatrix()
			end
		end
		gl.glEndList()
	else
		gl.glCallList(list)
	end
end

return SHApp():run()
