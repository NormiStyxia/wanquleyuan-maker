--- 未成年人游戏时间限制模块（渲染层）
--- 职责：检查防沉迷状态并渲染 NanoVG 遮罩
--- 实际限制逻辑由 anti-addiction.lua 统一管理
local antiAddiction = require("shared.anti-addiction")

local Paper=require("shared.components.game-paper")
local Sprites=require("shared.rendering.piece-sprites")
local M = {}

--- 检查当前是否处于受限状态（宵禁或时长锁定）
--- 成年人始终返回 false
---@return boolean true=当前受限
function M.isRestricted()
    local allowed, _ = antiAddiction.canEnterGame()
    return not allowed
end

--- 获取拦截原因
---@return string|nil "curfew"|"time_limit"|nil
function M.getBlockReason()
    return antiAddiction.getBlockReason()
end

--- 在 NanoVG 上下文中绘制受限状态遮罩提示
--- 根据不同的拦截原因显示不同提示文案
---@param vg userdata NanoVG 上下文
---@param screenW number 逻辑宽度
---@param screenH number 逻辑高度
---@param fontName string 字体名称（需已创建）
---@param t number 动画时间（用于呼吸动画）
function M.renderOverlay(vg, screenW, screenH, fontName, t)
    if not M.isRestricted() then return end
    local reason=M.getBlockReason()
    local title,subtitle,timeInfo
    if reason=="time_limit" then
        title="今天玩够啦！"
        subtitle="你已经玩了 60 分钟，今天要先休息了哦！"
        timeInfo="明天再来吧"
    else
        title="现在不能玩哦"
        subtitle="未成年人每日\n20:00 至次日 08:00\n不能进入游戏"
        timeInfo="当前北京时间 "..antiAddiction.getBeijingTimeStr()
    end
    local remaining
    if reason==nil and not antiAddiction.isAdult() then
        local value=antiAddiction.getRemainingMin()
        if value<999 then remaining="剩余可玩时间："..value.." 分钟" end
    end
    nvgSave(vg)
    nvgBeginPath(vg);nvgRect(vg,0,0,screenW,screenH)
    nvgFillColor(vg,nvgRGBA(63,56,36,120));nvgFill(vg)
    local w=math.min(420,screenW-40)
    local rows=Paper.wrap(vg,subtitle,15,w-36,fontName)
    local h=192+#rows*21+(remaining and 24 or 0)
    local x,y=(screenW-w)/2,(screenH-h)/2
    Paper.panel(vg,x,y,w,h)
    Sprites.draw(vg,"leaf",screenW/2,y+38+math.sin((t or 0)*1.6)*1.5,50)
    Paper.text(vg,screenW/2,y+84,title,23,nil,nil,fontName)
    for i,row in ipairs(rows) do
        Paper.text(vg,screenW/2,y+116+(i-1)*21,row,15,Paper.colors.muted,nil,fontName)
    end
    local footer=y+h-(remaining and 62 or 38)
    nvgBeginPath(vg);nvgMoveTo(vg,x+24,footer-20);nvgLineTo(vg,x+w-24,footer-20)
    nvgStrokeColor(vg,nvgRGBA(221,207,166,255));nvgStrokeWidth(vg,1.5);nvgStroke(vg)
    Paper.text(vg,screenW/2,footer,timeInfo,14,Paper.colors.ink,nil,fontName)
    if remaining then Paper.text(vg,screenW/2,footer+24,remaining,13,Paper.colors.muted,nil,fontName) end
    nvgRestore(vg)
    return {x=x,y=y,w=w,h=h}
end

function M.cleanup(vg) Sprites.release(vg) end
return M
