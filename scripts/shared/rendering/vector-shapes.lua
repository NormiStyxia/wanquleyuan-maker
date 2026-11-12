--- 记忆翻牌 - 矢量图案库
--- 职责：绘制所有卡牌正面的矢量图案
--- 签名统一：function(vg, cx, cy, size, color)

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local function ink(vg,size)
    nvgStrokeColor(vg,Pen.color(C.ink))
    nvgStrokeWidth(vg,math.max(1.2,math.min(2.1,size*0.035)))
    nvgLineJoin(vg,NVG_ROUND); nvgStroke(vg)
end
local M = {}

function M.circle(vg, cx, cy, size, color)
    local r = size * 0.38
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function M.square(vg, cx, cy, size, color)
    local s = size * 0.6
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s / 2, cy - s / 2, s, s, s * 0.1)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function M.triangle(vg, cx, cy, size, color)
    local r = size * 0.38
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - r)
    nvgLineTo(vg, cx + r * math.cos(math.rad(-30)), cy + r * math.sin(math.rad(-30)))
    nvgLineTo(vg, cx - r * math.cos(math.rad(-30)), cy + r * math.sin(math.rad(-30)))
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function M.star(vg, cx, cy, size, color)
    local outerR = size * 0.38
    local innerR = outerR * 0.42
    nvgBeginPath(vg)
    for i = 0, 9 do
        local r = (i % 2 == 0) and outerR or innerR
        local angle = math.rad(-90 + i * 36)
        local px = cx + r * math.cos(angle)
        local py = cy + r * math.sin(angle)
        if i == 0 then
            nvgMoveTo(vg, px, py)
        else
            nvgLineTo(vg, px, py)
        end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function M.diamond(vg, cx, cy, size, color)
    local w = size * 0.3
    local h = size * 0.42
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - h)
    nvgLineTo(vg, cx + w, cy)
    nvgLineTo(vg, cx, cy + h)
    nvgLineTo(vg, cx - w, cy)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function M.cross(vg, cx, cy, size, color)
    local arm = size * 0.36
    local t = size * 0.16
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

function M.halfcircle(vg, cx, cy, size, color)
    local r = size * 0.38
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy + r * 0.15, r, math.rad(180), math.rad(0), NVG_CW)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function M.heart(vg, cx, cy, size, color)
    local s = size * 0.25
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy + s * 1.5)
    nvgBezierTo(vg, cx - s * 0.5, cy + s * 0.8, cx - s * 1.7, cy - s * 0.2, cx - s * 1.0, cy - s * 1.1)
    nvgBezierTo(vg, cx - s * 0.4, cy - s * 1.7, cx, cy - s * 0.9, cx, cy - s * 0.5)
    nvgBezierTo(vg, cx, cy - s * 0.9, cx + s * 0.4, cy - s * 1.7, cx + s * 1.0, cy - s * 1.1)
    nvgBezierTo(vg, cx + s * 1.7, cy - s * 0.2, cx + s * 0.5, cy + s * 0.8, cx, cy + s * 1.5)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

-- shapes_medium 新增图案
function M.pentagon(vg, cx, cy, size, color)
    local r = size * 0.36
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

function M.hexagon(vg, cx, cy, size, color)
    local r = size * 0.36
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

function M.arrow(vg, cx, cy, size, color)
    local s = size * 0.35
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s)
    nvgLineTo(vg, cx + s * 0.7, cy)
    nvgLineTo(vg, cx + s * 0.25, cy)
    nvgLineTo(vg, cx + s * 0.25, cy + s)
    nvgLineTo(vg, cx - s * 0.25, cy + s)
    nvgLineTo(vg, cx - s * 0.25, cy)
    nvgLineTo(vg, cx - s * 0.7, cy)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function M.lightning(vg, cx, cy, size, color)
    local s = size * 0.24
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + s * 0.3, cy - s * 2.0)
    nvgLineTo(vg, cx - s * 1.1, cy + s * 0.2)
    nvgLineTo(vg, cx + s * 0.15, cy + s * 0.2)
    nvgLineTo(vg, cx - s * 0.3, cy + s * 2.0)
    nvgLineTo(vg, cx + s * 1.1, cy - s * 0.2)
    nvgLineTo(vg, cx - s * 0.15, cy - s * 0.2)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function M.crescent(vg, cx, cy, size, color)
    local r = size * 0.36
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 挖去内圆
    nvgBeginPath(vg)
    nvgCircle(vg, cx + r * 0.4, cy - r * 0.15, r * 0.78)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgFill(vg)
    ink(vg,size)
