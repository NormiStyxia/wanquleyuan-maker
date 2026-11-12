--- 连连看 - 棋盘渲染
--- 职责：网格绘制、方块绘制、选中高亮、连线动画、消除动画
local tileRenderer = require("games.p4-link-match.view.tile-renderer")
local State = require("games.p4-link-match.logic.state")
local LAYOUT = require("shared.constants.layout")
local PlayArea = require("shared.layout.game-board")

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local M = {}
local selectionBoard_, selectionKey_, selectionAt_

-- 背景色
M.BG_COLOR = { 245, 240, 230, 255 }

-- ============================================================================
-- 布局计算
-- ============================================================================

--- 计算网格布局
---@param screenW number
---@param screenH number
---@param rows number
---@param cols number
---@param topOffset number HUD 顶部高度
---@param bottomOffset number 底部留白
---@return table layout
function M.calcLayout(screenW, screenH, rows, cols, topOffset, bottomOffset)
    topOffset = topOffset or 70
    bottomOffset = bottomOffset or 75

    local gap=math.max(2.5,math.min(4,screenW*.008))
    -- The perimeter is a real route in the puzzle, so reserve half a cell on each side.
    local area=PlayArea.calc(screenW,screenH,rows,cols,topOffset,bottomOffset,{gap=gap,outer=1,footer=218})
    local cellSize=area.cell
    local gridW,gridH=area.width,area.height
    local startX,startY=area.x,area.y

    return {
        cellSize = cellSize,
        gap = gap,
        startX = startX,
        startY = startY,
        gridW = gridW,
        gridH = gridH,
        rows = rows,
        cols = cols,
    }
end

--- 根据逻辑坐标获取方块的像素中心
---@param layout table
---@param x number 0-based 逻辑 x
---@param y number 0-based 逻辑 y
---@return number cx, number cy
function M.getCellCenter(layout, x, y)
    local cx = layout.startX + x * (layout.cellSize + layout.gap) + layout.cellSize / 2
    local cy = layout.startY + y * (layout.cellSize + layout.gap) + layout.cellSize / 2
    return cx, cy
end

--- 根据像素坐标命中测试，返回逻辑坐标
---@param layout table
---@param mx number
---@param my number
---@return number|nil x, number|nil y (0-based)
function M.hitTest(layout, mx, my)
    local relX = mx - layout.startX
    local relY = my - layout.startY
    if relX < 0 or relY < 0 then return nil, nil end

    local step = layout.cellSize + layout.gap
    local col = math.floor(relX / step)
    local row = math.floor(relY / step)

    if col >= layout.cols or row >= layout.rows then return nil, nil end

    -- 检查是否在 gap 区域
    local localX = relX - col * step
    local localY = relY - row * step
    if localX > layout.cellSize or localY > layout.cellSize then
        return nil, nil
    end

    return col, row
end

-- ============================================================================
-- 绘制
-- ============================================================================

--- 绘制背景
---@param vg userdata
---@param screenW number
---@param screenH number
function M.drawBackground(vg, screenW, screenH)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(M.BG_COLOR[1], M.BG_COLOR[2], M.BG_COLOR[3], M.BG_COLOR[4]))
    nvgFill(vg)

    -- 装饰圆
    nvgBeginPath(vg)
    nvgCircle(vg, screenW + 20, -20, 120)
    nvgFillColor(vg, nvgRGBA(75, 130, 195, 12))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgCircle(vg, -15, screenH + 15, 90)
    nvgFillColor(vg, nvgRGBA(75, 130, 195, 10))
    nvgFill(vg)
end

--- 绘制单个连连看轻柔圆角格底板
local function drawTileCell(vg, tx, ty, cellSize, isSelected)
    local cellR = math.min(7, math.max(4, cellSize * 0.14))
    nvgBeginPath(vg)
    nvgRoundedRect(vg, tx, ty, cellSize, cellSize, cellR)
    if isSelected then
        nvgFillColor(vg, nvgRGBA(255, 232, 182, 255))
    else
        nvgFillColor(vg, nvgRGBA(255, 248, 226, 244))
    end
    nvgFill(vg)
    nvgStrokeColor(vg, isSelected and Pen.color(C.ink) or nvgRGBA(196, 178, 138, 90))
    nvgStrokeWidth(vg, isSelected and 1.6 or 1.0)
    nvgStroke(vg)
end

--- 绘制整个棋盘
---@param vg userdata
---@param board table Board 实例
---@param layout table
function M.drawBoard(vg, board, layout, time)
    local cellSize = layout.cellSize
    time=time or (board.elapsedMs or 0)/1000
    local selected=board.selectedPos
    local key=selected and (selected.y*board.cols+selected.x) or nil
    if board~=selectionBoard_ or key~=selectionKey_ then
        selectionBoard_,selectionKey_,selectionAt_=board,key,time
    end
    local age=math.max(0,time-(selectionAt_ or time))

    -- 棋盘外底托采用单层圆角手绘框，避免与内部格子形成多层平行边框干扰视线
    Pen.plaque(vg, layout.startX - 7, layout.startY - 7, layout.gridW + 14, layout.gridH + 14, {239, 226, 194, 255}, 2.2, { radius = 12 })

    for y = 0, board.rows - 1 do
        for x = 0, board.cols - 1 do
            local pid = board:getTile(x, y)
            if pid > 0 then
                local cx, cy = M.getCellCenter(layout, x, y)
                local half = cellSize / 2
                local tx = cx - half
                local ty = cy - half

                local isSelected = board.selectedPos and
                    board.selectedPos.x == x and board.selectedPos.y == y

                -- 提示闪烁
                local isHint = false
                if board.hintPair then
                    local hp = board.hintPair
                    if (hp.posA.x == x and hp.posA.y == y) or
                       (hp.posB.x == x and hp.posB.y == y) then
                        isHint = true
                    end
                end

                nvgSave(vg)

                drawTileCell(vg, tx, ty, cellSize, isSelected)

                -- 图案
                local artKey = board:getArtKey(x, y)
                local colorIdx = board:getColorIndex(x, y)
                if artKey then
                    local lift=isSelected and 1.7*(1-math.exp(-age*18)) or 0
                    tileRenderer.drawPattern(vg, artKey, cx, cy-lift, cellSize, colorIdx)
                end
                if isSelected then Paper.selection(vg,tx,ty,cellSize,age)
                elseif isHint then Paper.selection(vg,tx,ty,cellSize,board.hintTimer,C.orange) end

                nvgRestore(vg)
            end
        end
    end
