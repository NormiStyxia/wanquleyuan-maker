--- 游戏入口卡片：独立手绘插画 + 自适应纸卡和文字。
local Colors = require("shared.constants.colors")
local Layout = require("shared.constants.layout")

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local Art = require("shared.constants.art")
-- 图片句柄归属于创建它的 NanoVG 上下文；不跨上下文复用或每帧重新加载。
local iconImages_ = setmetatable({}, {__mode = "k"})
local M = {}

-- 游戏图标类型映射（替代原 Emoji 映射）
local ICON_TYPES = {
    ["p1-puzzle-land"]  = "box",
    ["p2-memory-flip"]  = "card",
    ["p3-match-3"]      = "gem",
    ["p4-link-match"]   = "link",
}

-- ============================================================================
-- 基础图形工具
-- ============================================================================

--- 绘制五角星路径（仅定义路径，不 fill）
---@param vg userdata NanoVG 上下文
---@param cx number 中心 X
---@param cy number 中心 Y
---@param outerR number 外径
---@param innerR number 内径
local function starPath(vg, cx, cy, outerR, innerR)
    nvgBeginPath(vg)
    for i = 0, 9 do
        local r = (i % 2 == 0) and outerR or innerR
        local angle = -math.pi / 2 + i * math.pi / 5
        local x = cx + r * math.cos(angle)
        local y = cy + r * math.sin(angle)
        if i == 0 then
            nvgMoveTo(vg, x, y)
        else
            nvgLineTo(vg, x, y)
        end
    end
    nvgClosePath(vg)
end

--- 绘制渐变圆角矩形
---@param vg userdata
---@param x number 左上 X
---@param y number 左上 Y
---@param w number 宽
---@param h number 高
---@param radius number 圆角
---@param colorFrom table RGBA
---@param colorTo table RGBA
---@param angle number|nil 渐变角度（度），默认 145
function M.drawGradientRect(vg, x, y, w, h, radius, colorFrom, colorTo, angle)
    local rad = math.rad(angle or 145)
    local sx = x + w / 2 - math.cos(rad) * w / 2
    local sy = y + h / 2 - math.sin(rad) * h / 2
    local ex = x + w / 2 + math.cos(rad) * w / 2
    local ey = y + h / 2 + math.sin(rad) * h / 2
    local paint = nvgLinearGradient(vg, sx, sy, ex, ey,
        nvgRGBA(colorFrom[1], colorFrom[2], colorFrom[3], colorFrom[4]),
        nvgRGBA(colorTo[1], colorTo[2], colorTo[3], colorTo[4]))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, x, y, w, h, radius)
    nvgFillPaint(vg, paint)
    nvgFill(vg)
end

-- ============================================================================
-- 星星绘制
-- ============================================================================

--- 绘制一行星星（进度显示）
---@param vg userdata
---@param cx number 行中心 X
---@param cy number 行中心 Y
---@param earned number 已获得星星数
---@param total number 总星星数
---@param starSize number 单颗星星直径
function M.drawStarRow(vg, cx, cy, earned, total, starSize)
    local gap = 3
    local totalW = total * starSize + (total - 1) * gap
    local startX = cx - totalW / 2
    for i = 1, total do
        local active = i <= earned
        local sx = startX + (i - 1) * (starSize + gap) + starSize / 2
        starPath(vg, sx, cy, starSize / 2, starSize * 0.19)
        local c = active and Colors.starActive or Colors.starInactive
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], c[4]))
        nvgFill(vg)
    end
end

--- 绘制单颗星星
---@param vg userdata
---@param cx number 中心 X
---@param cy number 中心 Y
---@param size number 直径
---@param color table RGBA
function M.drawStar(vg, cx, cy, size, color)
    starPath(vg, cx, cy, size / 2, size * 0.19)
    nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], color[4]))
    nvgFill(vg)
end

-- ============================================================================
-- 游戏图标绘制（半透明白色，叠加在渐变瓷砖上）
-- ============================================================================

