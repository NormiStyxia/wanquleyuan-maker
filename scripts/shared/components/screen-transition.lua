--- 屏幕转场与界面衔接动效组件
--- 支持 UI 层与独立 NanoVG 上下文顶层手绘云朵帷幕 + 跳跃小狐狸徽章转场，以及新页面进场弹簧衔接
local UI = require("urhox-libs/UI")
local ANIM = require("shared.constants.animations")
local Art = require("shared.constants.art")
local Pen = require("shared.components.handdrawn")
local Sprites = require("shared.rendering.piece-sprites")

local M = {}
local C = Art.colors
local PAPER = C.paper

---@type any
local overlay_ = nil
local alpha_ = 0
local targetAlpha_ = 0
local speed_ = 0         -- alpha/秒
local onComplete_ = nil
local animating_ = false
local animClock_ = 0
local enterAge_ = 10.0   -- 距离最近一次界面切换完成的时间（秒），初始设为已完成
local ENTER_DURATION = 0.36

--- 默认转场时长
M.DURATION = ANIM.DURATION_TRANSITION

--- 绘制手绘四角星点缀
local function drawSparkle(vg, cx, cy, r, rot, color, alpha)
    if r <= 0.5 or alpha <= 0.01 then return end
    nvgSave(vg)
    nvgTranslate(vg, cx, cy)
    nvgRotate(vg, rot or 0)
    nvgGlobalAlpha(vg, alpha)
    nvgBeginPath(vg)
    for i = 0, 7 do
        local rad = (i % 2 == 0) and r or (r * 0.38)
        local ang = i * math.pi / 4
        local px = math.cos(ang) * rad
        local py = math.sin(ang) * rad
        if i == 0 then nvgMoveTo(vg, px, py) else nvgLineTo(vg, px, py) end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], 255))
    nvgFill(vg)
    nvgStrokeColor(vg, Pen.color(C.ink))
    nvgStrokeWidth(vg, math.max(1.2, r * 0.16))
    nvgLineJoin(vg, NVG_ROUND)
    nvgStroke(vg)
    nvgRestore(vg)
end

