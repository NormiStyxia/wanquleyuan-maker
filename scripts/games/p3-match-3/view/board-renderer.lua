--- 消消乐 - 棋盘渲染器
--- 职责：NanoVG 矢量绘制方块网格、交换/消除/掉落动画、特殊方块图标
--- 约束：仅只读访问逻辑层状态，不修改 board

local State = require("games.p3-match-3.logic.state")
local Board = require("games.p3-match-3.logic.board")
local LAYOUT = require("shared.constants.layout")
local PlayArea = require("shared.layout.game-board")
local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local M = {}

local BG_COLOR = { 245, 240, 230 }
local GRID_BG = { 245, 240, 230, 240 }
local SELECT_RING = { 255, 255, 255, 200 }

-- 动画控制器（已提取到 animation/anim-controller.lua）
local animCtrl = require("games.p3-match-3.animation.anim-controller")

-- 粒子特效系统（已提取到 fx/particle-system.lua）
local particleFx = require("games.p3-match-3.fx.particle-system")

-- 方块绘制（已提取到 rendering/tile-renderer.lua）
local tileRenderer = require("games.p3-match-3.rendering.tile-renderer")
local drawTile = tileRenderer.drawTile

-- 选中方块（第一次点击选中，第二次点击交换）
---@type table|nil { row, col }
local selectedCell_ = nil
local selectedAt_ = 0

-- 棋盘布局缓存
---@type table|nil { x, y, cellSize, gap, totalW, totalH }
local layout_ = nil

-- ============================================================================
-- 布局计算
-- ============================================================================

--- 计算棋盘布局
---@param screenW number
---@param screenH number
---@param rows number
---@param cols number
---@param topOffset number
---@param bottomOffset number
---@return table layout
function M.calcLayout(screenW, screenH, rows, cols, topOffset, bottomOffset)
    local area=PlayArea.calc(screenW,screenH,rows,cols,topOffset,bottomOffset,{gap=2})
    local cellWithGap,gap=area.cell,area.gap
    local totalW,totalH=area.width,area.height
    local x,y=area.x,area.y

    layout_ = {
        x = x, y = y,
        cellSize = cellWithGap,
        gap = gap,
        totalW = totalW, totalH = totalH,
        rows = rows, cols = cols,
    }
    particleFx.setLayout(layout_)
    return layout_
end

--- 获取格子中心坐标
---@param row number
---@param col number
---@return number cx, number cy
function M.getCellCenter(row, col)
    if not layout_ then return 0, 0 end
    local l = layout_
    local cx = l.x + (col - 1) * (l.cellSize + l.gap) + l.cellSize / 2
    local cy = l.y + (row - 1) * (l.cellSize + l.gap) + l.cellSize / 2
    return cx, cy
end

--- 屏幕坐标命中测试
---@param mx number
---@param my number
---@return number|nil row, number|nil col
function M.hitTest(mx, my)
    if not layout_ then return nil, nil end
    local l = layout_

    local relX = mx - l.x
    local relY = my - l.y
    if relX < 0 or relY < 0 then return nil, nil end

    local step = l.cellSize + l.gap
    local col = math.floor(relX / step) + 1
    local row = math.floor(relY / step) + 1

    if col < 1 or col > l.cols or row < 1 or row > l.rows then
        return nil, nil
    end

    -- 检查是否在 gap 区域
    local inCellX = relX - (col - 1) * step
    local inCellY = relY - (row - 1) * step
    if inCellX > l.cellSize or inCellY > l.cellSize then
        return nil, nil
    end

    return row, col
end

-- ============================================================================
-- 选中状态
-- ============================================================================

function M.getSelected()
    return selectedCell_
end

function M.setSelected(cell)
    if cell and (not selectedCell_ or cell.row~=selectedCell_.row or cell.col~=selectedCell_.col) then
        selectedAt_=animCtrl.rainbowTime
    end
    selectedCell_ = cell
end

function M.clearSelected()
    selectedCell_ = nil
end

-- ============================================================================
-- 粒子特效代理（外部通过 boardRenderer 调用）
-- ============================================================================

function M.setScoreTarget(x, y)
    particleFx.setScoreTarget(x, y)
end

function M.spawnElimParticles(cells)
    particleFx.spawnElimParticles(cells, layout_, M.getCellCenter)
