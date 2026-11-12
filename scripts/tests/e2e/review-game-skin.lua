--- 输出引擎实际绘制命令，用于单文件美术预览；非原生截图。
---@diagnostic disable: undefined-global
local Trace=require("devtools.adventure-art-trace")
local F=require("tests.e2e.game-skin-fixture")
local pending
local oldDraw=F.draw
F.draw=function(vg,w,h)
    if pending then Trace.request();Trace.begin();print("[GameSkinPage] "..pending) end
    oldDraw(vg,w,h)
    if pending then Trace.finish(w,h,"packed");pending=nil end
end
local function page(n,label) F.page=n;pending=label end
V.atFrame(12,function() page(1,"推箱子") end)
V.atFrame(22,function()
    for i=1,math.min(6,#F.boards[2].cards) do F.boards[2].cards[i].state=i>4 and "matched" or "flipped" end
    page(2,"翻牌背面")
end)
V.atFrame(28,function() pending="翻牌侧面" end)
V.atFrame(36,function() pending="记忆翻牌" end)
V.atFrame(48,function()
    F.boards[3].grid[2][2].special="bomb"
    page(3,"消消乐")
end)
V.atFrame(58,function()
    F.boards[3].stateMachine.current="Eliminating"
    F.renderers[3].startElimAnim({{row=2,col=2,colorId=1,special="bomb"}},300)
    F.renderers[3].spawnElimParticles({{row=2,col=2,colorId=1,special="bomb"}})
end)
V.atFrame(63,function() pending="消除纸屑" end)
V.atFrame(74,function() page(4,"连连看") end)
V.atFrame(82,function()
    F.boards[4].activeEffects={{timer=0.1,path={{x=0,y=0},{x=-1,y=0},{x=-1,y=3},{x=0,y=3}},
        posA={x=0,y=0,colorIdx=1,artKey="circle"},posB={x=0,y=3,colorIdx=1,artKey="circle"}}}
    pending="连线笔迹"
end)
V.atFrame(92,function() page(5,"暂停") end)
V.atFrame(102,function() page(6,"结算") end)
V.atFrame(112,function() page(7,"未通关") end)
V.atFrame(122,function() page(8,"图案库") end)
V.atFrame(132,function() V.finish() end)
