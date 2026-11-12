--- 临时截图入口：复用 ui-flow-scene 的内存存档，启动后切到自由模式页。验证完删除。
---@diagnostic disable: undefined-global
require("tests.e2e.ui-flow-scene")
local Router = require("app.router")
local baseStart = Start
local frames = 0
function Start()
    baseStart()
    local node = Node()
    TMP_HOME_SHOT_NODE = node
    local receiver = node:CreateScriptObject("LuaScriptObject")
    receiver:SubscribeToEvent("Update", function()
        frames = frames + 1
        if frames == 20 then
            require("shared.components.health-advisory").dismiss()
            Router.replace("home")
        end
    end)
end
