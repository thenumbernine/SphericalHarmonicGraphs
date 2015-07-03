local factorial
do
	local cache = {}
	factorial = function(l)
		assert(l >= 0)
		if l == 0 then return 1 end
		local f = cache[l]
		if not f then
			f = l * factorial(l-1)
			cache[l] = f
		end
		return f
	end
end
return factorial
