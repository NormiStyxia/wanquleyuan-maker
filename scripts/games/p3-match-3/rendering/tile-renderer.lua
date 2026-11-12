--- 消消乐 - 方块渲染器
--- 职责：绘制各种方块（普通、石头、冰块、彩虹、特殊图标）
--- 提取自 board-renderer.lua

local Board = require("games.p3-match-3.logic.board")

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local M = {}
local Sprites=require("shared.rendering.piece-sprites")
local motifs={"heart","star","leaf","sun","flower","butterfly"}

-- ============================================================================
-- 方块配色调色板（colorId -> RGBA）
-- ============================================================================

local TILE_COLORS = {
    [1] = { 231, 76, 60 },     -- 红
    [2] = { 52, 152, 219 },    -- 蓝
    [3] = { 46, 204, 113 },    -- 绿
    [4] = { 241, 196, 15 },    -- 黄
    [5] = { 155, 89, 182 },    -- 紫
    [6] = { 255, 182, 193 },    -- 淡粉
}

local TILE_HIGHLIGHT = {
    [1] = { 255, 120, 100 },
    [2] = { 100, 185, 240 },
    [3] = { 100, 230, 155 },
    [4] = { 255, 225, 80 },
    [5] = { 190, 135, 215 },
    [6] = { 255, 210, 220 },
}

--- 获取方块颜色（供粒子系统等外部模块使用）
function M.getTileColors()
    return TILE_COLORS, TILE_HIGHLIGHT
end

-- 彩虹动画时间（由外部 updateAnim 驱动）
local rainbowTime_ = 0

function M.setRainbowTime(t)
    rainbowTime_ = t
end

-- ============================================================================
-- 绘制辅助
-- ============================================================================

--- 绘制石头方块
--- 绘制石头方块 —— 不规则多边形岩石，与普通圆角方块形成强烈区分
function M.drawStone(vg, cx, cy, size)
    local h = size / 2 * 0.88  -- 略小于格子，留出间距

    -- 不规则岩石轮廓顶点（顺时针，相对于中心）
    local pts = {
        { -h * 0.45, -h * 0.92 },  -- 顶部偏左
        {  h * 0.35, -h * 0.88 },  -- 顶部偏右
        {  h * 0.85, -h * 0.35 },  -- 右上凸起
        {  h * 0.78,  h * 0.25 },  -- 右侧内凹
        {  h * 0.55,  h * 0.82 },  -- 右下
        { -h * 0.15,  h * 0.90 },  -- 底部中心偏左
        { -h * 0.72,  h * 0.60 },  -- 左下
        { -h * 0.88, -h * 0.10 },  -- 左侧
    }

    -- 辅助：绘制石头多边形路径
    local function stoneOutline(ox, oy)
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx + pts[1][1] + ox, cy + pts[1][2] + oy)
        for i = 2, #pts do
            nvgLineTo(vg, cx + pts[i][1] + ox, cy + pts[i][2] + oy)
        end
        nvgClosePath(vg)
    end

    -- 阴影（偏移 + 模糊感）
    stoneOutline(2, 3)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 50))
    nvgFill(vg)

    -- 主体：深灰渐变
    stoneOutline(0, 0)
    nvgFillColor(vg,nvgRGBA(153,148,127,255)); nvgFill(vg)

    -- 表面纹理：几块深色斑块模拟岩石颗粒
    nvgBeginPath(vg)
    nvgCircle(vg, cx - h * 0.25, cy - h * 0.30, h * 0.18)
    nvgCircle(vg, cx + h * 0.30, cy + h * 0.15, h * 0.14)
    nvgCircle(vg, cx - h * 0.05, cy + h * 0.45, h * 0.12)
    nvgFillColor(vg, nvgRGBA(80, 75, 68, 55))
    nvgFill(vg)

    -- 表面纹理：浅色斑点
    nvgBeginPath(vg)
    nvgCircle(vg, cx + h * 0.10, cy - h * 0.50, h * 0.10)
    nvgCircle(vg, cx - h * 0.45, cy + h * 0.20, h * 0.09)
    nvgFillColor(vg, nvgRGBA(180, 175, 165, 60))
    nvgFill(vg)

    -- 裂纹线1
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - h * 0.50, cy - h * 0.55)
    nvgLineTo(vg, cx - h * 0.05, cy + h * 0.05)
    nvgLineTo(vg, cx + h * 0.25, cy + h * 0.40)
    nvgStrokeColor(vg, nvgRGBA(70, 65, 58, 100))
    nvgStrokeWidth(vg, 1.3)
    nvgStroke(vg)

    -- 裂纹线2
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + h * 0.15, cy - h * 0.40)
    nvgLineTo(vg, cx + h * 0.40, cy + h * 0.10)
    nvgStrokeColor(vg, nvgRGBA(70, 65, 58, 80))
    nvgStrokeWidth(vg, 1.0)
    nvgStroke(vg)

    -- 顶部边缘高光（沿着顶部几个顶点绘制弧线高光）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + pts[8][1] + h * 0.1, cy + pts[8][2] + h * 0.08)
    nvgLineTo(vg, cx + pts[1][1] + h * 0.05, cy + pts[1][2] + h * 0.08)
    nvgLineTo(vg, cx + pts[2][1] - h * 0.05, cy + pts[2][2] + h * 0.08)
    nvgLineTo(vg, cx + pts[3][1] - h * 0.10, cy + pts[3][2] + h * 0.1)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 35))
    nvgStrokeWidth(vg, 2.0)
    nvgStroke(vg)

    -- 轮廓描边
    stoneOutline(0, 0)
    nvgStrokeColor(vg, Pen.color(C.ink))
    nvgStrokeWidth(vg, 1.8)
    nvgStroke(vg)