--- 推箱子：等轴 3D 立方体
local function drawBoxIcon(vg, cx, cy, size)
    local s = size * 0.28
    -- 立方体中心偏移使视觉居中
    local ox, oy = cx - s * 0.3, cy + s * 0.15

    -- 正面
    nvgBeginPath(vg)
    nvgRect(vg, ox - s, oy - s, s * 1.6, s * 1.6)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 180))
    nvgFill(vg)

    -- 顶面
    nvgBeginPath(vg)
    nvgMoveTo(vg, ox - s, oy - s)
    nvgLineTo(vg, ox - s + s * 0.6, oy - s - s * 0.5)
    nvgLineTo(vg, ox - s + s * 0.6 + s * 1.6, oy - s - s * 0.5)
    nvgLineTo(vg, ox + s * 0.6, oy - s)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 120))
    nvgFill(vg)

    -- 右侧面
    nvgBeginPath(vg)
    nvgMoveTo(vg, ox + s * 0.6, oy - s)
    nvgLineTo(vg, ox + s * 0.6 + s * 0.6, oy - s - s * 0.5)
    nvgLineTo(vg, ox + s * 0.6 + s * 0.6, oy - s - s * 0.5 + s * 1.6)
    nvgLineTo(vg, ox + s * 0.6, oy + s * 0.6)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 80))
    nvgFill(vg)

    -- 棱线
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 50))
    nvgStrokeWidth(vg, 1.0)
    -- 正面边框
    nvgBeginPath(vg)
    nvgRect(vg, ox - s, oy - s, s * 1.6, s * 1.6)
    nvgStroke(vg)
end

--- 翻翻乐：两张叠加卡牌 + 问号
local function drawCardIcon(vg, cx, cy, size)
    local cw = size * 0.34
    local ch = size * 0.44
    local r = size * 0.04

    -- 底层卡牌（偏右偏上）
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - cw / 2 + 5, cy - ch / 2 - 3, cw, ch, r)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 80))
    nvgFill(vg)

    -- 前层卡牌
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - cw / 2 - 2, cy - ch / 2 + 1, cw, ch, r)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgFill(vg)

    -- 问号
    nvgFontSize(vg, size * 0.3)
    nvgFontFace(vg, "menu")
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 50))
    nvgText(vg, cx - 2, cy + 1, "?")
end

--- 消消乐：钻石/宝石
local function drawGemIcon(vg, cx, cy, size)
    local w = size * 0.38
    local h = size * 0.46
    local crownH = h * 0.3

    -- 宝石冠部（上梯形）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - h / 2)                       -- 顶点
    nvgLineTo(vg, cx + w * 0.35, cy - h / 2 + crownH)   -- 右
    nvgLineTo(vg, cx - w * 0.35, cy - h / 2 + crownH)   -- 左
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 140))
    nvgFill(vg)

    -- 宝石亭部（下三角）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - w / 2, cy - h / 2 + crownH)
    nvgLineTo(vg, cx + w / 2, cy - h / 2 + crownH)
    nvgLineTo(vg, cx, cy + h / 2)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgFill(vg)

    -- 左切面
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - w / 2, cy - h / 2 + crownH)
    nvgLineTo(vg, cx - w * 0.35, cy - h / 2 + crownH)
    nvgLineTo(vg, cx, cy + h / 2)
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 100))
    nvgFill(vg)

    -- 腰线高光
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - w / 2, cy - h / 2 + crownH)
    nvgLineTo(vg, cx + w / 2, cy - h / 2 + crownH)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 60))
    nvgStrokeWidth(vg, 1.0)
    nvgStroke(vg)

    -- 左斜线（冠 → 腰）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - h / 2)
    nvgLineTo(vg, cx - w / 2, cy - h / 2 + crownH)
    nvgStroke(vg)
    -- 右斜线
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - h / 2)
    nvgLineTo(vg, cx + w / 2, cy - h / 2 + crownH)
    nvgStroke(vg)
end

