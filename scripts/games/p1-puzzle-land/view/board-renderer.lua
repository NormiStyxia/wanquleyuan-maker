--- 推箱子棋盘渲染器
--- 职责：用 NanoVG 绘制棋盘（地板、墙、冰面、目标点、箱子、玩家、HUD）
--- 约束：只读逻辑层状态 + 动画系统的位置数据，不修改任何逻辑状态

local LAYOUT = require("shared.constants.layout")
local PlayArea = require("shared.layout.game-board")
local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local M = {}

-- ============================================================================
-- 配色方案
-- ============================================================================

local COLORS = {
    background  = { 255, 245, 228, 255 },   -- 暖奶油色背景
    bgDecoLight = { 245, 230, 205, 255 },   -- 背景装饰浅色
    bgDecoDark  = { 235, 215, 185, 255 },   -- 背景装饰深色
    floor       = { 238, 222, 195, 255 },   -- 沙黄色地板
    floorShine  = { 248, 238, 218, 100 },   -- 地板微光泽
    wall        = { 175, 125,  85, 255 },   -- 陶土色墙体
    wallTop     = { 195, 150, 110, 255 },   -- 浅陶土高光
    wallShadow  = { 145, 100,  65, 255 },   -- 墙体底部阴影
    ice         = { 180, 220, 235, 170 },   -- 微暖的冰面
    iceShine    = { 225, 242, 255, 110 },   -- 冰面光泽
    target      = { 255, 155,  50, 200 },   -- 橙色目标圈
    targetDot   = { 255, 185,  55, 255 },   -- 琥珀色目标点
    targetGlow  = { 255, 175,  50,  30 },   -- 目标点外围微光
    box         = { 230, 160,  55, 255 },   -- 明亮木箱色
    boxTop      = { 245, 185,  80, 255 },   -- 箱子顶部高光
    boxDone     = { 135, 200,  70, 255 },   -- 明亮黄绿完成
    boxDoneTop  = { 160, 220, 100, 255 },   -- 完成箱子高光
    boxBorder   = { 185, 120,  30, 255 },   -- 深木色边框
    boxDoneBorder = {  90, 160,  45, 255 }, -- 绿色完成边框
    player      = { 255, 125,  60, 255 },   -- 暖橙色玩家
    playerLight = { 255, 160, 100, 255 },   -- 玩家浅色高光
    playerEye   = { 255, 255, 255, 255 },   -- 白色眼睛
    hudBg       = { 120,  78,  42, 215 },   -- 暖棕色 HUD 底
    hudBgLight  = { 150, 105,  60, 215 },   -- HUD 渐变浅色
    hudText     = { 255, 250, 240, 255 },   -- 暖白文字
    hudIcon     = { 255, 215, 140, 255 },   -- HUD 图标色
    gridLine    = { 215, 195, 165,  80 },   -- 暖色网格线
    btnNormal   = { 235, 170,  65, 255 },   -- 琥珀色按钮
    btnHighlight= { 250, 195,  90, 255 },   -- 按钮高光
    btnShadow   = { 195, 135,  40, 255 },   -- 按钮底部阴影色
    btnText     = {  75,  45,  20, 255 },   -- 深棕色按钮文字
    starFilled  = { 255, 215,   0, 255 },   -- 金色星星（与 shared Colors.star.active 一致）
    starGlow    = { 255, 220,  80, 100 },   -- 星星光晕
    starEmpty   = { 200, 185, 160, 255 },   -- 暖灰空星
    -- 传送门
    portalRed       = { 230,  60,  60, 255 },   -- 红色传送门
    portalGreen     = {  60, 190,  80, 255 },   -- 绿色传送门
    portalBlue      = {  70, 130, 230, 255 },   -- 蓝色传送门
    portalRedGlow   = { 230,  60,  60,  50 },   -- 红色光晕
    portalGreenGlow = {  60, 190,  80,  50 },   -- 绿色光晕
    portalBlueGlow  = {  70, 130, 230,  50 },   -- 蓝色光晕
    -- 通关弹窗
    winBg       = { 255, 250, 238, 255 },   -- 弹窗底色
    winGlow     = { 255, 200,  70, 100 },   -- 弹窗金色光晕
    winTitle    = { 140,  90,  35, 255 },   -- 弹窗标题色
    winBtnPrimary   = { 245, 160, 50, 255 },   -- 主按钮色
    winBtnPrimaryHi = { 255, 185, 80, 255 },   -- 主按钮高光
    winBtnSecondary = { 235, 170, 65, 255 },   -- 次按钮色
    winBtnTertiary  = { 220, 205, 180, 255 },  -- 三级按钮色
}

-- ============================================================================
-- 布局计算
-- ============================================================================

--- 计算棋盘的屏幕布局参数
---@param screenW number 屏幕宽度
---@param screenH number 屏幕高度
---@param gridW number 网格列数
---@param gridH number 网格行数
---@return table layout { cellSize, offsetX, offsetY, hudHeight }
function M.calcLayout(screenW, screenH, gridW, gridH)
    local hudHeight = 56
    local bottomPadding = LAYOUT.BOARD_BOTTOM_PADDING
    local topPadding = LAYOUT.BOARD_TOP_PADDING

    local area=PlayArea.calc(screenW,screenH,gridH,gridW,hudHeight+topPadding,bottomPadding,
        {gap=0,maxCell=screenW*.2})
    local cellSize=area.cell
    local boardW,boardH=area.width,area.height
    local offsetX,offsetY=area.x,area.y

    return {
        cellSize = cellSize,
        offsetX = offsetX,
        offsetY = offsetY,
        boardW = boardW,
        boardH = boardH,
        hudHeight = hudHeight,
        bottomPadding = bottomPadding,
    }
