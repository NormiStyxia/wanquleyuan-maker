--- 可达工坊与休息遮罩验收；仅编辑器内存数据，不写存档/剪贴板/认证信息。
---@diagnostic disable: undefined-global
local F=require("tests.e2e.game-skin-fixture")
local Editor=require("games.p1-puzzle-land.screens.level-editor")
local Panels=require("games.p1-puzzle-land.editor.ui.editor-panels")
local Modal=require("games.p1-puzzle-land.editor.ui.modal-dialog")
local Guard=require("shared.utils.play-time-guard")
local Anti=require("shared.anti-addiction")
local Paper=require("shared.components.game-paper")
local UI=require("urhox-libs/UI")
local Transition=require("shared.components.screen-transition")
local Trace=require("devtools.adventure-art-trace")
local capture=WANQU_UI_TRACE==true
local mode,pending="editor"
local vg,w,h,hits,modal,card
local root,overlay,initialized,forcedW,forcedH
local function setup()
    Editor.enter()
    root=UI.Panel{width="100%",height="100%"};UI.SetRoot(root)
    overlay=Transition.create();root:AddChild(overlay)
    initialized=true
end
F.update=function(dt) Editor.update(dt) end
local function guarded(reason,draw)
    local a,b,c,d,e=Anti.canEnterGame,Anti.getBlockReason,Anti.isAdult,Anti.getRemainingMin,Anti.getBeijingTimeStr
    Anti.canEnterGame=function() return reason=="adult" end
    Anti.getBlockReason=function() return reason end
    Anti.isAdult=function() return reason=="adult" end
    Anti.getRemainingMin=function() return 42 end
    Anti.getBeijingTimeStr=function() return "21:30" end
    local ok,result=pcall(draw)
    Anti.canEnterGame,Anti.getBlockReason,Anti.isAdult,Anti.getRemainingMin,Anti.getBeijingTimeStr=a,b,c,d,e
    assert(ok,result)
    return result
end
F.draw=function(ctx,gw,gh)
    vg,w,h=ctx,forcedW or gw,forcedH or gh
    if not initialized then return end
    if pending and capture then print("[UIPaperPage] "..pending);Trace.request();Trace.begin() end
    if mode=="editor" or mode=="import" then
        hits=Editor.render(vg,w,h)
        if mode=="import" then modal=hits.modal end
    else
        nvgBeginPath(vg);nvgRect(vg,0,0,w,h)
        nvgFillColor(vg,nvgRGBA(239,229,206,255));nvgFill(vg)
        card=guarded(mode,function() return Guard.renderOverlay(vg,w,h,"sans",1.2) end)
    end
    if pending then
        if capture then Trace.finish(w,h,"packed") end
        pending=nil
    end
end
local function inside(b,p,label)
    p=p or {x=0,y=0,w=w,h=h}
    V.assert(b and b.w>0 and b.h>0,label.."有实际尺寸")
    if b then V.assert(b.x>=p.x and b.y>=p.y and b.x+b.w<=p.x+p.w+.01 and b.y+b.h<=p.y+p.h+.01,label.."未越界") end
end
local function overlaps(a,b)
    return a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h
