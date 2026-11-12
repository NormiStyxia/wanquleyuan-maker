--- 纸卡结构、导航皮肤与合规弹层排版验收。无个人信息、存档写入、认证或消费操作。
---@diagnostic disable: undefined-global
local UI = require("urhox-libs/UI")
local Privacy = require("shared.components.privacy-policy-popup")
local Auth = require("shared.components.real-name-auth-overlay")
local Rest = require("shared.components.anti-addiction-popup")
local Pen = require("shared.components.handdrawn")
local Tab = require("shared.components.tab-bar")
local F = require("tests.e2e.game-skin-fixture")
local root, overlay

local function reset()
    Rest.dismiss()
    if overlay then overlay:Remove(); overlay = nil end
    root = UI.Panel {width="100%",height="100%"}
    UI.SetRoot(root)
end
local function inside(node, parent, label)
    local b = node:GetAbsoluteLayout()
    local p = parent and parent:GetAbsoluteLayout() or {x=0,y=0}
    if not parent then p.w,p.h=UI.GetViewportSize() end
    V.assert(b.w>0 and b.h>0,label.."有实际尺寸")
    V.assert(b.x>=p.x-1 and b.y>=p.y-1 and b.x+b.w<=p.x+p.w+1 and b.y+b.h<=p.y+p.h+1,label.."在边界内")
end
local function card(id)
    local c=root:FindById(id)
    V.assert(c~=nil,id.."已挂载")
    if c then inside(c,nil,id) end
    return c
end
local function button(id, parent)
    local b=root:FindById(id)
    V.assert(b~=nil,id.."已显示")
    if not b then return end
    inside(b,parent,id)
    V.assert(b:GetLayout().h>=44,id.."可点高度至少44")
    V.assert(b.props.borderWidth==2,id.."使用纸卡粗描边")
    V.assert(b.props.textColor[1]==91,id.."深褐色按钮文字")