end

-- ============================================================================
-- 绘制函数
-- ============================================================================

--- 绘制单个格子的背景（地板/冰面）
local function drawCell(ctx,x,y,size,cellType)
    local pad=1
    if cellType=="wall" then
        Pen.plaque(ctx,x+pad,y+pad,size-2*pad,size-2*pad,{176,151,107,255},2)
        nvgBeginPath(ctx); nvgMoveTo(ctx,x+5,y+size*0.52)
        nvgLineTo(ctx,x+size-5,y+size*0.52)
        nvgMoveTo(ctx,x+size*0.56,y+4); nvgLineTo(ctx,x+size*0.56,y+size*0.52)
        nvgStrokeColor(ctx,nvgRGBA(91,76,47,150)); nvgStrokeWidth(ctx,1.3); nvgStroke(ctx)
    elseif cellType=="floor" or cellType=="ice" then
        Pen.plaque(ctx,x+pad,y+pad,size-2*pad,size-2*pad,
            cellType=="ice" and {184,214,216,255} or {237,223,190,255},1,{201,183,140,255})
        if cellType=="ice" then
            nvgBeginPath(ctx); nvgMoveTo(ctx,x+size*0.25,y+size*0.6)
            nvgLineTo(ctx,x+size*0.55,y+size*0.25)
            nvgMoveTo(ctx,x+size*0.45,y+size*0.7); nvgLineTo(ctx,x+size*0.7,y+size*0.4)
            nvgStrokeColor(ctx,nvgRGBA(255,246,220,220)); nvgStrokeWidth(ctx,2); nvgStroke(ctx)
        end
    end
end



--- 绘制目标点标记
local function drawTarget(ctx, px, py, size)
    local cx, cy = px + size / 2, py + size / 2
    local r = size * 0.15
    -- 外围微光（柔和光晕）
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r + 8)
    nvgFillColor(ctx, nvgRGBA(COLORS.targetGlow[1], COLORS.targetGlow[2], COLORS.targetGlow[3], COLORS.targetGlow[4]))
    nvgFill(ctx)
    -- 外圈
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r + 2)
    nvgStrokeColor(ctx, nvgRGBA(COLORS.target[1], COLORS.target[2], COLORS.target[3], COLORS.target[4]))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)
    -- 内点
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r * 0.5)
    nvgFillColor(ctx, nvgRGBA(COLORS.targetDot[1], COLORS.targetDot[2], COLORS.targetDot[3], COLORS.targetDot[4]))
    nvgFill(ctx)
end

--- 传送门颜色映射
local PORTAL_COLORS = {
    red   = { main = { 230,  60,  60 }, glow = { 230,  60,  60 }, light = { 255, 120, 120 } },
    green = { main = {  60, 190,  80 }, glow = {  60, 190,  80 }, light = { 130, 230, 140 } },
    blue  = { main = {  70, 130, 230 }, glow = {  70, 130, 230 }, light = { 140, 180, 255 } },
}

--- 绘制传送门（旋涡效果）
---@param ctx userdata
---@param px number 格子左上角 x
---@param py number 格子左上角 y
---@param size number 格子尺寸
---@param color string "red"|"green"|"blue"
---@param time number 动画时间
local function drawPortal(ctx, px, py, size, color, time)
    local pc = PORTAL_COLORS[color] or PORTAL_COLORS.red
    local cx, cy = px + size / 2, py + size / 2
    local r = size * 0.35

    -- 外围光晕（脉动）
    local pulseR = r + 6 + math.sin(time * 3) * 3
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, pulseR)
    nvgFillColor(ctx, nvgRGBA(pc.glow[1], pc.glow[2], pc.glow[3], 35))
    nvgFill(ctx)

    -- 外环
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r)
    nvgStrokeColor(ctx, nvgRGBA(pc.main[1], pc.main[2], pc.main[3], 220))
    nvgStrokeWidth(ctx, 2.5)
    nvgStroke(ctx)

    -- 内旋涡线（旋转的弧线）
    local arcCount = 3
    for i = 0, arcCount - 1 do
        local angle = time * 2.5 + (i * math.pi * 2 / arcCount)
        local innerR = r * 0.55
        local ax = cx + math.cos(angle) * innerR
        local ay = cy + math.sin(angle) * innerR
        nvgBeginPath(ctx)
        nvgCircle(ctx, ax, ay, size * 0.06)
        nvgFillColor(ctx, nvgRGBA(pc.light[1], pc.light[2], pc.light[3], 200))
        nvgFill(ctx)
    end

    -- 中心点
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, r * 0.2)
    nvgFillColor(ctx, nvgRGBA(pc.main[1], pc.main[2], pc.main[3], 180))
    nvgFill(ctx)

    -- 门标记文字
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, size * 0.22)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(255, 255, 255, 220))
    nvgText(ctx, cx, cy, "门", nil)
end

