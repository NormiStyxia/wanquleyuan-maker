--- Live layout, sprite identities, selection coordinates and decoration bounds. No saves.
---@diagnostic disable: undefined-global
local F=require("tests.e2e.game-skin-fixture")
local Bg=require("shared.background-manager")
local Trace=require("devtools.adventure-art-trace")
local Sprites=require("shared.rendering.piece-sprites")
local Scene=require("shared.rendering.game-scenery")
local pending,lastW,lastH,lastVg
local loaded={}
local create=nvgCreateImage
nvgCreateImage=function(vg,path,flags)
    local h=create(vg,path,flags)
    if path:find('handdrawn/pieces/',1,true) then
        V.assert(h and h>0,'独立手绘素材可加载：'..path)
        loaded[path]=true
    end
    return h
end
local function rect(l)
    return {x=l.x or l.startX or l.offsetX,y=l.y or l.startY or l.offsetY,
        w=l.totalW or l.gridW or l.boardW,h=l.totalH or l.gridH or l.boardH}
end
local draw=F.draw
F.draw=function(vg,w,h)
    lastW,lastH,lastVg=w,h,vg
    if pending then print('[GameSkinPage] '..pending);Trace.request();Trace.begin() end
    draw(vg,w,h)
    if F.page==13 then
        local names={'heart','star','leaf','sun','flower','butterfly','bomb','rainbow','ice-3','ice-2','ice-1','stone'}
        for i,key in ipairs(names) do
            local size=(w-40)/3
            local x=20+((i-1)%3)*size+size/2
            local y=120+math.floor((i-1)/3)*(size+22)+size/2
            Sprites.draw(vg,key,x,y,size*.86)
        end
    end
    if pending then Trace.finish(w,h,'packed');pending=nil end
end
local function page(p,theme,label)
    F.page=p;F.scenery=true
    F.background=Bg.getBackgroundForLevel({themeBackground='Textures/LevelThemes/'..theme..'.png'})
    pending=label
end
local function bounds(p)
    local l=F.layouts[p];local r=rect(l)
    V.assert(r.x>=8 and r.x+r.w<=lastW-8,'玩法'..p..'棋盘完整可见')
    V.assert(r.y>=115 and r.y+r.h<=lastH-(p==4 and 198 or 164)-12,'玩法'..p..'棋盘避开按钮及人物')
    V.assert(math.abs(r.x+r.w/2-lastW/2)<1,'玩法'..p..'棋盘水平居中')
    for name,d in pairs(Scene.layout(lastW,lastH,r,F.background)) do
        V.assert(loaded['image/handdrawn/pieces/'..d.key..'.png'],'有空位时才加载挂饰：'..d.key)
        V.assert(d.x-d.w/2>=0 and d.x+d.w/2<=lastW,'装饰'..name..'不出屏')
        V.assert(name=='top' and d.y+d.h/2<r.y-10 or name=='bottom' and d.y-d.h/2>r.y+r.h+10,
            '装饰'..name..'不覆盖棋盘')
        if name=='top' then V.assert(d.y-d.h/2>=115,'上挂饰不覆盖工具栏') end
    end
    if p==3 then
        local hit=F.renderers[3]
        for row=1,l.rows do for col=1,l.cols do
            local x,y=hit.getCellCenter(row,col);local rr,cc=hit.hitTest(x,y)
            V.assert(rr==row and cc==col,'三消格子命中与放大后绘制一致')
        end end
        V.assert(l.totalW>=lastW*.87,'三消棋盘充分使用宽度')
    elseif p==4 then
        local hit=F.renderers[4]
        local x,y=hit.getCellCenter(l,-1,-1)
        V.assert(x>=4 and y>=108,'外围折线留有实际可视空间')
        for row=0,l.rows-1 do for col=0,l.cols-1 do
            local cx,cy=hit.getCellCenter(l,col,row);local xx,yy=hit.hitTest(l,cx,cy)
            V.assert(xx==col and yy==row,'连连看命中保持同一坐标系')
        end end
    end
end
V.atFrame(4,function() page(1,'garden','推箱子·场景') end)
V.atFrame(12,function() bounds(1);page(2,'starlight','翻牌·背面') end)
V.atFrame(20,function()
    bounds(2)
    for i,c in ipairs(F.boards[2].cards) do if i<=6 then c.state='flipped' end end
end)
V.atFrame(34,function() pending='翻牌·手绘图案' end)
V.atFrame(42,function() page(3,'ice','冰原·异形棋子') end)
V.atFrame(50,function()
    bounds(3)
    local keys={'line_h','line_v','bomb','rainbow','ice','ice','ice','stone'}
    for col,special in ipairs(keys) do F.boards[3].grid[2][col]={colorId=(col-1)%6+1,special=special,hp=col==5 and 3 or col==6 and 2 or 1} end
    pending='冰原·特殊棋子与冰块差分'
end)
V.atFrame(60,function()
    F.boards[3].stateMachine.current='Eliminating'
    F.renderers[3].startElimAnim({{row=3,col=3,colorId=1,special='none'}},500)
    F.renderers[3].spawnElimParticles({{row=3,col=3,colorId=1,special='none'}})
end)
V.atFrame(64,function() pending='消除·轻弹与纸屑' end)
V.atFrame(74,function() page(4,'candy','糖果·配对与小场景') end)
V.atFrame(84,function() bounds(4) end)
V.atFrame(88,function()
    F.boards[4].activeEffects={{timer=.1,path={{x=0,y=0},{x=-1,y=0},{x=-1,y=3},{x=0,y=3}},
        posA={x=0,y=0,colorIdx=1,artKey='circle'},posB={x=0,y=3,colorIdx=1,artKey='circle'}}}
    pending='连线·外围空间'
end)
V.atFrame(98,function() page(13,'garden','透明素材·六色与特殊差分') end)
V.atFrame(106,function()
    -- A second context must never reuse another context's numeric image handles.
    local vg=nvgCreate(1); local count,deleted=0,0
    local make,del=nvgCreateImage,nvgDeleteImage
    nvgCreateImage=function(...) count=count+1;return make(...) end
    nvgDeleteImage=function(...) deleted=deleted+1;return del(...) end
    nvgBeginFrame(vg,100,100,1)
    Sprites.draw(vg,'heart',50,50,48);Sprites.draw(vg,'heart',50,50,48)
    nvgEndFrame(vg)
    V.assert(count==1,'同一上下文不重复解码图案')
    nvgBeginFrame(vg,100,100,1)
    for _,key in ipairs({'diamond','house','fish','apple','cross','cloud'}) do
        Sprites.draw(vg,key,50,50,48)
        Sprites.pattern(vg,key,50,50,48,24,'memory')
    end
    nvgEndFrame(vg)
    Sprites.release(vg);Sprites.release(vg)
    V.assert(deleted==count,'所属图案只释放一次')
    Sprites.release(nil)
    nvgCreateImage,nvgDeleteImage=make,del;nvgDelete(vg)
end)
V.atFrame(112,function()
    for _,key in ipairs({'heart','star','leaf','sun','flower','butterfly','bomb','rainbow','ice-3','ice-2','ice-1','stone',
        'scenes/ice-bottom','scenes/candy-bottom','scenes/garden-bottom'}) do
        V.assert(loaded['image/handdrawn/pieces/'..key..'.png'],'已覆盖真实素材：'..key)
    end
    nvgCreateImage=create;V.finish()
end)
