---@diagnostic disable: undefined-global
local UI = require("urhox-libs/UI")
local instance
function Start()
    UI.Init({fonts={{family="sans",weights={normal="Fonts/LongZhuTi-Regular.ttf"}}},scale=1})
    local err
    instance,err=UI.LoadJSON("ui/settings-popup.ui.json")
    assert(instance,err)
    UI.SetRoot(instance:GetRoot())
    if graphics:GetWidth()==538 then
        instance:Find("safe_area"):SetStyle({paddingTop=62,paddingBottom=34})
    end
    _G.SettingsLayoutInstance=instance
end
