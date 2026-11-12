--- 剧情与小知识共用纸卡画法；坐标沿用地图的 Density 游戏空间。
local UI = require("urhox-libs/UI")
local Density = require("shared.utils.density")
local Art = require("shared.constants.art")
local Pen = require("shared.components.handdrawn")
local M = {}
local C = Art.colors

--- UI 安全区是 UI 基准像素；换成地图坐标后再用于贴边，避免重复应用 DPR。
function M.safeArea(screenW)
    local safe = UI.GetSafeAreaInsets()
    local scale = graphics:GetDPR() * Density.getFactor()
    local ratio = UI.GetScale() / scale
    local offsetX = math.max(0, (graphics:GetWidth() / scale - screenW) / 2)
    return {
        left = math.max(0, safe.left * ratio - offsetX),
        right = math.max(0, safe.right * ratio - offsetX),
        top = safe.top * ratio, bottom = safe.bottom * ratio,
    }
end

function M.width(screenW, maxWidth)
    local safe = M.safeArea(screenW)
    local margin = math.max(14, math.min(22, screenW * 0.04))
    local available = screenW - safe.left - safe.right
    local width = math.min(maxWidth or 480, available - margin * 2)
    return safe.left + (available - width) / 2, width, safe
end

function M.backdrop(vg, w, h)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)
    nvgFillColor(vg, nvgRGBA(63, 56, 36, 100))
    nvgFill(vg)
end

function M.card(vg, x, y, w, h)
    Pen.plaque(vg, x + 2, y + 5, w, h, { 151, 123, 78, 70 }, 1, { 151, 123, 78, 0 })
    Pen.plaque(vg, x, y, w, h, C.paper, 2.5)
end

function M.text(vg, face, x, y, value, size, color, align)
    nvgFontFace(vg, face)
    nvgFontSize(vg, size)
    nvgTextAlign(vg, (align or NVG_ALIGN_LEFT) | NVG_ALIGN_TOP)
    nvgFillColor(vg, Pen.color(color or C.ink))
    nvgText(vg, x, y, value)
end

--- 每行独立绘制，行盒与内容高度使用同一行距，不依赖默认 TextBox 行距。
function M.paragraph(vg, face, x, y, value, size, lineHeight)
    local row = 0
    for line in (value .. "\n"):gmatch("(.-)\n") do
        M.text(vg, face, x, y + row * lineHeight, line, size)
        row = row + 1
    end
end

function M.lineCount(value)
    local _, breaks = value:gsub("\n", "")
    return breaks + 1
end

--- 图片按原比例完整放入矩形区域，没有头像底框、圆形遮罩或装饰描边。
function M.portrait(vg, image, x, y, w, h)
    if not image or image <= 0 then return end
    local iw, ih = nvgImageSize(vg, image)
    if iw <= 0 or ih <= 0 then return end
    local scale = math.min(w / iw, h / ih)
    local dw, dh = iw * scale, ih * scale
    local dx, dy = x + (w - dw) / 2, y + (h - dh) / 2
    nvgBeginPath(vg)
    nvgRect(vg, dx, dy, dw, dh)
    nvgFillPaint(vg, nvgImagePattern(vg, dx, dy, dw, dh, 0, image, 1))
    nvgFill(vg)
end

function M.rule(vg, x, y, width)
    nvgBeginPath(vg)
    nvgMoveTo(vg, x, y)
    nvgQuadTo(vg, x + width * 0.5, y + 1, x + width, y)
    nvgStrokeColor(vg, Pen.color(C.track))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)
end

function M.button(vg, face, x, y, w, h, label)
    Pen.plaque(vg, x, y, w, h, C.orange, 2)
    nvgFontFace(vg, face)
    nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, Pen.color(C.ink))
    nvgText(vg, x + w / 2, y + h / 2, label)
end

return M
