--- 连连看 - 方块图案绘制
--- 职责：NanoVG 矢量绘制各种图案
--- 每个图案函数签名：function(vg, cx, cy, size, color)

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local function ink(vg,size)
    nvgStrokeColor(vg,Pen.color(C.ink))
    nvgStrokeWidth(vg,math.max(1.2,math.min(2.1,size*0.035)))
    nvgLineJoin(vg,NVG_ROUND); nvgStroke(vg)
end
local M = {}
local Sprites=require("shared.rendering.piece-sprites")

-- 图案颜色调色板（24 色，高区分度）
M.COLORS = {
    nvgRGBA(46,  204, 113, 255),   -- 1  绿
    nvgRGBA(231, 76,  60,  255),   -- 2  红
    nvgRGBA(52,  152, 219, 255),   -- 3  蓝
    nvgRGBA(241, 196, 15,  255),   -- 4  黄
    nvgRGBA(155, 89,  182, 255),   -- 5  紫
    nvgRGBA(230, 126, 34,  255),   -- 6  橙
    nvgRGBA(26,  188, 156, 255),   -- 7  青
    nvgRGBA(236, 100, 175, 255),   -- 8  粉
    nvgRGBA(52,  73,  94,  255),   -- 9  深灰蓝
    nvgRGBA(245, 210, 50,  255),   -- 10 亮黄
    nvgRGBA(39,  174, 96,  255),   -- 11 翠绿
    nvgRGBA(41,  128, 185, 255),   -- 12 钢蓝
    nvgRGBA(142, 68,  173, 255),   -- 13 深紫
    nvgRGBA(211, 84,  0,   255),   -- 14 深橙
    nvgRGBA(22,  160, 133, 255),   -- 15 深青
    nvgRGBA(243, 156, 18,  255),   -- 16 琥珀
    nvgRGBA(127, 140, 141, 255),   -- 17 灰
    nvgRGBA(44,  62,  80,  255),   -- 18 暗蓝
    nvgRGBA(230, 80,  100, 255),   -- 19 玫红
    nvgRGBA(100, 180, 80,  255),   -- 20 草绿
    nvgRGBA(80,  100, 200, 255),   -- 21 靛蓝
    nvgRGBA(200, 150, 50,  255),   -- 22 金色
    nvgRGBA(170, 80,  160, 255),   -- 23 兰紫
    nvgRGBA(80,  190, 180, 255),   -- 24 湖绿
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

function shapes.pentagon(vg, cx, cy, size, color)
    local r = size * 0.3
    nvgBeginPath(vg)
    for i = 0, 4 do
        local angle = math.rad(-90 + i * 72)
        local px = cx + r * math.cos(angle)
        local py = cy + r * math.sin(angle)
        if i == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.hexagon(vg, cx, cy, size, color)
    local r = size * 0.3
    nvgBeginPath(vg)
    for i = 0, 5 do
        local angle = math.rad(-90 + i * 60)
        local px = cx + r * math.cos(angle)
        local py = cy + r * math.sin(angle)
        if i == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.arrow(vg, cx, cy, size, color)
    local s = size * 0.38
    local blueColor = nvgRGBA(52, 152, 219, 255)
    -- 朝下箭头
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy + s)
    nvgLineTo(vg, cx + s * 0.7, cy)
    nvgLineTo(vg, cx + s * 0.25, cy)
    nvgLineTo(vg, cx + s * 0.25, cy - s)
    nvgLineTo(vg, cx - s * 0.25, cy - s)
    nvgLineTo(vg, cx - s * 0.25, cy)
    nvgLineTo(vg, cx - s * 0.7, cy)
    nvgClosePath(vg)
    nvgFillColor(vg, blueColor)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.lightning(vg, cx, cy, size, color)
    local s = size * 0.21
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + s * 0.2, cy - s * 2.2)
    nvgLineTo(vg, cx - s * 1.0, cy + s * 0.2)
    nvgLineTo(vg, cx + s * 0.1, cy + s * 0.2)
    nvgLineTo(vg, cx - s * 0.2, cy + s * 2.2)
    nvgLineTo(vg, cx + s * 1.0, cy - s * 0.2)
    nvgLineTo(vg, cx - s * 0.1, cy - s * 0.2)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.crescent(vg, cx, cy, size, color)
    local r = size * 0.3
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx + r * 0.4, cy - r * 0.15, r * 0.78)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgFill(vg)
    ink(vg,size)