end
V.atFrame(12,function() reset();overlay=Privacy.showConsent(root,function() error("不得同意协议或写存档") end) end)
V.atFrame(24,function()
    local c=card("privacy-card")
    button("privacy-decline",c);button("privacy-accept",c)
    local scroll=root:FindById("privacy-scroll")
    V.assert(scroll:GetLayout().h>40,"隐私正文有受约束滚动区")
    local body=root:FindById("privacy-body-2")
    V.assert(body.props.whiteSpace=="normal" and body:GetLayout().h>body.props.fontSize*4,"隐私长文真实换行，不截成一行")
    scroll:ScrollToBottom()
end)
V.atFrame(34,function()
    local c=card("privacy-card");button("privacy-accept",c)
    reset();overlay=Privacy.showView(root)
end)
V.atFrame(46,function() local c=card("privacy-card");button("privacy-close",c) end)
V.atFrame(54,function() reset();overlay=Auth.create(function() error("不得提交认证") end);root:AddChild(overlay) end)
V.atFrame(66,function()
    local c=card("auth-card")
    local scroll=root:FindById("auth-scroll")
    V.assert(scroll:GetLayout().h>40,"认证表单有滚动高度")
    local name=root:FindById("auth-name")
    V.assert(name.props.textColor[1]==91 and name.props.focusedBorderColor[1]==238,"输入文字与聚焦边框匹配纸卡")
    Auth.submit()
    V.assert(Auth.isActive(),"空表单保留原校验，不绕过实名认证")
    V.assert(root:FindById("auth-error").props.text=="请输入真实姓名","原空值提示保留")
    scroll:ScrollToBottom()
end)
V.atFrame(78,function()
    local scroll=root:FindById("auth-scroll")
    local b=root:FindById("auth-submit"):GetAbsoluteLayoutForHitTest()
    local s=scroll:GetAbsoluteLayoutForHitTest()
    V.assert(b.y>=s.y-1 and b.y+b.h<=s.y+s.h+1,"短屏认证可滚到提交按钮")
    reset();Rest.showReminder(root,function() end,function() end)
end)
V.atFrame(90,function() local c=card("rest-card");button("rest-action-1",c);button("rest-action-2",c) end)
V.atFrame(98,function() reset();Rest.showForceExit(root,function() end) end)
V.atFrame(110,function() local c=card("rest-card");button("rest-action-1",c) end)
V.atFrame(118,function() reset();Rest.showCurfew(root,function() end) end)
V.atFrame(130,function() local c=card("rest-card");button("rest-action-1",c);button("rest-action-2",c) end)
V.atFrame(138,function() reset();Rest.showMinorLimitNotice(root,17,function() end) end)
V.atFrame(150,function()
    local c=card("rest-card");button("rest-action-1",c)
    local scroll=root:FindById("rest-scroll");V.assert(scroll:GetLayout().h>40,"长说明在独立滚动区")
    local body=root:FindById("rest-paragraph-3")
    V.assert(body.props.whiteSpace=="normal" and body:GetLayout().h>body.props.fontSize*2,"未成年长提示真实换行")
    scroll:ScrollToBottom()
end)
V.atFrame(162,function()
    button("rest-action-1",card("rest-card"))
    reset()
    -- 同一个真实绘制入口分别验证旧字符串参数和页面在用的表参数。
    local vg=UI.GetNVGContext()
    local original,count=Pen.plaque,0
    Pen.plaque=function(...) count=count+1;return original(...) end
    local a=Tab.render(vg,400,896,"home",0,"sans",nil,"handdrawn")
    local first=count;count=0
    local b=Tab.render(vg,400,896,"home",0,"sans",nil,{handdrawn=true})
    Pen.plaque=original
    V.assert(first==4 and count==first,"大厅/装扮表参数实际进入手绘导航")
    V.assert(a.tabs[2].x==b.tabs[2].x and a.settings.x==b.settings.x,"皮肤切换保留原路由点击区域")
    -- 检查所有直线段的轴向与边界；原先左右偏移的轮廓会失败。
    local move,line=nvgMoveTo,nvgLineTo
    local prev,segments=nil,{}
    nvgMoveTo=function(v,x,y) prev={x,y};return move(v,x,y) end
    nvgLineTo=function(v,x,y) if prev then segments[#segments+1]={prev[1],prev[2],x,y} end;prev={x,y};return line(v,x,y) end
    local quad=nvgQuadTo
    nvgQuadTo=function(v,cx,cy,x,y) prev={x,y};return quad(v,cx,cy,x,y) end
    Pen.plaque(vg,20,30,64,64,{255,246,220,255},2)
    nvgMoveTo,nvgLineTo,nvgQuadTo=move,line,quad
    V.assert(#segments==4,"纸卡四边都是独立结构直线")
    for i,p in ipairs(segments) do V.assert(p[1]==p[3] or p[2]==p[4],"纸卡结构边不倾斜"..i) end
    local Card=require("shared.components.game-card")
    local create,pattern=nvgCreateImage,nvgImagePattern
    local loads,draws=0,0
    nvgCreateImage=function(...) loads=loads+1;return create(...) end
    nvgImagePattern=function(v,x,y,w,h,angle,image,alpha)
        V.assert(image>0,"入口插画使用有效图片句柄")
        draws=draws+1;return pattern(v,x,y,w,h,angle,image,alpha)
    end
    local games={"p1-puzzle-land","p2-memory-flip","p3-match-3","p4-link-match"}
    for _,game in ipairs(games) do Card.drawGameIcon(vg,64,64,90,game) end
    local firstLoads=loads
    for _,game in ipairs(games) do Card.drawGameIcon(vg,64,64,90,game) end
    nvgCreateImage,nvgImagePattern=create,pattern
    V.assert(draws==8,"四个入口都实际绘制独立手绘贴图")
    V.assert(loads==firstLoads and loads<=4,"入口插画按上下文缓存，不每帧创建图片")
    V.finish()
end)
