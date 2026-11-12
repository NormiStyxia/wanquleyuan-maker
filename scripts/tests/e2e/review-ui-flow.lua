--- 引擎 SendEvent 驱动真实路由和四个 adapter；不使用真实云端/存档/支付。
---@diagnostic disable: undefined-global
local UI=require("urhox-libs/UI")
local Router=require("app.router")
local Container=require("modules.game-container.init")
local Transition=require("shared.components.screen-transition")
local Density=require("shared.utils.density")
local Health=require("shared.components.health-advisory")
local Bg=require("shared.background-manager")
local state=WANQU_UI_FLOW
-- 保留远端的真实引擎图标所有权检查；JSON 首页改为共享 UI 上下文，另测独立卡片上下文释放。
local Art=require("shared.constants.art")
local ImageCache=require("urhox-libs/UI/Core/ImageCache")
local Card=require("shared.components.game-card")
local iconPaths={}
for _,path in pairs(Art.gameIcons) do iconPaths[path]=true end
local iconOwners,iconContexts,iconReleases={},0,0
local createImage,deleteImage,deleteContext=nvgCreateImage,nvgDeleteImage,nvgDelete
nvgCreateImage=function(vg,path,flags)
    local image=createImage(vg,path,flags)
    if iconPaths[path] and image and image>0 then
        if not iconOwners[vg] then iconOwners[vg]={};iconContexts=iconContexts+1 end
        V.assert(iconOwners[vg][image]==nil,"当前上下文没有重复加载大厅图标")
        iconOwners[vg][image]=path
    end
    return image
end
nvgDeleteImage=function(vg,image)
    if iconOwners[vg] and iconOwners[vg][image] then
        iconOwners[vg][image]=nil;iconReleases=iconReleases+1
    end
    return deleteImage(vg,image)
end
nvgDelete=function(vg)
    if iconOwners[vg] then
        V.assert(next(iconOwners[vg])==nil,"销毁独立上下文前已释放全部图标并清空缓存")
        iconOwners[vg]=nil
    end
    return deleteContext(vg)
end
local sharedContext=UI.GetNVGContext()
local sharedImages,homeVisits={},0
local function assertHomeIcons()
    homeVisits=homeVisits+1
    V.assert(UI.GetNVGContext()==sharedContext,"切页及游戏进出保留全局UI上下文")
    for gameId,path in pairs(Art.gameIcons) do
        local widget=UI.GetRoot():FindById(gameId.."-icon")
        V.assert(widget and widget.props.backgroundImage==path,"JSON卡片保留独立手绘图标 "..gameId)
        V.assert(ImageCache.IsLoaded(path),"JSON图标实际加载成功 "..gameId)
        local image=ImageCache.Get(path)
        sharedImages[path]=sharedImages[path] or image
        V.assert(image==sharedImages[path] and iconOwners[sharedContext] and iconOwners[sharedContext][image]==path,
            "JSON图标仍归属原图片而非复用的字体句柄 "..gameId)
        local w,h=nvgImageSize(sharedContext,image)
        V.assert(w>0 and h>0,"JSON图标纹理仍可访问 "..gameId)
    end
end
local names={"p1-puzzle-land","p2-memory-flip","p3-match-3","p4-link-match"}
local tabs,selects,gameDraws,pauseHits={},{},{},nil
local tabRender=require("shared.components.tab-bar").render
require("shared.components.tab-bar").render=function(vg,w,h,active,...)
    local hits=tabRender(vg,w,h,active,...)
    tabs[active]=hits;return hits
end
for index,name in ipairs(names) do
    local select=require("games."..name..".screens.level-select")
    local draw=select.draw
    select.draw=function(vg,w,h,...)
        local hits=draw(vg,w,h,...)
        selects[index]={hits=hits,w=w,h=h};return hits
    end
    local play=require("games."..name..".screens.gameplay")
    local render=play.render
    play.render=function(...) gameDraws[index]=(gameDraws[index] or 0)+1;return render(...) end
end
local pause=require("shared.components.pause-overlay")
local drawPause=pause.draw
pause.draw=function(...) pauseHits=drawPause(...);return pauseHits end
local background=require("shared.components.level-select-ui")
local drawBackground=background.drawBackground
local renderedBackground
local renderBackground=Bg.renderBackground
Bg.renderBackground=function(vg,w,h,t,cfg)
    renderedBackground=cfg or Bg.getCurrent()
    return renderBackground(vg,w,h,t,cfg)