end

function shapes.shield(vg, cx, cy, size, color)
    local w = size * 0.25
    local h = size * 0.34
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - h)
    nvgLineTo(vg, cx + w, cy - h * 0.5)
    nvgLineTo(vg, cx + w, cy + h * 0.1)
    nvgBezierTo(vg, cx + w, cy + h * 0.6, cx, cy + h, cx, cy + h)
    nvgBezierTo(vg, cx, cy + h, cx - w, cy + h * 0.6, cx - w, cy + h * 0.1)
    nvgLineTo(vg, cx - w, cy - h * 0.5)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.plus(vg, cx, cy, size, color)
    local arm = size * 0.28
    local t = size * 0.1
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - arm, cy - t, arm * 2, t * 2, 2)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - t, cy - arm, t * 2, arm * 2, 2)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.minus(vg, cx, cy, size, color)
    local arm = size * 0.28
    local t = size * 0.1
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - arm, cy - t, arm * 2, t * 2, t)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.spiral(vg, cx, cy, size, color)
    local maxR = size * 0.38
    nvgBeginPath(vg)
    local points = 60
    for i = 0, points do
        local t = i / points
        local angle = t * math.pi * 4
        local r = maxR * t
        local px = cx + r * math.cos(angle)
        local py = cy + r * math.sin(angle)
        if i == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    nvgStrokeColor(vg, color)
    nvgStrokeWidth(vg, size * 0.09)
    nvgLineCap(vg, NVG_ROUND)
    nvgStroke(vg)
end

function shapes.gear(vg, cx, cy, size, color)
    local outerR = size * 0.3
    local innerR = outerR * 0.7
    local teeth = 8
    nvgBeginPath(vg)
    for i = 0, teeth * 2 - 1 do
        local r = (i % 2 == 0) and outerR or innerR
        local angle = math.rad(i * 360 / (teeth * 2))
        local px = cx + r * math.cos(angle)
        local py = cy + r * math.sin(angle)
        if i == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, innerR * 0.35)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgFill(vg)
    ink(vg,size)
end

function shapes.hourglass(vg, cx, cy, size, color)
    local w = size * 0.22
    local h = size * 0.32
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - w, cy - h)
    nvgLineTo(vg, cx + w, cy - h)
    nvgLineTo(vg, cx + w * 0.15, cy)
    nvgLineTo(vg, cx + w, cy + h)
    nvgLineTo(vg, cx - w, cy + h)
    nvgLineTo(vg, cx - w * 0.15, cy)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.gem(vg, cx, cy, size, color)
    local w = size * 0.26
    local h = size * 0.34
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - h)
    nvgLineTo(vg, cx + w, cy - h * 0.3)
    nvgLineTo(vg, cx + w * 0.6, cy - h * 0.3)
    nvgLineTo(vg, cx, cy + h)
    nvgLineTo(vg, cx - w * 0.6, cy - h * 0.3)
    nvgLineTo(vg, cx - w, cy - h * 0.3)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
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
    -- 黄色月亮（弯月形）
    local moonColor = nvgRGBA(255, 210, 50, 255)
    local r = size * 0.32
    -- 大圆（月亮主体）
    nvgBeginPath(vg)
    nvgCircle(vg, cx - size * 0.03, cy, r)
    nvgFillColor(vg, moonColor)
    nvgFill(vg)
    ink(vg,size)
    -- 用白色小圆遮挡形成弯月
    nvgBeginPath(vg)
    nvgCircle(vg, cx + r * 0.4, cy - r * 0.2, r * 0.75)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgFill(vg)
    ink(vg,size)
end