--- 在给定 NanoVG 上下文绘制手绘转场帷幕与跳跃小狐狸
---@param vg userdata
---@param screenW number
---@param screenH number
function M.renderNanoVG(vg, screenW, screenH)
    if not animating_ or alpha_ <= 1 or not vg then return end
    local p = math.max(0, math.min(1, alpha_ / 255))
    local ep = p * p * (3 - 2 * p)

    nvgSave(vg)

    -- 1. 柔和暖纸底幕
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(PAPER[1], PAPER[2], PAPER[3], math.floor(ep * 246)))
    nvgFill(vg)

    -- 2. 上下双向聚拢的手绘波浪云朵帷幕
    local curtainSlide = (1 - ep) * 110
    local topY = -curtainSlide
    local botY = screenH + curtainSlide
    local puffs = 6
    local puffStep = screenW / (puffs - 1)
    nvgGlobalAlpha(vg, ep)

    -- 顶部暖黄底衬与云朵波浪
    nvgBeginPath(vg)
    nvgRect(vg, 0, topY - 40, screenW, 92)
    nvgFillColor(vg, nvgRGBA(244, 229, 192, 255))
    nvgFill(vg)
    for i = 0, puffs - 1 do
        local px = i * puffStep
        local py = topY + 46 + math.sin(animClock_ * 5 + i * 1.1) * 4
        local pr = puffStep * 0.46
        Pen.circle(vg, px, py, pr, { 244, 229, 192, 255 }, 2.2, C.ink)
    end

    -- 底部暖黄底衬与云朵波浪
    nvgBeginPath(vg)
    nvgRect(vg, 0, botY - 52, screenW, 92)
    nvgFillColor(vg, nvgRGBA(244, 229, 192, 255))
    nvgFill(vg)
    for i = 0, puffs - 1 do
        local px = i * puffStep
        local py = botY - 46 + math.cos(animClock_ * 5 + i * 1.1) * 4
        local pr = puffStep * 0.46
        Pen.circle(vg, px, py, pr, { 244, 229, 192, 255 }, 2.2, C.ink)
    end

    -- 两侧飘入的手绘花草云朵插画
    local cloudSlide = (1 - ep) * 90
    Sprites.drawUI(vg, "transition-cloud", 68 - cloudSlide, topY + 74, 132, 88, ep * 0.95)
    Sprites.drawUI(vg, "transition-cloud", screenW - 68 + cloudSlide, botY - 74, 132, 88, ep * 0.95)

    -- 3. 中央弹簧弹出的跳跃小狐狸圆章与环绕星点
    if ep > 0.08 then
        local cx, cy = screenW * 0.5, screenH * 0.48
        -- 弹簧缩放曲线：快速弹出并微幅回弹
        local badgeScale = 0.45 + 0.62 * math.sin(math.min(1, ep * 1.15) * math.pi * 0.58)
        local hopY = -math.abs(math.sin(animClock_ * 9.5)) * 8 * ep
        local tilt = math.sin(animClock_ * 11.0) * 0.06

        nvgSave(vg)
        nvgTranslate(vg, cx, cy + hopY)
        nvgScale(vg, badgeScale, badgeScale)

        -- 外圈柔和光晕环与旋转小星星
        Pen.circle(vg, 0, 0, 74, { 255, 238, 196, 220 }, 2.0, C.orange)
        Pen.circle(vg, 0, 0, 64, { 255, 250, 234, 255 }, 2.6, C.ink)

        for i = 1, 6 do
            local ang = animClock_ * 2.2 + (i - 1) * (math.pi / 3)
            local orbitR = 84 + math.sin(animClock_ * 6 + i) * 4
            local sx = math.cos(ang) * orbitR
            local sy = math.sin(ang) * orbitR * 0.88
            local starCol = (i % 2 == 0) and C.orange or C.green
            drawSparkle(vg, sx, sy, (i % 2 == 0) and 8.5 or 6.5, ang * 0.8, starCol, ep)
        end

        -- 欢快跳跃的小狐狸手绘插画
        nvgSave(vg)
        nvgRotate(vg, tilt)
        if not Sprites.drawUI(vg, "transition-fox", 0, -4, 128, 128, ep) then
            Pen.circle(vg, 0, -4, 36, C.orange, 2.5, C.ink)
        end
        nvgRestore(vg)

        -- 底部活泼手绘铭牌
        Pen.texturedPlaque(vg, -54, 52, 108, 28, C.orange, 2.2, { radius = 14 })
        local dots = string.rep(".", (math.floor(animClock_ * 6) % 3) + 1)
        Pen.text(vg, 0, 66, "出发喽" .. dots, 14, C.ink)

        nvgRestore(vg)
    end

    nvgRestore(vg)
end

---@class ScreenTransitionOverlay : Panel
local ScreenTransitionOverlay = UI.Panel:Extend("ScreenTransitionOverlay")
function ScreenTransitionOverlay:Render(vg)
    if not animating_ or alpha_ <= 1 then return end
    local w, h = UI.GetViewportSize()
    if w > 0 and h > 0 then
        M.renderNanoVG(vg, w, h)
    end
end

--- 创建转场遮罩（需添加到 UI 根节点最上层）
---@return any UI 节点
function M.create()
    overlay_ = ScreenTransitionOverlay {
        position = "absolute",
        left = 0, top = 0,
        width = "100%",
        height = "100%",
        backgroundColor = { PAPER[1], PAPER[2], PAPER[3], 0 },
    }
    overlay_:SetVisible(false)
    alpha_ = 0
    animating_ = false
    return overlay_
end

--- 通知新页面或子界面进入（触发新界面元素的弹簧进场衔接动效）
function M.notifyPageEnter()
    enterAge_ = 0.0
end

