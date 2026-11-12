--- 第二批界面验收：真实布局/渲染与无写入点击；不认证、不支付、不改进度。
---@diagnostic disable: undefined-global
local UI=require("urhox-libs/UI")
local Density=require("shared.utils.density")
local Trace=require("devtools.adventure-art-trace")
local Paper=require("shared.components.game-paper")
local C=Paper.colors
local Profile=require("pages.profile.init")
local Grid=require("pages.profile.layout")
local Outfits=require("shared.outfit-manager")
local Bg=require("shared.background-manager")
local SkinPopup=require("shared.components.outfit-unlock-popup")
local BgPopup=require("shared.components.bg-unlock-popup")
local Settings=require("shared.components.settings-popup")
local F=require("tests.e2e.game-skin-fixture")
local root,overlay,layout,w,h
local mapImages,mapBackground
local seen={}
F.draw=function(vg,gw,gh)
    nvgBeginPath(vg);nvgRect(vg,0,0,gw,gh);nvgFillColor(vg,nvgRGBA(255,246,220,255));nvgFill(vg)
end
-- 资源加载属于验收场景初始化，避免在采集关键帧时临时读字体与大图。
V.atFrame(4,function()
    local vg=UI.GetNVGContext()
    nvgCreateFont(vg,"adv",require("shared.constants.art").font)
    mapImages={}
    for role,file in pairs({owl="owl",cat="cat",rabbit="bunny",raccoon="raccoon"}) do
        mapImages[role]=nvgCreateImage(vg,"Textures/character/"..file..".png",0)
    end
    require("pages.adventure.rendering.adventure-renderer").init(vg)
    require("shared.components.fox-mascot").init(vg)
    mapBackground=nvgCreateImage(vg,require("shared.constants.art").adventureBackground,0)
    root=UI.Panel{width="100%",height="100%"};UI.SetRoot(root)
    root:AddChild(Profile.create())
end)
local function raw(label,draw)
    local vg=UI.GetNVGContext()
    print("[UIPaperPage] "..label)
    nvgBeginFrame(vg,w,h,1);Trace.request();Trace.begin();draw(vg)
    Trace.finish(w,h,"packed");nvgEndFrame(vg)
end
local function uiCapture(label)
    print("[UIPaperPage] "..label);Trace.request();Trace.begin();UI.Render()
    local uw,uh=UI.GetViewportSize();Trace.finish(uw,uh,"packed")
end
local function inside(node,parent,label)
    V.assert(node~=nil,label.."已挂载")
    if not node then return end
    local b=node:GetAbsoluteLayoutForHitTest()
    local p=parent and parent:GetAbsoluteLayoutForHitTest() or {x=0,y=0}
    if not parent then p.w,p.h=UI.GetViewportSize() end
    V.assert(b.w>0 and b.h>0,label.."有实际尺寸")
    V.assert(b.x>=p.x-1 and b.y>=p.y-1 and b.x+b.w<=p.x+p.w+1 and b.y+b.h<=p.y+p.h+1,label.."位于边界内")
end
local function find(id) return root:FindById(id) end
local function button(id,parent)
    local b=find(id);inside(b,parent,id)
    if b then V.assert(b:GetLayout().h>=44,id.."触摸高度至少44");V.assert(b.props.textColor[1]==91,id.."深褐文字") end
    return b
end
local function click(x,y)
    local scale=graphics:GetDPR()*Density.getFactor()
    local offset=math.max(0,(graphics:GetWidth()/scale-w)/2)
    local function value(n) return {GetInt=function() return n end} end
    Profile_HandleMouseDown(nil,{Button=value(MOUSEB_LEFT),X=value(math.floor((x+offset)*scale)),Y=value(math.floor(y*scale))})
end
local function profileCapture(label)
    local pattern=nvgImagePattern
    nvgImagePattern=function(v,x,y,dw,dh,a,image,alpha)
        if math.abs(dw-70)<0.01 and math.abs(dh-70)<0.01 then seen[image]=true end
        return pattern(v,x,y,dw,dh,a,image,alpha)
    end
    print("[UIPaperPage] "..label);Trace.request();Trace.begin();Profile_HandleNanoVGRender()
    Trace.finish(w,h,"packed");nvgImagePattern=pattern