function shapes.drop(vg, cx, cy, size, color)
    local r = size * 0.18
    local h = size * 0.16
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - h - r)
    nvgBezierTo(vg, cx + r * 1.2, cy - h * 0.2, cx + r, cy + h * 0.5, cx, cy + h + r * 0.5)
    nvgBezierTo(vg, cx - r, cy + h * 0.5, cx - r * 1.2, cy - h * 0.2, cx, cy - h - r)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function shapes.flame(vg, cx, cy, size, color)
    local s = size * 0.16
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 2.0)
    nvgBezierTo(vg, cx + s * 0.8, cy - s * 1.0, cx + s * 1.4, cy, cx + s * 0.8, cy + s * 1.2)
    nvgBezierTo(vg, cx + s * 0.5, cy + s * 1.8, cx, cy + s * 1.5, cx, cy + s * 1.5)
    nvgBezierTo(vg, cx, cy + s * 1.5, cx - s * 0.5, cy + s * 1.8, cx - s * 0.8, cy + s * 1.2)
    nvgBezierTo(vg, cx - s * 1.4, cy, cx - s * 0.8, cy - s * 1.0, cx, cy - s * 2.0)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
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
    local s = size * 0.12
    -- 机身
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 0.8, cy - s * 1.5, s * 1.6, s * 3.0, s * 0.3)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 头部
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 2.8)
    nvgBezierTo(vg, cx + s * 0.6, cy - s * 2.0, cx + s * 0.8, cy - s * 1.5, cx + s * 0.8, cy - s * 1.2)
    nvgLineTo(vg, cx - s * 0.8, cy - s * 1.2)
    nvgBezierTo(vg, cx - s * 0.8, cy - s * 1.5, cx - s * 0.6, cy - s * 2.0, cx, cy - s * 2.8)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 左尾翼
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.8, cy + s * 0.8)
    nvgLineTo(vg, cx - s * 1.5, cy + s * 1.8)
    nvgLineTo(vg, cx - s * 0.8, cy + s * 1.5)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 右尾翼
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + s * 0.8, cy + s * 0.8)
    nvgLineTo(vg, cx + s * 1.5, cy + s * 1.8)
    nvgLineTo(vg, cx + s * 0.8, cy + s * 1.5)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 窗户
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - s * 0.6, s * 0.35)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 180))
    nvgFill(vg)
    ink(vg,size)
end

--- 铃铛：上方圆弧 + 下方梯形 + 小圆锤
function shapes.bell(vg, cx, cy, size, color)
    local s = size * 0.26
    -- 铃体
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.2, cy - s * 1.0)
    nvgBezierTo(vg, cx - s * 0.8, cy - s * 0.6, cx - s * 0.9, cy + s * 0.3, cx - s * 0.9, cy + s * 0.6)
    nvgLineTo(vg, cx + s * 0.9, cy + s * 0.6)
    nvgBezierTo(vg, cx + s * 0.9, cy + s * 0.3, cx + s * 0.8, cy - s * 0.6, cx + s * 0.2, cy - s * 1.0)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 铃舌
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy + s * 0.75, s * 0.18)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 顶部小圆
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - s * 1.1, s * 0.14)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 锚：竖杆 + 底部弧 + 横杆 + 顶圆
function shapes.anchor(vg, cx, cy, size, color)
    local s = size * 0.14
    -- 竖杆
    nvgBeginPath(vg)
    nvgRect(vg, cx - s * 0.25, cy - s * 1.2, s * 0.5, s * 2.6)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 横杆
    nvgBeginPath(vg)
    nvgRect(vg, cx - s * 1.2, cy - s * 0.7, s * 2.4, s * 0.4)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 底部弧
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy + s * 0.5, s * 1.1, math.rad(0), math.rad(180), NVG_CW)
    nvgStrokeColor(vg, color)
    nvgStrokeWidth(vg, s * 0.4)
    nvgStroke(vg)
    -- 顶部圆环
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - s * 1.6, s * 0.4)
    nvgStrokeColor(vg, color)
    nvgStrokeWidth(vg, s * 0.25)
    nvgStroke(vg)
end

