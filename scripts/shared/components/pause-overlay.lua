--- 暂停菜单 NanoVG 覆盖层（全局共享，暖色调风格）
--- 职责：暂停时绘制半透明遮罩 + 卡片 + 继续/返回按钮
--- 接口：draw(vg, screenW, screenH) → buttons, hitTest(mx, my, buttons) → action

local Paper=require("shared.components.game-paper")
local M={}

--- 绘制暂停菜单
---@param vg userdata
---@param screenW number
---@param screenH number
---@return table[] buttons { { x, y, w, h, action } }
function M.draw(vg,screenW,screenH)
    local w,h=math.min(280,screenW-32),260
    local x,y=(screenW-w)/2,(screenH-h)/2
    nvgBeginPath(vg); nvgRect(vg,0,0,screenW,screenH)
    nvgFillColor(vg,nvgRGBA(63,56,36,120)); nvgFill(vg)
    Paper.panel(vg,x,y,w,h)
    Paper.text(vg,screenW/2,y+40,"游戏暂停",25)
    Paper.text(vg,screenW/2,y+76,"歇一会儿，再继续",14,Paper.colors.muted)
    local hits={}
    for i,def in ipairs({{"继续游戏","resume"},{"退出关卡","exit"}}) do
        local bx,by,bw=x+24,y+112+(i-1)*62,w-48
        Paper.button(vg,bx,by,bw,48,def[1],i==1,true)
        hits[i]={x=bx,y=by,w=bw,h=48,action=def[2]}
    end
    return hits
end

--- 检测点击命中
---@param mx number
---@param my number
---@param buttons table[]
---@return string|nil action "resume" | "exit" | nil
function M.hitTest(mx, my, buttons)
    if not buttons then return nil end
    for _, btn in ipairs(buttons) do
        if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
            return btn.action
        end
    end
    return nil
end

return M