end

function M.spawnIceDamageEffects(damagedCells)
    particleFx.spawnIceDamageEffects(damagedCells, layout_, M.getCellCenter)
end

-- ============================================================================
-- 动画控制代理（委托到 animCtrl）
-- ============================================================================

function M.startSwapAnim(fromR, fromC, toR, toC, durationMs, reverse)
    animCtrl.startSwap(fromR, fromC, toR, toC, durationMs, reverse)
end

function M.startShakeAnim(row, col, dr, dc, durationMs)
    animCtrl.startShake(row, col, dr, dc, durationMs)
end

function M.startElimAnim(cells, durationMs)
    animCtrl.startElim(cells, durationMs)
end

function M.startFallAnim(cells, durationMsPerCell)
    animCtrl.startFall(cells, durationMsPerCell)
end

function M.startComboAnim(combo, screenW)
    animCtrl.startCombo(combo, screenW, layout_ and layout_.y or nil)
end

function M.isAnimating()
    return animCtrl.isAnimating()
end

--- 更新动画
---@param dt number
---@return boolean finished
function M.updateAnim(dt)
    local finished = animCtrl.update(dt)

    -- 彩虹方块动画时间（转发到 tileRenderer）
    tileRenderer.setRainbowTime(animCtrl.rainbowTime)

    -- 更新粒子（独立于状态机，跨状态持续）
    particleFx.update(dt)

    return finished
end

function M.clearAnims()
    animCtrl.clearAnims()
end

--- 重置所有状态
function M.resetAll()
    animCtrl.resetAll()
    selectedCell_ = nil
    particleFx.reset()
    layout_ = nil
end

-- ============================================================================
-- 主绘制入口
-- ============================================================================

--- 绘制棋盘
---@param vg userdata
---@param board table Board 实例
---@param screenW number
---@param screenH number
function M.draw(vg, board, screenW, screenH)
    if not layout_ then return end
    local l = layout_

    -- 应用屏幕震动偏移
    local shakeOffX, shakeOffY = particleFx.getShakeOffset()
    local hasShake = (shakeOffX ~= 0 or shakeOffY ~= 0)
    if hasShake then
        nvgSave(vg)
        nvgTranslate(vg, shakeOffX, shakeOffY)
    end

    Paper.panel(vg,l.x-6,l.y-6,l.totalW+12,l.totalH+12,{239,226,194,255})

    -- 格子底色
    for r = 1, l.rows do
        for c = 1, l.cols do
            local cx, cy = M.getCellCenter(r, c)
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cx - l.cellSize / 2, cy - l.cellSize / 2,
                l.cellSize, l.cellSize, 4)
            nvgFillColor(vg, nvgRGBA(255, 246, 220, 240))
            nvgFill(vg)
            nvgStrokeColor(vg,nvgRGBA(185,165,123,100))
            nvgStrokeWidth(vg,1); nvgStroke(vg)
        end
    end

    local state = board.stateMachine.current

    -- 绘制方块（根据状态决定动画）
    if state == State.SWAP_BACK then
        M._drawWithShakeAnim(vg, board)
    elseif state == State.SWAPPING then
        M._drawWithSwapAnim(vg, board)
    elseif state == State.ELIMINATING then
        M._drawWithElimAnim(vg, board)
    elseif state == State.FALLING then
        M._drawWithFallAnim(vg, board)
    else
        M._drawStatic(vg, board)
    end

    -- 选中高亮
    if selectedCell_ and state == State.IDLE then
        local cx, cy = M.getCellCenter(selectedCell_.row, selectedCell_.col)
        Paper.selection(vg,cx-l.cellSize/2,cy-l.cellSize/2,l.cellSize,animCtrl.rainbowTime-selectedAt_)
    end



    -- 粒子特效（在所有方块之上）
    particleFx.draw(vg)

    -- 恢复震动偏移
    if hasShake then
        nvgRestore(vg)
    end

    -- combo 文本（不受震动影响，保持稳定）
    M._drawCombo(vg)
end