--- 雪花：三条交叉线 + 六个端点菱形
function shapes.snowflake(vg, cx, cy, size, color)
    local r = size * 0.3
    local t = size * 0.025
    for i = 0, 2 do
        local angle = math.rad(i * 60)
        local x1 = cx + r * math.cos(angle)
        local y1 = cy + r * math.sin(angle)
        local x2 = cx - r * math.cos(angle)
        local y2 = cy - r * math.sin(angle)
        nvgBeginPath(vg)
        nvgMoveTo(vg, x1, y1)
        nvgLineTo(vg, x2, y2)
        nvgStrokeColor(vg, color)
        nvgStrokeWidth(vg, t * 2)
        nvgStroke(vg)
        -- 分支
        for _, sign in ipairs({ 1, -1 }) do
            local bx = cx + r * 0.55 * math.cos(angle) * sign
            local by = cy + r * 0.55 * math.sin(angle) * sign
            local ba = angle + math.rad(45)
            local bb = angle - math.rad(45)
            local bl = r * 0.25
            nvgBeginPath(vg)
            nvgMoveTo(vg, bx, by)
            nvgLineTo(vg, bx + bl * math.cos(ba) * sign, by + bl * math.sin(ba) * sign)
            nvgStroke(vg)
            nvgBeginPath(vg)
            nvgMoveTo(vg, bx, by)
            nvgLineTo(vg, bx + bl * math.cos(bb) * sign, by + bl * math.sin(bb) * sign)
            nvgStroke(vg)
        end
    end
    -- 中心
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, t * 3)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 音符：圆头 + 竖杆 + 旗子
function shapes.note(vg, cx, cy, size, color)
    local s = size * 0.14
    -- 音符头（椭圆）
    nvgBeginPath(vg)
    nvgEllipse(vg, cx - s * 0.3, cy + s * 1.2, s * 0.6, s * 0.45)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 竖杆
    nvgBeginPath(vg)
    nvgRect(vg, cx + s * 0.15, cy - s * 1.3, s * 0.2, s * 2.6)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 旗子
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + s * 0.35, cy - s * 1.3)
    nvgBezierTo(vg, cx + s * 1.2, cy - s * 1.0, cx + s * 1.0, cy - s * 0.4, cx + s * 0.35, cy - s * 0.4)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
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
    local r = size * 0.28
    -- 弯月（大圆减小圆）
    nvgBeginPath(vg)
    nvgCircle(vg, cx - size * 0.04, cy, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx + r * 0.35, cy - r * 0.2, r * 0.78)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgFill(vg)
    ink(vg,size)
    -- 小星星
    local sx = cx + size * 0.2
    local sy = cy - size * 0.16
    local sr = size * 0.07
    local si = sr * 0.42
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
    local s = size * 0.13
    -- 手柄圆环
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - s * 1.2, s * 0.9)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - s * 1.2, s * 0.45)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgFill(vg)
    ink(vg,size)
    -- 杆
    nvgBeginPath(vg)
    nvgRect(vg, cx - s * 0.2, cy - s * 0.4, s * 0.4, s * 2.2)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 齿
    nvgBeginPath(vg)
    nvgRect(vg, cx + s * 0.2, cy + s * 1.0, s * 0.5, s * 0.3)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgRect(vg, cx + s * 0.2, cy + s * 0.4, s * 0.4, s * 0.3)
    nvgFillColor(vg, color)
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
    local s = size * 0.24
    -- 杯身（梯形）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.85, cy - s * 0.7)
    nvgLineTo(vg, cx + s * 0.85, cy - s * 0.7)
    nvgLineTo(vg, cx + s * 0.65, cy + s * 0.7)
    nvgLineTo(vg, cx - s * 0.65, cy + s * 0.7)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 手柄
    nvgBeginPath(vg)
    nvgArc(vg, cx + s * 0.85, cy, s * 0.35, math.rad(-60), math.rad(60), NVG_CW)
    nvgStrokeColor(vg, color)
    nvgStrokeWidth(vg, size * 0.04)
    nvgStroke(vg)
end

--- 山峰：两座高低不同的三角山
function shapes.mountain(vg, cx, cy, size, color)
    local s = size * 0.28
    -- 大山
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.2, cy - s * 1.1)
    nvgLineTo(vg, cx + s * 0.8, cy + s * 0.8)
    nvgLineTo(vg, cx - s * 1.2, cy + s * 0.8)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 小山
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + s * 0.6, cy - s * 0.5)
    nvgLineTo(vg, cx + s * 1.2, cy + s * 0.8)
    nvgLineTo(vg, cx + s * 0.0, cy + s * 0.8)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 雪顶
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.2, cy - s * 1.1)
    nvgLineTo(vg, cx - s * 0.45, cy - s * 0.65)
    nvgLineTo(vg, cx - s * 0.05, cy - s * 0.75)
    nvgLineTo(vg, cx + s * 0.05, cy - s * 0.65)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgFill(vg)
    ink(vg,size)
end

