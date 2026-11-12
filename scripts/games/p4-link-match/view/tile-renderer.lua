--- 连连看 - 方块图案绘制
--- 职责：NanoVG 矢量绘制各种图案
--- 每个图案函数签名：function(vg, cx, cy, size, color)

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local function ink(vg,size)
    nvgStrokeColor(vg,Pen.color(C.ink))
    nvgStrokeWidth(vg,math.max(1.5,math.min(2.4,size*0.042)))
    nvgLineCap(vg,NVG_ROUND)
    nvgLineJoin(vg,NVG_ROUND); nvgStroke(vg)
end
local function shine(vg, x, y, r)
    nvgBeginPath(vg)
    nvgCircle(vg, x, y, r)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 185))
    nvgFill(vg)
end
local CELL_CREAM = nvgRGBA(255, 248, 226, 255)
local M = {}
local Sprites=require("shared.rendering.piece-sprites")

-- 图案颜色调色板（24 色，与手绘贴图色板一致的柔和暖调高区分度色彩）
M.COLORS = {
    nvgRGBA(97,  212, 146, 255),   -- 1  薄荷绿
    nvgRGBA(234, 124, 112, 255),   -- 2  珊瑚红
    nvgRGBA(104, 176, 224, 255),   -- 3  晴空蓝
    nvgRGBA(242, 215, 106, 255),   -- 4  奶酪黄
    nvgRGBA(174, 125, 195, 255),   -- 5  薰衣草紫
    nvgRGBA(233, 164, 102, 255),   -- 6  蜜桃橙
    nvgRGBA(88,  200, 177, 255),   -- 7  松石青
    nvgRGBA(238, 142, 195, 255),   -- 8  樱花粉
    nvgRGBA(121, 136, 209, 255),   -- 9  矢车菊蓝
    nvgRGBA(203, 103, 92,  255),   -- 10 陶土红
    nvgRGBA(86,  188, 129, 255),   -- 11 翠竹绿
    nvgRGBA(89,  155, 197, 255),   -- 12 湖海蓝
    nvgRGBA(164, 108, 188, 255),   -- 13 丁香紫
    nvgRGBA(218, 144, 96,  255),   -- 14 杏仁橙
    nvgRGBA(78,  177, 158, 255),   -- 15 碧玉青
    nvgRGBA(244, 191, 107, 255),   -- 16 琥珀黄
    nvgRGBA(133, 193, 118, 255),   -- 17 青苹果绿
    nvgRGBA(185, 116, 178, 255),   -- 18 兰花紫
    nvgRGBA(233, 126, 141, 255),   -- 19 玫瑰粉
    nvgRGBA(148, 185, 105, 255),   -- 20 嫩芽绿
    nvgRGBA(110, 150, 215, 255),   -- 21 钴蓝
    nvgRGBA(215, 172, 99,  255),   -- 22 麦穗金
    nvgRGBA(196, 132, 182, 255),   -- 23 藕荷紫
    nvgRGBA(119, 201, 194, 255),   -- 24 浅湖绿
}

--- 根据 colorIndex 获取颜色
---@param idx number 1-based
---@return userdata color
function M.getColor(idx)
    return M.COLORS[((idx - 1) % #M.COLORS) + 1]
end

-- ============================================================================
-- 矢量图案绘制函数
-- ============================================================================

local shapes = {}

function shapes.circle(vg, cx, cy, size, color)
    local r = size * 0.32
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.square(vg, cx, cy, size, color)
    local s = size * 0.52
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s / 2, cy - s / 2, s, s, s * 0.1)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.triangle(vg, cx, cy, size, color, colorIndex)
    local r = size * 0.42
    -- 奇数 colorIndex 朝上，偶数朝下（增强区分度）
    local up = (not colorIndex) or (colorIndex % 2 == 0)
    -- 正三角形三顶点均匀分布在以 (cx,cy) 为圆心的圆上
    -- 朝上：顶点在 -90°, 30°, 150°；朝下：顶点在 90°, -30°, -150°
    local apex = up and -90 or 90
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy + r * math.sin(math.rad(apex)))
    nvgLineTo(vg, cx + r * math.cos(math.rad(apex + 120)), cy + r * math.sin(math.rad(apex + 120)))
    nvgLineTo(vg, cx + r * math.cos(math.rad(apex + 240)), cy + r * math.sin(math.rad(apex + 240)))
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.star(vg, cx, cy, size, color, colorIndex)
    local outerR = size * 0.38
    -- 奇数 colorIndex: 五角星，偶数: 四角星
    local isFour = colorIndex and (colorIndex % 2 == 0)
    local points = isFour and 4 or 5
    local innerR = outerR * (isFour and 0.38 or 0.42)
    local totalVerts = points * 2
    nvgBeginPath(vg)
    for i = 0, totalVerts - 1 do
        local r = (i % 2 == 0) and outerR or innerR
        local angle = math.rad(-90 + i * (360 / totalVerts))
        local px = cx + r * math.cos(angle)
        local py = cy + r * math.sin(angle)
        if i == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.diamond(vg, cx, cy, size, color)
    local arm = size * 0.32
    local t = size * 0.09
    -- 45° 旋转的十字 = X 形
    nvgSave(vg)
    nvgTranslate(vg, cx, cy)
    nvgRotate(vg, math.rad(45))
    nvgBeginPath(vg)
    nvgRect(vg, -arm, -t, arm * 2, t * 2)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgRect(vg, -t, -arm, t * 2, arm * 2)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgRestore(vg)
end

