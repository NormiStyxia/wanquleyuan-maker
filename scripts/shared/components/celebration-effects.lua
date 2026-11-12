--- 庆祝特效 - 共享模块
--- 职责：烟花 + 彩带 + 弹窗弹性动画的通用实现
--- 供 P2 记忆翻牌、P3 消消乐等游戏复用

local Art=require("shared.constants.art")
local M = {}

-- ============================================================================
-- HSV 转 RGB
-- ============================================================================

function M.hsvToRgb(h, s, v)
    local c = v * s
    local x = c * (1 - math.abs((h / 60) % 2 - 1))
    local m = v - c
    local r, g, b = 0, 0, 0
    if h < 60 then r, g, b = c, x, 0
    elseif h < 120 then r, g, b = x, c, 0
    elseif h < 180 then r, g, b = 0, c, x
    elseif h < 240 then r, g, b = 0, x, c
    elseif h < 300 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end
    return math.floor((r + m) * 255), math.floor((g + m) * 255), math.floor((b + m) * 255)
end

-- ============================================================================
-- 创建庆祝实例
-- ============================================================================

--- 创建庆祝特效状态
---@param screenW number
---@param screenH number
---@param opts table|nil 可选配置
---   opts.fireworkCount number 烟花数量（默认 4）
---   opts.confettiCount number 彩带数量（默认 30）
---   opts.enableRankAnim boolean 是否包含评级弹出动画（默认 false）
---   opts.elasticStyle string "sin"|"step" 弹窗弹性风格（默认 "sin"）
---@return table celebration
function M.create(screenW, screenH, opts)
    opts = opts or {}
    local fwCount = math.min(3,opts.fireworkCount or 3)
    local confettiCount = math.min(24,opts.confettiCount or 22)
    local elasticStyle = opts.elasticStyle or "sin"

    local cel = {
        elapsed = 0,
        fireworks = {},
        confetti = {},
        dialogScale = 0,
        dialogAlpha = 0,
        elasticStyle = elasticStyle,
    }

    -- 评级弹出动画（P2 记忆翻牌专用）
    if opts.enableRankAnim then
        cel.rankAnim = { delay = 0.3, scale = 0, alpha = 0, rotation = 0 }
    end

    -- 生成烟花
    for i = 1, fwCount do
        local fw = {
            active = true,
            x = 0.15 + 0.7 * ((i - 1) / math.max(1, fwCount - 1)),
            y = 0.15 + math.random() * 0.25,
            elapsed = -0.15 * (i - 1),
            duration = 0.8 + math.random() * 0.3,
            sparks = {},
        }
        local sparkCount = 12 + math.random(8)
        for j = 1, sparkCount do
            local angle = (j / sparkCount) * math.pi * 2
            local hue = (j * 30 + i * 60) % 360
            local color=({Art.colors.orange,Art.colors.green,Art.colors.track})[(j%3)+1]
            local r,g,b=color[1],color[2],color[3]
            fw.sparks[j] = {
                angle = angle + (math.random() - 0.5) * 0.3,
                speed = 40 + math.random() * 50,
                size = 2 + math.random() * 2,
                r = r, g = g, b = b,
            }
        end
        cel.fireworks[i] = fw
    end

    -- 生成彩带
    for i = 1, confettiCount do
        local hue = math.random(360)
        local color=({Art.colors.orange,Art.colors.green,Art.colors.track})[(i%3)+1]
        local r,g,b=color[1],color[2],color[3]
        cel.confetti[i] = {
            x = math.random() * screenW,
            y = -20 - math.random() * 100,
            width = 4 + math.random() * 5,
            height = 8 + math.random() * 6,
            rotation = math.random() * math.pi * 2,
            rotSpeed = (math.random() - 0.5) * 8,
            fallSpeed = 50 + math.random() * 80,
            swaySpeed = 1 + math.random() * 2,
            swayAmp = 10 + math.random() * 20,
            alpha = 0.8 + math.random() * 0.2,
            r = r, g = g, b = b,
            phase = math.random() * math.pi * 2,
        }
    end

    return cel
end

-- ============================================================================
-- 更新
-- ============================================================================