end
background.drawBackground=function(...)
    renderedBackground=nil
    drawBackground(...)
    V.assert(renderedBackground==Bg.getCurrent(),"选关使用玩家手绘背景配置")
end
local function settle() Transition.update(1);Transition.update(1) end
local function emit(event,x,y)
    local data=VariantMap()
    data["X"]=Variant(math.floor(x));data["Y"]=Variant(math.floor(y))
    data["Button"]=Variant(MOUSEB_LEFT);data["Buttons"]=Variant(0)
    data["Qualifiers"]=Variant(0);data["TouchID"]=Variant(0);data["Pressure"]=Variant(1.0)
    SendEvent(event,data)
end
local function clickPhysical(x,y,touch)
    emit(touch and "TouchBegin" or "MouseButtonDown",x,y)
    emit(touch and "TouchEnd" or "MouseButtonUp",x,y)
    settle()
end
local function click(r,touch)
    V.assert(r~=nil,"实际绘制的点击区存在");if not r then return end
    local w=Density.getGameSize()
    local scale=graphics:GetDPR()*Density.getFactor()
    local offset=math.max(0,(graphics:GetWidth()/scale-w)/2)
    clickPhysical((r.x+r.w/2+offset)*scale,(r.y+r.h/2)*scale,touch)
end
local function clickWidget(id,touch)
    local widget=UI.GetRoot():FindById(id)
    V.assert(widget~=nil,"JSON控件可达 "..id)
    if not widget then return end
    local b=widget:GetAbsoluteLayoutForHitTest()
    local canvas=UI.GetRoot():FindById("home-document-canvas")
    local scale=UI.GetScale()
    local x,y=b.x+b.w/2,b.y+b.h/2
    if canvas then
        local origin=canvas:GetAbsoluteLayoutForHitTest()
        local factor=canvas.props.scale or 1
        x=origin.x+(x-origin.x)*factor
        y=origin.y+(y-origin.y)*factor
    end
    clickPhysical(x*scale,y*scale,touch)
end
local function tab(id)
    if Router.getCurrent()=="home" then
        clickWidget("tab-"..id)
        return
    end
    local hits=tabs[Router.getCurrent()]
    if hits then for _,r in ipairs(hits.tabs) do if r.id==id then click(r);return end end end
    V.assert(false,"页签可达 "..id)
end
local function key(code)
    local data=VariantMap();data["Key"]=Variant(code);data["Repeat"]=Variant(false)
    SendEvent("KeyDown",data);settle()
end
local function inside(r,w,h,label)
    V.assert(r and r.w>=44 and r.h>=44,label.."触摸区至少44")
    if r then V.assert(r.x>=0 and r.y>=0 and r.x+r.w<=w+1 and r.y+r.h<=h+1,label.."不越界") end
end
V.atFrame(8,function()
    V.assert(Router.getCurrent()=="adventure","真实Start进入主线地图")
    V.assert(Health.isActive(),"真实启动忠告存在")
    Health.update(5.1)
    local splash=UI.GetRoot():FindById("splash-screen")
    V.assert(splash~=nil,"真实UI树挂载启动界面")
    clickPhysical(graphics:GetWidth()/2,graphics:GetHeight()*.06)
    Health.update(1)
    V.assert(not Health.isActive(),"进度完成后引擎点击关闭启动页")
    tab("home")
end)
for index,name in ipairs(names) do
    local at=18+(index-1)*48
    local play=require("games."..name..".screens.gameplay")
    V.atFrame(at,function()
        V.assert(Router.getCurrent()=="home","大厅恢复 "..name)
        V.assert(UI.GetRoot():FindById("home-page")~=nil,"大厅挂载JSON文档根")
        assertHomeIcons()
        clickWidget("game-"..name,index%2==0)
        V.assert(Router.getCurrent()=="game" and Container.isRunning(),"真实卡片进入adapter "..name)
        V.assert(Container.getGameConfig() and Container.getGameConfig().gameId==name,"进入的玩法身份正确 "..name)
        V.assert(Router.getStackDepth()==2,"游戏压栈保留来源大厅")
    end)
    V.atFrame(at+8,function()
        local s=selects[index]
        V.assert(s~=nil,"选关由adapter渲染 "..name);if not s then return end
        inside(s.hits.backBtn,s.w,s.h,"选关返回")
        for _,r in pairs(s.hits.levelBtns) do inside(r,s.w,s.h,"关卡") end
        if s.hits.nextBtn then inside(s.hits.nextBtn,s.w,s.h,"下一页") end
        click(s.hits.levelBtns[1],index%2==0)
        V.assert(play.isActive(),"真实选关点击进入关卡 "..name)
    end)
    V.atFrame(at+16,function()
        V.assert((gameDraws[index] or 0)>0,"真实关卡已渲染 "..name)
        V.assert(Container.pause("ui_review") and Container.getState()=="PAUSED","容器暂停有效 "..name)
        V.assert(Container.resume() and Container.getState()=="RUNNING","容器恢复有效 "..name)
        key(KEY_ESCAPE)
        if index>1 then V.assert(play.isPaused(),"Escape打开真实暂停层 "..name) end
    end)
    V.atFrame(at+24,function()
        if index==1 then return end
        local r=pauseHits and pauseHits[1]
        click(r,index%2==0)
        V.assert(not play.isPaused(),"暂停层继续按钮恢复关卡 "..name)
        key(KEY_ESCAPE)
    end)
    V.atFrame(at+32,function()
        if index>1 then
            click(pauseHits and pauseHits[2],index%2==0)
        end
        V.assert(not play.isActive(),"退出关卡清理棋盘 "..name)
    end)
    V.atFrame(at+40,function()
        local s=selects[index]
        if s then click(s.hits.backBtn,index%2==0) end
        V.assert(Container.getState()=="IDLE","退出adapter释放容器 "..name)
        V.assert(Router.getCurrent()=="home" and Router.getStackDepth()==1,"返回真实大厅 "..name)
    end)