end

function M.shield(vg, cx, cy, size, color)
    local w = size * 0.3
    local h = size * 0.4
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

function M.plus(vg, cx, cy, size, color)
    local arm = size * 0.35
    local t = size * 0.14
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

function M.minus(vg, cx, cy, size, color)
    local arm = size * 0.36
    local t = size * 0.18
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - arm, cy - t, arm * 2, t * 2, t)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

-- shapes_hard 新增图案
function M.spiral(vg, cx, cy, size, color)
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

function M.gear(vg, cx, cy, size, color)
    local outerR = size * 0.36
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
    -- 中心孔
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, innerR * 0.35)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgFill(vg)
    ink(vg,size)
end

function M.hourglass(vg, cx, cy, size, color)
    local w = size * 0.28
    local h = size * 0.38
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

function M.gem(vg, cx, cy, size, color)
    local w = size * 0.32
    local h = size * 0.4
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

function M.flower(vg, cx, cy, size, color)
    local petalR = size * 0.16
    local dist = size * 0.2
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
    -- 花心
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, petalR * 0.65)
    nvgFillColor(vg, nvgRGBA(255, 220, 50, 255))
    nvgFill(vg)
    ink(vg,size)
end

function M.leaf(vg, cx, cy, size, color)
    local w = size * 0.24
    local h = size * 0.40
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - h)
    nvgBezierTo(vg, cx + w * 2, cy - h * 0.3, cx + w * 2, cy + h * 0.5, cx, cy + h)
    nvgBezierTo(vg, cx - w * 2, cy + h * 0.5, cx - w * 2, cy - h * 0.3, cx, cy - h)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 叶脉
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - h * 0.7)
    nvgLineTo(vg, cx, cy + h * 0.7)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 130))
    nvgStrokeWidth(vg, 2)
    nvgLineCap(vg, NVG_ROUND)
    nvgStroke(vg)
end

function M.drop(vg, cx, cy, size, color)
    local r = size * 0.28
    local h = size * 0.24
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - h - r)
    nvgBezierTo(vg, cx + r * 1.2, cy - h * 0.2, cx + r, cy + h * 0.5, cx, cy + h + r * 0.5)
    nvgBezierTo(vg, cx - r, cy + h * 0.5, cx - r * 1.2, cy - h * 0.2, cx, cy - h - r)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

function M.flame(vg, cx, cy, size, color)
    local s = size * 0.26
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 1.8)
    nvgBezierTo(vg, cx + s * 0.9, cy - s * 0.9, cx + s * 1.4, cy + s * 0.1, cx + s * 0.85, cy + s * 1.1)
    nvgBezierTo(vg, cx + s * 0.5, cy + s * 1.6, cx, cy + s * 1.4, cx, cy + s * 1.4)
    nvgBezierTo(vg, cx, cy + s * 1.4, cx - s * 0.5, cy + s * 1.6, cx - s * 0.85, cy + s * 1.1)
    nvgBezierTo(vg, cx - s * 1.4, cy + s * 0.1, cx - s * 0.9, cy - s * 0.9, cx, cy - s * 1.8)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 内焰高光
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 0.5)
    nvgBezierTo(vg, cx + s * 0.3, cy + s * 0.1, cx + s * 0.35, cy + s * 0.6, cx, cy + s * 0.9)
    nvgBezierTo(vg, cx - s * 0.35, cy + s * 0.6, cx - s * 0.3, cy + s * 0.1, cx, cy - s * 0.5)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 230, 120, 140))
    nvgFill(vg)
    ink(vg,size)
end

-- ============================================================================
-- 复合图案（来自连连看，多个多边形组成，辨识度更高）
-- ============================================================================

--- 房子：三角屋顶 + 方形房体 + 门
function M.house(vg, cx, cy, size, color)
    local s = size * 0.32
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

--- 鱼：椭圆身体 + 三角尾巴 + 眼睛
function M.fish(vg, cx, cy, size, color)
    local s = size * 0.42
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

--- 树：两层三角树冠 + 矩形树干
function M.tree(vg, cx, cy, size, color)
    local s = size * 0.32
    -- 上层树冠
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 1.2)
    nvgLineTo(vg, cx + s * 0.8, cy + s * 0.1)
    nvgLineTo(vg, cx - s * 0.8, cy + s * 0.1)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 下层树冠
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