--- 手掌：五指张开的简化手型
function shapes.hand(vg, cx, cy, size, color)
    local s = size * 0.1
    -- 掌心
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 1.2, cy - s * 0.2, s * 2.4, s * 2.0, s * 0.4)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 五根手指
    local fingers = {
        { -s * 0.9, -s * 0.2, s * 0.35, s * 1.2 },
        { -s * 0.35, -s * 0.2, s * 0.35, s * 1.6 },
        { s * 0.15, -s * 0.2, s * 0.35, s * 1.5 },
        { s * 0.65, -s * 0.2, s * 0.35, s * 1.2 },
    }
    for _, f in ipairs(fingers) do
        nvgBeginPath(vg)
        nvgRoundedRect(vg, cx + f[1], cy - f[4], f[3], f[4], s * 0.15)
        nvgFillColor(vg, color)
        nvgFill(vg)
    ink(vg,size)
    end
    -- 拇指
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 1.5, cy + s * 0.1, s * 0.9, s * 0.35, s * 0.15)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 骰子：圆角方块 + 点数
function shapes.dice(vg, cx, cy, size, color)
    local s = size * 0.5
    -- 底色方块
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s / 2, cy - s / 2, s, s, s * 0.12)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 5 点
    local dot = s * 0.08
    local off = s * 0.22
    local dotColor = nvgRGBA(255, 255, 255, 230)
    local dots = {
        { 0, 0 }, { -off, -off }, { off, -off }, { -off, off }, { off, off },
    }
    for _, d in ipairs(dots) do
        nvgBeginPath(vg)
        nvgCircle(vg, cx + d[1], cy + d[2], dot)
        nvgFillColor(vg, dotColor)
        nvgFill(vg)
    ink(vg,size)
    end
end

--- 樱桃：两个圆果实 + Y 形茎
function shapes.cherry(vg, cx, cy, size, color)
    local r = size * 0.13
    -- 茎
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - size * 0.22)
    nvgBezierTo(vg, cx - size * 0.05, cy - size * 0.1, cx - size * 0.12, cy + size * 0.02, cx - size * 0.13, cy + size * 0.08)
    nvgStrokeColor(vg, nvgRGBA(100, 70, 40, 220))
    nvgStrokeWidth(vg, size * 0.025)
    nvgStroke(vg)
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - size * 0.22)
    nvgBezierTo(vg, cx + size * 0.05, cy - size * 0.1, cx + size * 0.12, cy + size * 0.02, cx + size * 0.13, cy + size * 0.08)
    nvgStrokeColor(vg, nvgRGBA(100, 70, 40, 220))
    nvgStrokeWidth(vg, size * 0.025)
    nvgStroke(vg)
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
    -- 叶子
    nvgBeginPath(vg)
    nvgEllipse(vg, cx + size * 0.05, cy - size * 0.24, size * 0.06, size * 0.03)
    nvgFillColor(vg, nvgRGBA(80, 180, 60, 220))
    nvgFill(vg)
    ink(vg,size)
end

--- 星星（六角）
function shapes.star6(vg, cx, cy, size, color)
    local outerR = size * 0.3
    local innerR = outerR * 0.5
    nvgBeginPath(vg)
    for i = 0, 11 do
        local r = (i % 2 == 0) and outerR or innerR
        local angle = math.rad(-90 + i * 30)
        local px = cx + r * math.cos(angle)
        local py = cy + r * math.sin(angle)
        if i == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 七角星
function shapes.star7(vg, cx, cy, size, color)
    local outerR = size * 0.3
    local innerR = outerR * 0.45
    nvgBeginPath(vg)
    for i = 0, 13 do
        local r = (i % 2 == 0) and outerR or innerR
        local angle = math.rad(-90 + i * (360 / 14))
        local px = cx + r * math.cos(angle)
        local py = cy + r * math.sin(angle)
        if i == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 环形甜甜圈
function shapes.donut(vg, cx, cy, size, color)
    local outerR = size * 0.28
    local innerR = outerR * 0.48
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, outerR)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, innerR)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgFill(vg)
    ink(vg,size)
end

--- 棒棒糖：圆头 + 长杆
function shapes.lollipop(vg, cx, cy, size, color)
    local r = size * 0.2
    -- 杆
    nvgBeginPath(vg)
    nvgRect(vg, cx - size * 0.02, cy + r * 0.5, size * 0.04, size * 0.2)
    nvgFillColor(vg, nvgRGBA(200, 180, 150, 220))
    nvgFill(vg)
    ink(vg,size)
    -- 糖果头（螺旋效果用两半色模拟）
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - size * 0.02, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 白色纹路
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy - size * 0.02, r * 0.6, math.rad(0), math.rad(180), NVG_CW)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 160))
    nvgStrokeWidth(vg, size * 0.04)
    nvgStroke(vg)
end

