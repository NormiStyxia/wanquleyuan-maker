--- 游戏内纸片画法。只负责表现，不持有棋盘、输入或存档状态。
local Pen = require("shared.components.handdrawn")
local Art = require("shared.constants.art")
local M = { colors = Art.colors }
local C = Art.colors

--- 使用真实字宽拆行；供小型提示/编辑器使用，不截断错误信息。
function M.wrap(vg, value, size, width, face)
    nvgFontFace(vg, face or "sans")
    nvgFontSize(vg, size)
    local rows, row = {}, ""
    for _, code in utf8.codes(tostring(value)) do
        local char = utf8.char(code)
        if char == "\n" then
            rows[#rows + 1], row = row, ""
        elseif row ~= "" and (nvgTextBounds(vg, 0, 0, row .. char) or 0) > width then
            rows[#rows + 1], row = row, char
        else row = row .. char end
    end
    rows[#rows + 1] = row
    return rows
end

function M.text(vg, x, y, text, size, color, align, face)
    nvgFontFace(vg, face or "sans")
    nvgFontSize(vg, size or 16)
    nvgTextAlign(vg, (align or NVG_ALIGN_CENTER) | NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, Pen.color(color or C.ink))
    nvgText(vg, x, y, tostring(text))
end

function M.panel(vg, x, y, w, h, fill, alpha)
    nvgSave(vg)
    if alpha then nvgGlobalAlpha(vg, alpha) end
    Pen.texturedPlaque(vg, x, y, w, h, fill or C.paper, 2.4)
    nvgRestore(vg)
end

function M.button(vg, x, y, w, h, label, primary, enabled, face, alpha)
    nvgSave(vg)
    nvgGlobalAlpha(vg, (alpha or 1) * (enabled == false and 0.5 or 1))
    Pen.texturedPlaque(vg, x, y, w, h, primary and C.orange or C.paper, 2.2)
    M.text(vg, x + w / 2, y + h / 2, label, math.min(16, h * 0.4), C.ink, nil, face)
    nvgRestore(vg)
end

function M.hud(vg, w, h)
    nvgBeginPath(vg); nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, Pen.color(C.paper)); nvgFill(vg)
    nvgBeginPath(vg); nvgMoveTo(vg, 0, h - 1)
    nvgLineTo(vg, w, h - 1)
    nvgStrokeColor(vg, Pen.color(C.ink)); nvgStrokeWidth(vg, 2.3); nvgStroke(vg)
end

--- 角标落在格子内部，不伸进相邻格的点按区域。
function M.selection(vg, x, y, size, t, color)
    -- 翻牌经过侧面时宽度接近零，此时保留侧线，不画挤出卡面的选中框。
    if size<12 then return end
    -- 整圈细框提供持续识别，双层角标提供形状提示；呼吸时也不淡出。
    local breath = (1 + math.sin((t or 0) * 2.4)) * 0.5
    local inset, arm = 3 + breath * 0.6, math.max(5, size * 0.2)
    local alpha = 0.9 + 0.1 * breath
    nvgSave(vg); nvgGlobalAlpha(vg, alpha)
    nvgBeginPath(vg)
    nvgRoundedRect(vg,x+2.5,y+2.5,size-5,size-5,math.min(7,size*.14))
    nvgStrokeColor(vg,Pen.color(C.ink));nvgStrokeWidth(vg,1.3);nvgStroke(vg)
    nvgBeginPath(vg)
    for _, p in ipairs({{x+inset,y+inset,1,1},{x+size-inset,y+inset,-1,1},
        {x+inset,y+size-inset,1,-1},{x+size-inset,y+size-inset,-1,-1}}) do
        nvgMoveTo(vg, p[1] + arm*p[3], p[2])
        nvgLineTo(vg, p[1], p[2]); nvgLineTo(vg, p[1], p[2]+arm*p[4])
    end
    nvgLineCap(vg, NVG_ROUND);nvgLineJoin(vg,NVG_ROUND)
    nvgStrokeColor(vg, Pen.color(C.ink));nvgStrokeWidth(vg,4.2);nvgStroke(vg)
    nvgStrokeColor(vg, Pen.color(color or C.orange));nvgStrokeWidth(vg,2.2);nvgStroke(vg)
    nvgRestore(vg)
end

--- 固定方向的小纸屑；时间只改变距离和透明度，不每帧随机。
function M.burst(vg, cx, cy, size, progress)
    if progress <= 0 or progress >= 1 then return end
    nvgSave(vg); nvgGlobalAlpha(vg, (1-progress)^2)
    for i = 1, 6 do
        local angle = i * math.pi / 3 + 0.2
        local dist = size * (0.32 + progress * 0.48)
        local x, y = cx + math.cos(angle)*dist, cy + math.sin(angle)*dist
        nvgBeginPath(vg); nvgMoveTo(vg, x, y-3)
        nvgLineTo(vg, x+2, y); nvgLineTo(vg, x, y+3); nvgLineTo(vg, x-2, y)
        nvgClosePath(vg); Pen.paint(vg, i % 2 == 0 and C.orange or C.green, 1)
    end
    nvgRestore(vg)
end

return M