--- 钻石：上梯形 + 下倒三角 + 分割线
function M.jewel(vg, cx, cy, size, color)
    local w = size * 0.32
    local h = size * 0.38
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

--- 蝴蝶结：左右两翼 + 中心结
function M.bowtie(vg, cx, cy, size, color)
    local s = size * 0.32
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

--- 皇冠：底座 + 三个尖角 + 宝石装饰
function M.crown(vg, cx, cy, size, color)
    local w = size * 0.34
    local h = size * 0.30
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

--- 火箭：圆头 + 机身 + 尾翼 + 窗户
function M.rocket(vg, cx, cy, size, color)
    local s = size * 0.19
    -- 机身
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - s * 0.8, cy - s * 1.4, s * 1.6, s * 2.8, s * 0.3)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 头部
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s * 2.5)
    nvgBezierTo(vg, cx + s * 0.6, cy - s * 1.8, cx + s * 0.8, cy - s * 1.4, cx + s * 0.8, cy - s * 1.1)
    nvgLineTo(vg, cx - s * 0.8, cy - s * 1.1)
    nvgBezierTo(vg, cx - s * 0.8, cy - s * 1.4, cx - s * 0.6, cy - s * 1.8, cx, cy - s * 2.5)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 左尾翼
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.8, cy + s * 0.6)
    nvgLineTo(vg, cx - s * 1.5, cy + s * 1.6)
    nvgLineTo(vg, cx - s * 0.8, cy + s * 1.4)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 右尾翼
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + s * 0.8, cy + s * 0.6)
    nvgLineTo(vg, cx + s * 1.5, cy + s * 1.6)
    nvgLineTo(vg, cx + s * 0.8, cy + s * 1.4)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 窗户
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - s * 0.4, s * 0.38)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 180))
    nvgFill(vg)
    ink(vg,size)
end

--- 铃铛：铃体 + 铃舌 + 顶部小圆
function M.bell(vg, cx, cy, size, color)
    local s = size * 0.30
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

--- 锚：竖杆 + 横杆 + 底部弧 + 顶圆环
function M.anchor(vg, cx, cy, size, color)
    local s = size * 0.20
    -- 竖杆
    nvgBeginPath(vg)
    nvgRect(vg, cx - s * 0.28, cy - s * 1.1, s * 0.56, s * 2.4)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 横杆
    nvgBeginPath(vg)
    nvgRect(vg, cx - s * 1.1, cy - s * 0.6, s * 2.2, s * 0.45)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 底部弧
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy + s * 0.5, s * 1.0, math.rad(0), math.rad(180), NVG_CW)
    nvgStrokeColor(vg, color)
    nvgStrokeWidth(vg, s * 0.5)
    nvgLineCap(vg, NVG_ROUND)
    nvgStroke(vg)
    -- 顶部圆环
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - s * 1.45, s * 0.42)
    nvgStrokeColor(vg, color)
    nvgStrokeWidth(vg, s * 0.32)
    nvgStroke(vg)
end

--- 雪花：三条交叉线 + 分支 + 中心圆
function M.snowflake(vg, cx, cy, size, color)
    local r = size * 0.36
    local t = size * 0.04
    nvgLineCap(vg, NVG_ROUND)
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
        nvgStrokeWidth(vg, t * 2.5)
        nvgStroke(vg)
        -- 分支
        for _, sign in ipairs({ 1, -1 }) do
            local bx = cx + r * 0.55 * math.cos(angle) * sign
            local by = cy + r * 0.55 * math.sin(angle) * sign
            local ba = angle + math.rad(45)
            local bb = angle - math.rad(45)
            local bl = r * 0.30
            nvgBeginPath(vg)
            nvgMoveTo(vg, bx, by)
            nvgLineTo(vg, bx + bl * math.cos(ba) * sign, by + bl * math.sin(ba) * sign)
            nvgStrokeWidth(vg, t * 2)
            nvgStroke(vg)
            nvgBeginPath(vg)
            nvgMoveTo(vg, bx, by)
            nvgLineTo(vg, bx + bl * math.cos(bb) * sign, by + bl * math.sin(bb) * sign)
            nvgStroke(vg)
        end
    end
    -- 中心
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, t * 4)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 音符：椭圆头 + 竖杆 + 旗子
function M.note(vg, cx, cy, size, color)
    local s = size * 0.22
    -- 音符头
    nvgBeginPath(vg)
    nvgEllipse(vg, cx - s * 0.3, cy + s * 1.1, s * 0.65, s * 0.5)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 竖杆
    nvgBeginPath(vg)
    nvgRect(vg, cx + s * 0.2, cy - s * 1.2, s * 0.22, s * 2.4)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 旗子
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + s * 0.42, cy - s * 1.2)
    nvgBezierTo(vg, cx + s * 1.3, cy - s * 0.9, cx + s * 1.1, cy - s * 0.3, cx + s * 0.42, cy - s * 0.3)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 太阳：中心圆 + 8 条三角光芒