function shapes.cross(vg, cx, cy, size, color)
    local arm = size * 0.3
    local t = size * 0.1
    nvgBeginPath(vg)
    nvgRect(vg, cx - arm, cy - t, arm * 2, t * 2)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgRect(vg, cx - t, cy - arm, t * 2, arm * 2)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.halfcircle(vg, cx, cy, size, color)
    local r = size * 0.40
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy + r * 0.15, r, math.rad(180), math.rad(0), NVG_CW)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.heart(vg, cx, cy, size, color)
    local s = size * 0.22
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy + s * 1.6)
    nvgBezierTo(vg, cx - s * 0.5, cy + s * 0.8, cx - s * 1.8, cy - s * 0.2, cx - s * 1.0, cy - s * 1.2)
    nvgBezierTo(vg, cx - s * 0.4, cy - s * 1.8, cx, cy - s * 0.9, cx, cy - s * 0.5)
    nvgBezierTo(vg, cx, cy - s * 0.9, cx + s * 0.4, cy - s * 1.8, cx + s * 1.0, cy - s * 1.2)
    nvgBezierTo(vg, cx + s * 1.8, cy - s * 0.2, cx + s * 0.5, cy + s * 0.8, cx, cy + s * 1.6)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

local function roundedPoly(vg, pts, cornerR)
    local n = #pts
    nvgBeginPath(vg)
    for i = 1, n do
        local prev = pts[(i - 2) % n + 1]
        local curr = pts[i]
        local nextPt = pts[i % n + 1]
        local dx1, dy1 = prev[1] - curr[1], prev[2] - curr[2]
        local dx2, dy2 = nextPt[1] - curr[1], nextPt[2] - curr[2]
        local len1 = math.sqrt(dx1 * dx1 + dy1 * dy1)
        local len2 = math.sqrt(dx2 * dx2 + dy2 * dy2)
        local r = math.min(cornerR, len1 * 0.35, len2 * 0.35)
        local p1x, p1y = curr[1] + dx1 / len1 * r, curr[2] + dy1 / len1 * r
        local p2x, p2y = curr[1] + dx2 / len2 * r, curr[2] + dy2 / len2 * r
        if i == 1 then nvgMoveTo(vg, p1x, p1y) else nvgLineTo(vg, p1x, p1y) end
        nvgQuadTo(vg, curr[1], curr[2], p2x, p2y)
    end
    nvgClosePath(vg)
end

function shapes.pentagon(vg, cx, cy, size, color)
    local r = size * 0.30
    local pts = {}
    for i = 0, 4 do
        local angle = math.rad(-90 + i * 72)
        pts[#pts + 1] = { cx + r * math.cos(angle), cy + size * 0.02 + r * math.sin(angle) }
    end
    roundedPoly(vg, pts, size * 0.048)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - r * 0.28, cy - r * 0.22, size * 0.036)
end

function shapes.hexagon(vg, cx, cy, size, color)
    local r = size * 0.30
    local pts = {}
    for i = 0, 5 do
        local angle = math.rad(-90 + i * 60)
        pts[#pts + 1] = { cx + r * math.cos(angle), cy + r * math.sin(angle) }
    end
    roundedPoly(vg, pts, size * 0.045)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - r * 0.28, cy - r * 0.25, size * 0.036)
end

function shapes.arrow(vg, cx, cy, size, color)
    local s = size * 0.28
    local pts = {
        { cx, cy + s },
        { cx + s * 0.82, cy + s * 0.05 },
        { cx + s * 0.36, cy + s * 0.05 },
        { cx + s * 0.36, cy - s * 0.92 },
        { cx - s * 0.36, cy - s * 0.92 },
        { cx - s * 0.36, cy + s * 0.05 },
        { cx - s * 0.82, cy + s * 0.05 },
    }
    roundedPoly(vg, pts, size * 0.035)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - s * 0.14, cy - s * 0.52, size * 0.032)
end

function shapes.lightning(vg, cx, cy, size, color)
    local s = size * 0.145
    local pts = {
        { cx + s * 0.35, cy - s * 1.95 },
        { cx - s * 1.15, cy + s * 0.15 },
        { cx - s * 0.05, cy + s * 0.15 },
        { cx - s * 0.35, cy + s * 1.95 },
        { cx + s * 1.15, cy - s * 0.15 },
        { cx + s * 0.05, cy - s * 0.15 },
    }
    roundedPoly(vg, pts, size * 0.024)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

local function drawTrueCrescent(vg, cx, cy, r, dir, color, size)
    -- 使用两条贝塞尔曲线绘制闭合弯月，不依赖底色遮挡圆
    local tipX = cx + dir * r * 0.38
    local topY = cy - r * 0.86
    local botY = cy + r * 0.86
    nvgBeginPath(vg)
    nvgMoveTo(vg, tipX, topY)
    nvgBezierTo(vg, cx - dir * r * 1.18, cy - r * 0.72, cx - dir * r * 1.18, cy + r * 0.72, tipX, botY)
    nvgBezierTo(vg, cx - dir * r * 0.36, cy + r * 0.42, cx - dir * r * 0.36, cy - r * 0.42, tipX, topY)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg, size)
end

function shapes.crescent(vg, cx, cy, size, color)
    drawTrueCrescent(vg, cx + size * 0.02, cy, size * 0.30, 1, color, size)
    shine(vg, cx - size * 0.12, cy - size * 0.08, size * 0.032)
end

function shapes.shield(vg, cx, cy, size, color)
    local w = size * 0.25
    local h = size * 0.29
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - h)
    nvgLineTo(vg, cx + w, cy - h * 0.5)
    nvgLineTo(vg, cx + w, cy + h * 0.1)
    nvgBezierTo(vg, cx + w, cy + h * 0.65, cx, cy + h, cx, cy + h)
    nvgBezierTo(vg, cx, cy + h, cx - w, cy + h * 0.65, cx - w, cy + h * 0.1)
    nvgLineTo(vg, cx - w, cy - h * 0.5)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - w * 0.38, cy - h * 0.32, size * 0.034)
