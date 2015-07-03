#! /usr/bin/env luajit
local class = require 'ext.class'
local gl = require 'ffi.OpenGL'
local GLApp = require 'glapp'
local quat = require 'vec.quat'
local vec3 = require 'vec.vec3'
local sphericalHarmonic = require 'sphericalharmonics'
local sdl = require 'ffi.sdl'

local GraphApp = class(GLApp)

local angle = 
	quat():fromAngleAxis(0,0,1,180)
	* quat():fromAngleAxis(1,0,0,90)
local distance = 1

function GraphApp:initGL()
	gl.glEnable(gl.GL_DEPTH_TEST)
	gl.glEnable(gl.GL_COLOR_MATERIAL)
	gl.glColorMaterial(gl.GL_FRONT_AND_BACK, gl.GL_DIFFUSE)
	gl.glEnable(gl.GL_LIGHTING)
	gl.glEnable(gl.GL_LIGHT0)
end

local idiv = 360
local jdiv = 180
local l = assert(tonumber(arg[1]), "expected run.lua l m")
local m = assert(tonumber(arg[2]), "expected run.lua l m")
assert(sphericalHarmonic[l], "couldn't find table for l="..l)
local f = assert(sphericalHarmonic[l][m], "couldn't find function for l="..l.." m="..m)

local vtx
do
	local cache = {}
	vtx = function(i,j)
		if not cache[i] then cache[i] = {} end
		if cache[i][j] then return unpack(cache[i][j]) end
		
		local phi = i/idiv*2*math.pi
		local theta = j/jdiv*math.pi
		local re, im = f(theta, phi)
		local r = math.abs(re)	
		local x = r * math.sin(theta) * math.cos(phi)
		local y = r * math.sin(theta) * math.sin(phi)
		local z = r * math.cos(theta)
		local c = {re,im,x,y,z}
		cache[i][j] = c
		return unpack(c)
	end
end

local normal
do
	local cache = {}
	normal = function(i,j)
		if not cache[i] then cache[i] = {} end
		if cache[i][j] then return unpack(cache[i][j]) end
		
		local ip = vec3(select(3, vtx(i+1,j)))
		local im = vec3(select(3, vtx(i-1,j)))
		local jp = vec3(select(3, vtx(i,j+1)))
		local jm = vec3(select(3, vtx(i,j-1)))
		cache[i][j] = -vec3.cross(ip-im,jp-jm):normalize()
		return unpack(cache[i][j])
	end
end

local leftMouseButtonDown
local leftShiftDown 
local rightShiftDown
function GraphApp:event(e)
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
function GraphApp:update()
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
		--gl.glPolygonMode(gl.GL_FRONT_AND_BACK, gl.GL_LINE)
		for i=0,idiv-1 do
			gl.glBegin(gl.GL_TRIANGLE_STRIP)
			for j=0,jdiv do
				for iofs=0,1 do
					local re, im, x, y, z = vtx(i+iofs,j)
					if re >= 0 then
						gl.glColor3f(1,0,0)
					else
						gl.glColor3f(0,1,1)
					end
					gl.glNormal3f(normal(i+iofs,j))
					gl.glVertex3f(x,y,z)
				end
			end
			gl.glEnd()
		end
		gl.glEndList()
	else
		gl.glCallList(list)
	end
end

GraphApp():run()