function M.sun(vg, cx, cy, size, color)
    local r = size * 0.18
    local rayLen = size * 0.14
    local rayW = size * 0.045
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
function M.moonstar(vg, cx, cy, size, color)
    local r = size * 0.32
    -- 弯月
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
    local sr = size * 0.08
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

--- 钥匙：圆形手柄 + 杆 + 齿
function M.key(vg, cx, cy, size, color)
    local s = size * 0.20
    -- 手柄圆环
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - s * 1.2, s * 0.95)
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
    nvgRoundedRect(vg, cx - s * 0.25, cy - s * 0.4, s * 0.5, s * 2.2, 2)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 齿
    nvgBeginPath(vg)
    nvgRect(vg, cx + s * 0.25, cy + s * 0.9, s * 0.55, s * 0.35)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgRect(vg, cx + s * 0.25, cy + s * 0.3, s * 0.45, s * 0.35)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 旗帜：旗杆 + 三角旗面
function M.flag(vg, cx, cy, size, color)
    local s = size * 0.32
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

--- 眼睛：外形 + 虹膜 + 瞳孔
function M.eye(vg, cx, cy, size, color)
    local w = size * 0.36
    local h = size * 0.22
    -- 外形
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

--- 云朵：三个重叠圆
function M.cloud(vg, cx, cy, size, color)
    local s = size * 0.16
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
function M.umbrella(vg, cx, cy, size, color)
    local r = size * 0.36
    -- 伞面
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy - size * 0.04, r, math.rad(180), math.rad(0), NVG_CW)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 伞杆
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - size * 0.022, cy - size * 0.04, size * 0.044, size * 0.32, 2)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 弯钩
    nvgBeginPath(vg)
    nvgArc(vg, cx + size * 0.06, cy + size * 0.28, size * 0.082, math.rad(0), math.rad(180), NVG_CW)
    nvgStrokeColor(vg, color)
    nvgStrokeWidth(vg, size * 0.044)
    nvgLineCap(vg, NVG_ROUND)
    nvgStroke(vg)
end

--- 蘑菇：半圆帽 + 圆点 + 矩形柄
function M.mushroom(vg, cx, cy, size, color)
    local s = size * 0.30
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

--- 苹果：圆身 + 柄 + 叶子
function M.apple(vg, cx, cy, size, color)
    local r = size * 0.30
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
function M.cup(vg, cx, cy, size, color)
    local s = size * 0.30
    -- 杯身
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
    nvgArc(vg, cx + s * 0.85, cy, s * 0.38, math.rad(-65), math.rad(65), NVG_CW)
    nvgStrokeColor(vg, color)
    nvgStrokeWidth(vg, size * 0.055)
    nvgLineCap(vg, NVG_ROUND)
    nvgStroke(vg)
end

--- 山峰：两座三角山 + 雪顶
function M.mountain(vg, cx, cy, size, color)
    local s = size * 0.32
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

--- 骰子：圆角方块 + 5 个点
function M.dice(vg, cx, cy, size, color)
    local s = size * 0.56
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

