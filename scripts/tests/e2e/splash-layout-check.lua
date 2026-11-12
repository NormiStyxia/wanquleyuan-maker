---@diagnostic disable: undefined-global, need-check-nil, undefined-field
local UI = require("urhox-libs/UI")
local targets = {"splash-enter-hint", "splash-health-title", "splash-health-line-1", "splash-health-line-2", "splash-health-line-3", "splash-health-line-4"}
local function verify(label)
    local root = UI.GetRoot()
    local safe = root:FindById("safe_content"):GetAbsoluteLayout()
    local stack = root:FindById("splash-bottom-stack"):GetAbsoluteLayout()
    V.assert(stack.w > 0 and stack.w <= 637.5, label .. " 限宽")
    V.assertNear(stack.x + stack.w / 2, safe.x + safe.w / 2, 1, label .. " 底部容器居中")
    for _, id in ipairs(targets) do
        local widget = root:FindById(id)
        V.assert(widget ~= nil, label .. " 节点存在 " .. id)
        local b = widget:GetAbsoluteLayout()
        V.assert(b.w > 0 and b.h > 0, label .. " 节点非空 " .. id)
        V.assert(b.x >= safe.x - 1 and b.x + b.w <= safe.x + safe.w + 1, label .. " 水平安全区 " .. id)
        V.assert(b.y >= safe.y - 1 and b.y + b.h <= safe.y + safe.h + 1, label .. " 垂直安全区 " .. id)
        local parent = widget.parent:GetAbsoluteLayout()
        V.assert(b.x >= parent.x - 1 and b.x + b.w <= parent.x + parent.w + 1 and b.y >= parent.y - 1 and b.y + b.h <= parent.y + parent.h + 1, label .. " 父容器不裁切 " .. id)
        local vg = UI.GetNVGContext()
        nvgSave(vg)
        nvgFontFace(vg, "sans")
        nvgFontSize(vg, UI.Theme.FontSize(widget.props.fontSize))
        local advance = nvgTextBounds(vg, 0, 0, widget.props.text)
        nvgRestore(vg)
        V.assert(advance <= b.w + 1, label .. " 文字完整宽度 " .. id)
        print(string.format("[SplashLayout] %s %s x=%.1f y=%.1f w=%.1f h=%.1f text=%.1f", label, id, b.x, b.y, b.w, b.h, advance))
    end
end
V.atFrame(12, function() verify("正常安全区") end)
V.atFrame(16, function()
    -- 仅用于测试非零安全区，不向 UI 文档写入设备数值。
    UI.GetRoot():FindById("safe_area"):SetStyle({paddingTop = 62, paddingBottom = 34, paddingLeft = 12, paddingRight = 12})
end)
V.atFrame(20, function() verify("非零安全区") end)