end

function shapes.plus(vg, cx, cy, size, color)
    local a = size * 0.27
    local t = size * 0.105
    local pts = {
        { cx - t, cy - a }, { cx + t, cy - a },
        { cx + t, cy - t }, { cx + a, cy - t },
        { cx + a, cy + t }, { cx + t, cy + t },
        { cx + t, cy + a }, { cx - t, cy + a },
        { cx - t, cy + t }, { cx - a, cy + t },
        { cx - a, cy - t }, { cx - t, cy - t },
    }
    roundedPoly(vg, pts, size * 0.032)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - t * 0.3, cy - a * 0.58, size * 0.03)
end

function shapes.minus(vg, cx, cy, size, color)
    local arm = size * 0.27
    local t = size * 0.125
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - arm, cy - t, arm * 2, t * 2, t)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - arm * 0.45, cy - t * 0.25, size * 0.032)
end

function shapes.spiral(vg, cx, cy, size, color)
    local r = size * 0.28
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg, size)
    nvgBeginPath(vg)
    local points = 48
    for i = 0, points do
        local t = i / points
        local angle = t * math.pi * 3.5
        local sr = r * 0.72 * t
        local px = cx + sr * math.cos(angle)
        local py = cy + sr * math.sin(angle)
        if i == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    nvgStrokeColor(vg, CELL_CREAM)
    nvgStrokeWidth(vg, size * 0.05)
    nvgLineCap(vg, NVG_ROUND)
    nvgStroke(vg)
end

function shapes.gear(vg, cx, cy, size, color)
    local outerR = size * 0.29
    local innerR = outerR * 0.74
    local teeth = 8
    local pts = {}
    for i = 0, teeth * 2 - 1 do
        local r = (i % 2 == 0) and outerR or innerR
        local angle = math.rad(i * 360 / (teeth * 2))
        pts[#pts + 1] = { cx + r * math.cos(angle), cy + r * math.sin(angle) }
    end
    roundedPoly(vg, pts, size * 0.025)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, innerR * 0.42)
    nvgFillColor(vg, CELL_CREAM)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.hourglass(vg, cx, cy, size, color)
    local w = size * 0.23
    local h = size * 0.27
    local pts = {
        { cx - w, cy - h },
        { cx + w, cy - h },
        { cx + w * 0.22, cy },
        { cx + w, cy + h },
        { cx - w, cy + h },
        { cx - w * 0.22, cy },
    }
    roundedPoly(vg, pts, size * 0.03)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.gem(vg, cx, cy, size, color)
    local w = size * 0.27
    local h = size * 0.29
    local pts = {
        { cx, cy - h },
        { cx + w, cy },
        { cx, cy + h },
        { cx - w, cy },
    }
    roundedPoly(vg, pts, size * 0.038)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - w * 0.25, cy - h * 0.32, size * 0.034)
end

function shapes.flower(vg, cx, cy, size, color)
    local petalR = size * 0.13
    local dist = size * 0.16
    for i = 0, 4 do
        local angle = math.rad(i * 72 - 90)
        local px = cx + dist * math.cos(angle)
        local py = cy + dist * math.sin(angle)
        nvgBeginPath(vg)
        nvgCircle(vg, px, py, petalR)
        nvgFillColor(vg, color)
        nvgFill(vg)
    ink(vg,size)
    end
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, petalR * 0.6)
    nvgFillColor(vg, nvgRGBA(255, 220, 50, 255))
    nvgFill(vg)
    ink(vg,size)
end

function shapes.leaf(vg, cx, cy, size, color)
    drawTrueCrescent(vg, cx + size * 0.02, cy, size * 0.30, 1, color, size)
    shine(vg, cx - size * 0.12, cy - size * 0.08, size * 0.032)
end

function shapes.drop(vg, cx, cy, size, color)
    local r = size * 0.21
    local h = size * 0.18
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - h - r * 0.65)
    nvgBezierTo(vg, cx + r * 1.25, cy - h * 0.15, cx + r * 1.05, cy + h * 0.6, cx, cy + h + r * 0.45)
    nvgBezierTo(vg, cx - r * 1.05, cy + h * 0.6, cx - r * 1.25, cy - h * 0.15, cx, cy - h - r * 0.65)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - r * 0.35, cy + h * 0.1, size * 0.032)
end

function shapes.flame(vg, cx, cy, size, color)
    local s = size * 0.165
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 1.75)
    nvgBezierTo(vg, cx + s * 0.95, cy - s * 0.85, cx + s * 1.55, cy + s * 0.1, cx + s * 0.9, cy + s * 1.2)
    nvgBezierTo(vg, cx + s * 0.55, cy + s * 1.75, cx, cy + s * 1.65, cx, cy + s * 1.65)
    nvgBezierTo(vg, cx, cy + s * 1.65, cx - s * 0.55, cy + s * 1.75, cx - s * 0.9, cy + s * 1.2)
    nvgBezierTo(vg, cx - s * 1.55, cy + s * 0.1, cx - s * 0.95, cy - s * 0.85, cx, cy - s * 1.75)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - s * 0.32, cy + s * 0.35, size * 0.032)
end

-- ============================================================================
-- 复合图案（多个多边形组成）
-- ============================================================================

--- 房子：三角屋顶 + 方形房体
function shapes.house(vg, cx, cy, size, color)
    local s = size * 0.28
    -- 房体
    nvgBeginPath(vg)
    nvgRect(vg, cx - s * 0.7, cy - s * 0.1, s * 1.4, s * 1.1)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 屋顶
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 1.1)
    nvgLineTo(vg, cx + s * 0.9, cy - s * 0.1)
    nvgLineTo(vg, cx - s * 0.9, cy - s * 0.1)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 门
    nvgBeginPath(vg)
    nvgRect(vg, cx - s * 0.18, cy + s * 0.3, s * 0.36, s * 0.7)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 180))
    nvgFill(vg)
    ink(vg,size)
