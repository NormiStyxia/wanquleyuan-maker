--- 消消乐 - 暂停菜单（NanoVG 自绘）
--- 职责：暂停时的半透明遮罩 + 继续/返回大厅按钮

local M = {}

--- 绘制暂停菜单
---@param vg userdata
---@param screenW number
---@param screenH number
---@return table[] buttons { { x, y, w, h, action } }
function M.draw(vg, screenW, screenH)
    -- 半透明遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 150))
    nvgFill(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 240))
    nvgText(vg, screenW / 2, screenH / 2 - 60, "已暂停", nil)

    -- 按钮
    local btnW = 140
    local btnH = 42
    local btnGap = 16
    local btnX = (screenW - btnW) / 2
    local btnY1 = screenH / 2 - 10
    local btnY2 = btnY1 + btnH + btnGap

    local buttons = {}

    -- 继续按钮
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, btnY1, btnW, btnH, 10)
    nvgFillColor(vg, nvgRGBA(60, 120, 180, 230))
    nvgFill(vg)
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, screenW / 2, btnY1 + btnH / 2, "继续游戏", nil)
    buttons[1] = { x = btnX, y = btnY1, w = btnW, h = btnH, action = "resume" }

    -- 返回大厅按钮
    nvgBeginPath(vg)
    nvgRoundedRect(vg, btnX, btnY2, btnW, btnH, 10)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 30))
    nvgFill(vg)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 100))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
    nvgText(vg, screenW / 2, btnY2 + btnH / 2, "返回大厅", nil)
    buttons[2] = { x = btnX, y = btnY2, w = btnW, h = btnH, action = "exit" }

    return buttons
end

--- 检测点击命中
---@param mx number
---@param my number
---@param buttons table[]
---@return string|nil action "resume" | "exit" | nil
function M.hitTest(mx, my, buttons)
    if not buttons then return nil end
    for _, btn in ipairs(buttons) do
        if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
            return btn.action
        end
    end
    return nil
end

return M
