---@diagnostic disable: undefined-global
-- 临时资源验证入口，不替换项目入口、不加载游戏或任何平台业务。
local UI = require("urhox-libs/UI")
function Start()
    UI.Init({
        fonts = {{family="sans", weights={normal="Fonts/LongZhuTi-Regular.ttf"}}},
        scale = 1,
    })
    local instance, err = UI.LoadJSON("ui/profile.ui.json")
    assert(instance, err)
    UI.SetRoot(instance:GetRoot())
    _G.UIJsonPreviewInstance = instance
    print("[UI资源验证] 主线参考图已加载")
end
