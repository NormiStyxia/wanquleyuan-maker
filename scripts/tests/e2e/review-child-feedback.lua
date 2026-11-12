--- 手绘选关与儿童操作反馈的真实绘制采集；连续帧检查视觉变化和输入位置稳定。
---@diagnostic disable: undefined-global
local F=require("tests.e2e.game-skin-fixture")
local Bg=require("shared.background-manager")
local Paper=require("shared.components.game-paper")
local Sprites=require("shared.rendering.piece-sprites")
local Trace=require("devtools.adventure-art-trace")
local last,frames,pending={},{},nil
local selected,selectionRect,samples
local decoration
local scenery=require("shared.rendering.game-scenery")
local drawScenery=scenery.draw
scenery.draw=function(...) decoration=drawScenery(...);return decoration end
local rect=Sprites.rect
Sprites.rect=function(vg,key,x,y,w,h,alpha)
    if samples and F.page~=4 then samples[#samples+1]={key=key,x=x,y=y,w=w,h=h} end
    return rect(vg,key,x,y,w,h,alpha)
end
-- 连连看有真实镜像图案，记录镜像变换前的棋盘坐标，避免把局部原点当成屏幕位置。
local linkTiles=require("games.p4-link-match.view.tile-renderer")
local drawPattern=linkTiles.drawPattern
linkTiles.drawPattern=function(vg,key,x,y,size,index)
    if samples and F.page==4 then samples[#samples+1]={key=key,x=x,y=y,w=size,h=size} end
    return drawPattern(vg,key,x,y,size,index)
end
local selection=Paper.selection
Paper.selection=function(vg,x,y,size,t,...)
    selectionRect={x=x,y=y,size=size,t=t}
    return selection(vg,x,y,size,t,...)
end
local draw=F.draw
F.draw=function(vg,w,h)
    samples={};selectionRect=nil
    if pending then print("[UIPaperPage] "..pending);Trace.request();Trace.begin() end
    draw(vg,w,h)
    last={w=w,h=h,samples=samples,selection=selectionRect}
    if pending then
        Trace.finish(w,h,"packed");frames[pending]=last;pending=nil
    end
    samples=nil
end
local function page(n,label,theme)
    F.page=n;F.scenery=true
    F.background=Bg.getBackgroundForLevel({themeBackground="Textures/LevelThemes/"..(theme or "garden")..".png"})
    pending=label
end
local function hits(index)
    local list=F.hits[index]
    V.assert(list and #list>1,"真实选关按钮已绘制")
    for _,b in ipairs(list or {}) do
        V.assert(b.w>=44 and b.h>=44,"选关点按区至少44×44")
        V.assert(b.x>=0 and b.y>=0 and b.x+b.w<=last.w and b.y+b.h<=last.h,"选关按钮不出界")
    end
    if decoration and decoration.bottom then
        local p=decoration.bottom
        local lowest=0
        for _,b in ipairs(list) do lowest=math.max(lowest,b.y+b.h) end
        V.assert(p.y-p.h/2>lowest+10,"手绘小景避开全部关卡与翻页按钮")
        V.assert(p.x-p.w/2>=0 and p.x+p.w/2<=last.w and p.y+p.h/2<last.h,"手绘小景完整留在屏幕内")
    end
end
local function motion(first,second,renderer,p)
    local a,b=frames[first],frames[second]
    V.assert(a and b and a.selection and b.selection,"选中状态有连续真实绘制")
    if not (a and b and a.selection and b.selection) then return end
    local x,y,size=a.selection.x,a.selection.y,a.selection.size
    V.assert(b.selection.x==x and b.selection.y==y and b.selection.size==size,"呼吸不移动点按区")
    V.assert(b.selection.t>a.selection.t,"呼吸由真实更新时间推进")
    local moved=0
    for i,old in ipairs(a.samples) do
        local new=b.samples[i]
        if new and old.key==new.key and math.abs(new.y-old.y)>.01
            and old.x>=x and old.x<=x+size and old.y>=y and old.y<=y+size then
            moved=moved+1
            V.assert(new.x==old.x and new.w==old.w and new.h==old.h,"选中图案身份、比例和横向位置不变")
            V.assert(math.abs(new.y-old.y)<=1.71,"选中轻抬幅度受限，不跳进邻格")
        end
    end
    V.assert(moved==1,"只轻抬一个选中图案")
    if p==3 then
        local r,c=renderer.hitTest(x+size/2,y+size/2)
        V.assert(r==2 and c==2,"三消选中动效后仍命中同一格")
    else
        local xx,yy=renderer.hitTest(F.layouts[4],x+size/2,y+size/2)
        V.assert(xx==0 and yy==0,"连连看选中动效后仍命中同一格")
    end
end
for i=1,4 do
    local at=4+(i-1)*12
    local labels={"推箱子选关","翻牌选关","消消乐选关","连连看选关"}
    V.atFrame(at,function() page(8+i,labels[i]) end)
    V.atFrame(at+8,function() hits(8+i) end)
end
V.atFrame(56,function()
    page(3,"三消·选中瞬间","candy")
    F.renderers[3].setSelected({row=2,col=2})
end)
V.atFrame(74,function() pending="三消·呼吸与轻抬" end)
V.atFrame(82,function()
    motion("三消·选中瞬间","三消·呼吸与轻抬",F.renderers[3],3)
    F.renderers[3].clearSelected()
    page(4,"配对·选中瞬间","garden")
    F.boards[4].selectedPos={x=0,y=0}
end)
V.atFrame(100,function() pending="配对·呼吸与轻抬" end)
V.atFrame(108,function()
    motion("配对·选中瞬间","配对·呼吸与轻抬",F.renderers[4],4)
    F.boards[4].selectedPos=nil
    V.assert(F.boards[3]:getTile(2,2)~=nil and F.boards[4]:getTile(0,0)>0,"动效未消除棋子或修改规则")
    V.finish()
end)