--- 船：梯形船体 + 三角帆
function shapes.boat(vg, cx, cy, size, color)
    local s = size * 0.26
    -- 船体（梯形）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 1.0, cy + s * 0.1)
    nvgLineTo(vg, cx + s * 1.0, cy + s * 0.1)
    nvgLineTo(vg, cx + s * 0.7, cy + s * 0.7)
    nvgLineTo(vg, cx - s * 0.7, cy + s * 0.7)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 桅杆
    nvgBeginPath(vg)
    nvgRect(vg, cx - s * 0.06, cy - s * 1.1, s * 0.12, s * 1.2)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 帆
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + s * 0.06, cy - s * 1.0)
    nvgLineTo(vg, cx + s * 0.8, cy + s * 0.0)
    nvgLineTo(vg, cx + s * 0.06, cy + s * 0.0)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgFill(vg)
    ink(vg,size)
end

--- 飞机：简化侧视图
function shapes.plane(vg, cx, cy, size, color)
    local s = size * 0.14
    -- 机身
    nvgBeginPath(vg)
    nvgEllipse(vg, cx, cy, s * 2.0, s * 0.45)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 主翼
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.2, cy)
    nvgLineTo(vg, cx + s * 0.3, cy - s * 1.4)
    nvgLineTo(vg, cx + s * 0.7, cy - s * 1.4)
    nvgLineTo(vg, cx + s * 0.3, cy)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 尾翼
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 1.5, cy)
    nvgLineTo(vg, cx - s * 1.2, cy - s * 0.8)
    nvgLineTo(vg, cx - s * 0.9, cy)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 信封：矩形 + V 形折口
function shapes.envelope(vg, cx, cy, size, color)
    local w = size * 0.32
    local h = size * 0.22
    -- 信封体
    nvgBeginPath(vg)
    nvgRect(vg, cx - w, cy - h, w * 2, h * 2)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- V 形折口
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - w, cy - h)
    nvgLineTo(vg, cx, cy + h * 0.15)
    nvgLineTo(vg, cx + w, cy - h)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 180))
    nvgStrokeWidth(vg, size * 0.025)
    nvgStroke(vg)
end

--- 灯泡：圆球 + 矩形底座
function shapes.bulb(vg, cx, cy, size, color)
    local r = size * 0.2
    -- 灯泡球体
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - size * 0.05, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 灯泡下方收束
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - r * 0.65, cy + r * 0.6)
    nvgLineTo(vg, cx - r * 0.4, cy + r * 1.3)
    nvgLineTo(vg, cx + r * 0.4, cy + r * 1.3)
    nvgLineTo(vg, cx + r * 0.65, cy + r * 0.6)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 底座横纹
    nvgBeginPath(vg)
    nvgRect(vg, cx - r * 0.38, cy + r * 1.3, r * 0.76, r * 0.25)
    nvgFillColor(vg, nvgRGBA(200, 200, 200, 220))
    nvgFill(vg)
    ink(vg,size)
end

--- 月牙（加粗版，与 crescent 不同朝向）
function shapes.moon(vg, cx, cy, size, color)
    local r = size * 0.3
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx - r * 0.4, cy - r * 0.2, r * 0.75)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgFill(vg)
    ink(vg,size)
end

--- 四叶草
function shapes.clover(vg, cx, cy, size, color)
    local r = size * 0.13
    local d = size * 0.1
    -- 四片叶子
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - d, r)
    nvgCircle(vg, cx, cy + d, r)
    nvgCircle(vg, cx - d, cy, r)
    nvgCircle(vg, cx + d, cy, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 茎
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy + d)
    nvgLineTo(vg, cx + size * 0.04, cy + size * 0.25)
    nvgStrokeColor(vg, color)
    nvgStrokeWidth(vg, size * 0.03)
    nvgStroke(vg)
end

--- 拱门
function shapes.arch(vg, cx, cy, size, color)
    local w = size * 0.26
    local h = size * 0.3
    local t = size * 0.07
    -- 左柱
    nvgBeginPath(vg)
    nvgRect(vg, cx - w, cy - h * 0.2, t, h * 1.2)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 右柱
    nvgBeginPath(vg)
    nvgRect(vg, cx + w - t, cy - h * 0.2, t, h * 1.2)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 拱顶
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy - h * 0.2, w, math.rad(180), math.rad(0), NVG_CW)
    nvgStrokeColor(vg, color)
    nvgStrokeWidth(vg, t)
    nvgStroke(vg)
end

--- 靶心（同心圆环）
function shapes.target(vg, cx, cy, size, color)
    local r = size * 0.3
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r * 0.65)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r * 0.35)
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
