--- 记忆翻牌 - 网格布局计算
--- 职责：根据屏幕尺寸和行列数计算自适应卡牌网格布局
local LAYOUT = require("shared.constants.layout")
local PlayArea = require("shared.layout.game-board")

local M = {}

--- 计算卡牌网格布局
---@param screenW number
---@param screenH number
---@param rows number
---@param cols number
---@param topOffset number HUD 顶部高度
---@return table layout { cellSize, gap, startX, startY, cardW, cardH }
function M.calc(screenW, screenH, rows, cols, topOffset)
    topOffset = topOffset or 80

    local gap=math.max(6,math.min(12,screenW*.018))
    local area=PlayArea.calc(screenW,screenH,rows,cols,topOffset,LAYOUT.BOARD_BOTTOM_PADDING,
        {gap=gap,maxCell=math.max(100,screenW*.32)})
    local cardSize=area.cell
    local gridW,gridH=area.width,area.height
    local startX,startY=area.x,area.y

    return {
        cardSize = cardSize,
        gap = gap,
        startX = startX,
        startY = startY,
        gridW = gridW,
        gridH = gridH,
        rows = rows,
        cols = cols,
    }
end

return M
