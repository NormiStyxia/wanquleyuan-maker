--- 装扮页内容布局。短屏分页、长屏平铺；绘制和点击共用同一份几何。
local TabBar = require("shared.components.tab-bar")
local M = {categoryY=88, categoryH=44, cell=76, gapX=14, gapY=16, labelH=22}
function M.calculate(w, h, count, requestedPage)
    local top, bottom = M.categoryY + M.categoryH + 12, h - TabBar.HEIGHT
    local gridTop = top + math.floor(math.min(250, (bottom-top)*0.36))
    local cols = math.max(1, math.floor((w-48+M.gapX)/(M.cell+M.gapX)))
    local cellH = M.cell + M.labelH
    local totalRows = math.ceil(count/cols)
    local needed = 26 + totalRows*cellH + math.max(0,totalRows-1)*M.gapY
    local paged = needed > bottom-gridTop
    local gridBottom = bottom - (paged and 56 or 0)
    local rows = math.max(1, math.floor((gridBottom-gridTop-26+M.gapY)/(cellH+M.gapY)))
    local capacity = rows*cols
    local pages = math.max(1, math.ceil(count/capacity))
    local page = math.max(1,math.min(pages,requestedPage or 1))
    local result = {previewTop=top,gridTop=gridTop,gridBottom=gridBottom,cols=cols,rows=rows,
        cellH=cellH,first=(page-1)*capacity+1,last=math.min(page*capacity,count),page=page,pages=pages,
        startX=(w-(cols*M.cell+(cols-1)*M.gapX))/2}
    if pages>1 then
        result.previous={x=24,y=bottom-50,w=90,h=44,delta=-1}
        result.next={x=w-114,y=bottom-50,w=90,h=44,delta=1}
    end
    return result
end
return M
