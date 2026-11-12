--- 关卡工坊纸卡面板；绘制与命中使用同一布局。
local Board = require("games.p1-puzzle-land.view.board-renderer")
local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local M = {TOP_BAR_H=116, BOTTOM_BAR_H=104, SIDE_PAD=16}

local function toolLayout(w, count)
    local maxColumns=math.min(7, math.max(1, math.floor((w-24+6)/50)))
    local columns=math.ceil(count/math.ceil(count/maxColumns))
    local gap,height=6,54
    local width=math.min(64, (w-24-(columns-1)*gap)/columns)
    return columns,width,height,gap,math.ceil(count/columns)*60+16
end
function M.toolbarHeight(w,count)
    local _,_,_,_,h=toolLayout(w,count or 13)
    return h
end

function M.drawTopBar(vg,w,state)
    Paper.hud(vg,w,M.TOP_BAR_H)
    Paper.button(vg,12,6,48,44,"返回",false)
    Paper.text(vg,w/2,28,"关卡工坊",21)
    local hits={backBtn={x=12,y=6,w=48,h=44}}
    local buttonW,gap=44,6
    local x=w-12-buttonW*4-gap*3
    Paper.text(vg,12,82,state.gridW.." × "..state.gridH,18,C.ink,NVG_ALIGN_LEFT)
    local keys={"widthMinus","widthPlus","heightMinus","heightPlus"}
    local labels={"宽−","宽+","高−","高+"}
    for i,key in ipairs(keys) do
        local bx=x+(i-1)*(buttonW+gap)
        Paper.button(vg,bx,60,buttonW,44,labels[i],false)
        hits[key]={x=bx,y=60,w=buttonW,h=44}
    end
    return hits
end

function M.drawToolbar(vg,w,state,tools)
    local columns,bw,bh,gap,h=toolLayout(w,#tools)
    local top=M.TOP_BAR_H
    local hits={}
    nvgBeginPath(vg);nvgRect(vg,0,top,w,h)
    nvgFillColor(vg,Pen.color({241,230,202,255}));nvgFill(vg)
    for i,tool in ipairs(tools) do
        local row=math.floor((i-1)/columns)
        local rowCount=math.min(columns,#tools-row*columns)
        local start=(w-rowCount*bw-(rowCount-1)*gap)/2
        local x=start+((i-1)%columns)*(bw+gap)
        local y=top+8+math.floor((i-1)/columns)*(bh+gap)
        Pen.plaque(vg,x,y,bw,bh,state.currentTool==tool.id and {245,201,129,255} or C.paper,2)
        if tool.id=="eraser" then
            Pen.plaque(vg,x+bw/2-11,y+8,22,17,{230,176,159,255},1.5)
        else Board.drawEditorTile(vg,tool.id,x+bw/2-13,y+3,26) end
        Paper.text(vg,x+bw/2,y+42,tool.label,12)
        hits[#hits+1]={x=x,y=y,w=bw,h=bh,toolId=tool.id}
    end
    return hits
end

function M.drawGrid(vg,layout,state)
    local cs,ox,oy=layout.cellSize,layout.offsetX,layout.offsetY
    Paper.panel(vg,ox-6,oy-6,layout.boardW+12,layout.boardH+12,{239,226,194,255})
    for y=1,state.gridH do for x=1,state.gridW do
        Board.drawEditorTile(vg,state.grid[y][x],ox+(x-1)*cs,oy+(y-1)*cs,cs)
    end end
    local function entity(key,p) Board.drawEditorTile(vg,key,ox+(p[1]-1)*cs,oy+(p[2]-1)*cs,cs) end
    for _,p in ipairs(state.targetPositions) do entity("target",p) end
    for color,p in pairs(state.portalPositions) do entity("portal_"..color,p) end
    for color,p in pairs(state.portalTargetPositions) do entity("ptarget_"..color,p) end
    for _,p in ipairs(state.boxPositions) do entity("box",p) end
    if state.playerPos then entity("player",state.playerPos) end
end

function M.drawBottomBar(vg,w,h,state)
    local y=h-M.BOTTOM_BAR_H
    nvgSave(vg);nvgTranslate(vg,0,y);Paper.hud(vg,w,M.BOTTOM_BAR_H);nvgRestore(vg)
    Paper.text(vg,12,y+16,"箱子 "..#state.boxPositions.."  ·  目标 "..#state.targetPositions,13,C.muted,NVG_ALIGN_LEFT)
    local warning={}
    if not state.playerPos then warning[#warning+1]="请放置玩家" end
    if #state.boxPositions~=#state.targetPositions then warning[#warning+1]="箱子与目标需等量" end
    Paper.text(vg,12,y+36,table.concat(warning," · "),12,C.ink,NVG_ALIGN_LEFT)
    local bw=(w-24-6*3)/4
    local hits={}
    for i,def in ipairs({{"clearBtn","清空"},{"importBtn","导入"},{"playBtn","试玩"},{"exportBtn","导出"}}) do
        local x=12+(i-1)*(bw+6)
        Paper.button(vg,x,h-54,bw,44,def[2],i==3)
        hits[def[1]]={x=x,y=h-54,w=bw,h=44}
    end
    return hits
end

function M.drawExportMessage(vg,w,h,state)
    if not state.exportMessage or state.exportMessageTimer<=0 then return end
    local width=math.min(w-40,420)
    local rows=Paper.wrap(vg,state.exportMessage,14,width-28)
    local height=#rows*21+24
    local x,y=(w-width)/2,(h-height)/2
    nvgSave(vg);nvgGlobalAlpha(vg,math.min(1,state.exportMessageTimer/.25))
    Paper.panel(vg,x,y,width,height)
    for i,row in ipairs(rows) do Paper.text(vg,w/2,y+22+(i-1)*21,row,14) end
    nvgRestore(vg)
end
return M
