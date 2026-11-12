--- 暂停菜单 NanoVG 覆盖层（全局共享，暖色调风格）
--- 职责：暂停时绘制半透明遮罩 + 卡片 + 继续/返回按钮
--- 接口：draw(vg, screenW, screenH) → buttons, hitTest(mx, my, buttons) → action

local Paper=require("shared.components.game-paper")
local Sprites=require("shared.rendering.piece-sprites")
local M={}

local lastDrawAt_ = -10
local openAt_ = 0

--- 绘制暂停菜单
---@param vg userdata
---@param screenW number
---@param screenH number
---@return table[] buttons { { x, y, w, h, action } }
function M.draw(vg,screenW,screenH)
    local now = GetTime and GetTime():GetElapsedTime() or 1
    if now - lastDrawAt_ > 0.12 then
        openAt_ = now
    end
    lastDrawAt_ = now
    local age = math.max(0, now - openAt_)
    local p = math.min(1, age / 0.22)
    -- EaseOutBack 弹窗弹簧缩放
    local c1 = 1.70158
    local tm1 = p - 1
    local spring = p >= 1 and 1 or (1 + (c1 + 1) * tm1 * tm1 * tm1 + c1 * tm1 * tm1)
    local scale = 0.90 + 0.10 * spring

    local w,h=math.min(286,screenW-32),316
    local x,y=(screenW-w)/2,(screenH-h)/2
    local cx, cy = screenW / 2, screenH / 2

    nvgBeginPath(vg); nvgRect(vg,0,0,screenW,screenH)
    nvgFillColor(vg,nvgRGBA(63,56,36,math.floor(120 * math.min(1, p * 1.4)))); nvgFill(vg)

    nvgSave(vg)
    nvgTranslate(vg, cx, cy)
    nvgScale(vg, scale, scale)
    nvgTranslate(vg, -cx, -cy)

    Paper.panel(vg,x,y,w,h)
    local bobY = math.sin(now * 3.2) * 2.2
    Sprites.drawUI(vg, "fox-rest", screenW / 2, y + 48 + bobY, 72, 72, 1.0)
    Paper.text(vg,screenW/2,y+98,"游戏暂停",24)
    Paper.text(vg,screenW/2,y+128,"歇一会儿，喝口茶再继续~",14,Paper.colors.muted)
    local hits={}
    for i,def in ipairs({{"继续游戏","resume"},{"退出关卡","exit"}}) do
        local bx,by,bw=x+24,y+164+(i-1)*60,w-48
        Paper.button(vg,bx,by,bw,48,def[1],i==1,true)
        hits[i]={x=bx,y=by,w=bw,h=48,action=def[2]}
    end
    nvgRestore(vg)
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
