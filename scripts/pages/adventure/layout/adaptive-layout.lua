--- 一章七关的交错地图。按两列卡片的实际高度反算半径，保持同列不重叠。
local TabBar = require("shared.components.tab-bar")
local M = {}

M.HEADER_H_BASE = 92
M.CHAPTER_H_BASE = 36
M.NODE_RADIUS_BASE = 42
M.NODE_LEFT_RATIO = 0.27
M.NODE_RIGHT_RATIO = 0.73
M.CARD_ATTACH = 44
M.MARGIN = 12
M.PORTRAIT_OVERHANG = 0.18
M.ARROW_H = 44
M.ARROW_W = 44
M.ARROW_SPREAD = 63
M.DOT_RADIUS = 4
M.DOT_GAP = 13

function M.getFoxOptions(screenH)
    local size = screenH < 720 and 100 or 128
    return { size = size, marginLeft = 0, handdrawn = true, bubbleBottomInset = size * 0.6 }
end

function M.calcAdaptiveRegions(screenH)
    local foxSize = M.getFoxOptions(screenH).size
    return screenH < 720 and 76 or M.HEADER_H_BASE, M.CHAPTER_H_BASE,
        TabBar.HEIGHT + foxSize + 10
end

function M.calcAdaptiveLayout(areaH, pageNodeCount)
    local rows = math.ceil(pageNodeCount / 2)
    local radius = math.floor(((areaH - M.MARGIN * 2) / rows - M.CARD_ATTACH - 6) / (2 + M.PORTRAIT_OVERHANG))
    radius = math.max(16, math.min(M.NODE_RADIUS_BASE, radius))
    local spacing = pageNodeCount > 1
        and (areaH - M.MARGIN * 2 - radius * (2 + M.PORTRAIT_OVERHANG) - M.CARD_ATTACH) / (pageNodeCount - 1) or 0
    return radius, spacing
end

function M.getPageNodePosition(localIdx, screenW, areaTop, areaH, pageNodeCount, nodeRadius, rowSpacing)
    local cx = screenW * (localIdx % 2 == 1 and M.NODE_LEFT_RATIO or M.NODE_RIGHT_RATIO)
    local cy = areaTop + M.MARGIN + nodeRadius * (1 + M.PORTRAIT_OVERHANG) + (localIdx - 1) * rowSpacing
    return cx, cy
end

--- 当前四枚角色图的透明边距均为：顶部32、底部32（512px原图）。
--- 以可见脚底为锚点，头顶高出圆框0.18r；不裁图、不拉伸、不改变原素材。
function M.getPortraitBox(cx, cy, radius)
    local size=radius*(1.86+M.PORTRAIT_OVERHANG)/(448/512)
    return cx-size/2, cy+radius*0.86-size*(480/512), size
end

function M.getPaginationCenter(screenW, screenH)
    -- 翻页区位于狐狸右侧，不抢占角色聊天点击区。
    return math.max(196, screenW * 0.65), screenH - TabBar.HEIGHT - 36
end

return M
