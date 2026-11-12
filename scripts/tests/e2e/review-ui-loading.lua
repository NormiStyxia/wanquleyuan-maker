--- 资源生命周期与失败页返回验收；装扮切换仅使用内存状态，不写存档或执行支付。
---@diagnostic disable: undefined-global
local UI=require('urhox-libs/UI')
local F=require('tests.e2e.game-skin-fixture')
local Profile=require('pages.profile.init')
local Outfits=require('shared.outfit-manager')
local Grid=require('pages.profile.layout')
local Density=require('shared.utils.density')
local StoryPaper=require('shared.components.story-paper')
local Popup=require('shared.components.purchase-popup')
local Router=require('app.router')
local Game=require('pages.game.init')
local Container=require('modules.game-container.init')
local Trace= WANQU_UI_TRACE and require('devtools.adventure-art-trace') or nil
local original, calls, images = {}, {}, {}
local root, w, h, vg, previewPath, purchase
local current='default'
local profileVg, loaded, deleted={}, {}, {}
-- 入口已完成Start；本脚本只替换验收底图和内存选择，不重启生产入口。
F.draw=function(v,bw,bh)
    nvgBeginPath(v);nvgRect(v,0,0,bw,bh);nvgFillColor(v,nvgRGBA(255,246,220,255));nvgFill(v)
