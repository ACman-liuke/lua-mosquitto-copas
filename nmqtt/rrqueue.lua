-- 循环队列 round-roubin-queue

local queue_method = {}
local mt = {__index = queue_method}

function queue_method:pop()
	--print("pop:", self.front, self.rear)
	if self.front == self.rear then  
		return nil, "empty queue"
	end
	self.front = (self.front +  1) % self.capacity
	return table.remove(self.arr, 1)

end

function queue_method:len()
	return (self.rear - self.front + self.capacity) % self.capacity
end

function queue_method:push(data)
	--print("rrqueue self:", self)
	if (self.rear + 1) % self.capacity == self.front % self.capacity then
		return false, "full queue"
	end

	self.rear = (self.rear + 1) % self.capacity
	--print("push:", self.rear)
	table.insert(self.arr, data)
	return true
end


function queue_method:size()
	return self.capacity
end

local function new(cap)
	local obj = {
		capacity = (cap + 1) or 10000,
		front = 0,
		rear = 0,
		arr = {}
	}
	setmetatable(obj, mt)
	return obj
end

return {
	new = new,
}