end
V.atFrame(10,function()
    w,h=Density.getGameSize()
    for _,size in ipairs({{540,1200},{360,640},{320,568},{768,1024}}) do
        local visited={}
        local l=Grid.calculate(size[1],size[2],11,1)
        for page=1,l.pages do
            local p=Grid.calculate(size[1],size[2],11,page)
            for i=p.first,p.last do
                visited[i]=true
                local index=i-p.first
                local right=p.startX+(index%p.cols)*90+76
                local bottom=p.gridTop+14+math.floor(index/p.cols)*114+98
                V.assert(right<=size[1]-23 and bottom<=p.gridBottom-10,"装扮完整卡片在网格内"..size[1].."/"..i)
            end
            if p.pages>1 then V.assert(p.next.y+p.next.h<=size[2]-require("shared.components.tab-bar").HEIGHT,"分页不盖导航"..size[1]) end
        end
        V.assert(#visited==11,"所有角色都能通过分页到达"..size[1])
    end
    layout=Grid.calculate(w,h,#Outfits.getAllSkins(),1)
end)
V.atFrame(18,function()
    profileCapture("装扮·角色第一页")
    if layout.pages>1 then click(layout.next.x+45,layout.next.y+22) end
end)
V.atFrame(26,function()
    profileCapture("装扮·角色末页")
    local count=0;for _ in pairs(seen) do count=count+1 end
    V.assert(count==#Outfits.getAllSkins(),"分页真实点击后绘制全部11枚角色")
    click(w/2+49,110)
end)
V.atFrame(34,function() profileCapture("装扮·真实背景缩略图");Profile.setActive(false)
    overlay=Settings.open(root,{extraButtons=Settings.makeDevButtons()})
end)
V.atFrame(44,function()
    local c=find("settings-card");inside(c,nil,"设置纸卡")
    local scroll=find("settings-scroll");V.assert(scroll:GetLayout().h>60,"设置有受约束滚动区")
    local protection=find("settings-protection-desc"):GetLayout()
    local age=find("settings-age-desc"):GetLayout()
    V.assert(protection.w>c:GetLayout().w*0.5,"保护说明占据状态卡可用宽度")
    V.assert(age.w>c:GetLayout().w*0.4,"年龄说明不挤成窄竖条")
    uiCapture("设置·音量与状态")
    find("settings-age-open").props.onClick()
end)
V.atFrame(54,function()
    local c=find("settings-age-card");inside(c,nil,"年龄纸卡")
    button("settings-age-cancel",c)
    local scroll=find("settings-age-scroll");V.assert(scroll:GetLayout().h>40,"年龄选项可独立滚动")
    scroll:ScrollToBottom()
end)
V.atFrame(62,function()
    local bands=require("shared.cloud-age").BANDS
    button("settings-age-option-"..bands[#bands].id,find("settings-age-scroll"))
    uiCapture("设置·年龄选择")
    find("settings-age-cancel").props.onClick()
    V.assert(find("settings-age-card")==nil,"年龄取消关闭且不提交云存档")
    -- 最后两个扩展按钮分别为解锁/清档，只打开确认卡，不执行确认。
    find("settings-extra-7").props.onClick()
end)
V.atFrame(72,function()
    local c=find("settings-confirm-card");inside(c,nil,"解锁确认卡")
    button("settings-confirm-cancel",c);button("settings-confirm-submit",c)
    local desc=find("settings-confirm-desc")
    V.assert(desc.props.whiteSpace=="normal" and desc:GetLayout().h>20,"长确认说明真实换行")
    uiCapture("设置·操作确认")
    find("settings-confirm-cancel").props.onClick()
    V.assert(find("settings-confirm-card")==nil,"取消不执行原解锁回调")
    find("settings-extra-8").props.onClick()
end)
V.atFrame(82,function()
    local c=find("settings-confirm-card");inside(c,nil,"清档确认卡")
    button("settings-confirm-cancel",c);button("settings-confirm-submit",c)
    find("settings-confirm-cancel").props.onClick()
    find("settings-scroll"):ScrollToBottom()
end)
V.atFrame(90,function()
    button("settings-close",find("settings-scroll"))
    overlay:Remove();overlay=nil
    -- 同一张皮肤反复打开时旧图片只释放一次，关闭释放最后一次。
    local deleted=0;local del=nvgDeleteImage
    nvgDeleteImage=function(...) deleted=deleted+1;return del(...) end
    local vg=UI.GetNVGContext();local dismissed=0
    SkinPopup.show(vg,"default",{fontName="sans"})
    SkinPopup.show(vg,"sport",{fontName="sans",onDismiss=function() dismissed=dismissed+1 end})
    V.assert(deleted==1,"替换解锁插画释放旧图片")
    SkinPopup.update(0.5)
    nvgBeginFrame(vg,w,h,1);SkinPopup.render(vg,w,h);nvgEndFrame(vg)
    SkinPopup.handleClick(w/2,h/2+136)
    V.assert(SkinPopup.isActive(),"不足1秒不能提前关闭奖励")
    SkinPopup.update(0.9)
    local hit,original
    original=Paper.button
    Paper.button=function(v,x,y,bw,bh,label,...)
        if label=="太棒了！" then hit={x=x,y=y,w=bw,h=bh} end
        return original(v,x,y,bw,bh,label,...)
    end
    raw("获得装扮",function(v) SkinPopup.render(v,w,h) end)
    Paper.button=original
    V.assert(hit and hit.h>=44 and hit.y+hit.h<h,"皮肤奖励按钮出现且在视口内")
    if hit then SkinPopup.handleClick(hit.x+hit.w/2,hit.y+hit.h/2) end
    V.assert(not SkinPopup.isActive() and dismissed==1 and deleted==2,"皮肤确认保留回调并释放图片")
    nvgDeleteImage=del
    SkinPopup.dismiss();V.assert(dismissed==1,"重复关闭不重复通知")
end)
V.atFrame(100,function()
    local vg=UI.GetNVGContext();local dismissed=0
    BgPopup.show(vg,"sunset_glow",{fontName="sans",onDismiss=function() dismissed=dismissed+1 end})
    BgPopup.update(1.4)
    local original,preview=Bg.renderBackground,0
    Bg.renderBackground=function(v,bw,bh,t,data)
        V.assert(data.id=="sunset_glow" and math.abs(bw/bh-9/20)<0.001,"解锁背景使用真实9:20配置")
        preview=preview+1;return original(v,bw,bh,t,data)
    end
    local btn,draw= nil,Paper.button
    Paper.button=function(v,x,y,bw,bh,label,...)
        if label=="太棒了！" then btn={x=x,y=y,w=bw,h=bh} end
        return draw(v,x,y,bw,bh,label,...)
    end
    raw("获得背景",function(v) BgPopup.render(v,w,h) end)
    Bg.renderBackground,Paper.button=original,draw
    V.assert(preview==1 and btn and btn.h==44,"真实背景只绘制一次且按钮44高")
    if btn then BgPopup.handleClick(btn.x+btn.w/2,btn.y+btn.h/2) end
    V.assert(not BgPopup.isActive() and dismissed==1,"背景确认回调保留")
    BgPopup.show(vg,"not-a-background");V.assert(not BgPopup.isActive(),"未知ID不会复用上次背景")
end)
V.atFrame(110,function()
    local Result=require("shared.components.result-popup")
    local text,drawn=Paper.text,{}
    Paper.text=function(v,x,y,value,size,color,align,face)
        drawn[tostring(value)]={x=x,y=y,size=size}
        return text(v,x,y,value,size,color,align,face)
    end
    raw("结算·长目标",function(v)
        local hits=Result.drawCleared(v,w,h,{ratingType="stars",ratingValue=3,isNewBest=true,
            stats={{label="本次得分",value=1280},{label="历史最佳",value=1280},
                {label="剩余时间",value="00:45"},{label="目标完成",value="收集全部蓝色花朵图案 12/12"}}})
        for _,b in ipairs(hits) do V.assert(b.y>=0 and b.y+b.h<=h,"长目标结算按钮在视口内") end
    end)
    Paper.text=text
    V.assert(drawn["目标完成"].y<drawn["收集全部蓝色花朵图案 12/12"].y,"长目标另起一行不压标签")
end)
V.atFrame(120,function()
    local Map=require("pages.adventure.rendering.adventure-renderer")
    local L=require("pages.adventure.layout.adaptive-layout")
    local vg=UI.GetNVGContext()
    local imgs=mapImages
    local nodes={};local titles={"慧慧的花园课堂","泡泡的星光捉迷藏","糖糖的花园","豆豆的花园配对","慧慧的冰面谜题","糖糖的糖果风暴","泡泡的记忆迷宫"}
    local roles={"owl","cat","rabbit","raccoon","owl","rabbit","cat"}
    local games={"p1-puzzle-land","p2-memory-flip","p3-match-3","p4-link-match"}
    for i=1,7 do nodes[i]={state=i==7 and "current" or "done",node={npc={role=roles[i]},title=titles[i],gameType=games[(i-1)%4+1]}} end
    local header,chapter,footer=L.calcAdaptiveRegions(h)
    local top,area=header+chapter,h-header-chapter-footer
    local radius,spacing=L.calcAdaptiveLayout(area,7)
    local hits={}
    raw("主线地图·角色出框",function(v)
        nvgBeginPath(v);nvgRect(v,0,0,w,h);nvgFillColor(v,nvgRGBA(209,226,148,255));nvgFill(v)
        -- 复用真实完整地图背景、标题与节点渲染，进度为独立验收数据。
        local bg=mapBackground
        local iw,ih=nvgImageSize(v,bg);local scale=math.max(w/iw,h/ih)
        nvgBeginPath(v);nvgRect(v,0,0,w,h);nvgFillPaint(v,nvgImagePattern(v,(w-iw*scale)/2,(h-ih*scale)/2,iw*scale,ih*scale,0,bg,1));nvgFill(v)
        Map.renderHeader(v,w,1,header)
        Map.renderChapterTitle(v,w,1,7,1,header,chapter,1,{lastDisplayedPage=1,fadeAlpha=1})
        Map.renderPagePaths(v,nodes,1,7,w,top,area,7,radius,spacing)
        local count=0
        for i,node in ipairs(nodes) do count=Map.renderNode(v,node,i,i,w,top,area,7,1,radius,spacing,imgs,hits,count) end
        require("shared.components.fox-mascot").render(v,w,h,require("shared.components.tab-bar").HEIGHT,L.getFoxOptions(h))
        Map.renderPagination(v,w,h,6,1,1,footer)
        require("shared.components.tab-bar").render(v,w,h,"adventure",1,"adv",nil,"handdrawn")
        nvgDeleteImage(v,bg)
    end)
    for i,b in ipairs(hits) do
        local px,py,size=L.getPortraitBox(b.cx,b.cy,radius)
        local head,feet=py+size*32/512,py+size*480/512
        V.assert(head<b.cy-radius and feet<b.cy+radius,"角色头部出框且脚底在框内"..i)
        V.assert(head>=top+2 and px>=0 and px+size<=w,"角色出框仍在地图范围"..i)
        if i>=3 then V.assert(head>=hits[i-2].cy+radius+44+2,"同列角色不碰上一关标题"..i) end
        V.assert(b.r>=radius*(1+L.PORTRAIT_OVERHANG),"出框部分仍在可点范围"..i)
    end
    Map.cleanup();require("shared.components.fox-mascot").cleanup();for _,img in pairs(imgs) do nvgDeleteImage(vg,img) end
    Profile.destroy()
    V.assert(type(Profile_HandleMouseDown)=="function" and type(Profile_HandleNanoVGRender)=="function","装扮销毁保留可复用事件入口")
    root=UI.Panel{width="100%",height="100%"};UI.SetRoot(root);root:AddChild(Profile.create())
end)

V.atFrame(130,function()
    V.assert(type(Profile_HandleNanoVGRender)=="function","再次进入装扮页仍可渲染")
    Profile_HandleNanoVGRender();Profile.destroy()
    V.finish()
end)
