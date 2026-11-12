--- 真实 main.lua 中验证矩形立绘、说话者左右布局与推进回调，不写入关卡进度。
---@diagnostic disable: undefined-global
local Trace = require("devtools.adventure-art-trace")
local Paper = require("shared.components.story-paper")
local Fact = require("modules.dialogue.fun-fact")
local Dialogue = require("modules.dialogue.init")
local Renderer = require("pages.adventure.rendering.adventure-renderer")
local Art = require("shared.constants.art")
local UI = require("urhox-libs/UI")
local Health = require("shared.components.health-advisory")
local vg_, images_, portrait_, speakerX_, largeCircles_, inside_ = nil, nil, nil, nil, 0, false
local completed_ = 0
local last_, card_, paragraph_, ruleY_, button_, screen_ = nil, nil, nil, nil, nil, nil
local realCard, realParagraph, realRule, realButton = Paper.card, Paper.paragraph, Paper.rule, Paper.button
Paper.card = function(vg,x,y,w,h)
    if inside_ then card_ = {x=x,y=y,w=w,h=h} end
    return realCard(vg,x,y,w,h)
end
Paper.paragraph = function(vg,face,x,y,value,size,lineHeight)
    if inside_ then paragraph_ = {x=x,y=y,text=value,h=Paper.lineCount(value)*lineHeight} end
    return realParagraph(vg,face,x,y,value,size,lineHeight)
end
Paper.rule = function(vg,x,y,w)
    if inside_ then ruleY_ = y end
    return realRule(vg,x,y,w)
end
Paper.button = function(vg,face,x,y,w,h,label)
    if inside_ then button_ = {x=x,y=y,w=w,h=h} end
    return realButton(vg,face,x,y,w,h,label)
end
local function checkBounds(label, isFact)
    V.assert(last_ and last_.card and last_.paragraph, label .. "已有实际绘制")
    if not last_ or not last_.card or not last_.paragraph then return end
    local c,p = last_.card,last_.paragraph
    V.assert(c.x >= 12 and c.x+c.w <= last_.w-12, label .. "左右留白且不出界")
    V.assert(c.y >= 12 and c.y+c.h <= last_.h-12, label .. "上下在屏内")
    V.assert(p.y+p.h <= (isFact and last_.button.y or last_.ruleY)-10, label .. "正文不撞底部操作")
    V.assert(last_.circles == 0, label .. "没有圆形头像框")
    if isFact then V.assert(last_.button.h >= 52, "知识卡按钮满足小屏点击尺寸") end
end
local function observe(render)
    return function(vg,w,h)
        inside_, card_, paragraph_, ruleY_, button_, largeCircles_ = true,nil,nil,nil,nil,0
        render(vg,w,h)
        if card_ then last_ = {card=card_,paragraph=paragraph_,ruleY=ruleY_,button=button_,circles=largeCircles_,w=w,h=h} end
        inside_ = false
    end
end
local realMap = Renderer.renderMap
Renderer.renderMap = function(vg, w, h, t, page, images, hits, cache, state)
    vg_, images_ = vg, images
    return realMap(vg, w, h, t, page, images, hits, cache, state)
end
local realCircle, realPattern, realText = nvgCircle, nvgImagePattern, nvgText
nvgCircle = function(vg, x, y, r)
    if inside_ and r > 10 then largeCircles_ = largeCircles_ + 1 end
    return realCircle(vg, x, y, r)
end
nvgImagePattern = function(vg, x, y, w, h, angle, image, alpha)
    if inside_ then portrait_ = {x=x, y=y, w=w, h=h} end
    return realPattern(vg, x, y, w, h, angle, image, alpha)
end
nvgText = function(vg, x, y, text)
    if inside_ and (text == "慧慧" or text == "火火") then speakerX_ = x end
    return realText(vg, x, y, text)
end
local realRender = observe(Dialogue.render)
Dialogue.render = function(vg, w, h)
    inside_, portrait_, speakerX_, largeCircles_ = true, nil, nil, 0
    if Dialogue.isActive() then Trace.begin() end
    realRender(vg, w, h)
    if Dialogue.isActive() then Trace.finish(w,h,true) end
    inside_ = false
end
local realFact = observe(Fact.render)
Fact.render = function(vg,w,h)
    if Fact.isActive() then Trace.begin() end
    realFact(vg,w,h)
    if Fact.isActive() then Trace.finish(w,h,true) end
