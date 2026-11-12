--- 记忆翻牌 - 卡牌渲染器
--- 职责：绘制卡牌（背面/正面/配对状态）+ 矢量图案库 + 翻转动画
local Board = require("games.p2-memory-flip.logic.board")
local celebrationFx = require("shared.components.celebration-effects")

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local M = {}
local Sprites=require("shared.rendering.piece-sprites")

-- 翻转动画（已提取到 animation/flip-controller.lua）
local flipCtrl = require("games.p2-memory-flip.animation.flip-controller")

--- 重置动画状态（兼容外部调用）
function M.resetAnims()
    flipCtrl.reset()
end

--- 驱动动画更新（每帧调用）- 含配对特效触发
---@param dt number
---@param board table Board 实例
---@param layout table|nil calcLayout 返回值
function M.updateAnims(dt, board, layout)
    local newlyMatched = flipCtrl.detectChanges(board)

    -- 如果有两张卡配对成功且有布局信息，触发配对特效
    if #newlyMatched == 2 and layout then
        local c1 = newlyMatched[1]
        local c2 = newlyMatched[2]
        local cx1 = layout.startX + (c1.col - 1) * (layout.cardSize + layout.gap) + layout.cardSize / 2
        local cy1 = layout.startY + (c1.row - 1) * (layout.cardSize + layout.gap) + layout.cardSize / 2
        local cx2 = layout.startX + (c2.col - 1) * (layout.cardSize + layout.gap) + layout.cardSize / 2
        local cy2 = layout.startY + (c2.row - 1) * (layout.cardSize + layout.gap) + layout.cardSize / 2

        local hash = 0
        for ci = 1, #c1.artKey do
            hash = hash + string.byte(c1.artKey, ci)
        end
        local colorIndex = (hash % #M.PALETTE) + 1

        local color = M.PALETTE[colorIndex] or nvgRGBA(231, 76, 60, 255)
        M.triggerMatchEffect(cx1, cy1, cx2, cy2, layout.cardSize, color)
    end

    flipCtrl.advance(dt)
end

-- 配对特效（已提取到 fx/particle-system.lua）
local matchFx = require("games.p2-memory-flip.fx.particle-system")
M.triggerMatchEffect = matchFx.triggerMatchEffect
M.updateMatchEffects = matchFx.updateMatchEffects
M.getMatchBounceScale = matchFx.getMatchBounceScale
M.drawMatchEffects = matchFx.drawMatchEffects
M.resetMatchEffects = matchFx.resetMatchEffects
-- ============================================================================
-- 通关庆祝特效（委托给共享模块）
-- ============================================================================

---@type table|nil
local celebration_ = nil

--- 启动通关庆祝特效
---@param screenW number
---@param screenH number
---@param rank string "S"/"A"/"B"/"C"
function M.startCelebration(screenW, screenH, rank)
    celebration_ = celebrationFx.create(screenW, screenH, {
        fireworkCount = 8,
        confettiCount = 55,
        enableRankAnim = true,
        elasticStyle = "step",
    })
    celebration_.rank = rank
    celebration_.active = true
end

--- 获取庆祝状态
---@return table|nil
function M.getCelebration()
    return celebration_
end

--- 庆祝是否活跃
---@return boolean
function M.isCelebrating()
    return celebration_ ~= nil and celebration_.active
end

--- 停止庆祝
function M.stopCelebration()
    celebration_ = nil
end

--- 更新庆祝特效（每帧调用）
---@param dt number
function M.updateCelebration(dt)
    if not celebration_ or not celebration_.active then return end
    celebrationFx.update(celebration_, dt)
end

-- ============================================================================
-- 配色
-- ============================================================================

M.COLORS = {
    background = { 245, 240, 230, 255 },
    cardBack = { 235, 145, 65 },
    cardBackPattern = { 210, 125, 55 },
    cardFront = { 255, 255, 255 },
    cardBorder = { 220, 215, 205 },
    cardMatched = { 230, 248, 230 },
    cardMatchedBorder = { 120, 200, 120 },
    cardHighlight = { 255, 250, 200 },
}

--- 图案配色调色板（确保同关卡内区分度足够）
M.PALETTE = {
    nvgRGBA(231, 76, 60, 255),     -- 红
    nvgRGBA(46, 204, 113, 255),    -- 绿
    nvgRGBA(52, 152, 219, 255),    -- 蓝
    nvgRGBA(241, 196, 15, 255),    -- 黄
    nvgRGBA(155, 89, 182, 255),    -- 紫
    nvgRGBA(230, 126, 34, 255),    -- 橙
    nvgRGBA(26, 188, 156, 255),    -- 青
    nvgRGBA(236, 100, 175, 255),   -- 粉
    nvgRGBA(52, 73, 94, 255),      -- 深灰蓝
    nvgRGBA(192, 57, 43, 255),     -- 深红
    nvgRGBA(39, 174, 96, 255),     -- 翠绿
    nvgRGBA(41, 128, 185, 255),    -- 钢蓝
    nvgRGBA(142, 68, 173, 255),    -- 深紫
    nvgRGBA(211, 84, 0, 255),      -- 深橙
    nvgRGBA(22, 160, 133, 255),    -- 深青
    nvgRGBA(243, 156, 18, 255),    -- 琥珀
    nvgRGBA(127, 140, 141, 255),   -- 灰
    nvgRGBA(44, 62, 80, 255),      -- 暗蓝
    nvgRGBA(230, 80, 100, 255),    -- 玫红
    nvgRGBA(100, 180, 80, 255),    -- 草绿
    nvgRGBA(80, 100, 200, 255),    -- 靛蓝
    nvgRGBA(200, 150, 50, 255),    -- 金色
    nvgRGBA(170, 80, 160, 255),    -- 兰紫
    nvgRGBA(80, 190, 180, 255),    -- 湖绿
}

-- 矢量图案（已提取到 shared/rendering/vector-shapes.lua）
local shapes = require("shared.rendering.vector-shapes")
M.shapes = shapes
-- 布局计算（已提取到 layout/grid-calculator.lua）
local gridCalc = require("games.p2-memory-flip.layout.grid-calculator")
M.calcLayout = gridCalc.calc
-- ============================================================================
-- 卡牌绘制
-- ============================================================================

--- 背面呼吸光效计时器
local backGlowTimer_ = 0

--- 更新背面呼吸光效
---@param dt number
function M.updateBackGlow(dt)
    backGlowTimer_ = backGlowTimer_ + dt
end

--- 绘制单张卡牌背面
---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
local function drawCardBack(vg, x, y, w, h)
    Paper.panel(vg, x, y, w, h, C.orange)
    local cx, cy, d = x+w/2, y+h/2, math.min(w,h)*0.14
    nvgBeginPath(vg); nvgMoveTo(vg,cx,cy-d); nvgLineTo(vg,cx+d,cy)
    nvgLineTo(vg,cx,cy+d); nvgLineTo(vg,cx-d,cy); nvgClosePath(vg)
    Pen.paint(vg,C.paper,1.8)
end

local function drawCardFront(vg, x, y, w, h, artKey, color, isMatched, isHighlighting, colorIndex)
    Paper.panel(vg,x,y,w,h,isMatched and {225,235,193,255} or C.paper)
    local drawFn = shapes[artKey]
    if not Sprites.pattern(vg,artKey,x+w/2,y+h/2,math.min(w,h)*0.85,colorIndex,"memory") and drawFn then
        drawFn(vg,x+w/2,y+h/2,math.min(w,h)*0.85,color)
    end
    if isMatched then
        -- 小勾与底色一起表达配对成功，不依赖颜色。
        nvgBeginPath(vg); nvgMoveTo(vg,x+w-13,y+7); nvgLineTo(vg,x+w-10,y+10)
        nvgLineTo(vg,x+w-5,y+4); nvgStrokeColor(vg,Pen.color(C.ink))
        nvgStrokeWidth(vg,1.8); nvgStroke(vg)
    elseif isHighlighting then
        Paper.selection(vg,x,y,math.min(w,h),backGlowTimer_,C.orange)
    end
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 绘制整个卡牌网格（含翻转动画）
---@param vg userdata
---@param board table Board 实例
---@param layout table calcLayout 返回值
function M.drawCards(vg, board, layout)
    Paper.panel(vg, layout.startX-7,layout.startY-7,layout.gridW+14,layout.gridH+14,{239,226,194,255})

    for _, card in ipairs(board.cards) do
        local col = card.col
        local row = card.row
        local x = layout.startX + (col - 1) * (layout.cardSize + layout.gap)
        local y = layout.startY + (row - 1) * (layout.cardSize + layout.gap)
        local w = layout.cardSize
        local h = layout.cardSize

        -- 获取动画显示状态
        local displayFace, scaleX = flipCtrl.getCardDisplay(card.index, card.state)

        -- 卡牌中心
        local centerX = x + w / 2
        local centerY = y + h / 2

        -- 侧面保留一笔细线。
        if scaleX < 0.02 then
            nvgBeginPath(vg); nvgMoveTo(vg,centerX,y); nvgLineTo(vg,centerX,y+h)
            nvgStrokeColor(vg,Pen.color(C.ink)); nvgStrokeWidth(vg,1.5); nvgStroke(vg)
            goto continue
        end

        -- 配对弹跳缩放
        local bounceScale = M.getMatchBounceScale(centerX, centerY)

        -- 合并水平翻转缩放 + 均匀弹跳缩放
        local finalW = w * scaleX * bounceScale
        local finalH = h * bounceScale
        local finalX = centerX - finalW / 2
        local finalY = centerY - finalH / 2



        if displayFace == "back" then
            drawCardBack(vg, finalX, finalY, finalW, finalH)
        else
            -- 根据图案在调色板中的索引分配颜色
            local hash = 0
            for c = 1, #card.artKey do
                hash = hash + string.byte(card.artKey, c)
            end
            local colorIndex = (hash % #M.PALETTE) + 1

            local isMatched = card.state == Board.CARD_MATCHED
            local isHighlighting = card.state == Board.CARD_FLIPPED and board:isHighlighting()

            local color = M.PALETTE[colorIndex] or nvgRGBA(231, 76, 60, 255)
            drawCardFront(vg, finalX, finalY, finalW, finalH, card.artKey, color, isMatched, isHighlighting,colorIndex)
        end

        ::continue::
    end

    -- 配对特效绘制在卡牌上方
    M.drawMatchEffects(vg)
end

--- 根据屏幕坐标判断点击了哪张卡牌
---@param mx number
---@param my number
---@param layout table
---@param board table
---@return number|nil cardIndex
function M.hitTestCard(mx, my, layout, board)
    for _, card in ipairs(board.cards) do
        local x = layout.startX + (card.col - 1) * (layout.cardSize + layout.gap)
        local y = layout.startY + (card.row - 1) * (layout.cardSize + layout.gap)
        if mx >= x and mx <= x + layout.cardSize and my >= y and my <= y + layout.cardSize then
            return card.index
        end
    end
    return nil
end

return M
