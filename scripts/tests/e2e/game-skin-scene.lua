--- 独立美术验收入口，基于2D脚手架生命周期；不修改main.lua或用户存档。
local UI=require("urhox-libs/UI")
local Art=require("shared.constants.art")
local Density=require("shared.utils.density")
local Trace=require("devtools.adventure-art-trace")
local Fixture=require("tests.e2e.game-skin-fixture")
local vg
-- 主入口提供的音量回调；独立排版验收使用内存值，不启动BGM或写设置。
local volume=0.5
function GetBGMVolume() return volume end
function SetBGMVolume(value) volume=value end
function Start()
    UI.Init({fonts={{family="sans",weights={normal=Art.font}}},scale=UI.Scale.DEFAULT})
    vg=nvgCreate(1)
    nvgCreateFont(vg,"sans",Art.font)
    Fixture.setup()
    SubscribeToEvent(vg,"NanoVGRender","SkinReview_Render")
    SubscribeToEvent("Update","SkinReview_Update")
end
function SkinReview_Update(_,data) Fixture.update(data["TimeStep"]:GetFloat()) end
function SkinReview_Render()
    local w,h=Density.beginFrame(vg)
    Fixture.draw(vg,w,h)
    Density.endFrame(vg)
end
function Stop()
    require("shared.components.fox-mascot").cleanup()
    if vg then
        require("shared.rendering.piece-sprites").release(vg)
        require("shared.background-manager").clearThemeCache(vg)
        nvgDelete(vg);vg=nil
    end
    UI.Shutdown()
end