--- 绘制传送目标（菱形标记）
---@param ctx userdata
---@param px number 格子左上角 x
---@param py number 格子左上角 y
---@param size number 格子尺寸
---@param color string "red"|"green"|"blue"
---@param time number 动画时间
local function drawPortalTarget(ctx, px, py, size, color, time)
    local pc = PORTAL_COLORS[color] or PORTAL_COLORS.red
    local cx, cy = px + size / 2, py + size / 2
    local r = size * 0.18

    -- 外围光晕（脉动，和门错开节奏）
    local pulseR = r + 4 + math.sin(time * 3 + 1.5) * 2
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy, pulseR)
    nvgFillColor(ctx, nvgRGBA(pc.glow[1], pc.glow[2], pc.glow[3], 25))
    nvgFill(ctx)

    -- 菱形外框
    nvgSave(ctx)
    nvgTranslate(ctx, cx, cy)
    nvgRotate(ctx, math.rad(45))
    nvgBeginPath(ctx)
    nvgRect(ctx, -r, -r, r * 2, r * 2)
    nvgStrokeColor(ctx, nvgRGBA(pc.main[1], pc.main[2], pc.main[3], 180))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    -- 菱形内填充（半透明）
    nvgBeginPath(ctx)
    local innerR = r * 0.6
    nvgRect(ctx, -innerR, -innerR, innerR * 2, innerR * 2)
    nvgFillColor(ctx, nvgRGBA(pc.main[1], pc.main[2], pc.main[3], 50))
    nvgFill(ctx)
    nvgRestore(ctx)

    -- 中心小圆点（上下浮动）
    local floatY = math.sin(time * 2.5) * 1.5
    nvgBeginPath(ctx)
    nvgCircle(ctx, cx, cy + floatY, size * 0.06)
    nvgFillColor(ctx, nvgRGBA(pc.light[1], pc.light[2], pc.light[3], 200))
    nvgFill(ctx)
end

--- 绘制箱子
local function drawBox(ctx, px, py, size, onTarget)
    local pad = size * 0.12
    local c = onTarget and COLORS.boxDone or COLORS.box
    local ct = onTarget and COLORS.boxDoneTop or COLORS.boxTop
    local bc = onTarget and COLORS.boxDoneBorder or COLORS.boxBorder
    local bx, by = px + pad, py + pad
    local bw, bh = size - pad * 2, size - pad * 2

    Paper.panel(ctx,bx,by,bw,bh,onTarget and {164,188,113,255} or C.orange)


    -- 十字线装饰
    local ccx, ccy = px + size / 2, py + size / 2
    local halfLen = size * 0.18
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, ccx - halfLen, ccy)
    nvgLineTo(ctx, ccx + halfLen, ccy)
    nvgMoveTo(ctx, ccx, ccy - halfLen)
    nvgLineTo(ctx, ccx, ccy + halfLen)
    nvgStrokeColor(ctx, nvgRGBA(bc[1], bc[2], bc[3], 130))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    -- 四角小圆点装饰
    local dotR = size * 0.035
    local dotOff = size * 0.22
    nvgBeginPath(ctx)
    nvgCircle(ctx, ccx - dotOff, ccy - dotOff, dotR)
    nvgCircle(ctx, ccx + dotOff, ccy - dotOff, dotR)
    nvgCircle(ctx, ccx - dotOff, ccy + dotOff, dotR)
    nvgCircle(ctx, ccx + dotOff, ccy + dotOff, dotR)
    nvgFillColor(ctx, nvgRGBA(bc[1], bc[2], bc[3], 100))
    nvgFill(ctx)
end

