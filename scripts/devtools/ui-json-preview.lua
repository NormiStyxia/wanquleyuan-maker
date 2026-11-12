---@diagnostic disable: undefined-global
-- 临时资源验证入口，不替换项目入口、不加载游戏或任何平台业务。
local UI = require("urhox-libs/UI")
function Start()
    UI.Init({
        fonts = {{family="sans", weights={normal="Fonts/LongZhuTi-Regular.ttf"}}},
        scale = 1,
    })
    UI.SetRoot(UI.Panel{width="100%",height="100%",backgroundColor={255,246,220,255}})
    print("[UI资源验证] 独立验证环境已初始化")
end
