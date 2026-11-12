--- 屏幕转场组件
--- 全屏暖纸色遮罩 UI Panel，支持淡入/淡出动画
--- 调用方需在 PostUpdate 等不冲突的事件中调用 M.update(dt)
local UI = require("urhox-libs/UI")
local ANIM = require("shared.constants.animations")

local M = {}
local PAPER = require("shared.constants.art").colors.paper

---@type any
local overlay_ = nil
local alpha_ = 0
local targetAlpha_ = 0
local speed_ = 0         -- alpha/秒
local onComplete_ = nil
local animating_ = false

--- 默认转场时长
M.DURATION = ANIM.DURATION_TRANSITION

--- 创建转场遮罩（需添加到 UI 根节点最上层）
---@return any UI 节点
function M.create()
    overlay_ = UI.Panel {
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
    overlay_:SetVisible(true)
    overlay_:SetStyle({ backgroundColor = { PAPER[1], PAPER[2], PAPER[3], 255 } })
end

--- 每帧更新（由外部 PostUpdate 事件调用）
---@param dt number 帧间隔
function M.update(dt)
    if not animating_ or not overlay_ then return end

    local step = speed_ * dt
    if targetAlpha_ > alpha_ then
        alpha_ = math.min(alpha_ + step, 255)
    else
        alpha_ = math.max(alpha_ - step, 0)
    end

    local a = math.floor(alpha_)
    overlay_:SetStyle({ backgroundColor = { PAPER[1], PAPER[2], PAPER[3], a } })

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
        M.fadeOut(d)
    end)
end

return M