end
local opts_, dismisses_, shows_, sounds_ = nil,0,0,0
V.atFrame(25, function()
    Health.update(6)
    local splash = UI.GetRoot():FindById("splash-screen")
    if splash then splash.props.onClick() end
    V.assert(vg_ ~= nil and images_ ~= nil, "真实地图提供有效纹理上下文")
    opts_ = {npcImages=images_,foxImage=nvgCreateImage(vg_, Art.characters.fox, 0),fontName="adv"}
    Trace.request()
    Dialogue.start({{speaker="慧慧", text="欢迎来到慧慧花园！我是慧慧。"},
        {speaker="火火", text="一起出发吧！"}}, {
        npcImages=images_, foxImage=nvgCreateImage(vg_, Art.characters.fox, 0), fontName="adv",
        onComplete=function() completed_ = completed_ + 1 end,
    })
end)
V.atFrame(30, function() Dialogue.update(10); Trace.request() end)
V.atFrame(40, function()
    V.assert(portrait_ ~= nil, "NPC 完整图片已绘制")
    V.assert(largeCircles_ == 0, "NPC 区无圆形头像底框或圆形描边")
    if portrait_ then
        V.assert(math.abs(portrait_.w - portrait_.h) < 0.01, "方形透明角色纹理没有被拉伸")
        V.assert(speakerX_ and speakerX_ > portrait_.x + portrait_.w, "NPC 台词区仍在立绘右侧")
    end
    checkBounds("NPC 对话",false)
    Dialogue.handleClick()
    Dialogue.handleClick()
end)
V.atFrame(60, function()
    V.assert(portrait_ ~= nil, "主角完整图片已绘制")
    V.assert(largeCircles_ == 0, "主角同样不使用圆形头像框")
    if portrait_ then V.assert(speakerX_ and speakerX_ < portrait_.x, "主角原有右侧立绘布局保留") end
    Dialogue.handleClick()
    Dialogue.handleClick()
    V.assert(not Dialogue.isActive(), "点击仍可结束对话")
    V.assert(completed_ == 1, "完成回调只执行一次")
end)
V.atFrame(75, function()
    local tall = nvgCreateImage(vg_, Art.splashBackground, 0)
    Dialogue.start({{speaker="慧慧",text="非方形素材保持原比例。"}}, {npcImages={owl=tall},fontName="adv"})
end)
V.atFrame(90, function()
    V.assert(portrait_ ~= nil and portrait_.h > portrait_.w, "竖向纹理按 contain 方式绘制")
    if portrait_ then
        V.assert(math.abs(portrait_.w / portrait_.h - 9 / 20) < 0.001, "立绘保持源图9:20宽高比")
    end
    Dialogue.stop()
    -- 相同索引、相同宽度的新段落，先 update 再 render，不能沿用旧文本缓存。
    Dialogue.start({{speaker="慧慧",text="新的段落不会沿用前一段的换行缓存。"}},opts_)
    Dialogue.update(10)
end)
V.atFrame(100,function()
    V.assert(last_ and last_.paragraph.text:gsub("\n","") == "新的段落不会沿用前一段的换行缓存。", "同索引新对话没有串台词")
    Dialogue.start({{speaker="慧慧",text=string.rep("把箱子推到星星上，仔细观察再行动！",5)},
        {speaker="火火",text="准备好了，出发！"}}, opts_)
    Dialogue.handleClick()
    Trace.request()
end)
V.atFrame(115,function()
    checkBounds("长台词",false)
    Dialogue.handleClick()
    Dialogue.update(10)
end)
V.atFrame(125,function()
    V.assert(last_.paragraph.text:gsub("\n","") == "准备好了，出发！", "推进后在首帧更新也不使用旧行缓存")
    checkBounds("主角对话",false)
    Dialogue.stop()
    Fact.show({speaker="慧慧",text="猫头鹰的脖子可以转动270度哦！"},{npcImages=images_,fontName="adv",
        onDismiss=function() dismisses_=dismisses_+1 end,
        onShow=function() shows_=shows_+1 end,
        onDismissSound=function() sounds_=sounds_+1 end})
    Fact.update(1)
    Trace.request()
end)
V.atFrame(140,function()
    checkBounds("小知识",true)
    V.assert(shows_ == 1,"小知识显示音效只触发一次")
    Fact.handleClick(0,0)
    V.assert(not Fact.isActive() and dismisses_ == 1 and sounds_ == 1,"点击遮罩仍关闭且回调与音效各执行一次")
    V.assert(not Fact.handleClick(0,0) and dismisses_ == 1,"关闭后不重复消费点击")
    Fact.show({speaker="火火",text=string.rep("森林里的动物各有自己的小本领，和朋友一起发现吧！",5)},opts_)
    Fact.update(1)
end)
V.atFrame(155,function()
    checkBounds("长知识文案",true)
    Fact.stop()
    V.assert(not Fact.isActive(),"离开页面可清除小知识")
    V.finish()
end)