--- 连连看：两个相同方块 + 折线路径
local function drawLinkIcon(vg, cx, cy, size)
    local s = size * 0.16
    local gap = s * 2.2

    -- 左方块
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - gap - s, cy - s, s * 2, s * 2, 3)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgFill(vg)

    -- 右方块
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx + gap - s, cy - s, s * 2, s * 2, 3)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 200))
    nvgFill(vg)

    -- 方块内圆点
    nvgBeginPath(vg)
    nvgCircle(vg, cx - gap, cy, s * 0.4)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 100))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgCircle(vg, cx + gap, cy, s * 0.4)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 100))
    nvgFill(vg)

    -- 连接折线（从左到右）
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx - gap + s, cy)
    nvgLineTo(vg, cx - gap + s + s * 0.4, cy - s * 1.5)
    nvgLineTo(vg, cx + gap - s - s * 0.4, cy - s * 1.5)
    nvgLineTo(vg, cx + gap - s, cy)
    nvgStrokeColor(vg, nvgRGBA(255, 255, 255, 140))
    nvgStrokeWidth(vg, 1.5)
    nvgStroke(vg)
end

--- 默认：简约游戏手柄
local function drawDefaultIcon(vg, cx, cy, size)
    local r = size * 0.2

    -- 圆形底座
    nvgBeginPath(vg)
    nvgCircle(vg, cx, cy, r)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 150))
    nvgFill(vg)

    -- 十字方向键
    local t = size * 0.035
    local arm = r * 0.55
    nvgBeginPath(vg)
    nvgRect(vg, cx - t, cy - arm, t * 2, arm * 2)
    nvgRect(vg, cx - arm, cy - t, arm * 2, t * 2)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 80))
    nvgFill(vg)
end

--- 标题拼图图标：2×2 网格
---@param vg userdata
---@param cx number 中心 X
---@param cy number 中心 Y
---@param size number 图标区域大小
function M.drawPuzzleIcon(vg, cx, cy, size)
    local cellSize = size * 0.24
    local gap = size * 0.06
    local offset = (cellSize + gap) / 2
    local radius = size * 0.05

    local cells = {
        { cx - offset, cy - offset },
        { cx + offset, cy - offset },
        { cx - offset, cy + offset },
        { cx + offset, cy + offset },
    }
    local alphas = { 220, 160, 160, 110 }
    for i, pos in ipairs(cells) do
        nvgBeginPath(vg)
        nvgRoundedRect(vg, pos[1] - cellSize / 2, pos[2] - cellSize / 2,
                       cellSize, cellSize, radius)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, alphas[i]))
        nvgFill(vg)
    end
end

--- 在指定位置绘制游戏图标
---@param vg userdata
---@param cx number 中心 X
---@param cy number 中心 Y
---@param size number 图标区域大小
---@param gameId string 游戏 ID
function M.drawGameIcon(vg, cx, cy, size, gameId)
    local path = Art.gameIcons[gameId]
    if path then
        local images = iconImages_[vg]
        if not images then images = {}; iconImages_[vg] = images end
        if images[gameId] == nil then
            local image = nvgCreateImage(vg, path, 0)
            images[gameId] = image and image > 0 and image or false
        end
        local image = images[gameId]
        if image then
            local x, y = cx - size / 2, cy - size / 2
            nvgBeginPath(vg); nvgRect(vg, x, y, size, size)
            nvgFillPaint(vg, nvgImagePattern(vg, x, y, size, size, 0, image, 1))
            nvgFill(vg)
            return
        end
    end
    -- 未知游戏或资源加载失败时保留可辨识的轻量后备图标。
    local function diamond(x, y, r, color)
        nvgBeginPath(vg); nvgMoveTo(vg,x,y-r); nvgLineTo(vg,x+r,y)
        nvgLineTo(vg,x,y+r); nvgLineTo(vg,x-r,y); nvgClosePath(vg)
        Pen.paint(vg,color,2)
    end
    if gameId == "p1-puzzle-land" then
        local r=size*0.37
        Pen.plaque(vg,cx-r,cy-r,r*2,r*2,C.orange,2.5)
        nvgBeginPath(vg);nvgMoveTo(vg,cx-r*0.6,cy);nvgLineTo(vg,cx+r*0.6,cy)
        nvgMoveTo(vg,cx,cy-r*0.6);nvgLineTo(vg,cx,cy+r*0.6)
        nvgStrokeColor(vg,Pen.color(C.ink));nvgStrokeWidth(vg,2);nvgStroke(vg)
    elseif gameId == "p2-memory-flip" then
        local w,h=size*0.5,size*0.7
        Pen.plaque(vg,cx-w*0.8,cy-h*0.6,w,h,C.green,2)
        Pen.plaque(vg,cx-w*0.15,cy-h*0.4,w,h,C.paper,2)
        diamond(cx+w*0.35,cy+h*0.1,size*0.12,C.orange)
    elseif gameId == "p3-match-3" then
        diamond(cx-size*0.27,cy+size*0.12,size*0.22,C.green)
        diamond(cx,cy-size*0.17,size*0.25,C.orange)
        diamond(cx+size*0.28,cy+size*0.14,size*0.22,{157,185,203,255})
    elseif gameId == "p4-link-match" then
        local w,h=size*0.37,size*0.56
        nvgBeginPath(vg);nvgMoveTo(vg,cx-size*0.3,cy)
        nvgLineTo(vg,cx+size*0.3,cy)
        nvgStrokeColor(vg,Pen.color(C.ink));nvgStrokeWidth(vg,2.5);nvgStroke(vg)
        for _,side in ipairs({-1,1}) do
            local x=cx+side*size*0.3
            Pen.plaque(vg,x-w/2,cy-h/2,w,h,C.paper,2)
            Pen.circle(vg,x,cy,size*0.09,C.green,1.5)
        end
    else
        Pen.circle(vg,cx,cy,size*0.3,C.orange,2)
    end
