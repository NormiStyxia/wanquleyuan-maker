-- 启动页 JSON 适配隔离验证：不加载游戏，不访问玩家存档。
---@diagnostic disable: undefined-global, need-check-nil, undefined-field
local UI = require("urhox-libs/UI")
local instance
function Start()
    UI.Init({
        scale = 1,
        fonts = {{family = "sans", weights = {normal = "Fonts/LongZhuTi-Regular.ttf"}}},
    })
    local err
    instance, err = UI.LoadJSON("ui/splash.ui.json")
    assert(instance, err)
    UI.SetRoot(instance:GetRoot())
    print("[SplashLayout] loaded splash.ui.json")
end