--- 绘制玩家（支持演出动画参数）
---@param ctx userdata
---@param px number 屏幕x
---@param py number 屏幕y
---@param size number 格子尺寸
---@param perfInfo table|nil { offsetX, offsetY, squish, bounceY, eyeSquint }
local function drawPlayer(ctx, px, py, size, perfInfo)
    local cx, cy = px + size / 2, py + size / 2
    local r = size * 0.32

    -- 读取演出 + 灵动动画属性
    local oxPixel, oyPixel = 0, 0
    local scaleX, scaleY = 1.0, 1.0
    local eyeSquint = 0
    local eyeCross = 0
    local breathScale = 1.0
    local blinkProgress = 0
    local eyeDirX, eyeDirY = 0, 0
    local landSquishX, landSquishY = 1.0, 1.0
    local tilt = 0

    if perfInfo then
        if perfInfo.offsetX then
            oxPixel = perfInfo.offsetX * size
            oyPixel = perfInfo.offsetY * size
        end
        if perfInfo.bounceY then
            oyPixel = oyPixel + perfInfo.bounceY * size
        end
        if perfInfo.squish and perfInfo.squish ~= 1.0 then
            scaleX = perfInfo.squish
            scaleY = 2.0 - perfInfo.squish
        end
        if perfInfo.eyeSquint then
            eyeSquint = perfInfo.eyeSquint
        end
        if perfInfo.eyeCross then
            eyeCross = perfInfo.eyeCross
        end
        if perfInfo.breathScale then
            breathScale = perfInfo.breathScale
        end
        if perfInfo.blinkProgress then
            blinkProgress = perfInfo.blinkProgress
        end
        if perfInfo.eyeDirX then
            eyeDirX = perfInfo.eyeDirX
            eyeDirY = perfInfo.eyeDirY or 0
        end
        if perfInfo.landSquishX then
            landSquishX = perfInfo.landSquishX
            landSquishY = perfInfo.landSquishY or 1.0
        end
        if perfInfo.tilt then
            tilt = perfInfo.tilt
        end
    end

    -- 组合缩放：演出压扁 × 呼吸 × 落地弹跳
    scaleX = scaleX * landSquishX
    scaleY = scaleY * breathScale * landSquishY

    nvgSave(ctx)
    nvgTranslate(ctx, cx + oxPixel, cy + oyPixel)
    if tilt ~= 0 then
        nvgRotate(ctx, tilt)
    end
    nvgScale(ctx, scaleX, scaleY)

    Pen.circle(ctx,0,0,r,C.orange,2.3)


    -- 眼睛
    local eyeR = r * 0.22
    local eyeOff = r * 0.3
    local eyeY = -eyeR * 0.5

    -- 整个眼组随移动方向偏移（模拟往那边看）
    local eyeGroupShiftX = eyeDirX * r * 0.28
    local eyeGroupShiftY = eyeDirY * r * 0.24

    if eyeCross > 0 then
        -- X 眼：遇到障碍物时的表情
        local xSize = eyeR * 0.75 * eyeCross
        local xStroke = math.max(1.5, eyeR * 0.25)
        nvgStrokeWidth(ctx, xStroke)
        nvgStrokeColor(ctx, nvgRGBA(60, 40, 30, math.floor(255 * eyeCross)))
        nvgLineCap(ctx, NVG_ROUND)

        -- 左眼 X
        local lx = -eyeOff + eyeGroupShiftX
        local ly = eyeY + eyeGroupShiftY
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, lx - xSize, ly - xSize)
        nvgLineTo(ctx, lx + xSize, ly + xSize)
        nvgMoveTo(ctx, lx + xSize, ly - xSize)
        nvgLineTo(ctx, lx - xSize, ly + xSize)
        nvgStroke(ctx)

        -- 右眼 X
        local rx = eyeOff + eyeGroupShiftX
        local ry = eyeY + eyeGroupShiftY
        nvgBeginPath(ctx)
        nvgMoveTo(ctx, rx - xSize, ry - xSize)
        nvgLineTo(ctx, rx + xSize, ry + xSize)
        nvgMoveTo(ctx, rx + xSize, ry - xSize)
        nvgLineTo(ctx, rx - xSize, ry + xSize)
        nvgStroke(ctx)
    elseif eyeSquint > 0 then
        -- 眯眼：推完满足表情
        local openH = eyeR * 2 * (1 - eyeSquint * 0.7)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, -eyeOff - eyeR + eyeGroupShiftX, eyeY - openH / 2 + eyeGroupShiftY, eyeR * 2, openH, openH / 2)
        nvgRoundedRect(ctx, eyeOff - eyeR + eyeGroupShiftX, eyeY - openH / 2 + eyeGroupShiftY, eyeR * 2, openH, openH / 2)
        nvgFillColor(ctx, nvgRGBA(COLORS.playerEye[1], COLORS.playerEye[2], COLORS.playerEye[3], COLORS.playerEye[4]))
        nvgFill(ctx)
    elseif blinkProgress > 0.1 then
        -- 眨眼：上下收缩
        local openH = eyeR * 2 * (1 - blinkProgress * 0.85)
        nvgBeginPath(ctx)
        nvgRoundedRect(ctx, -eyeOff - eyeR + eyeGroupShiftX, eyeY - openH / 2 + eyeGroupShiftY, eyeR * 2, openH, eyeR)
        nvgRoundedRect(ctx, eyeOff - eyeR + eyeGroupShiftX, eyeY - openH / 2 + eyeGroupShiftY, eyeR * 2, openH, eyeR)
        nvgFillColor(ctx, nvgRGBA(COLORS.playerEye[1], COLORS.playerEye[2], COLORS.playerEye[3], COLORS.playerEye[4]))
        nvgFill(ctx)
    else
        -- 正常眼白 + 瞳孔（整体偏移）
        nvgBeginPath(ctx)
        nvgCircle(ctx, -eyeOff + eyeGroupShiftX, eyeY + eyeGroupShiftY, eyeR)
        nvgCircle(ctx, eyeOff + eyeGroupShiftX, eyeY + eyeGroupShiftY, eyeR)
        nvgFillColor(ctx, nvgRGBA(COLORS.playerEye[1], COLORS.playerEye[2], COLORS.playerEye[3], COLORS.playerEye[4]))
        nvgFill(ctx)

        -- 瞳孔（在眼白偏移基础上再额外偏移）
        local pupilR = eyeR * 0.5
        local pupilMaxOff = eyeR * 0.50
        local pdx = eyeDirX * pupilMaxOff
        local pdy = eyeDirY * pupilMaxOff
        nvgBeginPath(ctx)
        nvgCircle(ctx, -eyeOff + eyeGroupShiftX + pdx, eyeY + eyeGroupShiftY + pdy, pupilR)
        nvgCircle(ctx, eyeOff + eyeGroupShiftX + pdx, eyeY + eyeGroupShiftY + pdy, pupilR)
        nvgFillColor(ctx, nvgRGBA(60, 40, 30, 255))
        nvgFill(ctx)
    end

    nvgRestore(ctx)
end

-- ============================================================================
-- 冰面滑行特效
-- ============================================================================

--- 绘制冰面滑行拖尾（半透明残影）
---@param ctx userdata
---@param slideInfo table 来自 anim:getSlideInfo()
---@param ox number 棋盘偏移 X
---@param oy number 棋盘偏移 Y
---@param cs number 格子尺寸
local function drawSlideTrail(ctx, slideInfo, ox, oy, cs)
    local trail = slideInfo.trail
    if not trail or #trail == 0 then return end

    local pad = cs * 0.12
    for _, tp in ipairs(trail) do
        local px = ox + (tp.x - 1) * cs
        local py = oy + (tp.y - 1) * cs
        local a = math.floor(tp.alpha * 100)
        if a > 5 then
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, px + pad, py + pad, cs - pad * 2, cs - pad * 2, 4)
            nvgFillColor(ctx, nvgRGBA(180, 220, 235, a))
            nvgFill(ctx)
        end
    end
end

