local rrqueue = require("rrqueue")

local function test1()
	local queue = rrqueue.new(10)
	print("new pop:", queue:pop())
	print("size:", queue:len(), " cap:", queue:size())
	for i=1, 11 do
		print(queue:push(i))
		print("size:", queue:len(), " cap:", queue:size())
	end

	for i=1, 11 do
		print("old pop:", queue:pop())
	end

	print("size:", queue:len(), " cap:", queue:size())
end

test1()