end

--- 绘制冰块方块 —— 六边形冰晶，棱角分明的宝石造型，与普通圆角方块形成强烈区分
---@param vg userdata
---@param cx number 中心 X
---@param cy number 中心 Y
---@param size number 格子尺寸
---@param hp number 当前生命值 (1-3)
function M.drawIce(vg, cx, cy, size, hp)
    local h = size / 2 * 0.88  -- 略小于格子

    -- 六边形顶点（尖顶朝上的正六边形）
    local sin60 = 0.866  -- sin(60°)
    local cos60 = 0.5    -- cos(60°)
    local hex = {
        { 0,           -h         },  -- 顶
        {  h * sin60,  -h * cos60 },  -- 右上
        {  h * sin60,   h * cos60 },  -- 右下
        { 0,            h         },  -- 底
        { -h * sin60,   h * cos60 },  -- 左下
        { -h * sin60,  -h * cos60 },  -- 左上
    }

    -- 辅助：绘制六边形路径
    local function hexPath(ox, oy)
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx + hex[1][1] + ox, cy + hex[1][2] + oy)
        for i = 2, 6 do
            nvgLineTo(vg, cx + hex[i][1] + ox, cy + hex[i][2] + oy)
        end
        nvgClosePath(vg)
    end

    -- 根据 HP 选择颜色参数
    local bodyAlpha, crackAlpha, highlightAlpha
    if hp >= 3 then
        bodyAlpha = 210
        crackAlpha = 0
        highlightAlpha = 70
    elseif hp == 2 then
        bodyAlpha = 175
        crackAlpha = 140
        highlightAlpha = 45
    else
        bodyAlpha = 140
        crackAlpha = 190
        highlightAlpha = 28
    end

    -- 阴影
    hexPath(2, 3)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 35))
    nvgFill(vg)

    -- 主体：冰蓝渐变
    hexPath(0, 0)
    nvgFillColor(vg,nvgRGBA(164,203,212,bodyAlpha)); nvgFill(vg)

    -- 内部菱形高光（宝石切面感）
    local innerH = h * 0.55
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - innerH)
    nvgLineTo(vg, cx + innerH * 0.7, cy)
    nvgLineTo(vg, cx, cy + innerH)
    nvgLineTo(vg, cx - innerH * 0.7, cy)
    nvgClosePath(vg)
    local innerGlow = nvgRadialGradient(vg, cx, cy - innerH * 0.3,
        innerH * 0.1, innerH * 0.9,
        nvgRGBA(230, 245, 255, math.floor(highlightAlpha * 1.0)),
        nvgRGBA(140, 200, 245, 0))
    nvgFillPaint(vg, innerGlow)
    nvgFill(vg)

    -- 顶面高光三角（六边形上方两条边的内侧亮面）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx + hex[6][1] * 0.75, cy + hex[6][2] * 0.75)
    nvgLineTo(vg, cx, cy + hex[1][2] * 0.75)
    nvgLineTo(vg, cx + hex[2][1] * 0.75, cy + hex[2][2] * 0.75)
    nvgLineTo(vg, cx, cy - h * 0.15)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, highlightAlpha))
    nvgFill(vg)

    -- 裂纹（HP < 3 时绘制）
    if crackAlpha > 0 then
        nvgStrokeColor(vg, nvgRGBA(210, 235, 255, crackAlpha))

        -- 裂纹1：从顶部向中心偏右延伸
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx - h * 0.15, cy - h * 0.70)
        nvgLineTo(vg, cx + h * 0.10, cy - h * 0.10)
        nvgLineTo(vg, cx + h * 0.35, cy + h * 0.30)
        nvgStrokeWidth(vg, hp == 1 and 2.0 or 1.3)
        nvgStroke(vg)

        -- 裂纹2：从右上到中心偏下
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx + h * 0.55, cy - h * 0.30)
        nvgLineTo(vg, cx + h * 0.10, cy + h * 0.20)
        nvgStrokeWidth(vg, hp == 1 and 1.6 or 1.1)
        nvgStroke(vg)

        if hp == 1 then
            -- 裂纹3：左侧长裂纹
            nvgBeginPath(vg)
            nvgMoveTo(vg, cx - h * 0.60, cy - h * 0.20)
            nvgLineTo(vg, cx - h * 0.10, cy + h * 0.15)
            nvgLineTo(vg, cx + h * 0.20, cy + h * 0.60)
            nvgStrokeWidth(vg, 1.6)
            nvgStroke(vg)

            -- 裂纹4：底部碎裂
            nvgBeginPath(vg)
            nvgMoveTo(vg, cx - h * 0.30, cy + h * 0.45)
            nvgLineTo(vg, cx + h * 0.05, cy + h * 0.70)
            nvgStrokeWidth(vg, 1.4)
            nvgStroke(vg)

            -- 裂纹5：右上短裂
            nvgBeginPath(vg)
            nvgMoveTo(vg, cx + h * 0.40, cy - h * 0.55)
            nvgLineTo(vg, cx + h * 0.60, cy - h * 0.15)
            nvgStrokeWidth(vg, 1.2)
            nvgStroke(vg)
        end
    end

    -- 亮点反光（冰晶光斑）
    nvgBeginPath(vg)
    nvgCircle(vg, cx - h * 0.25, cy - h * 0.50, h * 0.09)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(highlightAlpha * 1.3)))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgCircle(vg, cx + h * 0.35, cy - h * 0.15, h * 0.06)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(highlightAlpha * 0.9)))
    nvgFill(vg)

    -- 六边形轮廓描边
    hexPath(0, 0)
    nvgStrokeColor(vg, Pen.color(C.ink))
    nvgStrokeWidth(vg, 1.8)
    nvgStroke(vg)
