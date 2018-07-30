local copas = require("copas")
local js = require("cjson.safe")
copas.autoclose = false

local function rcvfrom(skt)
    local header, err = skt:receive("*l")
    if not header then
        return nil, err
    end
    print("len"..header)
    len = tonumber(header)
    if not len then
        return nil, "len invalid format" .. header
    end

    local data, err = skt:receive(len)
    if not data then
        return nil, err
    end
    if #data ~= len then
        return nil, string.format("data invalid format:len=%d ~= data=%d", len, #data)
    end

    return data
end


local function gen_tcp_cli(count)
    local socket = require("socket")
    local cli = socket.connect("127.0.0.1", 50005)

    local data_source = {cmd = "ctrllog_get", pld= {count=count}}
    local mpac = js.encode(data_source)

    cli:send(#mpac .."\r\n".. mpac)
    local data, err =  rcvfrom(cli)
    if data then
        print("receive :", data)
    else
        print("receive error:", err)
    end
    
    cli:close()
end

local count = 0
while true do
    count = count + 1
    copas.addthread(gen_tcp_cli, count)
    socket.sleep(0.05)
end