--- 樱桃：两个圆果实 + Y 形茎 + 叶子
function M.cherry(vg, cx, cy, size, color)
    local r = size * 0.20
    -- 茎
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - size * 0.24)
    nvgBezierTo(vg, cx - size * 0.06, cy - size * 0.1, cx - size * 0.15, cy + size * 0.02, cx - size * 0.16, cy + size * 0.08)
    nvgStrokeColor(vg, nvgRGBA(100, 70, 40, 220))
    nvgStrokeWidth(vg, size * 0.038)
    nvgLineCap(vg, NVG_ROUND)
    nvgStroke(vg)
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - size * 0.24)
    nvgBezierTo(vg, cx + size * 0.06, cy - size * 0.1, cx + size * 0.15, cy + size * 0.02, cx + size * 0.16, cy + size * 0.08)
    nvgStrokeColor(vg, nvgRGBA(100, 70, 40, 220))
    nvgStrokeWidth(vg, size * 0.038)
    nvgStroke(vg)
    -- 果实
    nvgBeginPath(vg)
    nvgCircle(vg, cx - size * 0.16, cy + size * 0.14, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    nvgBeginPath(vg)
    nvgCircle(vg, cx + size * 0.16, cy + size * 0.14, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 叶子
    nvgBeginPath(vg)
    nvgEllipse(vg, cx + size * 0.06, cy - size * 0.26, size * 0.08, size * 0.04)
    nvgFillColor(vg, nvgRGBA(80, 180, 60, 220))
    nvgFill(vg)
    ink(vg,size)
end

--- 六角星
function M.star6(vg, cx, cy, size, color)
    local outerR = size * 0.34
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

--- 甜甜圈：环形
function M.donut(vg, cx, cy, size, color)
    local outerR = size * 0.32
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

--- 棒棒糖：圆头 + 长杆 + 白色纹路
function M.lollipop(vg, cx, cy, size, color)
    local r = size * 0.28
    -- 杆
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - size * 0.025, cy + r * 0.4, size * 0.05, size * 0.22, 2)
    nvgFillColor(vg, nvgRGBA(200, 180, 150, 220))
    nvgFill(vg)
    ink(vg,size)
    -- 糖果头
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - size * 0.04, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 白色纹路
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy - size * 0.04, r * 0.6, math.rad(-20), math.rad(200), NVG_CW)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 160))
    nvgStrokeWidth(vg, size * 0.05)
    nvgLineCap(vg, NVG_ROUND)
    nvgStroke(vg)
end

--- 船：梯形船体 + 桅杆 + 帆
function M.boat(vg, cx, cy, size, color)
    local s = size * 0.30
    -- 船体
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

--- 飞机：机身 + 主翼 + 尾翼
function M.plane(vg, cx, cy, size, color)
    local s = size * 0.20
    -- 机身
    nvgBeginPath(vg)
    nvgEllipse(vg, cx, cy, s * 2.0, s * 0.5)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 主翼
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 0.2, cy)
    nvgLineTo(vg, cx + s * 0.3, cy - s * 1.4)
    nvgLineTo(vg, cx + s * 0.75, cy - s * 1.4)
    nvgLineTo(vg, cx + s * 0.35, cy)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 尾翼
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - s * 1.5, cy)
    nvgLineTo(vg, cx - s * 1.2, cy - s * 0.9)
    nvgLineTo(vg, cx - s * 0.85, cy)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
end

--- 信封：矩形 + V 形折口
function M.envelope(vg, cx, cy, size, color)
    local w = size * 0.36
    local h = size * 0.25
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

--- 灯泡：圆球 + 收束 + 底座
function M.bulb(vg, cx, cy, size, color)
    local r = size * 0.28
    -- 灯泡球体
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy - size * 0.06, r)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 下方收束
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - r * 0.65, cy + r * 0.55)
    nvgLineTo(vg, cx - r * 0.4, cy + r * 1.2)
    nvgLineTo(vg, cx + r * 0.4, cy + r * 1.2)
    nvgLineTo(vg, cx + r * 0.65, cy + r * 0.55)
    nvgClosePath(vg)
    nvgFillColor(vg, color)
    nvgFill(vg)
    ink(vg,size)
    -- 底座横纹
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - r * 0.38, cy + r * 1.2, r * 0.76, r * 0.28, 2)
    nvgFillColor(vg, nvgRGBA(200, 200, 200, 220))
    nvgFill(vg)
    ink(vg,size)
end

--- 四叶草：四片圆叶 + 茎
function M.clover(vg, cx, cy, size, color)
    local r = size * 0.19
    local d = size * 0.14
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
    nvgLineTo(vg, cx + size * 0.04, cy + size * 0.28)
    nvgStrokeColor(vg, color)
    nvgStrokeWidth(vg, size * 0.045)
    nvgLineCap(vg, NVG_ROUND)
    nvgStroke(vg)
end

--- 拱门：左右柱 + 拱顶弧
function M.arch(vg, cx, cy, size, color)
    local w = size * 0.32
    local h = size * 0.36
    local t = size * 0.11
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

--- 靶心：三层同心圆环
function M.target(vg, cx, cy, size, color)
    local r = size * 0.34
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

return M