--- 获取新界面进场动效进度（0~1，1 表示已完全落定）
---@return number
function M.getEnterProgress()
    if enterAge_ >= ENTER_DURATION then return 1.0 end
    return math.max(0.0, math.min(1.0, enterAge_ / ENTER_DURATION))
end

--- 获取带错峰延迟的界面元素弹簧进场参数（供标题、卡片、棋盘、关卡格调用）
---@param delay number|nil 错峰延迟秒数（默认 0）
---@param duration number|nil 持续秒数（默认 0.28）
---@return number offsetY, number scale, number alpha
function M.getEnterSpring(delay, duration)
    delay = delay or 0
    duration = duration or 0.28
    if enterAge_ >= delay + duration then
        return 0.0, 1.0, 1.0
    end
    local t = math.max(0.0, math.min(1.0, (enterAge_ - delay) / math.max(0.01, duration)))
    -- EaseOutBack 弹簧曲线
    local c1 = 1.70158
    local c3 = c1 + 1.0
    local tm1 = t - 1.0
    local spring = 1.0 + c3 * tm1 * tm1 * tm1 + c1 * tm1 * tm1
    local offsetY = (1.0 - spring) * 18.0
    local scale = 0.92 + 0.08 * spring
    local alpha = math.min(1.0, t * 1.6)
    return offsetY, scale, alpha
end

--- 淡入（屏幕覆盖暖纸色）
---@param duration number 持续时间（秒）
---@param onComplete function|nil 完成回调
function M.fadeIn(duration, onComplete)
    if not overlay_ then return end
    duration = duration or ANIM.DURATION_HOVER
    alpha_ = 0
    targetAlpha_ = 255
    speed_ = 255 / math.max(duration, 0.01)
    onComplete_ = onComplete
    animating_ = true
    overlay_:SetVisible(true)
    overlay_:SetStyle({ backgroundColor = { PAPER[1], PAPER[2], PAPER[3], 0 } })
end

--- 淡出（屏幕恢复）
---@param duration number 持续时间（秒）
---@param onComplete function|nil 完成回调
function M.fadeOut(duration, onComplete)
    if not overlay_ then return end
    duration = duration or ANIM.DURATION_HOVER
    alpha_ = 255
    targetAlpha_ = 0
    speed_ = 255 / math.max(duration, 0.01)
    onComplete_ = onComplete
    animating_ = true
    enterAge_ = 0.0
    overlay_:SetVisible(true)
    overlay_:SetStyle({ backgroundColor = { PAPER[1], PAPER[2], PAPER[3], 0 } })
end

--- 每帧更新（由外部 PostUpdate 事件调用）
---@param dt number 帧间隔
function M.update(dt)
    animClock_ = animClock_ + dt
    if enterAge_ < 10.0 then
        enterAge_ = enterAge_ + dt
    end
    if not animating_ or not overlay_ then return end

    local step = speed_ * dt
    if targetAlpha_ > alpha_ then
        alpha_ = math.min(alpha_ + step, 255)
    else
        alpha_ = math.max(alpha_ - step, 0)
    end

    -- 到达目标
    if (targetAlpha_ > 0 and alpha_ >= 255) or (targetAlpha_ == 0 and alpha_ <= 0) then
        animating_ = false
        if targetAlpha_ == 0 then
            overlay_:SetVisible(false)
        end
        if onComplete_ then
            local cb = onComplete_
            onComplete_ = nil
            cb()
        end
    end
end

--- 是否正在动画中
---@return boolean
function M.isAnimating()
    return animating_
end

--- 便捷方法：fadeIn → 执行操作 → fadeOut
---@param midCallback function 屏幕完全覆盖时执行的操作
---@param duration number|nil 单程时长（默认 M.DURATION）
function M.run(midCallback, duration)
    if animating_ then return end
    local d = duration or M.DURATION
    M.fadeIn(d, function()
        if midCallback then
            local ok, err = pcall(midCallback)
            if not ok then
                print("[ScreenTransition] midCallback error: " .. tostring(err))
            end
        end
        M.notifyPageEnter()
        M.fadeOut(d)
    end)
end

return M