end

--- 鱼：椭圆身体 + 三角尾巴
function shapes.fish(vg, cx, cy, size, color)
    local s = size * 0.38
    -- 身体
    nvgBeginPath(vg)
    nvgEllipse(vg, cx - s * 0.1, cy, s * 0.7, s * 0.4)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 尾巴
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + s * 0.5, cy)
    nvgLineTo(vg, cx + s * 1.0, cy - s * 0.45)
    nvgLineTo(vg, cx + s * 1.0, cy + s * 0.45)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 眼睛
    nvgBeginPath(vg)
    nvgCircle(vg, cx - s * 0.35, cy - s * 0.08, s * 0.1)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
    nvgFill(vg)
    ink(vg,size)
end

--- 树：三角树冠 + 矩形树干
function shapes.tree(vg, cx, cy, size, color)
    local s = size * 0.28
    -- 树冠（两层三角）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 1.2)
    nvgLineTo(vg, cx + s * 0.8, cy + s * 0.1)
    nvgLineTo(vg, cx - s * 0.8, cy + s * 0.1)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 0.6)
    nvgLineTo(vg, cx + s * 0.95, cy + s * 0.55)
    nvgLineTo(vg, cx - s * 0.95, cy + s * 0.55)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 树干
    nvgBeginPath(vg)
    nvgRect(vg, cx - s * 0.15, cy + s * 0.55, s * 0.3, s * 0.5)
    nvgFillColor(vg, nvgRGBA(139, 90, 43, 200))
    nvgFill(vg)
    ink(vg,size)
end

--- 钻石：上三角 + 下倒三角，中间横线
function shapes.jewel(vg, cx, cy, size, color)
    local w = size * 0.28
    local h = size * 0.34
    -- 上部梯形
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - w * 0.5, cy - h)
    nvgLineTo(vg, cx + w * 0.5, cy - h)
    nvgLineTo(vg, cx + w, cy - h * 0.3)
    nvgLineTo(vg, cx - w, cy - h * 0.3)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 下部倒三角
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - w, cy - h * 0.3)
    nvgLineTo(vg, cx + w, cy - h * 0.3)
    nvgLineTo(vg, cx, cy + h)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 分割线
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - w, cy - h * 0.3)
    nvgLineTo(vg, cx + w, cy - h * 0.3)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 120))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)
end

--- 蝴蝶结：左右两个三角 + 中心小圆
function shapes.bowtie(vg, cx, cy, size, color)
    local s = size * 0.28
    -- 左翼
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 0.2)
    nvgLineTo(vg, cx - s, cy - s * 0.8)
    nvgLineTo(vg, cx - s, cy + s * 0.8)
    nvgLineTo(vg, cx, cy + s * 0.2)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 右翼
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 0.2)
    nvgLineTo(vg, cx + s, cy - s * 0.8)
    nvgLineTo(vg, cx + s, cy + s * 0.8)
    nvgLineTo(vg, cx, cy + s * 0.2)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 中心结
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, s * 0.16)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 180))
    nvgFill(vg)
    ink(vg,size)
end

--- 皇冠：底座矩形 + 三个尖角
function shapes.crown(vg, cx, cy, size, color)
    local w = size * 0.3
    local h = size * 0.26
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - w, cy + h)
    nvgLineTo(vg, cx - w, cy - h * 0.2)
    nvgLineTo(vg, cx - w * 0.5, cy + h * 0.2)
    nvgLineTo(vg, cx, cy - h)
    nvgLineTo(vg, cx + w * 0.5, cy + h * 0.2)
    nvgLineTo(vg, cx + w, cy - h * 0.2)
    nvgLineTo(vg, cx + w, cy + h)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 底边装饰
    nvgBeginPath(vg)
    nvgRect(vg, cx - w, cy + h * 0.55, w * 2, h * 0.45)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 宝石
    for _, ox in ipairs({ -w * 0.5, 0, w * 0.5 }) do
        nvgBeginPath(vg)
        nvgCircle(vg, cx + ox, cy + h * 0.75, w * 0.1)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
        nvgFill(vg)
    ink(vg,size)
    end
end

--- 火箭：圆头 + 矩形机身 + 两个尾翼三角
function shapes.rocket(vg, cx, cy, size, color)
    local s = size * 0.145
    -- 左尾翼
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.7, cy + s * 0.5)
    nvgLineTo(vg, cx - s * 1.45, cy + s * 1.55)
    nvgLineTo(vg, cx - s * 0.65, cy + s * 1.35)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 右尾翼
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + s * 0.7, cy + s * 0.5)
    nvgLineTo(vg, cx + s * 1.45, cy + s * 1.55)
    nvgLineTo(vg, cx + s * 0.65, cy + s * 1.35)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 一体化流线机身
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 1.95)
    nvgBezierTo(vg, cx + s * 0.85, cy - s * 1.2, cx + s * 0.9, cy + s * 0.6, cx + s * 0.7, cy + s * 1.45)
    nvgLineTo(vg, cx - s * 0.7, cy + s * 1.45)
    nvgBezierTo(vg, cx - s * 0.9, cy + s * 0.6, cx - s * 0.85, cy - s * 1.2, cx, cy - s * 1.95)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 窗户
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - s * 0.25, s * 0.38)
    nvgFillColor(vg, CELL_CREAM)
    nvgFill(vg)
    ink(vg,size)
end

