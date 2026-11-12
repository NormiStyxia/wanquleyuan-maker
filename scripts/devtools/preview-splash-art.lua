--- 美术验收入口：复用真实启动页组件，停留在加载完成状态供截图。
local UI = require("urhox-libs/UI")
local Health = require("shared.components.health-advisory")
local elapsed_ = 0

function Start()
    graphics.windowTitle = "玩趣乐园 · 启动页美术验收"
    UI.Init({
        fonts = { { family = "sans", weights = { normal = "Fonts/LongZhuTi-Regular.ttf" } } },
        scale = UI.Scale.DEFAULT,
    })
    UI.SetRoot(UI.Panel {
        width = "100%", height = "100%",
        children = { Health.create(function() end) },
    })
    SubscribeToEvent("PostUpdate", "SplashArtPreview_Update")
end

function SplashArtPreview_Update(_, data)
    local dt = data["TimeStep"]:GetFloat()
    if elapsed_ < 6 then
        elapsed_ = elapsed_ + dt
        Health.update(dt)
    else
        Health.update(0)
    end
end

function Stop()
    UnsubscribeFromEvent("PostUpdate")
    UI.Shutdown()
end
