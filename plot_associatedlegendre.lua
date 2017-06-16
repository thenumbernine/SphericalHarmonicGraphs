#! /usr/bin/env luajit
local plot2d = require 'plot2d'
local associatedLegendre = require 'associatedlegendre'
local table = require 'ext.table'

local lmax = tonumber(arg[1]) or 1
local xmin = -1
local xmax = 1
local xres = 200

local graphs = table()
for l=0,lmax do
	for m=-l,l do
		local xs = table()
		local ys = table()
		for i=0,xres do
			local x = i/xres*(xmax-xmin)+xmin
			local y = associatedLegendre(l,m,x)
			xs:insert(x)
			ys:insert(y)
		end
		graphs['l='..l..' m='..m] = {xs,ys,enabled=true}
	end
end
plot2d(graphs)