--- 铃铛：上方圆弧 + 下方梯形 + 小圆锤
function shapes.bell(vg, cx, cy, size, color)
    local s = size * 0.25
    -- 铃舌
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy + s * 0.72, s * 0.22)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 顶部小圆
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - s * 0.98, s * 0.16)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 铃体
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.22, cy - s * 0.9)
    nvgBezierTo(vg, cx - s * 0.82, cy - s * 0.55, cx - s * 0.95, cy + s * 0.3, cx - s * 0.95, cy + s * 0.62)
    nvgLineTo(vg, cx + s * 0.95, cy + s * 0.62)
    nvgBezierTo(vg, cx + s * 0.95, cy + s * 0.3, cx + s * 0.82, cy - s * 0.55, cx + s * 0.22, cy - s * 0.9)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - s * 0.32, cy - s * 0.22, size * 0.032)
end

--- 锚：竖杆 + 底部弧 + 横杆 + 顶圆
function shapes.anchor(vg, cx, cy, size, color)
    local s = size * 0.155
    -- 底部弧（先描黑边再描主色）
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy + s * 0.35, s * 1.15, math.rad(15), math.rad(165), NVG_CW)
    nvgStrokeColor(vg, Pen.color(C.ink))
    nvgStrokeWidth(vg, s * 0.58 + math.max(2.6, size * 0.065))
    nvgLineCap(vg, NVG_ROUND)
    nvgStroke(vg)
    nvgStrokeColor(vg, color)
    nvgStrokeWidth(vg, s * 0.55)
    nvgStroke(vg)
    -- 竖杆
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 0.28, cy - s * 1.0, s * 0.56, s * 2.45, s * 0.18)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 横杆
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 1.05, cy - s * 0.55, s * 2.1, s * 0.48, s * 0.18)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 顶部圆环
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - s * 1.25, s * 0.48)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - s * 1.25, s * 0.2)
    nvgFillColor(vg, CELL_CREAM)
    nvgFill(vg)
end

--- 雪花：六角饱满冰晶
function shapes.snowflake(vg, cx, cy, size, color)
    local r = size * 0.27
    local w = size * 0.075
    for i = 0, 2 do
        local angle = math.rad(i * 60)
        nvgSave(vg)
        nvgTranslate(vg, cx, cy)
        nvgRotate(vg, angle)
        nvgBeginPath(vg)
        nvgRoundedRect(vg, -r, -w / 2, r * 2, w, w / 2)
        nvgFillColor(vg, color)
        nvgFill(vg)
        ink(vg, size)
        nvgRestore(vg)
    end
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, size * 0.11)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx, cy, size * 0.035)
end

--- 音符：饱满八分音符
function shapes.note(vg, cx, cy, size, color)
    local s = size * 0.175
    -- 竖杆與横梁
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 0.05, cy - s * 1.35, s * 0.42, s * 2.25, s * 0.15)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 旗子
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + s * 0.2, cy - s * 1.35)
    nvgBezierTo(vg, cx + s * 1.25, cy - s * 1.1, cx + s * 1.2, cy - s * 0.2, cx + s * 0.3, cy - s * 0.35)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 音符头（椭圆）
    nvgBeginPath(vg)
    nvgEllipse(vg, cx - s * 0.32, cy + s * 0.85, s * 0.72, s * 0.54)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - s * 0.5, cy + s * 0.72, size * 0.03)
end

--- 太阳：中心圆 + 外围三角光芒
function shapes.sun(vg, cx, cy, size, color)
    local r = size * 0.16
    local rayLen = size * 0.12
    local rayW = size * 0.04
    -- 光芒
    for i = 0, 7 do
        local angle = math.rad(i * 45)
        local rx = cx + (r + rayLen * 0.3) * math.cos(angle)
        local ry = cy + (r + rayLen * 0.3) * math.sin(angle)
        local tx = cx + (r + rayLen) * math.cos(angle)
        local ty = cy + (r + rayLen) * math.sin(angle)
        local perpX = -math.sin(angle) * rayW
        local perpY = math.cos(angle) * rayW
        nvgBeginPath(vg)
        nvgMoveTo(vg, rx + perpX, ry + perpY)
        nvgLineTo(vg, tx, ty)
        nvgLineTo(vg, rx - perpX, ry - perpY)
        nvgClosePath(vg)
        nvgFillColor(vg, color)
        nvgFill(vg)
    ink(vg,size)
    end
    -- 中心圆
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 月亮与星：弯月 + 小星星
function shapes.moonstar(vg, cx, cy, size, color)
    drawTrueCrescent(vg, cx - size * 0.02, cy + size * 0.02, size * 0.27, 1, color, size)
    -- 小星星
    local sx = cx + size * 0.15
    local sy = cy - size * 0.13
    local sr = size * 0.085
    local si = sr * 0.45
    nvgBeginPath(vg)
    for i = 0, 9 do
        local pr = (i % 2 == 0) and sr or si
        local angle = math.rad(-90 + i * 36)
        local px = sx + pr * math.cos(angle)
        local py = sy + pr * math.sin(angle)
        if i == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 钥匙：圆形手柄 + 长方齿
function shapes.key(vg, cx, cy, size, color)
    local s = size * 0.145
    -- 杆与齿先画，手柄圆环盖在上方避免内部交叉线
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 0.24, cy - s * 0.4, s * 0.48, s * 2.15, s * 0.12)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx + s * 0.18, cy + s * 0.95, s * 0.62, s * 0.36, s * 0.1)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx + s * 0.18, cy + s * 0.35, s * 0.48, s * 0.34, s * 0.1)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 手柄圆环
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - s * 1.05, s * 0.95)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - s * 1.05, s * 0.42)
    nvgFillColor(vg, CELL_CREAM)
    nvgFill(vg)
    ink(vg,size)
end

