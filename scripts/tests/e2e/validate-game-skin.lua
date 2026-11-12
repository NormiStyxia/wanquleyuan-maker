---@diagnostic disable: undefined-global
local F=require("tests.e2e.game-skin-fixture")
local Paper=require("shared.components.game-paper")
local Flip=require("games.p2-memory-flip.animation.flip-controller")
local Density=require("shared.utils.density")
local passedPages={}
local oldDraw=F.draw
local lastW,lastH
F.draw=function(vg,w,h)
    oldDraw(vg,w,h);passedPages[F.page]=true;lastW,lastH=w,h
end
local function bounds(hits,label)
    V.assert(hits and #hits>0,label.."产生实际按钮")
    if not hits then return end
    for _,b in ipairs(hits) do
        V.assert(b.h>=44 and b.x>=0 and b.x+b.w<=lastW and b.y>=0 and b.y+b.h<=lastH,
            label.."按钮不出界且高度至少44")
    end
end
local function nextPage(p)
    F.page=p
end
V.atFrame(12,function()
    V.assert(F.boards and F.boards[1].steps==0,"验收棋盘初始化且不写进度")
    bounds(F.hits[1],"推箱子")
    local l=F.layouts[1]
    V.assert(l.offsetY-7>=F.hits[1][3].y+44,"推箱子工具栏不压棋盘")
    local board=F.boards[1]
    local events=board:applyMove("up")
    F.anim:playEvents(events)
    V.assert(board.won and board.steps==1,"推箱子原一推通关规则保持")
end)
V.atFrame(20,function() nextPage(2) end)
V.atFrame(28,function()
    bounds(F.hits[2],"翻牌")
    local b=F.boards[2];Flip.reset();Flip.detectChanges(b)
    b.cards[1].state="flipped";Flip.detectChanges(b)
    Flip.advance(0.1)
    local _,sx=Flip.getCardDisplay(1,"flipped")
    V.assert(math.abs(sx)<0.001,"翻牌中点变为细侧边")
    Flip.advance(0.11)
    local face,scale=Flip.getCardDisplay(1,"flipped")
    V.assert(face=="front" and scale==1,"原翻转时长结束后正面完整显示")
    local l=F.layouts[2]
    V.assert(l.startY-7>=F.hits[2][1].y+44,"翻牌工具栏不压棋盘")
    F.renderers[2].triggerMatchEffect(80,200,160,200,60,nvgRGBA(132,166,78,255))
end)
V.atFrame(38,function() nextPage(3) end)
V.atFrame(45,function()
    bounds(F.hits[3],"消消乐")
    local l=F.layouts[3]
    V.assert(l.y-6>=F.hits[3][1].y+44,"消消乐工具栏不压棋盘")
    local r=F.renderers[3]
    F.boards[3].stateMachine.current="Swapping"
    r.startSwapAnim(1,1,1,2,180,false)
    r.spawnElimParticles({{row=2,col=2,colorId=1,special="bomb"},
        {row=3,col=3,colorId=2,special="line_h"},
        {row=4,col=4,colorId=3,special="line_v"}})
end)
V.atFrame(53,function()
    F.boards[3].stateMachine.current="Eliminating"
    F.renderers[3].startElimAnim({{row=2,col=2,colorId=1,special="bomb"}},180)
end)
V.atFrame(60,function()
    F.boards[3].stateMachine.current="Falling"
    F.renderers[3].startFallAnim({{col=2,fromRow=0,toRow=2,colorId=1,isNew=true}},60)
end)
V.atFrame(68,function() nextPage(4) end)
V.atFrame(72,function()
    bounds(F.hits[4],"连连看")
    local l=F.layouts[4]
    V.assert(l.startY-7>=F.hits[4][1].y+44,"连连看工具栏不压棋盘")
    F.boards[4].activeEffects={{timer=0.1,path={{x=0,y=0},{x=-1,y=0},{x=-1,y=3},{x=0,y=3}},
        posA={x=0,y=0,colorIdx=1,artKey="circle"},posB={x=0,y=3,colorIdx=1,artKey="circle"}}}
end)
V.atFrame(80,function() nextPage(5) end)
V.atFrame(90,function()
    bounds(F.hits[5],"暂停")
    local Pause=require("shared.components.pause-overlay")
    local b=F.hits[5][1]
    V.assert(Pause.hitTest(b.x+b.w/2,b.y+b.h/2,F.hits[5])=="resume","暂停按钮绘制与点击坐标一致")
    nextPage(6)
end)
V.atFrame(102,function()
    bounds(F.hits[6],"结算")
    V.assert(F.hits[6][1].action=="next_level","自由结算下一关操作保留")
    nextPage(7)
end)
V.atFrame(116,function() bounds(F.hits[7],"失败"); nextPage(8) end)
V.atFrame(128,function()
    for p=1,8 do V.assert(passedPages[p]==true,"真实绘制页面"..p.."无Lua错误") end
end)

local UI=require("urhox-libs/UI")
local overlay,scroll,close
V.atFrame(132,function() nextPage(9) end)
V.atFrame(140,function() bounds(F.hits[9],"推箱子选关");nextPage(10) end)
V.atFrame(148,function() bounds(F.hits[10],"翻牌选关");nextPage(11) end)
V.atFrame(156,function() bounds(F.hits[11],"消消乐选关");nextPage(12) end)
V.atFrame(164,function() bounds(F.hits[12],"连连看选关") end)
V.atFrame(170,function()
    UI.SetRoot(UI.Panel{width="100%",height="100%"})
    overlay=require("shared.components.settings-popup").open(UI.GetRoot())
end)
V.atFrame(182,function()
    local card=overlay:FindById("settings-card"):GetAbsoluteLayout()
    local w,h=UI.GetViewportSize()
    V.assert(card.x>=0 and card.y>=0 and card.x+card.w<=w+1 and card.y+card.h<=h+1,"设置纸卡在视口内")
    scroll=overlay:FindById("settings-scroll");close=overlay:FindById("settings-close")
    local box=scroll:GetLayout()
    V.assert(box.h>0 and box.h<card.h,"设置滚动区有约束高度")
    scroll:ScrollToBottom()
end)
V.atFrame(190,function()
    local c=close:GetAbsoluteLayoutForHitTest()
    local s=scroll:GetAbsoluteLayoutForHitTest()
    V.assert(c.y>=s.y-1 and c.y+c.h<=s.y+s.h+1,"短屏滚到末尾可见关闭按钮")
    V.assert(c.h>=44,"设置关闭按钮保持可点尺寸")
    overlay:Remove() -- 不调用保存/账号/消费相关回调。
    V.finish()
end)
