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

--- 带奶油外衬边、底部厚边、内嵌细框与手绘横纹的立体木牌/纸牌。
function M.texturedPlaque(vg, x, y, w, h, fill, width, opts)
    opts = opts or {}
    local c = fill or Art.colors.paper
    local r = math.min(11, h * 0.3, w * 0.3)
    local shadowY = opts.shadowOffset or 3.5

    -- 1. 底部立体厚边阴影
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y + shadowY, w, h, r + 1)
    nvgFillColor(vg, nvgRGBA(110, 86, 50, 90))
    nvgFill(vg)

    -- 2. 奶油色外衬边（参考旅行青蛙的双层边轮廓）
    if opts.outerRim ~= false then
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x - 1.5, y - 1.5, w + 3, h + 3, r + 1.5)
        nvgFillColor(vg, nvgRGBA(255, 250, 236, 235))
        nvgFill(vg)
        nvgStrokeColor(vg, nvgRGBA(138, 112, 72, 150))
        nvgStrokeWidth(vg, 1.2)
        nvgStroke(vg)
    end

    -- 3. 牌面底色
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, r)
    nvgFillColor(vg, M.color(c))
    nvgFill(vg)

    -- 4. 顶部高光与底部内斜切厚边
    if h >= 26 and w >= 36 then
        local glossH = math.min(10, math.max(5, h * 0.16))
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x + 2.5, y + 2, w - 5, glossH, math.max(3, r - 3))
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 95))
        nvgFill(vg)

        local bevelH = math.min(8, math.max(4, h * 0.12))
        local br = math.max(0, math.floor(c[1] * 0.84))
        local bg = math.max(0, math.floor(c[2] * 0.78))
        local bb = math.max(0, math.floor(c[3] * 0.68))
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x + 2, y + h - bevelH - 1.5, w - 4, bevelH, math.max(3, r - 3))
        nvgFillColor(vg, nvgRGBA(br, bg, bb, 120))
        nvgFill(vg)

        -- 5. 手绘横纹肌理（低对比度断续木纹/纸纹）
        local gr = math.max(0, math.floor(c[1] * 0.72))
        local gg = math.max(0, math.floor(c[2] * 0.66))
        local gb = math.max(0, math.floor(c[3] * 0.54))
        local rows = h >= 80 and 5 or 3
        nvgLineCap(vg, NVG_ROUND)
        for i = 1, rows do
            local gy = y + h * (i / (rows + 1))
            local padL = (i % 2 == 1) and 8 or 14
            local segW = (i % 2 == 1) and (w - 16) or (w * 0.52)
            if segW > 12 then
                nvgBeginPath(vg)
                nvgMoveTo(vg, x + padL, gy)
                nvgLineTo(vg, x + padL + segW, gy)
                nvgStrokeColor(vg, nvgRGBA(gr, gg, gb, 40))
                nvgStrokeWidth(vg, 1.4)
                nvgStroke(vg)
            end
        end

        -- 6. 内嵌细框
        local inset = h >= 80 and 4.5 or 3.2
        nvgBeginPath(vg)
        nvgRoundedRect(vg, x + inset, y + inset, w - inset * 2, h - inset * 2, math.max(4, r - 2.5))
        nvgStrokeColor(vg, nvgRGBA(120, 96, 60, 85))
        nvgStrokeWidth(vg, 1.1)
        nvgStroke(vg)
    end

    -- 7. 主深褐描边
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, r)
    nvgStrokeColor(vg, M.color(opts.stroke or Art.colors.ink))
    nvgStrokeWidth(vg, width or 2.4)
    nvgLineJoin(vg, NVG_ROUND)
    nvgStroke(vg)
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