--- 旗帜：旗杆 + 三角旗面
function shapes.flag(vg, cx, cy, size, color)
    local s = size * 0.28
    -- 旗杆
    nvgBeginPath(vg)
    nvgRect(vg, cx - s * 0.7, cy - s * 1.1, s * 0.12, s * 2.2)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 旗面
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.58, cy - s * 1.1)
    nvgLineTo(vg, cx + s * 0.7, cy - s * 0.55)
    nvgLineTo(vg, cx - s * 0.58, cy + s * 0.0)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 眼睛：外椭圆 + 内圆（瞳孔）
function shapes.eye(vg, cx, cy, size, color)
    local w = size * 0.32
    local h = size * 0.2
    -- 外形（上下弧）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - w, cy)
    nvgBezierTo(vg, cx - w * 0.5, cy - h * 1.5, cx + w * 0.5, cy - h * 1.5, cx + w, cy)
    nvgBezierTo(vg, cx + w * 0.5, cy + h * 1.5, cx - w * 0.5, cy + h * 1.5, cx - w, cy)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 虹膜
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, h * 0.8)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
    nvgFill(vg)
    ink(vg,size)
    -- 瞳孔
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, h * 0.4)
    nvgFillColor(vg, nvgRGBA(40, 40, 40, 240))
    nvgFill(vg)
    ink(vg,size)
end

-- ============================================================================
-- 新增图案
-- ============================================================================

--- 云朵：三个重叠圆
function shapes.cloud(vg, cx, cy, size, color)
    local s = size * 0.14
    nvgBeginPath(vg)
    nvgCircle(vg, cx - s * 0.9, cy + s * 0.2, s * 0.8)
    nvgCircle(vg, cx, cy - s * 0.4, s * 1.05)
    nvgCircle(vg, cx + s * 0.9, cy + s * 0.15, s * 0.85)
    nvgRect(vg, cx - s * 1.6, cy + s * 0.2, s * 3.2, s * 0.8)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 伞：半圆顶 + 细杆 + 弯钩
function shapes.umbrella(vg, cx, cy, size, color)
    local r = size * 0.3
    -- 伞面
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy - size * 0.05, r, math.rad(180), math.rad(0), NVG_CW)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 伞杆
    nvgBeginPath(vg)
    nvgRect(vg, cx - size * 0.015, cy - size * 0.05, size * 0.03, size * 0.32)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 弯钩
    nvgBeginPath(vg)
    nvgArc(vg, cx + size * 0.06, cy + size * 0.27, size * 0.075, math.rad(0), math.rad(180), NVG_CW)
    nvgStrokeColor(vg, color)
    nvgStrokeWidth(vg, size * 0.03)
    nvgStroke(vg)
end

--- 蘑菇：半圆帽 + 矩形柄
function shapes.mushroom(vg, cx, cy, size, color)
    local s = size * 0.26
    -- 帽
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy - s * 0.1, s * 1.0, math.rad(180), math.rad(0), NVG_CW)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 帽上圆点
    nvgBeginPath(vg)
    nvgCircle(vg, cx - s * 0.4, cy - s * 0.5, s * 0.18)
    nvgCircle(vg, cx + s * 0.3, cy - s * 0.65, s * 0.15)
    nvgCircle(vg, cx + s * 0.05, cy - s * 0.85, s * 0.13)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgFill(vg)
    ink(vg,size)
    -- 柄
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 0.3, cy - s * 0.1, s * 0.6, s * 0.9, s * 0.08)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgFill(vg)
    ink(vg,size)
end

--- 苹果：圆身 + 小柄 + 叶子
function shapes.apple(vg, cx, cy, size, color)
    local r = size * 0.26
    -- 果身
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy + size * 0.02, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 柄
    nvgBeginPath(vg)
    nvgRect(vg, cx - size * 0.015, cy - r - size * 0.06, size * 0.03, size * 0.08)
    nvgFillColor(vg, nvgRGBA(100, 70, 40, 220))
    nvgFill(vg)
    ink(vg,size)
    -- 叶子
    nvgBeginPath(vg)
    nvgEllipse(vg, cx + size * 0.06, cy - r - size * 0.04, size * 0.06, size * 0.03)
    nvgFillColor(vg, nvgRGBA(80, 180, 60, 220))
    nvgFill(vg)
    ink(vg,size)
end

--- 杯子：梯形杯身 + 半圆手柄
function shapes.cup(vg, cx, cy, size, color)
    local s = size * 0.27
    -- 手柄
    nvgBeginPath(vg)
    nvgArc(vg, cx + s * 0.72, cy, s * 0.36, math.rad(-65), math.rad(65), NVG_CW)
    nvgStrokeColor(vg, Pen.color(C.ink))
    nvgStrokeWidth(vg, size * 0.055 + 2.4)
    nvgLineCap(vg, NVG_ROUND)
    nvgStroke(vg)
    nvgStrokeColor(vg, color)
    nvgStrokeWidth(vg, size * 0.048)
    nvgStroke(vg)
    -- 杯身（梯形）
    local pts = {
        { cx - s * 0.85, cy - s * 0.78 },
        { cx + s * 0.75, cy - s * 0.78 },
        { cx + s * 0.58, cy + s * 0.78 },
        { cx - s * 0.68, cy + s * 0.78 },
    }
    roundedPoly(vg, pts, size * 0.035)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - s * 0.38, cy - s * 0.25, size * 0.032)
end