end

-- ============================================================================
-- 瓷砖绘制
-- ============================================================================

--- 绘制装饰半透明圆（瓷砖内部）
local function drawDecoCircles(vg, x, y, w, h)
    -- 右上角大圆
    nvgBeginPath(vg)
    nvgCircle(vg, x + w - 8, y + 8, 35)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 12))
    nvgFill(vg)
    -- 左下角
    nvgBeginPath(vg)
    nvgCircle(vg, x + 10, y + h - 10, 24)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 10))
    nvgFill(vg)
    -- 右下小圆
    nvgBeginPath(vg)
    nvgCircle(vg, x + w - 20, y + h - 5, 16)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 8))
    nvgFill(vg)
end

--- 绘制 NEW/HOT 角标
---@param vg userdata
---@param x number 瓷砖左上角 X
---@param y number 瓷砖左上角 Y
---@param size number 瓷砖边长
---@param config table 游戏配置
local function drawBadge(vg, x, y, size, config)
    local label = nil
    local bgColor = nil

    if config.isNew then
        label = "新"
        bgColor = Colors.tagNew
    elseif config.isHot then
        label = "热门"
        bgColor = Colors.tagHot
    end

    if not label then return end

    local badgeW = 38
    local badgeH = 18
    local bx = x + size - badgeW - 6
    local by = y + 6

    -- 角标背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, by, badgeW, badgeH, 9)
    nvgFillColor(vg, nvgRGBA(bgColor[1], bgColor[2], bgColor[3], 230))
    nvgFill(vg)

    -- 角标文字
    nvgFontFace(vg, "menu")
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, bx + badgeW / 2, by + badgeH / 2, label)
end

--- 绘制完整的游戏瓷砖
---@param vg userdata NanoVG 上下文
---@param x number 瓷砖左上角 X
---@param y number 瓷砖左上角 Y
---@param size number 瓷砖边长（正方形）
---@param config table 游戏配置
---@param index number 瓷砖索引（1-based，用于选择主题色）
function M.drawTile(vg, x, y, size, config, index)
    local fills={{246,216,165,255},{220,232,196,255},{242,226,166,255},{227,216,230,255}}
    Paper.panel(vg,x,y,size,size,fills[((index-1)%#fills)+1])
    local centerX=x+size/2
    local iconSize=math.min(98,size*0.54)
    local iconY=y+size*0.34
    M.drawGameIcon(vg,centerX,iconY,iconSize,config.gameId)
    Paper.text(vg,centerX,y+size*0.69,config.title,math.min(18,size*0.12),C.ink,nil,"menu")
    if config.subtitle and config.subtitle~="" then
        Paper.text(vg,centerX,y+size*0.85,config.subtitle,math.min(12,size*0.078),C.muted,nil,"menu")
    end
    drawBadge(vg,x,y,size,config)
end
return M