--- 静态绘制（Idle / Settled / ChainCheck 等）
function M._drawStatic(vg, board)
    if not layout_ then return end
    local l = layout_

    for r = 1, board.rows do
        for c = 1, board.cols do
            local tile = board:getTile(r, c)
            if tile then
                local cx, cy = M.getCellCenter(r, c)
                -- 冰块受伤震动偏移
                if tile.special == Board.SPECIAL_ICE then
                    local ox, oy = particleFx.getIceShakeOffset(r, c)
                    cx, cy = cx + ox, cy + oy
                end
                local selected=selectedCell_ and selectedCell_.row==r and selectedCell_.col==c
                    and board.stateMachine.current==State.IDLE
                local age=math.max(0,animCtrl.rainbowTime-selectedAt_)
                local lift=selected and 1.7*(1-math.exp(-age*18)) or 0
                drawTile(vg, cx, cy-lift, l.cellSize - 2, tile.colorId, tile.special, 1.0, 1.0, tile.hp)
            end
        end
    end
end

--- 交换动画绘制
function M._drawWithSwapAnim(vg, board)
    if not layout_ or not animCtrl.swapAnim then
        M._drawStatic(vg, board)
        return
    end
    local l = layout_
    local sa = animCtrl.swapAnim
    local t = particleFx.easeOutQuad(animCtrl.progress)
    if animCtrl.swapAnimReverse then t = 1 - t end

    for r = 1, board.rows do
        for c = 1, board.cols do
            local tile = board:getTile(r, c)
            if tile then
                local cx, cy = M.getCellCenter(r, c)

                -- 正在交换的两个格子做位移插值
                if r == sa.fromR and c == sa.fromC then
                    local toCx, toCy = M.getCellCenter(sa.toR, sa.toC)
                    cx = cx + (toCx - cx) * t
                    cy = cy + (toCy - cy) * t
                elseif r == sa.toR and c == sa.toC then
                    local fromCx, fromCy = M.getCellCenter(sa.fromR, sa.fromC)
                    cx = cx + (fromCx - cx) * t
                    cy = cy + (fromCy - cy) * t
                end

                -- 冰块受伤震动偏移
                if tile.special == Board.SPECIAL_ICE then
                    local ox, oy = particleFx.getIceShakeOffset(r, c)
                    cx, cy = cx + ox, cy + oy
                end
                drawTile(vg, cx, cy, l.cellSize - 2, tile.colorId, tile.special, 1.0, 1.0, tile.hp)
            end
        end
    end
end

--- 抖动动画绘制（无效交换，方块轻微前移后弹回）
function M._drawWithShakeAnim(vg, board)
    if not layout_ or not animCtrl.shakeAnim then
        M._drawStatic(vg, board)
        return
    end
    local l = layout_
    local sa = animCtrl.shakeAnim
    local t = animCtrl.progress

    -- 前 40% 时间：方块向目标方向移动 ~30% 格距
    -- 后 60% 时间：弹回原位（带减速）
    local offset
    if t < 0.4 then
        offset = (t / 0.4) * 0.3
    else
        local back = (t - 0.4) / 0.6
        offset = 0.3 * (1 - back * back)  -- 减速回弹
    end

    local stepX = (l.cellSize + l.gap) * sa.dc * offset
    local stepY = (l.cellSize + l.gap) * sa.dr * offset

    for r = 1, board.rows do
        for c = 1, board.cols do
            local tile = board:getTile(r, c)
            if tile then
                local cx, cy = M.getCellCenter(r, c)
                if r == sa.row and c == sa.col then
                    cx = cx + stepX
                    cy = cy + stepY
                end
                -- 冰块受伤震动偏移
                if tile.special == Board.SPECIAL_ICE then
                    local ox, oy = particleFx.getIceShakeOffset(r, c)
                    cx, cy = cx + ox, cy + oy
                end
                drawTile(vg, cx, cy, l.cellSize - 2, tile.colorId, tile.special, 1.0, 1.0, tile.hp)
            end
        end
    end
end

