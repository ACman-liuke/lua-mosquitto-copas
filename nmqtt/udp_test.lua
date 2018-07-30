local copas = require("copas")
local js = require("cjson.safe")
copas.autoclose = false


local function gen_udp_cli(count)
    local socket = require("socket")
    local cli = socket.udp()

    local data_source = {cmd = "aclog_add", pld = {subtype ="RULE", actions = "", user = {ip= "192.168.2.111", mac= "11:33:44:55:66:88"}}}
    cli:setpeername("127.0.0.1", 50005)
    
    cli:send(js.encode(data_source))
    local data=  cli:receive()
    print("recive resp:",count, data)
    cli:close()
     
end

local count = 0


while true do
    count = count + 1
    copas.addthread(gen_udp_cli, count)
    socket.sleep(0.05)
end