--- 更新庆祝特效状态
---@param cel table 庆祝实例
---@param dt number
function M.update(cel, dt)
    if not cel then return end
    cel.elapsed = cel.elapsed + dt

    -- 弹窗弹性出现
    if cel.elasticStyle == "sin" then
        -- P3 风格：sin-based elastic
        local popDelay = 0.3
        if cel.elapsed > popDelay then
            local t = math.min(1, (cel.elapsed - popDelay) / 0.4)
            local p = 0.3
            cel.dialogScale = 1 + (2 ^ (-10 * t)) * math.sin((t - p / 4) * (2 * math.pi) / p) * 0.15
            if t >= 0.8 then cel.dialogScale = 1.0 end
            cel.dialogAlpha = math.min(1, t / 0.3)
        end
    else
        -- P2 风格：step-based elastic
        local dialogT = math.min(1, cel.elapsed / 0.4)
        if dialogT < 0.6 then
            cel.dialogScale = (dialogT / 0.6) * 1.15
        elseif dialogT < 0.8 then
            local bt = (dialogT - 0.6) / 0.2
            cel.dialogScale = 1.15 - 0.15 * bt
        else
            local bt = (dialogT - 0.8) / 0.2
            cel.dialogScale = 1.0 + 0.02 * math.sin(bt * math.pi)
        end
        cel.dialogAlpha = math.min(1, cel.elapsed / 0.25)
    end

    -- 评级弹出动画
    if cel.rankAnim then
        local ra = cel.rankAnim
        local rt = cel.elapsed - ra.delay
        if rt > 0 then
            local t = math.min(1, rt / 0.35)
            if t < 0.5 then
                ra.scale = (t / 0.5) * 1.4
                ra.rotation = (1 - t / 0.5) * 0.3
            elseif t < 0.75 then
                local bt = (t - 0.5) / 0.25
                ra.scale = 1.4 - 0.5 * bt
                ra.rotation = -0.1 * (1 - bt)
            else
                local bt = (t - 0.75) / 0.25
                ra.scale = 0.9 + 0.1 * bt
                ra.rotation = 0
            end
            ra.alpha = math.min(1, rt / 0.1)
        end
    end

    -- 更新烟花
    for _, fw in ipairs(cel.fireworks) do
        if fw.active then
            fw.elapsed = fw.elapsed + dt
            if fw.elapsed > fw.duration then
                fw.active = false
            end
        end
    end

    -- 更新彩带
    for _, c in ipairs(cel.confetti) do
        c.y = c.y + c.fallSpeed * dt
        c.x = c.x + math.sin(cel.elapsed * c.swaySpeed + c.phase) * c.swayAmp * dt
        c.rotation = c.rotation + c.rotSpeed * dt
        if c.y > 1000 then
            c.alpha = math.max(0, c.alpha - dt)
        end
    end
end

-- ============================================================================
-- 绘制
-- ============================================================================

--- 绘制单个烟花
---@param vg userdata
---@param fw table 烟花实例
---@param screenW number
---@param screenH number
---@param enableFlash boolean|nil 是否绘制中心闪光（默认 false）
function M.drawFirework(vg, fw, screenW, screenH, enableFlash)
    if not fw.active or fw.elapsed <= 0 then return end

    local t = math.min(1, fw.elapsed / fw.duration)
    local cx = fw.x * screenW
    local cy = fw.y * screenH

    for _, sp in ipairs(fw.sparks) do
        local dist = sp.speed * t
        local px = cx + math.cos(sp.angle) * dist
        local py = cy + math.sin(sp.angle) * dist + 30 * t * t

        local alpha = math.max(0, 1.0 - t * 1.2)
        local a = math.floor(alpha * 255)
        local size = sp.size * (1 - t * 0.5)

        if a > 5 and size > 0.5 then
            nvgBeginPath(vg)
            nvgCircle(vg, px, py, size)
            nvgFillColor(vg, nvgRGBA(sp.r, sp.g, sp.b, a))
            nvgFill(vg)

            nvgBeginPath(vg)
            nvgCircle(vg, px, py, size * 2.5)
            nvgFillColor(vg, nvgRGBA(sp.r, sp.g, sp.b, math.floor(a * 0.2)))
            nvgFill(vg)
        end
    end

    -- 中心闪光（P2 风格）
    if enableFlash and t < 0.15 then
        local flashAlpha = math.floor((1 - t / 0.15) * 200)
        local flashR = 15 * (1 - t / 0.15)
        nvgBeginPath(vg)
        nvgCircle(vg, cx, cy, flashR)
        nvgFillColor(vg, nvgRGBA(255, 255, 220, flashAlpha))
        nvgFill(vg)
    end
end

--- 绘制所有烟花
---@param vg userdata
---@param cel table 庆祝实例
---@param screenW number
---@param screenH number
---@param enableFlash boolean|nil
function M.drawFireworks(vg, cel, screenW, screenH, enableFlash)
    if not cel then return end
    for _, fw in ipairs(cel.fireworks) do
        M.drawFirework(vg, fw, screenW, screenH, enableFlash)
    end
end

--- 绘制彩带
---@param vg userdata
---@param cel table 庆祝实例
---@param screenH number
function M.drawConfetti(vg, cel, screenH)
    if not cel then return end
    for _, c in ipairs(cel.confetti) do
        if c.y > screenH + 20 then goto nextC end
        local a = math.floor(c.alpha * 255)
        if a < 5 then goto nextC end

        nvgSave(vg)
        nvgTranslate(vg, c.x, c.y)
        nvgRotate(vg, c.rotation)

        nvgBeginPath(vg)
        nvgRect(vg, -c.width / 2, -c.height / 2, c.width, c.height)
        nvgFillColor(vg, nvgRGBA(c.r, c.g, c.b, a))
        nvgFill(vg)

        -- 折痕高光
        nvgBeginPath(vg)
        nvgRect(vg, -c.width / 2, -c.height / 2, c.width * 0.4, c.height)
        nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(a * 0.15)))
        nvgFill(vg)

        nvgRestore(vg)
        ::nextC::
    end
end

return M