end
V.atFrame(212,function() tab("profile") end)
V.atFrame(222,function()
    V.assert(Router.getCurrent()=="profile","四次退出后装扮仍可达")
    tab("adventure")
end)
V.atFrame(232,function()
    V.assert(Router.getCurrent()=="adventure","装扮返回主线仍可达")
    tab("home")
end)
V.atFrame(242,function()
    clickWidget("tab-settings")
end)
V.atFrame(248,function()
    local scroll=UI.GetRoot():FindById("settings-scroll")
    V.assert(scroll~=nil,"设置滚动区存在")
    if scroll then scroll:ScrollToBottom() end
end)
V.atFrame(252,function()
    local close=UI.GetRoot():FindById("settings-close")
    V.assert(close~=nil,"退出游戏后Yoga设置层正常打开")
    if close then
        local r=close:GetAbsoluteLayoutForHitTest();local scale=UI.Theme.GetScale()
        local scroll=UI.GetRoot():FindById("settings-scroll"):GetAbsoluteLayoutForHitTest()
        V.assert(r.y>=scroll.y-1 and r.y+r.h<=scroll.y+scroll.h+1,"滚至末尾后关闭按钮完整可见")
        clickPhysical((r.x+r.w/2)*scale,(r.y+r.h/2)*scale)
    end
end)
V.atFrame(262,function()
    V.assert(UI.GetRoot():FindById("settings-close")==nil,"原生UI事件可关闭设置层")
    tab("adventure")
end)
V.atFrame(272,function()
    V.assert(Router.getCurrent()=="adventure","关闭设置后主线输入仍有效")
    V.assert(#state.errors==0,"完整路径没有业务logger.error")
    for _,err in ipairs(state.errors) do print("[UIFlowError] "..cjson.encode(err)) end
    V.assert(#state.imageFailures==0,"完整路径所有实际图片加载成功")
    for _,path in ipairs(state.imageFailures) do print("[UIFlowImageError] "..path) end
    V.assert(state.files["saves/p1-puzzle-land.json"]~=nil,"退出存档只写独立内存")
    Router.replace("home")
end)
V.atFrame(278,function()
    local root=UI.GetRoot()
    local document=root:FindById("home-page")
    V.assert(document and document._jsonSource and document._jsonSource.file=="ui/home.ui.json","首页确实来自目标JSON资源")
    local guard=require("shared.utils.play-time-guard")
    local restricted,reason=guard.isRestricted,guard.getBlockReason
    guard.isRestricted=function() return true end
    guard.getBlockReason=function() return "time_limit" end
    clickWidget("game-p1-puzzle-land")
    V.assert(Router.getCurrent()=="home" and Container.getState()=="IDLE","防沉迷限制仍拦截JSON卡片进入")
    V.assert(root:FindById("rest-card")~=nil,"受限入口仍显示原防沉迷弹窗")
    require("shared.components.anti-addiction-popup").dismiss()
    guard.isRestricted,guard.getBlockReason=restricted,reason
    local previousBg=Bg.getCurrent
    Bg.getCurrent=function()
        return {id="preview-test",themeImage="image/handdrawn/backgrounds/sky_blue.png",colors={base={230,242,255,255}}}
    end
    local outfit=require("shared.outfit-manager")
    local previousTexture=outfit.getTexturePath
    outfit.getTexturePath=function() return "Textures/character/skins/fox_sport.png" end
    state.restoreHomeDynamic=function()
        Bg.getCurrent=previousBg
        outfit.getTexturePath=previousTexture
    end
end)
V.atFrame(282,function()
    local root=UI.GetRoot()
    V.assert(root:FindById("home-background").props.backgroundImage=="image/handdrawn/backgrounds/sky_blue.png","JSON背景跟随原管理器状态更新")
    V.assert(root:FindById("home-mascot").props.backgroundImage=="Textures/character/skins/fox_sport.png","JSON狐狸跟随原皮肤状态更新")
    V.assert(root:FindById("tab-home").props.disabled==false,"已通关第4关时解除JSON自由页签静态禁用")
    state.restoreHomeDynamic()
    print("[UIFlow] finished JSON home/router/adapter path; saves and cloud isolated")
    tab("adventure")
end)
-- replace 重建 JSON 树但保留 UI 上下文；四玩法 push/pop 和反复切页都要覆盖。
-- 从 292 帧开始，避免覆盖本地 282 帧的动态状态回归。
for round=0,7 do
    V.atFrame(292+round*20,function() tab("home") end)
    V.atFrame(302+round*20,function()
        V.assert(Router.getCurrent()=="home","重建大厅可达")
        assertHomeIcons()
        tab(round%2==0 and "profile" or "adventure")
    end)
end
-- 旧手绘卡片仍保留远端 release 修复；用十个真实独立上下文检查40张图的释放。
---@type NVGContextWrapper
local cardContext
local cardRounds,cardDraws=0,0
function UIFlow_HandleCardRender(eventType,eventData)
    Density.beginFrame(cardContext)
    for _,name in ipairs(names) do Card.drawGameIcon(cardContext,32,32,32,name) end
    Density.endFrame(cardContext)
    cardDraws=cardDraws+1
end
V.atFrame(452,function()
    local loaded=0
    for _ in pairs(iconOwners[sharedContext] or {}) do loaded=loaded+1 end
    V.assert(homeVisits==12,"四玩法入口及八次大厅重建均校验图标")
    V.assert(iconContexts==1 and loaded==4,"JSON大厅仅共享UI上下文加载四张图，不跨上下文复用")
    V.assert(iconReleases==0,"切页不误删共享UI图标")
    cardContext=nvgCreate(1)
    SubscribeToEvent(cardContext,"NanoVGRender","UIFlow_HandleCardRender")
end)
for round=0,9 do
    V.atFrame(462+round*10,function()
        local loaded=0
        for _ in pairs(iconOwners[cardContext] or {}) do loaded=loaded+1 end
        V.assert(loaded==4,"独立上下文重新加载四个手绘图标")
        Card.release(cardContext)
        V.assert(next(iconOwners[cardContext] or {})==nil,"release清空当前上下文全部图标所有权")
        Card.release(cardContext)
        nvgDelete(cardContext)
        cardRounds=cardRounds+1
        if round<9 then
            cardContext=nvgCreate(1)
            SubscribeToEvent(cardContext,"NanoVGRender","UIFlow_HandleCardRender")
        end
    end)
end
V.atFrame(562,function()
    V.assert(cardRounds==10 and cardDraws>=10,"十次独立上下文均实际绘制图标")
    V.assert(iconContexts==11,"共享UI及十次独立卡片上下文分别加载图标")
    V.assert(iconReleases==40,"四十个独立图标均在所属上下文销毁前释放且重复release安全")
    V.assert(next(iconOwners)==sharedContext and next(iconOwners,sharedContext)==nil,"独立上下文无遗留所有权，只保留全局UI缓存")
    V.assert(#state.errors==0 and #state.imageFailures==0,"反复切页后无业务错误或图片加载失败")
    nvgCreateImage,nvgDeleteImage,nvgDelete=createImage,deleteImage,deleteContext
    print("[UIFlow] icon lifecycle contexts="..iconContexts.." released="..iconReleases)
    V.finish()
end)