--- 绘制正在冰面滑行的箱子（带运动拉伸效果）
---@param ctx userdata
---@param px number 屏幕 x
---@param py number 屏幕 y
---@param size number 格子尺寸
---@param onTarget boolean
---@param slideInfo table
local function drawBoxSliding(ctx, px, py, size, onTarget, slideInfo)
    local pad = size * 0.12
    local c = onTarget and COLORS.boxDone or COLORS.box
    local bc = onTarget and COLORS.boxDoneBorder or COLORS.boxBorder

    -- 运动方向拉伸：在运动方向上稍微拉长，垂直方向压扁
    local stretchFactor = 0.08
    local dx, dy = slideInfo.dx or 0, slideInfo.dy or 0
    local stretchX = math.abs(dx) * stretchFactor * size
    local stretchY = math.abs(dy) * stretchFactor * size

    local drawX = px + pad - stretchX
    local drawY = py + pad - stretchY
    local drawW = size - pad * 2 + stretchX * 2
    local drawH = size - pad * 2 + stretchY * 2

    -- 箱子底部冰面反光
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, drawX + 2, drawY + 2, drawW, drawH, 4)
    nvgFillColor(ctx, nvgRGBA(200, 230, 245, 40))
    nvgFill(ctx)

    -- 箱子主体
    nvgBeginPath(ctx)
    nvgRoundedRect(ctx, drawX, drawY, drawW, drawH, 4)
    nvgFillColor(ctx, nvgRGBA(c[1], c[2], c[3], c[4]))
    nvgFill(ctx)

    nvgStrokeColor(ctx, nvgRGBA(bc[1], bc[2], bc[3], bc[4]))
    nvgStrokeWidth(ctx, 2)
    nvgStroke(ctx)

    -- 十字线装饰
    local cx, cy = px + size / 2, py + size / 2
    local halfLen = size * 0.18
    nvgBeginPath(ctx)
    nvgMoveTo(ctx, cx - halfLen, cy)
    nvgLineTo(ctx, cx + halfLen, cy)
    nvgMoveTo(ctx, cx, cy - halfLen)
    nvgLineTo(ctx, cx, cy + halfLen)
    nvgStrokeColor(ctx, nvgRGBA(bc[1], bc[2], bc[3], 150))
    nvgStrokeWidth(ctx, 1.5)
    nvgStroke(ctx)

    -- 速度线（运动方向后方）
    local lineAlpha = 80
    local lineCount = 3
    for li = 1, lineCount do
        local offset = li * size * 0.08
        local spread = (li - 1) * size * 0.12
        local la = math.floor(lineAlpha * (1 - (li - 1) / lineCount))

        if math.abs(dx) > 0 then
            -- 水平运动：在后方画竖线
            local lx = cx - dx * (size * 0.4 + offset)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, lx, cy - size * 0.15 - spread)
            nvgLineTo(ctx, lx, cy + size * 0.15 + spread)
            nvgStrokeColor(ctx, nvgRGBA(215, 235, 248, la))
            nvgStrokeWidth(ctx, 1)
            nvgStroke(ctx)
        else
            -- 垂直运动：在后方画横线
            local ly = cy - dy * (size * 0.4 + offset)
            nvgBeginPath(ctx)
            nvgMoveTo(ctx, cx - size * 0.15 - spread, ly)
            nvgLineTo(ctx, cx + size * 0.15 + spread, ly)
            nvgStrokeColor(ctx, nvgRGBA(215, 235, 248, la))
            nvgStrokeWidth(ctx, 1)
            nvgStroke(ctx)
        end
    end
end

--- 绘制冰花粒子
---@param ctx userdata
---@param anim table 动画实例
---@param ox number 棋盘偏移 X
---@param oy number 棋盘偏移 Y
---@param cs number 格子尺寸
local function drawIceParticles(ctx, anim, ox, oy, cs)
    local particles = anim:getParticles()
    if not particles or #particles == 0 then return end

    for _, p in ipairs(particles) do
        local px = ox + (p.x - 1) * cs + cs / 2
        local py = oy + (p.y - 1) * cs + cs / 2
        local r = p.size * cs
        local a = math.floor(p.alpha * 255)

        if a > 5 and r > 0.5 then
            nvgBeginPath(ctx)
            nvgCircle(ctx, px, py, r)
            nvgFillColor(ctx, nvgRGBA(215, 238, 250, a))
            nvgFill(ctx)
        end
    end
end

-- ============================================================================
-- 目标命中特效绘制
-- ============================================================================

--- 绘制目标命中的扩散环和金色星光粒子
---@param ctx userdata
---@param anim table 动画实例
---@param ox number 棋盘偏移 X
---@param oy number 棋盘偏移 Y
---@param cs number 格子尺寸
local function drawTargetEffects(ctx, anim, ox, oy, cs)
    local effects = anim:getTargetEffects()
    if not effects or #effects == 0 then return end

    for _, fx in ipairs(effects) do
        if fx.progress < 0 then goto continue end  -- 延迟中

        local cx = ox + (fx.x - 1) * cs + cs / 2
        local cy = oy + (fx.y - 1) * cs + cs / 2

        Paper.burst(ctx,cx,cy,cs,fx.progress)

        ::continue::
    end
end

-- ============================================================================
-- 撞击粒子特效
-- ============================================================================

--- 绘制箱子撞击产生的碎屑粒子
---@param ctx userdata
---@param anim table 动画实例
---@param ox number 棋盘偏移 X
---@param oy number 棋盘偏移 Y
---@param cs number 格子尺寸
local function drawImpactParticles(ctx, anim, ox, oy, cs)
    local particles = anim:getImpactParticles()
    if not particles or #particles == 0 then return end

    for _, p in ipairs(particles) do
        local px = ox + (p.x - 1) * cs + cs / 2
        local py = oy + (p.y - 1) * cs + cs / 2
        local r = p.size * cs
        local a = math.floor(p.alpha * 255)

        if a > 5 and r > 0.3 then
            -- 暖色碎屑（来自箱子/墙壁）
            nvgBeginPath(ctx)
            nvgCircle(ctx, px, py, r)
            nvgFillColor(ctx, nvgRGBA(220, 175, 100, a))
            nvgFill(ctx)

            -- 微光晕
            if r > 0.8 then
                nvgBeginPath(ctx)
                nvgCircle(ctx, px, py, r * 2)
                nvgFillColor(ctx, nvgRGBA(255, 210, 110, math.floor(a * 0.2)))
                nvgFill(ctx)
            end
        end
    end