--- 山峰：两座高低不同的三角山
function shapes.mountain(vg, cx, cy, size, color)
    local s = size * 0.28
    -- 大山
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.2, cy - s * 1.0)
    nvgLineTo(vg, cx + s * 0.75, cy + s * 0.78)
    nvgLineTo(vg, cx - s * 1.1, cy + s * 0.78)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 小山
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + s * 0.55, cy - s * 0.45)
    nvgLineTo(vg, cx + s * 1.1, cy + s * 0.78)
    nvgLineTo(vg, cx - s * 0.05, cy + s * 0.78)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 雪顶
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.2, cy - s * 1.0)
    nvgLineTo(vg, cx - s * 0.45, cy - s * 0.55)
    nvgLineTo(vg, cx - s * 0.05, cy - s * 0.65)
    nvgLineTo(vg, cx + s * 0.06, cy - s * 0.55)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 215))
    nvgFill(vg)
    ink(vg,size)
end

--- 手掌：可爱猫爪肉垫造型
function shapes.hand(vg, cx, cy, size, color)
    local s = size * 0.26
    -- 主掌垫
    nvgBeginPath(vg)
    nvgEllipse(vg, cx, cy + s * 0.28, s * 0.75, s * 0.58)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 四个指垫
    local toes = {
        { -s * 0.68, -s * 0.32, s * 0.25 },
        { -s * 0.24, -s * 0.62, s * 0.27 },
        {  s * 0.24, -s * 0.62, s * 0.27 },
        {  s * 0.68, -s * 0.32, s * 0.25 },
    }
    for _, t in ipairs(toes) do
        nvgBeginPath(vg)
        nvgCircle(vg, cx + t[1], cy + t[2], t[3])
        nvgFillColor(vg, color)
        nvgFill(vg)
        ink(vg,size)
    end
    shine(vg, cx - s * 0.25, cy + s * 0.18, size * 0.03)
end

--- 骰子：圆角方块 + 点数
function shapes.dice(vg, cx, cy, size, color)
    local s = size * 0.52
    -- 底色方块
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s / 2, cy - s / 2, s, s, s * 0.16)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 5 点
    local dot = s * 0.085
    local off = s * 0.23
    local dotColor = nvgRGBA(255, 255, 255, 235)
    local dots = {
        { 0, 0 }, { -off, -off }, { off, -off }, { -off, off }, { off, off },
    }
    for _, d in ipairs(dots) do
        nvgBeginPath(vg)
        nvgCircle(vg, cx + d[1], cy + d[2], dot)
        nvgFillColor(vg, dotColor)
        nvgFill(vg)
    end
end

--- 樱桃：两个圆果实 + Y 形茎
function shapes.cherry(vg, cx, cy, size, color)
    local r = size * 0.15
    -- 茎
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - size * 0.22)
    nvgBezierTo(vg, cx - size * 0.05, cy - size * 0.1, cx - size * 0.13, cy + size * 0.02, cx - size * 0.14, cy + size * 0.10)
    nvgMoveTo(vg, cx, cy - size * 0.22)
    nvgBezierTo(vg, cx + size * 0.05, cy - size * 0.1, cx + size * 0.13, cy + size * 0.02, cx + size * 0.14, cy + size * 0.10)
    nvgStrokeColor(vg, Pen.color(C.ink))
    nvgStrokeWidth(vg, math.max(1.8, size * 0.04))
    nvgLineCap(vg, NVG_ROUND)
    nvgStroke(vg)
    -- 叶子
    nvgBeginPath(vg)
    nvgEllipse(vg, cx + size * 0.06, cy - size * 0.22, size * 0.08, size * 0.042)
    nvgFillColor(vg, nvgRGBA(97, 212, 146, 255))
    nvgFill(vg)
    ink(vg,size)
    -- 果实
    nvgBeginPath(vg)
    nvgCircle(vg, cx - size * 0.13, cy + size * 0.12, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx + size * 0.13, cy + size * 0.12, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - size * 0.17, cy + size * 0.08, size * 0.026)
    shine(vg, cx + size * 0.09, cy + size * 0.08, size * 0.026)
end

--- 星星（六角）
function shapes.star6(vg, cx, cy, size, color)
    local outerR = size * 0.31
    local innerR = outerR * 0.54
    local pts = {}
    for i = 0, 11 do
        local r = (i % 2 == 0) and outerR or innerR
        local angle = math.rad(-90 + i * 30)
        pts[#pts + 1] = { cx + r * math.cos(angle), cy + r * math.sin(angle) }
    end
    roundedPoly(vg, pts, size * 0.025)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - outerR * 0.22, cy - outerR * 0.22, size * 0.032)
end

--- 七角星
function shapes.star7(vg, cx, cy, size, color)
    local outerR = size * 0.31
    local innerR = outerR * 0.52
    local pts = {}
    for i = 0, 13 do
        local r = (i % 2 == 0) and outerR or innerR
        local angle = math.rad(-90 + i * (360 / 14))
        pts[#pts + 1] = { cx + r * math.cos(angle), cy + r * math.sin(angle) }
    end
    roundedPoly(vg, pts, size * 0.022)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - outerR * 0.22, cy - outerR * 0.22, size * 0.032)
end

--- 环形甜甜圈
function shapes.donut(vg, cx, cy, size, color)
    local outerR = size * 0.29
    local innerR = outerR * 0.44
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, outerR)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, innerR)
    nvgFillColor(vg, CELL_CREAM)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - outerR * 0.52, cy - outerR * 0.45, size * 0.032)
end

--- 棒棒糖：圆头 + 长杆
function shapes.lollipop(vg, cx, cy, size, color)
    local r = size * 0.22
    -- 杆
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - size * 0.028, cy + r * 0.45, size * 0.056, size * 0.22, size * 0.02)
    nvgFillColor(vg, nvgRGBA(225, 205, 175, 255))
    nvgFill(vg)
    ink(vg,size)
    -- 糖果头
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - size * 0.05, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 白色纹路
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy - size * 0.05, r * 0.55, math.rad(0), math.rad(180), NVG_CW)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 175))
    nvgStrokeWidth(vg, size * 0.04)
    nvgLineCap(vg, NVG_ROUND)
    nvgStroke(vg)
