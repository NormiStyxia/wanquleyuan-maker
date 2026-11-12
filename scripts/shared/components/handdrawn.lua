--- 扁平手绘基础形状。结构边保持水平/垂直，手绘感由圆润粗线和插画承担。
local Art = require("shared.constants.art")
local M = {}

function M.color(c)
    return nvgRGBA(c[1], c[2], c[3], c[4] or 255)
end

function M.paint(vg, fill, width, stroke)
    if fill then nvgFillColor(vg, M.color(fill)); nvgFill(vg) end
    nvgStrokeColor(vg, M.color(stroke or Art.colors.ink))
    nvgStrokeWidth(vg, width or 2.5)
    nvgLineJoin(vg, NVG_ROUND)
    nvgStroke(vg)
end

function M.plaque(vg, x, y, w, h, fill, width, stroke)
    local r = math.min(11, h * 0.3, w * 0.3)
    nvgBeginPath(vg)
    nvgMoveTo(vg, x + r, y)
    nvgLineTo(vg, x + w - r, y)
    nvgQuadTo(vg, x + w, y, x + w, y + r)
    nvgLineTo(vg, x + w, y + h - r)
    nvgQuadTo(vg, x + w, y + h, x + w - r, y + h)
    nvgLineTo(vg, x + r, y + h)
    nvgQuadTo(vg, x, y + h, x, y + h - r)
    nvgLineTo(vg, x, y + r)
    nvgQuadTo(vg, x, y, x + r, y)
    nvgClosePath(vg)
    M.paint(vg, fill, width, stroke)
end

function M.circle(vg, cx, cy, r, fill, width, stroke)
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - r)
    nvgBezierTo(vg, cx + r * 0.58, cy - r * 1.02, cx + r * 1.01, cy - r * 0.55, cx + r, cy)
    nvgBezierTo(vg, cx + r, cy + r * 0.57, cx + r * 0.55, cy + r, cx, cy + r)
    nvgBezierTo(vg, cx - r * 0.57, cy + r * 1.01, cx - r, cy + r * 0.54, cx - r, cy)
    nvgBezierTo(vg, cx - r * 1.02, cy - r * 0.56, cx - r * 0.55, cy - r, cx, cy - r)
    nvgClosePath(vg)
    M.paint(vg, fill, width, stroke)
end

function M.text(vg, x, y, text, size, color)
    nvgFontFace(vg, "adv")
    nvgFontSize(vg, size)
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, M.color(color or Art.colors.ink))
    nvgText(vg, x, y, text)
end

return M