end

-- 彩虹方块颜色表（7色彩虹）
local RAINBOW_STRIPE = {
    { 231, 76,  60  },  -- 红
    { 241, 196, 15  },  -- 黄
    { 46,  204, 113 },  -- 绿
    { 52,  152, 219 },  -- 蓝
    { 155, 89,  182 },  -- 紫
    { 255, 182, 193 },  -- 淡粉
    { 255, 105, 180 },  -- 粉
}

--- 绘制彩虹方块（专属渲染）
function M.drawRainbowTile(vg, cx, cy, half, r, a)
    -- 阴影
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - half + 1, cy - half + 2, half * 2, half * 2, r)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(a * 0.18)))
    nvgFill(vg)

    -- 白色底板
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - half, cy - half, half * 2, half * 2, r)
    nvgFillColor(vg, nvgRGBA(255, 246, 220, a))
    nvgFill(vg)

    -- 彩虹条纹（对角渐变滚动）
    nvgSave(vg)
    nvgScissor(vg, cx - half, cy - half, half * 2, half * 2)

    local stripeCount = #RAINBOW_STRIPE
    local stripeW = half * 2 / stripeCount
    -- 用 rainbowTime_ 做色相偏移，让颜色流动
    local shift = 0  -- 每秒偏移 1.5 个色带

    for i = 1, stripeCount do
        -- 颜色索引随时间偏移
        local ci = ((i - 1 + math.floor(shift)) % stripeCount) + 1
        local nextCi = (ci % stripeCount) + 1
        local frac = shift - math.floor(shift)  -- 插值因子

        local c1 = RAINBOW_STRIPE[ci]
        local c2 = RAINBOW_STRIPE[nextCi]
        local cr = math.floor(c1[1] + (c2[1] - c1[1]) * frac)
        local cg = math.floor(c1[2] + (c2[2] - c1[2]) * frac)
        local cb = math.floor(c1[3] + (c2[3] - c1[3]) * frac)

        local sx = cx - half + (i - 1) * stripeW
        nvgBeginPath(vg)
        nvgRect(vg, sx, cy - half, stripeW + 1, half * 2)
        nvgFillColor(vg, nvgRGBA(cr, cg, cb, math.floor(a * 0.75)))
        nvgFill(vg)
    end

    nvgResetScissor(vg)
    nvgRestore(vg)

    -- 圆角边框遮盖（重新画圆角让边缘干净）
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - half, cy - half, half * 2, half * 2, r)
    nvgStrokeColor(vg, nvgRGBA(C.ink[1],C.ink[2],C.ink[3],a))
    nvgStrokeWidth(vg, 2)
    nvgStroke(vg)

    -- 中心白色星星图标
    local iconR = half * 0.38
    local outerR = iconR
    local innerR = iconR * 0.42
    nvgBeginPath(vg)
    for i = 0, 9 do
        local pr = (i % 2 == 0) and outerR or innerR
        local angle = math.rad(-90 + i * 36)
        local px = cx + pr * math.cos(angle)
        local py = cy + pr * math.sin(angle)
        if i == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(a * 0.9)))
    nvgFill(vg)