end

--- 获取路径点的像素坐标（处理外围点 clamp）
local function getPathPointPx(layout, pt)
    local cx, cy = M.getCellCenter(layout, pt.x, pt.y)
    if pt.x < 0 then cx = layout.startX - layout.gap end
    if pt.x >= layout.cols then cx = layout.startX + layout.gridW + layout.gap end
    if pt.y < 0 then cy = layout.startY - layout.gap end
    if pt.y >= layout.rows then cy = layout.startY + layout.gridH + layout.gap end
    return cx, cy
end

--- 连线先描深色轮廓，再让橘色笔迹沿真实路径走一遍。
function M.drawLinkLine(vg,board,layout)
    for _,fx in ipairs(board.activeEffects) do
        local t, dur = fx.timer, 0.4
        if t < dur then
            local p = math.min(1,t/dur)
            nvgSave(vg); nvgGlobalAlpha(vg,1-p)
            if fx.path and #fx.path >= 2 then
                nvgLineCap(vg,NVG_ROUND); nvgLineJoin(vg,NVG_ROUND)
                local points, total = {},0
                for _,pt in ipairs(fx.path) do
                    local x,y=getPathPointPx(layout,pt)
                    if #points>0 then
                        local prev=points[#points]; total=total+math.abs(x-prev[1])+math.abs(y-prev[2])
                    end
                    points[#points+1]={x,y}
                end
                nvgBeginPath(vg); nvgMoveTo(vg,points[1][1],points[1][2])
                for i=2,#points do nvgLineTo(vg,points[i][1],points[i][2]) end
                nvgStrokeColor(vg,Pen.color(C.ink)); nvgStrokeWidth(vg,5); nvgStroke(vg)
                local remain=total*math.min(1,t/0.12)
                nvgBeginPath(vg); nvgMoveTo(vg,points[1][1],points[1][2])
                for i=2,#points do
                    local a,b=points[i-1],points[i]
                    local dist=math.abs(b[1]-a[1])+math.abs(b[2]-a[2])
                    local frac=dist>0 and math.min(1,remain/dist) or 1
                    nvgLineTo(vg,a[1]+(b[1]-a[1])*frac,a[2]+(b[2]-a[2])*frac)
                    remain=remain-dist
                    if remain<=0 then break end
                end
                nvgStrokeColor(vg,Pen.color(C.orange)); nvgStrokeWidth(vg,2.4); nvgStroke(vg)
            end
            for _,tile in ipairs({fx.posA,fx.posB}) do
                local cx,cy=M.getCellCenter(layout,tile.x,tile.y)
                local scale=p<0.2 and 1+p*0.3 or 1.06*(1-(p-0.2)/0.8)
                nvgSave(vg); nvgTranslate(vg,cx,cy)
                nvgScale(vg,math.max(0.01,scale),math.max(0.01,scale))
                nvgRotate(vg,p*0.1); nvgTranslate(vg,-cx,-cy)
                drawTileCell(vg,cx-layout.cellSize/2,cy-layout.cellSize/2,layout.cellSize,false)
                if tile.artKey then tileRenderer.drawPattern(vg,tile.artKey,cx,cy,layout.cellSize,tile.colorIdx) end
                nvgRestore(vg)
                Paper.burst(vg,cx,cy,layout.cellSize,p)
            end
            nvgRestore(vg)
        end
    end
end

--- 绘制洗牌动画遮罩
---@param vg userdata
---@param board table
---@param screenW number
---@param screenH number
function M.drawShuffleOverlay(vg, board, screenW, screenH)
    if board.sm.current ~= State.SHUFFLING then return end

    local progress = math.min(1, board.shuffleTimer / 0.5)
    local alpha = 0
    if progress < 0.35 then
        alpha = math.floor(180 * (progress / 0.35))
    else
        alpha = math.floor(180 * (1 - (progress - 0.35) / 0.65))
    end

    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, alpha))
    nvgFill(vg)

    if progress < 0.6 then
        local textA = math.floor(240 * math.min(1, progress / 0.2))
        local textScale = 0.8 + 0.2 * math.min(1, progress / 0.3)
        nvgSave(vg)
        nvgTranslate(vg, screenW / 2, screenH / 2)
        nvgScale(vg, textScale, textScale)
        nvgTranslate(vg, -screenW / 2, -screenH / 2)

        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 22)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        -- 文字阴影
        nvgFillColor(vg, nvgRGBA(200, 150, 50, math.floor(textA * 0.3)))
        nvgText(vg, screenW / 2 + 1, screenH / 2 + 1, "洗牌中……", nil)
        -- 文字主体（金色）
        nvgFillColor(vg, nvgRGBA(180, 120, 30, textA))
        nvgText(vg, screenW / 2, screenH / 2, "洗牌中……", nil)

        nvgRestore(vg)
    end
end

return M
