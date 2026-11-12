--- Yoga UI 控件的纸卡皮肤；只填表现属性，不改事件、状态和业务回调。
local UI = require("urhox-libs/UI")
local C = require("shared.constants.art").colors
local M = {}

local function copy(props)
    local result = {}
    for k, v in pairs(props or {}) do result[k] = v end
    return result
end

function M.button(props)
    local p = copy(props)
    local secondary = p.variant == "outline" or p.variant == "secondary"
    p.backgroundColor = p.backgroundColor or (secondary and C.paper or C.orange)
    -- Button 使用 textColor。统一深褐字，避免旧 fontColor 把橘色按钮设成浅字。
    p.textColor = p.textColor or C.ink
    p.borderColor = C.ink
    p.borderWidth = 2
    p.borderRadius = math.min(p.borderRadius or 10, 10)
    p.minHeight = math.max(p.minHeight or 0, 44)
    p.flexShrink = 0
    p.hoverBackgroundColor = secondary and {249, 237, 204, 255} or {245, 176, 98, 255}
    p.pressedBackgroundColor = secondary and C.track or {221, 140, 57, 255}
    p.boxShadow = false
    p.hoverBoxShadow = false
    p.pressedBoxShadow = false
    return UI.Button(p)
end

function M.field(props)
    local p = copy(props)
    p.backgroundColor = {255, 251, 238, 255}
    p.borderColor = C.muted
    p.focusedBorderColor = C.orange
    p.borderWidth = 1.5
    p.borderRadius = 8
    p.textColor = C.ink
    p.placeholderColor = C.muted
    p.flexShrink = 0
    return UI.TextField(p)
end

return M