end

--- 绘制单个方块
---@param hp number|nil 冰块生命值（仅冰块方块使用）
function M.drawTile(vg, cx, cy, size, colorId, special, alpha, scale, hp)
    alpha,scale=alpha or 1,scale or 1
    if alpha<=0.01 or scale<=0 then return end
    local key=special==Board.SPECIAL_STONE and "stone"
        or special==Board.SPECIAL_ICE and ("ice-"..math.max(1,math.min(3,hp or 3)))
        or special==Board.SPECIAL_RAINBOW and "rainbow"
        or motifs[colorId]
    if key and Sprites.draw(vg,key,cx,cy,size*scale,alpha) then
        if special==Board.SPECIAL_BOMB then
            -- Keep the color/shape identity; a separate bomb badge communicates the special.
            Sprites.draw(vg,"bomb",cx+size*scale*.24,cy+size*scale*.22,size*scale*.53,alpha)
        elseif special==Board.SPECIAL_LINE_H or special==Board.SPECIAL_LINE_V then
            -- Cream ribbon keeps direction readable on every colored silhouette.
            nvgSave(vg); nvgGlobalAlpha(vg,alpha)
            nvgTranslate(vg,cx,cy)
            if special==Board.SPECIAL_LINE_V then nvgRotate(vg,math.pi/2) end
            Pen.plaque(vg,-size*scale*.34,-size*scale*.085,size*scale*.68,size*scale*.17,C.paper,1.2)
            nvgRestore(vg)
            M.drawSpecialIcon(vg,cx,cy,size*scale*.23,special,math.floor(alpha*255))
        end
        return
    end
    -- 石头方块使用专属绘制
    if special == Board.SPECIAL_STONE then
        M.drawStone(vg, cx, cy, size)
        return
    end

    -- 冰块方块使用专属绘制
    if special == Board.SPECIAL_ICE then
        M.drawIce(vg, cx, cy, size, hp or 3)
        return
    end

    if not colorId or colorId <= 0 then return end

    local c = TILE_COLORS[colorId] or { 150, 150, 150 }
    local hi = TILE_HIGHLIGHT[colorId] or { 200, 200, 200 }
    local half = (size / 2) * scale
    local r = math.max(4, half * 0.25)
    local a = math.floor(alpha * 255)
    if a < 5 then return end

    -- 彩虹方块使用专属绘制
    if special == Board.SPECIAL_RAINBOW then
        M.drawRainbowTile(vg, cx, cy, half, r, a)
        return
    end

    Paper.panel(vg,cx-half,cy-half,half*2,half*2,{c[1],c[2],c[3],255},alpha)

    -- 特殊方块图标
    if special and special ~= Board.SPECIAL_NONE then
        M.drawSpecialIcon(vg, cx, cy, half * 0.6, special, a)
    end