end

-- ============================================================================
-- 主绘制
-- ============================================================================

--- 绘制完整棋盘
---@param ctx userdata NanoVG 上下文
---@param board table 棋盘逻辑实例（只读）
---@param anim table 动画系统实例
---@param layout table 布局参数
---@param time number|nil 累积时间（用于传送门动画），可选
--- 编辑器与工具栏复用游戏内同一图案，避免试玩前后形象不一致。
function M.drawEditorTile(ctx, key, x, y, size)
    if key == "wall" or key == "floor" or key == "ice" then
        drawCell(ctx, x, y, size, key)
    elseif key == "box" then drawBox(ctx, x, y, size, false)
    elseif key == "target" then drawTarget(ctx, x, y, size)
    elseif key == "player" then drawPlayer(ctx, x, y, size)
    elseif key:match("^portal_") then drawPortal(ctx, x, y, size, key:sub(8), 0)
    elseif key:match("^ptarget_") then drawPortalTarget(ctx, x, y, size, key:sub(9), 0) end
end

function M.drawBoard(ctx, board, anim, layout, time)
    local cs = layout.cellSize
    local ox, oy = layout.offsetX, layout.offsetY

    Paper.panel(ctx,ox-7,oy-7,layout.boardW+14,layout.boardH+14,{239,226,194,255})

    -- 1. 绘制地板、墙、冰面（支持出生动画缩放）
    for gy = 1, board.height do
        for gx = 1, board.width do
            local px = ox + (gx - 1) * cs
            local py = oy + (gy - 1) * cs

            local birthScale = anim:getBirthScale(gx, gy, "cell")
            if birthScale then
                if birthScale < 0.01 then goto nextCell end
                local center_x = px + cs / 2
                local center_y = py + cs / 2
                nvgSave(ctx)
                nvgTranslate(ctx, center_x, center_y)
                nvgScale(ctx, birthScale, birthScale)
                nvgTranslate(ctx, -center_x, -center_y)
            end

            if board:isWall(gx, gy) then
                drawCell(ctx, px, py, cs, "wall")
            elseif board:isIce(gx, gy) then
                drawCell(ctx, px, py, cs, "ice")
            else
                drawCell(ctx, px, py, cs, "floor")
            end

            if birthScale then nvgRestore(ctx) end
            ::nextCell::
        end
    end

    -- 2. 绘制目标点（支持出生动画缩放）
    for _, t in ipairs(board.levelData.targets) do
        local px = ox + (t[1] - 1) * cs
        local py = oy + (t[2] - 1) * cs

        local birthScale = anim:getBirthScale(t[1], t[2], "target")
        if birthScale then
            if birthScale < 0.01 then goto nextTarget end
            local center_x = px + cs / 2
            local center_y = py + cs / 2
            nvgSave(ctx)
            nvgTranslate(ctx, center_x, center_y)
            nvgScale(ctx, birthScale, birthScale)
            nvgTranslate(ctx, -center_x, -center_y)
        end

        drawTarget(ctx, px, py, cs)

        if birthScale then nvgRestore(ctx) end
        ::nextTarget::
    end

    -- 2.5 绘制传送门和传送目标
    local portalTime = time or 0
    if board.levelData.portalList then
        for _, p in ipairs(board.levelData.portalList) do
            local ppx = ox + (p[2] - 1) * cs
            local ppy = oy + (p[3] - 1) * cs
            drawPortal(ctx, ppx, ppy, cs, p[1], portalTime)
        end
    end
    if board.levelData.portalTargetList then
        for _, p in ipairs(board.levelData.portalTargetList) do
            local ppx = ox + (p[2] - 1) * cs
            local ppy = oy + (p[3] - 1) * cs
            drawPortalTarget(ctx, ppx, ppy, cs, p[1], portalTime)
        end
    end

    -- 重置动画检测
    local resetInfo = anim:getResetAnim()

    -- 3. 绘制箱子（使用 box 索引作为动画实体键）
    if resetInfo then
        -- 重置动画期间：绘制缩放的箱子
        local entities = resetInfo.phase == 1 and resetInfo.oldEntities or resetInfo.newEntities
        local progress = resetInfo.progress

        for _, ent in ipairs(entities) do
            if ent.type == "box" then
                local bx, by = ent.x, ent.y
                local epx = ox + (bx - 1) * cs
                local epy = oy + (by - 1) * cs

                -- 计算缩放
                local scale
                if resetInfo.phase == 1 then
                    -- 缩小消失：1.0 → 0.0（加速）
                    scale = 1.0 - progress * progress
                else
                    -- 放大出现：0.0 → 1.0（弹性过冲）
                    if progress < 0.7 then
                        scale = (progress / 0.7) * 1.15
                    elseif progress < 0.85 then
                        local bt = (progress - 0.7) / 0.15
                        scale = 1.15 - 0.2 * bt
                    else
                        local bt = (progress - 0.85) / 0.15
                        scale = 0.95 + 0.05 * bt
                    end
                end

                if scale > 0.01 then
                    local center_x = epx + cs / 2
                    local center_y = epy + cs / 2
                    nvgSave(ctx)
                    nvgTranslate(ctx, center_x, center_y)
                    nvgScale(ctx, scale, scale)
                    nvgTranslate(ctx, -center_x, -center_y)
                    drawBox(ctx, epx, epy, cs, false)
                    nvgRestore(ctx)
                end
            end
        end
        goto skipNormalBoxes
    end

    for i, box in ipairs(board.boxes) do
        local bx, by = box[1], box[2]
        local animKey = "box_" .. i

        -- 出生动画缩放（与重置/滑行互斥，出生期间跳过其它特效）
        local boxBirthScale = anim:getBirthScale(box[1], box[2], "box")
        if boxBirthScale then
            if boxBirthScale < 0.01 then goto nextBox end
            local bpx = ox + (bx - 1) * cs
            local bpy = oy + (by - 1) * cs
            local center_x = bpx + cs / 2
            local center_y = bpy + cs / 2
            nvgSave(ctx)
            nvgTranslate(ctx, center_x, center_y)
            nvgScale(ctx, boxBirthScale, boxBirthScale)
            nvgTranslate(ctx, -center_x, -center_y)
            drawBox(ctx, bpx, bpy, cs, board:isTarget(box[1], box[2]))
            nvgRestore(ctx)
            goto nextBox
        end

        -- 冰面滑行拖尾特效
        local slideInfo = anim:getSlideInfo(animKey)
        if slideInfo and slideInfo.trail then
            drawSlideTrail(ctx, slideInfo, ox, oy, cs)
        end

        -- 获取动画插值位置
        local ax, ay = anim:getAnimPos(animKey)
        if ax then
            bx, by = ax, ay
        end

        -- 箱子撞击偏移
        local impOx, impOy = anim:getBoxImpactOffset(i)

        local px = ox + (bx - 1) * cs
        local py = oy + (by - 1) * cs

        -- 应用撞击偏移
        if impOx then
            px = px + impOx * cs
            py = py + impOy * cs
        end

        local onTarget = board:isTarget(box[1], box[2])

        -- 目标命中缩放弹跳
        local bounceScale = anim:getTargetBounceScale(box[1], box[2])

        -- 冰面滑行：运动方向拉伸效果
        if slideInfo then
            drawBoxSliding(ctx, px, py, cs, onTarget, slideInfo)
        elseif bounceScale and bounceScale ~= 1.0 then
            -- 带缩放弹跳的箱子绘制
            local center_x = px + cs / 2
            local center_y = py + cs / 2
            nvgSave(ctx)
            nvgTranslate(ctx, center_x, center_y)
            nvgScale(ctx, bounceScale, bounceScale)
            nvgTranslate(ctx, -center_x, -center_y)
            drawBox(ctx, px, py, cs, onTarget)
            nvgRestore(ctx)
        else
            drawBox(ctx, px, py, cs, onTarget)
        end
        ::nextBox::
    end

    ::skipNormalBoxes::

    -- 3.5 绘制冰花粒子
    drawIceParticles(ctx, anim, ox, oy, cs)

    -- 3.6 绘制目标命中特效（扩散环 + 金色星光）
    drawTargetEffects(ctx, anim, ox, oy, cs)

    -- 3.7 绘制撞击碎屑粒子
    drawImpactParticles(ctx, anim, ox, oy, cs)

    -- 4. 绘制玩家（含演出动画 / 重置动画）
    if resetInfo then
        -- 重置动画期间：绘制缩放的玩家
        local entities = resetInfo.phase == 1 and resetInfo.oldEntities or resetInfo.newEntities
        local progress = resetInfo.progress

        for _, ent in ipairs(entities) do
            if ent.type == "player" then
                local epx = ox + (ent.x - 1) * cs
                local epy = oy + (ent.y - 1) * cs

                local scale
                if resetInfo.phase == 1 then
                    scale = 1.0 - progress * progress
                else
                    if progress < 0.7 then
                        scale = (progress / 0.7) * 1.15
                    elseif progress < 0.85 then
                        local bt = (progress - 0.7) / 0.15
                        scale = 1.15 - 0.2 * bt
                    else
                        local bt = (progress - 0.85) / 0.15
                        scale = 0.95 + 0.05 * bt
                    end
                end

                if scale > 0.01 then
                    local center_x = epx + cs / 2
                    local center_y = epy + cs / 2
                    nvgSave(ctx)
                    nvgTranslate(ctx, center_x, center_y)
                    nvgScale(ctx, scale, scale)
                    nvgTranslate(ctx, -center_x, -center_y)
                    drawPlayer(ctx, epx, epy, cs, nil)
                    nvgRestore(ctx)
                end
            end
        end

        -- 绘制重置粒子
        local particles = resetInfo.particles
        if particles and #particles > 0 then
            for _, p in ipairs(particles) do
                local ppx = ox + (p.x - 1) * cs + cs / 2
                local ppy = oy + (p.y - 1) * cs + cs / 2
                local r = p.size * cs
                local a = math.floor(p.alpha * 255)

                if a > 5 and r > 0.3 then
                    nvgBeginPath(ctx)
                    nvgCircle(ctx, ppx, ppy, r)
                    nvgFillColor(ctx, nvgRGBA(p.r, p.g, p.b, a))
                    nvgFill(ctx)

                    -- 微光晕
                    if r > 0.8 then
                        nvgBeginPath(ctx)
                        nvgCircle(ctx, ppx, ppy, r * 2.2)
                        nvgFillColor(ctx, nvgRGBA(p.r, p.g, p.b, math.floor(a * 0.25)))
                        nvgFill(ctx)
                    end
                end
            end
        end
    else
        -- 正常绘制玩家
        local playerX, playerY = board.player[1], board.player[2]
        local ax, ay = anim:getAnimPos("player")
        if ax then
            playerX, playerY = ax, ay
        end
        local ppx = ox + (playerX - 1) * cs
        local ppy = oy + (playerY - 1) * cs

        -- 出生动画缩放
        local playerBirthScale = anim:getBirthScale(board.player[1], board.player[2], "player")
        if playerBirthScale then
            if playerBirthScale < 0.01 then goto skipPlayer end
            local center_x = ppx + cs / 2
            local center_y = ppy + cs / 2
            nvgSave(ctx)
            nvgTranslate(ctx, center_x, center_y)
            nvgScale(ctx, playerBirthScale, playerBirthScale)
            nvgTranslate(ctx, -center_x, -center_y)
            drawPlayer(ctx, ppx, ppy, cs, nil)
            nvgRestore(ctx)
            goto skipPlayer
        end

        -- 收集灵动动画信息（始终可用）
        local ambientInfo = anim:getPlayerAnimInfo()

        -- 收集演出信息（推不动/推完 优先级高于灵动动画的变形）
        local perfInfo = {}
        local blockedOx, blockedOy, blockedSquish, blockedEyeCross = anim:getBlockedOffset()
        local pushDone = anim:getPushDoneInfo()

        if blockedOx then
            perfInfo.offsetX = blockedOx
            perfInfo.offsetY = blockedOy
            perfInfo.squish = blockedSquish
            perfInfo.eyeCross = blockedEyeCross or 0
        elseif pushDone then
            perfInfo.bounceY = pushDone.bounceY
            perfInfo.eyeSquint = pushDone.eyeSquint
        end

        -- 合并灵动动画属性
        perfInfo.breathScale = ambientInfo.breathScale
        perfInfo.blinkProgress = ambientInfo.blinkProgress
        perfInfo.eyeDirX = ambientInfo.eyeDirX
        perfInfo.eyeDirY = ambientInfo.eyeDirY
        perfInfo.landSquishX = ambientInfo.landSquishX
        perfInfo.landSquishY = ambientInfo.landSquishY
        perfInfo.tilt = ambientInfo.tilt

        drawPlayer(ctx, ppx, ppy, cs, perfInfo)
        ::skipPlayer::
    end