end

--- 船：梯形船体 + 三角帆
function shapes.boat(vg, cx, cy, size, color)
    local s = size * 0.27
    -- 桅杆
    nvgBeginPath(vg)
    nvgRect(vg, cx - s * 0.08, cy - s * 1.05, s * 0.16, s * 1.2)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 帆
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + s * 0.05, cy - s * 1.0)
    nvgLineTo(vg, cx + s * 0.85, cy + s * 0.05)
    nvgLineTo(vg, cx + s * 0.05, cy + s * 0.05)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 225))
    nvgFill(vg)
    ink(vg,size)
    -- 船体（梯形）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 1.05, cy + s * 0.1)
    nvgLineTo(vg, cx + s * 1.05, cy + s * 0.1)
    nvgLineTo(vg, cx + s * 0.72, cy + s * 0.75)
    nvgLineTo(vg, cx - s * 0.72, cy + s * 0.75)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 飞机：俯视对称小飞机
function shapes.plane(vg, cx, cy, size, color)
    local s = size * 0.27
    -- 主翼
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 1.0, cy - s * 0.22, s * 2.0, s * 0.44, s * 0.18)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 尾翼
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 0.55, cy + s * 0.48, s * 1.1, s * 0.3, s * 0.12)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 机身
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 0.26, cy - s * 0.95, s * 0.52, s * 1.9, s * 0.26)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx, cy - s * 0.5, size * 0.032)
end

--- 信封：矩形 + V 形折口
function shapes.envelope(vg, cx, cy, size, color)
    local w = size * 0.28
    local h = size * 0.21
    -- 信封体
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - w, cy - h, w * 2, h * 2, size * 0.04)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- V 形折口
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - w * 0.9, cy - h * 0.85)
    nvgLineTo(vg, cx, cy + h * 0.15)
    nvgLineTo(vg, cx + w * 0.9, cy - h * 0.85)
    nvgStrokeColor(vg, Pen.color(C.ink))
    nvgStrokeWidth(vg, math.max(1.4, size * 0.038))
    nvgLineCap(vg, NVG_ROUND)
    nvgLineJoin(vg, NVG_ROUND)
    nvgStroke(vg)
end

--- 灯泡：圆球 + 矩形底座
function shapes.bulb(vg, cx, cy, size, color)
    local r = size * 0.22
    -- 底座横纹
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - r * 0.52, cy + r * 0.65, r * 1.04, r * 0.58, r * 0.18)
    nvgFillColor(vg, nvgRGBA(215, 205, 185, 255))
    nvgFill(vg)
    ink(vg,size)
    -- 灯泡球体
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - size * 0.06, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    shine(vg, cx - r * 0.35, cy - size * 0.06 - r * 0.35, size * 0.035)
end

--- 月牙（加粗版，与 crescent 不同朝向）
function shapes.moon(vg, cx, cy, size, color)
    drawTrueCrescent(vg, cx - size * 0.02, cy, size * 0.30, -1, color, size)
    shine(vg, cx + size * 0.12, cy - size * 0.08, size * 0.032)
end

--- 四叶草
function shapes.clover(vg, cx, cy, size, color)
    local r = size * 0.135
    local d = size * 0.11
    -- 茎
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy + d)
    nvgLineTo(vg, cx + size * 0.05, cy + size * 0.27)
    nvgStrokeColor(vg, Pen.color(C.ink))
    nvgStrokeWidth(vg, math.max(1.8, size * 0.045))
    nvgLineCap(vg, NVG_ROUND)
    nvgStroke(vg)
    -- 四片叶子
    for _, pos in ipairs({ { 0, -d }, { 0, d }, { -d, 0 }, { d, 0 } }) do
        nvgBeginPath(vg)
        nvgCircle(vg, cx + pos[1], cy - size * 0.02 + pos[2], r)
        nvgFillColor(vg, color)
        nvgFill(vg)
        ink(vg,size)
    end
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - size * 0.02, r * 0.65)
    nvgFillColor(vg, color)
    nvgFill(vg)
end

--- 拱门
function shapes.arch(vg, cx, cy, size, color)
    local w = size * 0.25
    local h = size * 0.27
    local innerW = w * 0.48
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy - h * 0.1, w, math.rad(180), math.rad(0), NVG_CW)
    nvgLineTo(vg, cx + w, cy + h)
    nvgLineTo(vg, cx + innerW, cy + h)
    nvgArc(vg, cx, cy + h * 0.05, innerW, math.rad(0), math.rad(180), NVG_CCW)
    nvgLineTo(vg, cx - innerW, cy + h)
    nvgLineTo(vg, cx - w, cy + h)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 靶心（同心圆环）
function shapes.target(vg, cx, cy, size, color)
    local r = size * 0.29
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r * 0.62)
    nvgFillColor(vg, CELL_CREAM)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r * 0.30)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

M.shapes = shapes

--- 绘制指定图案
---@param vg userdata
---@param artKey string 图案名称
---@param cx number 中心 x
---@param cy number 中心 y
---@param size number 方块尺寸
---@param colorIndex number 颜色索引 (1-based)
function M.drawPattern(vg, artKey, cx, cy, size, colorIndex)
    if Sprites.pattern(vg,artKey,cx,cy,size,colorIndex,"link") then return end
    local color = M.getColor(colorIndex)
    local fn = shapes[artKey]
    if fn then
        fn(vg, cx, cy, size, color, colorIndex)
    else
        -- fallback: 画一个带颜色的圆
        shapes.circle(vg, cx, cy, size, color)
    end
end

return M