--- 消除动画绘制
function M._drawWithElimAnim(vg, board)
    if not layout_ then return end
    local l = layout_
    local t = particleFx.easeOutQuad(animCtrl.progress)

    -- 先绘制未被消除的方块
    local elimKeys = {}
    for _, e in ipairs(animCtrl.elimAnims) do
        elimKeys[e.row * 100 + e.col] = true
    end

    for r = 1, board.rows do
        for c = 1, board.cols do
            local tile = board:getTile(r, c)
            if tile and not elimKeys[r * 100 + c] then
                local cx, cy = M.getCellCenter(r, c)
                -- 冰块受伤震动偏移
                if tile.special == Board.SPECIAL_ICE then
                    local ox, oy = particleFx.getIceShakeOffset(r, c)
                    cx, cy = cx + ox, cy + oy
                end
                drawTile(vg, cx, cy, l.cellSize - 2, tile.colorId, tile.special, 1.0, 1.0, tile.hp)
            end
        end
    end

    -- 纸片轻弹后收起；不覆盖白闪，消除前仍能识别原色和特殊图标。
    for _, e in ipairs(animCtrl.elimAnims) do
        local cx,cy=M.getCellCenter(e.row,e.col)
        local shrink=math.max(0,(t-0.18)/0.82)
        local scale=t<0.18 and (1+t/0.18*0.06) or (1.06*(1-shrink*0.9))
        drawTile(vg,cx,cy,l.cellSize-2,e.colorId,e.special,1-shrink,scale)
    end
end

--- 掉落动画绘制
function M._drawWithFallAnim(vg, board)
    if not layout_ then return end
    local l = layout_
    local t = particleFx.easeOutBounce(math.min(1, animCtrl.progress))

    -- 标记正在下落的列位
    local fallingKeys = {}
    for _, f in ipairs(animCtrl.fallAnims) do
        -- 标记目标位置
        fallingKeys[f.toRow * 100 + f.col] = true
    end

    -- 绘制非下落方块
    for r = 1, board.rows do
        for c = 1, board.cols do
            local tile = board:getTile(r, c)
            if tile and not fallingKeys[r * 100 + c] then
                local cx, cy = M.getCellCenter(r, c)
                drawTile(vg, cx, cy, l.cellSize - 2, tile.colorId, tile.special, 1.0, 1.0, tile.hp)
            end
        end
    end

    -- 绘制下落方块（从 fromRow 到 toRow 插值）
    for _, f in ipairs(animCtrl.fallAnims) do
        local fromCx, fromCy = M.getCellCenter(f.fromRow, f.col)
        local toCx, toCy = M.getCellCenter(f.toRow, f.col)
        if f.isNew then
            -- 新方块从上方屏幕外落入
            fromCy = fromCy - l.cellSize * 1.5
        end
        local cy = fromCy + (toCy - fromCy) * t
        drawTile(vg, toCx, cy, l.cellSize - 2, f.colorId, f.special, 1.0, 1.0)
    end
end

--- 连锁提示留在棋盘上方，小纸签上浮，不放大遮住格子。
function M._drawCombo(vg)
    local ca=animCtrl.comboAnim
    if not ca or ca.alpha<0.02 then return end
    local size=20+math.min(ca.combo or 2,8)
    nvgFontFace(vg,"sans"); nvgFontSize(vg,size)
    local width=(nvgTextBounds(vg,0,0,ca.text) or 90)+24
    local y=layout_ and math.max(113,math.min(ca.y,layout_.y-24)) or ca.y
    nvgSave(vg); nvgGlobalAlpha(vg,ca.alpha)
    Paper.panel(vg,ca.x-width/2,y-19,width,38)
    Paper.text(vg,ca.x,y,ca.text,size,C.ink)
    nvgRestore(vg)
end

-- ============================================================================
-- 拖拽支持
-- ============================================================================

---@type table|nil { row, col, sx, sy }
local dragStart_ = nil

function M.getDragStart()
    return dragStart_
end

function M.setDragStart(info)
    dragStart_ = info
end

function M.clearDragStart()
    dragStart_ = nil
end

--- 判断拖拽方向
---@param sx number 起始屏幕 X
---@param sy number 起始屏幕 Y
---@param ex number 结束屏幕 X
---@param ey number 结束屏幕 Y
---@return number dr, number dc 方向偏移 (-1/0/1)
function M.getDragDirection(sx, sy, ex, ey)
    local dx = ex - sx
    local dy = ey - sy
    local threshold = 10

    if math.abs(dx) < threshold and math.abs(dy) < threshold then
        return 0, 0
    end

    if math.abs(dx) > math.abs(dy) then
        return 0, dx > 0 and 1 or -1
    else
        return dy > 0 and 1 or -1, 0
    end
end

return M