end

--- 绘制特殊方块图标
function M.drawSpecialIcon(vg, cx, cy, iconR, special, alpha)
    local a = math.floor(alpha * 0.9)

    if special == Board.SPECIAL_LINE_H then
        -- 横向箭头
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx - iconR, cy)
        nvgLineTo(vg, cx + iconR, cy)
        nvgStrokeColor(vg, nvgRGBA(C.ink[1], C.ink[2], C.ink[3], a))
        nvgStrokeWidth(vg, 2.5)
        nvgStroke(vg)
        -- 箭头头
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx + iconR - 4, cy - 4)
        nvgLineTo(vg, cx + iconR, cy)
        nvgLineTo(vg, cx + iconR - 4, cy + 4)
        nvgStrokeColor(vg, nvgRGBA(C.ink[1], C.ink[2], C.ink[3], a))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx - iconR + 4, cy - 4)
        nvgLineTo(vg, cx - iconR, cy)
        nvgLineTo(vg, cx - iconR + 4, cy + 4)
        nvgStrokeColor(vg, nvgRGBA(C.ink[1], C.ink[2], C.ink[3], a))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)

    elseif special == Board.SPECIAL_LINE_V then
        -- 纵向箭头
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx, cy - iconR)
        nvgLineTo(vg, cx, cy + iconR)
        nvgStrokeColor(vg, nvgRGBA(C.ink[1], C.ink[2], C.ink[3], a))
        nvgStrokeWidth(vg, 2.5)
        nvgStroke(vg)
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx - 4, cy + iconR - 4)
        nvgLineTo(vg, cx, cy + iconR)
        nvgLineTo(vg, cx + 4, cy + iconR - 4)
        nvgStrokeColor(vg, nvgRGBA(C.ink[1], C.ink[2], C.ink[3], a))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)
        nvgBeginPath(vg)
        nvgMoveTo(vg, cx - 4, cy - iconR + 4)
        nvgLineTo(vg, cx, cy - iconR)
        nvgLineTo(vg, cx + 4, cy - iconR + 4)
        nvgStrokeColor(vg, nvgRGBA(C.ink[1], C.ink[2], C.ink[3], a))
        nvgStrokeWidth(vg, 2)
        nvgStroke(vg)

    elseif special == Board.SPECIAL_BOMB then
        -- 星形（6 角）
        local spikes = 6
        for i = 0, spikes - 1 do
            local angle = math.rad(i * 60 - 90)
            local x1 = cx + math.cos(angle) * iconR
            local y1 = cy + math.sin(angle) * iconR
            local angle2 = math.rad(i * 60 - 90 + 30)
            local x2 = cx + math.cos(angle2) * iconR * 0.45
            local y2 = cy + math.sin(angle2) * iconR * 0.45

            nvgBeginPath(vg)
            nvgMoveTo(vg, cx, cy)
            nvgLineTo(vg, x1, y1)
            nvgLineTo(vg, x2, y2)
            nvgClosePath(vg)
            nvgFillColor(vg, nvgRGBA(C.ink[1], C.ink[2], C.ink[3], a))
            nvgFill(vg)
        end

    elseif special == Board.SPECIAL_RAINBOW then
        -- 同心圆
        for i = 3, 1, -1 do
            local rr = iconR * (i / 3)
            nvgBeginPath(vg)
            nvgCircle(vg, cx, cy, rr)
            local ringA = math.floor(a * (0.3 + 0.25 * (4 - i)))
            nvgStrokeColor(vg, nvgRGBA(255, 255, 255, ringA))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)
        end
        -- 中心亮点
        nvgBeginPath(vg)
        nvgCircle(vg, cx, cy, 2.5)
        nvgFillColor(vg, nvgRGBA(C.ink[1], C.ink[2], C.ink[3], a))
        nvgFill(vg)
    end
end

return M
