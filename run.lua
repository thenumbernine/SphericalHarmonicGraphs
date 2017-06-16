#! /usr/bin/env luajit
local class = require 'ext.class'
local gl = require 'gl'
local GLApp = require 'glapp'
local quat = require 'vec.quat'
local vec3 = require 'vec.vec3'
local sphericalHarmonics = require 'sphericalharmonics'
local sdl = require 'ffi.sdl'

local lmax = tonumber(arg[1]) or 3
local distance = lmax

local idiv = 360
local jdiv = 180

local angle = quat()
--	* quat():fromAngleAxis(0,0,1,180)
--	* quat():fromAngleAxis(1,0,0,90)


local SHApp = class(GLApp)

SHApp.title = 'Spherical Harmonics Graph' 

function SHApp:initGL()
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

local leftMouseButtonDown
local leftShiftDown 
local rightShiftDown
function SHApp:event(e)
	if e.type == sdl.SDL_MOUSEMOTION and leftMouseButtonDown then
		local dx = e.motion.xrel
		local dy = e.motion.yrel
		if leftShiftDown or rightShiftDown then
			distance = distance * math.exp(-.01 * dy)
		else
			local r = math.sqrt(dx*dx + dy*dy)
			local rot = quat():fromAngleAxis(dy, dx, 0, r)
			angle = rot * angle
		end
	end
	if e.type == sdl.SDL_MOUSEBUTTONDOWN then
		leftMouseButtonDown = true
	end
	if e.type == sdl.SDL_MOUSEBUTTONUP then
		leftMouseButtonDown = false
	end
	if e.type == sdl.SDL_KEYDOWN then
		if e.key.keysym.sym == sdl.SDLK_LSHIFT then leftShiftDown = true end
		if e.key.keysym.sym == sdl.SDLK_RSHIFT then rightShiftDown = true end
	end
	if e.type == sdl.SDL_KEYUP then
		if e.key.keysym.sym == sdl.SDLK_LSHIFT then leftShiftDown = false end
		if e.key.keysym.sym == sdl.SDLK_RSHIFT then rightShiftDown = false end
	end
end

local list
function SHApp:update()
	gl.glClear(gl.GL_COLOR_BUFFER_BIT + gl.GL_DEPTH_BUFFER_BIT)
	
	gl.glMatrixMode(gl.GL_PROJECTION)
	gl.glLoadIdentity()
	local znear = .01
	local zfar = 10
	local ar = self.width / self.height
	gl.glFrustum(-ar*znear, ar*znear, -znear, znear, znear, zfar)
	
	gl.glMatrixMode(gl.GL_MODELVIEW)
	gl.glLoadIdentity()
	gl.glTranslatef(0,0,-distance)
	local aa = angle:toAngleAxis()
	gl.glRotatef(aa[4], aa[1], aa[2], aa[3])

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

SHApp():run()