end
F.update=function() end
local function replace(t,key,fn) original[#original+1]={t,key,t[key]};t[key]=fn end
local createImage,deleteImage=nvgCreateImage,nvgDeleteImage
replace(_G,'nvgCreateImage',function(v,path,flags)
    local image=createImage(v,path,flags)
    calls[path]=(calls[path] or 0)+1
    images[v]=images[v] or {};images[v][image]=path
    if path:find('character%-previews/') then profileVg[v]=true end
    if profileVg[v] and image>0 then
        local key=tostring(v)..':'..image
        loaded[key]=path;deleted[key]=0
    end
    return image
end)
replace(_G,'nvgDeleteImage',function(v,image)
    local key=tostring(v)..':'..image
    if loaded[key] then deleted[key]=deleted[key]+1 end
    return deleteImage(v,image)
end)
replace(Outfits,'getCurrent',function() return current end)
replace(Outfits,'setCurrent',function(id) current=id;return true end)
replace(Outfits,'getCurrentName',function() return Outfits.getSkinById(current).name end)
replace(Outfits,'isUnlocked',function(id) return id~='suit' end)
replace(Popup,'show',function(v,id,opts) purchase={vg=v,id=id,opts=opts} end)
local portrait=StoryPaper.portrait
replace(StoryPaper,'portrait',function(v,image,x,y,pw,ph,...)
    if pw>76 then vg=v;previewPath=images[v] and images[v][image] end
    return portrait(v,image,x,y,pw,ph,...)
end)
local function render(label)
    local capture=Trace and (label=='装扮·按需大图' or label=='装扮·背景明信片')
    if capture then print('[UIPaperPage] '..label);Trace.request();Trace.begin() end
    Profile_HandleNanoVGRender()
    if capture then Trace.finish(w,h,'packed') end
end
local function click(x,y)
    local scale=graphics:GetDPR()*Density.getFactor()
    local offset=math.max(0,(graphics:GetWidth()/scale-w)/2)
    local function value(n) return {GetInt=function() return n end} end
    Profile_HandleMouseDown(nil,{Button=value(MOUSEB_LEFT),X=value(math.floor((x+offset)*scale)),Y=value(math.floor(y*scale))})
end
local function clickSkin(index)
    local first=Grid.calculate(w,h,11,1)
    local capacity=first.rows*first.cols
    local page=math.floor((index-1)/capacity)+1
    for _=2,page do click(first.next.x+45,first.next.y+22);render('分页') end
    local l=Grid.calculate(w,h,11,page);local i=index-l.first
    click(l.startX+(i%l.cols)*90+38,l.gridTop+14+math.floor(i/l.cols)*114+38)
end
local function allReleased(label)
    for key,path in pairs(loaded) do V.assert(deleted[key]==1,label..'资源只释放一次 '..path) end
end
local function captureUI(label)
    if not Trace then return end
    print('[UIPaperPage] '..label);Trace.request();Trace.begin();UI.Render()
    local uw,uh=UI.GetViewportSize();Trace.finish(uw,uh,'packed')
end
local function inside(node,parent,label)
    V.assert(node~=nil,label..'已挂载');if not node then return end
    local b=node:GetAbsoluteLayoutForHitTest()
    local p=parent and parent:GetAbsoluteLayoutForHitTest() or {x=0,y=0}
    if not parent then p.w,p.h=UI.GetViewportSize() end
    V.assert(b.w>0 and b.h>0,label..'实际尺寸有效')
    V.assert(b.x>=p.x-1 and b.y>=p.y-1 and b.x+b.w<=p.x+p.w+1 and b.y+b.h<=p.y+p.h+1,label..'完整位于边界内')
end
local function unavailable()
    local card=root:FindById('game-unavailable-card')
    local back=root:FindById('game-unavailable-back')
    inside(card,nil,'加载失败纸卡');inside(back,card,'返回按钮')
    V.assert(back:GetLayout().h>=44,'返回按钮触摸高度44以上')
    V.assert(back.props.textColor[1]==91,'返回按钮深褐文字')
    return back
end
V.atFrame(4,function()
    root=UI.Panel{width='100%',height='100%'};UI.SetRoot(root)
    root:AddChild(Profile.create())
    for _,skin in ipairs(Outfits.getAllSkins()) do
        V.assert(calls[skin.thumbnail]==1,'列表加载独立缩略图 '..skin.id)
        V.assert((calls[skin.texture] or 0)==(skin.id=='default' and 1 or 0),'首次只加载当前角色原图 '..skin.id)
    end
end)
V.atFrame(12,function()
    w,h=Density.getGameSize();render('装扮·按需大图')
    V.assert(previewPath==Outfits.getSkinById('default').texture,'大预览仍使用512原画')
    clickSkin(2);render('装扮·运动装')
    V.assert(current=='sport' and previewPath==Outfits.getSkinById('sport').texture,'实际点击切换加载运动装原画')
    clickSkin(1);clickSkin(2)
    V.assert(calls[Outfits.getSkinById('sport').texture]==1,'回访同一角色不重复加载原图')
    clickSkin(4)
    V.assert(purchase and purchase.id=='suit','锁定付费角色仍走购买预览')
    V.assert(current=='sport','打开购买预览不直接选中锁定角色')
    V.assert(images[purchase.vg][purchase.opts.skinImage]==Outfits.getSkinById('suit').texture,'购买预览使用原画')
    -- 只验证外部成功通知的UI同步，不调用支付或Outfit.purchase。
    purchase.opts.onPurchased('suit');render('装扮·购买回调')
    V.assert(current=='suit' and previewPath==Outfits.getSkinById('suit').texture,'成功回调同步大预览且复用图片')
    V.assert(calls[Outfits.getSkinById('suit').texture]==1,'购买回调不重复解码预览')
    Profile.setActive(false);current='doctor';Profile.setActive(true);render('装扮·外部同步')
    V.assert(previewPath==Outfits.getSkinById('doctor').texture,'外部角色变化在激活时加载原画')
    local before={};for path,count in pairs(calls) do before[path]=count end
    click(w/2+49,110);render('装扮·背景明信片')
    for path,count in pairs(calls) do
        if count>(before[path] or 0) then V.assert(path:find('/previews/')~=nil,'背景列表和明信片不新载全尺寸主题 '..path) end
    end
end)
V.atFrame(22,function()
    Profile.destroy();allReleased('退出装扮')
    root=UI.Panel{width='100%',height='100%'};UI.SetRoot(root);root:AddChild(Profile.create())
end)
V.atFrame(32,function()
    render('装扮·重新进入')
    V.assert(previewPath==Outfits.getSkinById('doctor').texture,'销毁后重新进入仍能显示当前角色原画')
    Profile.destroy();allReleased('再次退出装扮')
    root=UI.Panel{width='100%',height='100%'};UI.SetRoot(root);Router.init(root)
    local function page() return UI.Panel{width='100%',flexGrow=1} end
    Router.register('adventure',page);Router.register('home',page)
    Router.register('game',Game.create,Game.destroy)
    Router.replace('adventure');Router.push('game',{})
end)
V.atFrame(42,function()
    captureUI('加载失败·可返回纸卡')
    local back=unavailable();back.props.onClick()
    V.assert(Router.getCurrent()=='adventure' and Router.getStackDepth()==1,'缺少关卡配置时返回原页面而非卡死')
    local enter=Container.enter
    Container.enter=function() return false end
    Router.push('game',{gameConfig={gameId='test-unavailable'}})
    Container.enter=enter
end)
V.atFrame(52,function()
    unavailable().props.onClick()
    V.assert(Router.getCurrent()=='adventure','容器进入被拒时仍可返回')
    Router.replace('game',{})
end)
V.atFrame(62,function()
    unavailable().props.onClick()
    V.assert(Router.getCurrent()=='home' and Router.getStackDepth()==1,'孤立失败页回退到自由模式入口')
    for i=#original,1,-1 do local r=original[i];r[1][r[2]]=r[3] end
    V.finish()
end)
