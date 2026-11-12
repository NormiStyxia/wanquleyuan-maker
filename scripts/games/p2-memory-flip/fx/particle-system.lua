--- 记忆翻牌 - 配对成功粒子特效系统
--- 职责：配对成功时的星光粒子、扩散环、连线闪光、弹跳缩放

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local M = {}

local MATCH_FX_DURATION = 0.7     -- 特效总时长（更持久）
local MATCH_FX_PARTICLE_COUNT = 6 -- 每张卡的星光粒子数（更多）
local MATCH_FX_RING_COUNT = 1     -- 扩散环数量（更多层）

---@type table[] 活跃的配对特效列表
local matchEffects_ = {}

--- 启动一次配对成功特效（两张卡的屏幕位置）
---@param cx1 number 卡牌1中心X（屏幕坐标）
---@param cy1 number 卡牌1中心Y
---@param cx2 number 卡牌2中心X
---@param cy2 number 卡牌2中心Y
---@param cardSize number 卡牌尺寸
---@param paletteColor userdata 图案颜色
function M.triggerMatchEffect(cx1, cy1, cx2, cy2, cardSize, paletteColor)
    -- 为两张卡各创建粒子和光环
    local positions = { { cx1, cy1 }, { cx2, cy2 } }
    local fx = {
        elapsed = 0,
        duration = MATCH_FX_DURATION,
        cardSize = cardSize,
        color = paletteColor,
        cards = {},
        -- 连线闪光
        line = { x1 = cx1, y1 = cy1, x2 = cx2, y2 = cy2 },
    }

    for _, pos in ipairs(positions) do
        local cardFx = {
            cx = pos[1], cy = pos[2],
            -- 扩散环
            rings = {},
            -- 星光粒子
            particles = {},
            -- 缩放弹跳
            scale = 1.0,
        }

        -- 初始化扩散环
        for i = 1, MATCH_FX_RING_COUNT do
            cardFx.rings[i] = {
                delay = (i - 1) * 0.05,
                radius = 0,
                alpha = 1.0,
            }
        end

        -- 初始化星光粒子
        for i = 1, MATCH_FX_PARTICLE_COUNT do
            local angle = (i - 1) / MATCH_FX_PARTICLE_COUNT * math.pi * 2 + (math.random() - 0.5) * 0.5
            cardFx.particles[i] = {
                angle = angle,
                speed = 60 + math.random() * 90,
                size = 3 + math.random() * 3.5,
                alpha = 1.0,
                -- 随机亮色（更鲜艳）
                r = 120 + math.random(135),
                g = 180 + math.random(75),
                b = 100 + math.random(155),
            }
        end

        fx.cards[#fx.cards + 1] = cardFx
    end

    matchEffects_[#matchEffects_ + 1] = fx
end

--- 更新配对特效
---@param dt number
function M.updateMatchEffects(dt)
    local i = 1
    while i <= #matchEffects_ do
        local fx = matchEffects_[i]
        fx.elapsed = fx.elapsed + dt

        if fx.elapsed >= fx.duration then
            -- 特效结束，移除
            matchEffects_[i] = matchEffects_[#matchEffects_]
            matchEffects_[#matchEffects_] = nil
        else
            local t = fx.elapsed / fx.duration

            for _, cardFx in ipairs(fx.cards) do
                -- 更新扩散环（更大范围）
                for _, ring in ipairs(cardFx.rings) do
                    local ringT = math.max(0, (fx.elapsed - ring.delay) / (fx.duration * 0.55))
                    ringT = math.min(1, ringT)
                    ring.radius = ringT * fx.cardSize * 0.85
                    ring.alpha = math.max(0, 1.0 - ringT * 1.3)
                end

                -- 更新粒子（更持久）
                for _, p in ipairs(cardFx.particles) do
                    p.alpha = math.max(0, 1.0 - t * 1.2)
                end

                -- 缩放弹跳（更明显）
                if t < 0.12 then
                    cardFx.scale = 1.0 + (t / 0.12) * 0.06  -- 放大到1.22
                elseif t < 0.3 then
                    local bt = (t - 0.12) / 0.18
                    cardFx.scale = 1.06 - 0.08 * bt           -- 缩回0.96
                elseif t < 0.45 then
                    local bt = (t - 0.3) / 0.15
                    cardFx.scale = 0.98 + 0.02 * bt            -- 回到1.0
                else
                    cardFx.scale = 1.0
                end
            end

            i = i + 1
        end
    end
end

--- 获取卡牌的配对弹跳缩放值
---@param cardCX number 卡牌中心X
---@param cardCY number 卡牌中心Y
---@return number scale 1.0=无特效
function M.getMatchBounceScale(cardCX, cardCY)
    for _, fx in ipairs(matchEffects_) do
        for _, cardFx in ipairs(fx.cards) do
            -- 用距离匹配（容差5像素）
            local dx = math.abs(cardFx.cx - cardCX)
            local dy = math.abs(cardFx.cy - cardCY)
            if dx < 5 and dy < 5 then
                return cardFx.scale
            end
        end
    end
    return 1.0
end

--- 绘制所有配对特效（在卡牌之上调用）
---@param vg userdata
function M.drawMatchEffects(vg)
    for _,fx in ipairs(matchEffects_) do
        local t = fx.elapsed/fx.duration
        for _,card in ipairs(fx.cards) do
            Paper.burst(vg,card.cx,card.cy,fx.cardSize,t)
        end
    end
end



--- 重置配对特效
function M.resetMatchEffects()
    matchEffects_ = {}
end

return M