end

--- 绘制 HUD（步数、关卡名、按钮区）
---@param ctx userdata
---@param screenW number
---@param board table
---@param levelTitle string
---@param layout table
function M.drawHUD(ctx, screenW, board, levelTitle, layout)
    local hudH = layout.hudHeight

    Paper.hud(ctx,screenW,hudH)


    -- 关卡名（左）带图标
    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 15)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, Pen.color(C.muted))
    nvgText(ctx, 14, hudH / 2, "#", nil)
    nvgFillColor(ctx, Pen.color(C.ink))
    nvgFontSize(ctx, 16)
    nvgText(ctx, 36, hudH / 2, levelTitle, nil)

    -- 步数（右）带图标
    local stepsStr = tostring(board.steps)
    nvgFontSize(ctx, 15)
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, Pen.color(C.ink))
    nvgText(ctx, screenW - 16, hudH / 2, stepsStr, nil)
    -- 步数标签
    nvgFontSize(ctx, 11)
    nvgFillColor(ctx, Pen.color(C.muted))
    local _, bounds = nvgTextBounds(ctx, screenW - 16, hudH / 2, stepsStr)
    local stepsLabelX = (bounds and bounds[1] or (screenW - 50)) - 6
    nvgTextAlign(ctx, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgText(ctx, stepsLabelX, hudH / 2, "步数", nil)
end

--- 绘制一个带立体感的按钮
---@param ctx userdata
---@param x number
---@param y number
---@param w number
---@param h number
---@param label string
---@param icon string|nil
local function drawStyledButton(ctx,x,y,w,h,label,icon)
    Paper.button(ctx,x,y,w,h,label,false,true)
end



--- 绘制操作按钮（返回在左上角，撤销/重置在右下角纵向排列）
---@param ctx userdata
---@param screenW number
---@param screenH number
---@param layout table
---@return table[] buttons 按钮区域 { {x,y,w,h,action} }
function M.drawBottomButtons(ctx,screenW,screenH,layout)
    local buttons={}
    local defs={{"返回","back"},{"撤销","undo"},{"重置","reset"}}
    local w=math.min(76,(screenW-40)/3)
    for i,def in ipairs(defs) do
        local x,y=12+(i-1)*(w+8),layout.hudHeight+7
        Paper.button(ctx,x,y,w,44,def[1],false,true)
        buttons[i]={x=x,y=y,w=w,h=44,action=def[2]}
    end
    return buttons
end



--- 绘制底部提示文字（滑动操作引导）
---@param ctx userdata
---@param screenW number
---@param screenH number
---@param layout table
---@param alpha number 0~1 透明度
function M.drawHintText(ctx, screenW, screenH, layout, alpha)
    if alpha <= 0 then return end

    local a = math.floor(alpha * 140)
    local hintY = math.min(screenH-36,layout.offsetY+layout.boardH+26)

    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 13)
    nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(ctx, nvgRGBA(160, 120, 75, a))
    nvgText(ctx, screenW / 2, hintY, "滑动屏幕进行移动", nil)
end

function M.drawWinDialog(ctx,screenW,screenH,steps,stars,anim,hasNextLevel,storylineMode)
    local popup=require("shared.components.result-popup")
    local buttons=popup.drawCleared(ctx,screenW,screenH,{
        ratingType="stars",ratingValue=stars,stats={{label="本次步数",value=tostring(steps)}},
        storylineMode=storylineMode,hasNextLevel=hasNextLevel,
        celebration=anim and anim:getCelebration() or nil,
    })
    for _,btn in ipairs(buttons) do if btn.action=="back" then btn.action="exit_level" end end
    return buttons
end

M.COLORS = COLORS

return M