end
local function verifyEditor()
    local all={}
    for _,group in ipairs({hits.topHits,hits.toolHits,hits.bottomHits}) do
        for _,r in pairs(group) do
            inside(r,nil,"工坊按钮")
            V.assert(r.w>=44 and r.h>=44,"工坊触摸区至少44×44")
            all[#all+1]=r
        end
    end
    local collision=false
    for i=1,#all do for j=i+1,#all do if overlaps(all[i],all[j]) then collision=true end end end
    V.assert(not collision,"工具、尺寸、底栏按钮互不重叠")
    local l=hits.layout
    inside({x=l.offsetX-6,y=l.offsetY-6,w=l.boardW+12,h=l.boardH+12},nil,"工坊纸棋盘")
    V.assert(l.offsetY-6>=Panels.TOP_BAR_H+Panels.toolbarHeight(w),"棋盘避开全部工具行")
    V.assert(l.offsetY+l.boardH+6<=h-Panels.BOTTOM_BAR_H,"棋盘避开底栏")
    V.assert(math.abs(l.offsetX+l.boardW/2-w/2)<1,"棋盘没有偏斜或偏心")
end
local function clickRect(r) Editor.handleClick(r.x+r.w/2,r.y+r.h/2,hits) end
local function place(tool,x,y)
    for _,r in ipairs(hits.toolHits) do if r.toolId==tool then clickRect(r) end end
    local l=hits.layout
    V.assert(Editor.beginDrag(l.offsetX+(x-.5)*l.cellSize,l.offsetY+(y-.5)*l.cellSize,hits),"可在新布局放置"..tool)
    Editor.endDrag()
end
V.atFrame(4,function() setup();pending="关卡工坊·手绘工具" end)
V.atFrame(12,function()
    verifyEditor()
    place("player",2,2);place("box",3,2);place("target",4,2)
    local level=Editor.buildPlayableLevel()
    V.assert(level~=nil and level.player[1]==2 and #level.boxes==1,"玩家/箱子/目标的放置可生成试玩关卡")
    local action=Editor.handleClick(hits.bottomHits.playBtn.x+10,hits.bottomHits.playBtn.y+10,hits)
    V.assert(action=="test_play","试玩按钮仍返回原有路由动作")
    clickRect(hits.topHits.widthPlus)
end)
V.atFrame(14,function() forcedW,forcedH=320,568;pending="工坊·320逻辑像素" end)
V.atFrame(18,function() verifyEditor();forcedW,forcedH=nil,nil end)
V.atFrame(20,function()
    verifyEditor();V.assert(hits.layout.boardW/hits.layout.cellSize==9,"尺寸按钮调整真实网格宽度")
    clickRect(hits.bottomHits.importBtn);mode="import";pending="导入关卡·纸卡"
end)
V.atFrame(28,function()
    inside(modal.card,nil,"导入弹框");inside(modal.input,modal.card,"输入区域")
    for _,r in pairs(modal.buttons) do inside(r,modal.card,"导入动作");V.assert(r.w>=44 and r.h>=44,"导入动作有完整触摸区") end
    local state={MIN_SIZE=4,MAX_SIZE=16}
    Modal.handleTextInput("{ width=4, height=4, player={1,1}, boxes={{2,1}}, targets={{2,2}}, walls={}, ice={} }")
    local r=modal.buttons.confirmBtn
    Modal.handleClick(r.x+5,r.y+5,state)
    V.assert(not Modal.isShowing() and state.gridW==4 and #state.boxPositions==1,"新导入框仍解析原关卡格式")
    Modal.open();Editor.leave()
    V.assert(not Modal.isShowing(),"离开工坊关闭输入框与系统键盘")
    mode="time_limit";pending="休息提醒·时长"
end)
V.atFrame(36,function() inside(card,nil,"时长锁定纸卡");mode="curfew";pending="休息提醒·宵禁" end)
V.atFrame(44,function()
    inside(card,nil,"宵禁纸卡")
    local a,b=Anti.canEnterGame,Anti.getBlockReason
    guarded("adult",function() V.assert(not Guard.isRestricted(),"成年允许分支未变");V.assert(Guard.renderOverlay(vg,w,h,"sans",0)==nil,"允许时不绘制拦截层") end)
    V.assert(Anti.canEnterGame==a and Anti.getBlockReason==b,"合规模拟已还原，不改真实年龄或限制")
    nvgFontFace(vg,"sans")
    local rows=Paper.wrap(vg,"错误：关卡内容不完整，请检查后再导入。",14,120)
    V.assert(#rows>1 and table.concat(rows)=="错误：关卡内容不完整，请检查后再导入。","长提示换行但不丢内容")
    for _,row in ipairs(rows) do V.assert(nvgTextBounds(vg,0,0,row)<=120,"真实字宽不溢出提示卡") end
    local mid,done=0,0
    Transition.run(function() mid=mid+1 end,.25)
    Transition.run(function() done=done+100 end,.25)
    Transition.update(.125)
    V.assert(mid==0 and Transition.isAnimating(),"遮挡完成前不切换页面，忽略重复转场")
    V.assert(overlay.props.backgroundColor[1]==255 and overlay.props.backgroundColor[4]>100,"转场采用暖纸色中间帧")
    Transition.update(.125);V.assert(mid==1 and done==0,"遮挡完成时只切换一次")
    Transition.update(.25);Transition.update(1)
    V.assert(not Transition.isAnimating() and not overlay:IsVisible(),"转场结束恢复画面")
    Transition.fadeOut(.01,function() done=done+1 end);Transition.update(1);Transition.update(1)
    V.assert(done==1,"转场完成回调恰好一次")
    Guard.cleanup(vg);Editor.leave();V.finish()
end)
