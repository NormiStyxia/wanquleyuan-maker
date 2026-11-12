--- 消消乐 - 粒子特效系统
--- 职责：消除粒子（散射/飞向分数/光束/冲击波/闪光）、冰块受伤特效、屏幕震动
--- 提取自 board-renderer.lua

local Board = require("games.p3-match-3.logic.board")

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local M = {}

-- ============================================================================
-- 方块配色（粒子颜色来源）
-- ============================================================================

local TILE_COLORS = {
    [1] = { 231, 76, 60 },     -- 红
    [2] = { 52, 152, 219 },    -- 蓝
    [3] = { 46, 204, 113 },    -- 绿
    [4] = { 241, 196, 15 },    -- 黄
    [5] = { 155, 89, 182 },    -- 紫
    [6] = { 255, 182, 193 },    -- 淡粉
}

local TILE_HIGHLIGHT = {
    [1] = { 255, 120, 100 },
    [2] = { 100, 185, 240 },
    [3] = { 100, 230, 155 },
    [4] = { 255, 225, 80 },
    [5] = { 190, 135, 215 },
    [6] = { 255, 210, 220 },
}

-- ============================================================================
-- 内部状态
-- ============================================================================

---@type table[] 活跃粒子列表
local particles_ = {}
---@type number 分数 UI 目标 X（粒子飞向此处）
local scoreTargetX_ = 300
---@type number 分数 UI 目标 Y
local scoreTargetY_ = 34

-- 屏幕震动
---@type number 震动剩余时间
local shakeTimer_ = 0
---@type number 震动强度
local shakeIntensity_ = 0
---@type number 当前帧偏移 X
local shakeOffX_ = 0
---@type number 当前帧偏移 Y
local shakeOffY_ = 0

-- 冰块受伤震动状态：key = row*100+col, value = { timer, intensity, destroyed }
---@type table<number, table>
local iceDamageFx_ = {}


-- ============================================================================
-- 公共 API
-- ============================================================================

--- 设置分数 UI 目标位置（粒子飞向此处）
---@param x number
---@param y number
function M.setScoreTarget(x, y)
    scoreTargetX_ = x
    scoreTargetY_ = y
end

--- 获取屏幕震动偏移（供外部渲染使用）
---@return number offX, number offY
function M.getShakeOffset()
    return shakeOffX_, shakeOffY_
end

--- 获取冰块受伤震动偏移
---@param r number 行
---@param c number 列
---@return number offX, number offY
function M.getIceShakeOffset(r, c)
    local fx = iceDamageFx_[r * 100 + c]
    if fx and fx.offX then
        return fx.offX, fx.offY
    end
    return 0, 0
end

function M.spawnElimParticles(cells, layout, getCellCenter)
    if not layout or not getCellCenter then return end
    local l = layout

    for _, c in ipairs(cells) do
        local cx, cy = getCellCenter(c.row, c.col)
        local color = TILE_COLORS[c.colorId] or { 150, 150, 150 }
        local hi = TILE_HIGHLIGHT[c.colorId] or { 200, 200, 200 }
        local special = c.special or Board.SPECIAL_NONE

        if special == Board.SPECIAL_LINE_H then
            -- ======== 横向激光束：沿整行发射光线粒子（更密集更亮） ========
            local startCx = l.x
            local endCx = l.x + l.totalW
            for i = 1, 8 do
                local px = startCx + (endCx - startCx) * ((i - 1) / 21)
                particles_[#particles_ + 1] = {
                    x = cx, y = cy,
                    vx = (px - cx) * 4.0,
                    vy = (math.random() - 0.5) * 50,
                    color = hi,
                    alpha = 1.0,
                    size = 6 + math.random() * 5,
                    elapsed = 0,
                    maxLife = 0.35 + math.random() * 0.15,
                    ptype = "burst",
                }
            end
            -- 水平光束线（更宽更亮）
            particles_[#particles_ + 1] = {
                x = l.x, y = cy,
                endX = l.x + l.totalW,
                color = hi,
                alpha = 1.0,
                size = l.cellSize * 0.9,
                elapsed = 0,
                maxLife = 0.4,
                ptype = "beam_h",
            }
            -- 中心闪光
            particles_[#particles_ + 1] = {
                x = cx, y = cy,
                color = { 255, 255, 220 },
                alpha = 1.0,
                size = l.cellSize * 0.3,
                elapsed = 0,
                maxLife = 0.2,
                ptype = "flash",
            }
            shakeTimer_ = 0.2
            shakeIntensity_ = 1.5

        elseif special == Board.SPECIAL_LINE_V then
            -- ======== 纵向激光束：沿整列发射光线粒子（更密集更亮） ========
            local startCy = l.y
            local endCy = l.y + l.totalH
            for i = 1, 8 do
                local py = startCy + (endCy - startCy) * ((i - 1) / 21)
                particles_[#particles_ + 1] = {
                    x = cx, y = cy,
                    vx = (math.random() - 0.5) * 50,
                    vy = (py - cy) * 4.0,
                    color = hi,
                    alpha = 1.0,
                    size = 6 + math.random() * 5,
                    elapsed = 0,
                    maxLife = 0.35 + math.random() * 0.15,
                    ptype = "burst",
                }
            end
            -- 垂直光束线（更宽更亮）
            particles_[#particles_ + 1] = {
                x = cx, y = l.y,
                endY = l.y + l.totalH,
                color = hi,
                alpha = 1.0,
                size = l.cellSize * 0.9,
                elapsed = 0,
                maxLife = 0.4,
                ptype = "beam_v",
            }
            -- 中心闪光
            particles_[#particles_ + 1] = {
                x = cx, y = cy,
                color = { 255, 255, 220 },
                alpha = 1.0,
                size = l.cellSize * 0.3,
                elapsed = 0,
                maxLife = 0.2,
                ptype = "flash",
            }
            shakeTimer_ = 0.2
            shakeIntensity_ = 1.5

        elseif special == Board.SPECIAL_BOMB then
            -- ======== 炸弹：大范围冲击波 + 密集散射（更震撼） ========
            -- 大冲击波环（双层）
            particles_[#particles_ + 1] = {
                x = cx, y = cy,
                color = { 255, 200, 50 },
                alpha = 1.0,
                size = 5,
                elapsed = 0,
                maxLife = 0.45,
                ptype = "shockwave",
            }
            particles_[#particles_ + 1] = {
                x = cx, y = cy,
                color = { 255, 120, 30 },
                alpha = 0.8,
                size = 5,
                elapsed = 0,
                delay = 0.06,
                maxLife = 0.5,
                ptype = "shockwave",
            }
            -- 内部大闪光
            particles_[#particles_ + 1] = {
                x = cx, y = cy,
                color = { 255, 255, 200 },
                alpha = 1.0,
                size = l.cellSize * 0.7,
                elapsed = 0,
                maxLife = 0.25,
                ptype = "flash",
            }
            -- 密集散射（28 个，更密集更亮）
            for i = 1, 10 do
                local angle = (i - 1) * (math.pi * 2 / 28) + (math.random() - 0.5) * 0.3
                local speed = 150 + math.random() * 220
                particles_[#particles_ + 1] = {
                    x = cx + (math.random() - 0.5) * 10,
                    y = cy + (math.random() - 0.5) * 10,
                    vx = math.cos(angle) * speed,
                    vy = math.sin(angle) * speed,
                    color = { 255, math.random(150, 255), math.random(30, 100) },
                    alpha = 1.0,
                    size = 5 + math.random() * 7,
                    elapsed = 0,
                    maxLife = 0.5 + math.random() * 0.25,
                    ptype = "burst",
                }
            end
            -- 屏幕震动（更强）
            shakeTimer_ = 0.3
            shakeIntensity_ = 1.5

        elseif special == Board.SPECIAL_RAINBOW then
            -- ======== 彩虹：多色同心波纹 + 星光散射（更华丽） ========
            -- 彩虹波纹（8层不同颜色扩散环）
            local rainbowColors = {
                { 231, 76, 60 }, { 241, 196, 15 }, { 46, 204, 113 },
                { 52, 152, 219 }, { 155, 89, 182 }, { 230, 126, 34 },
                { 255, 105, 180 }, { 0, 206, 209 },
            }
            for i = 1, 8 do
                particles_[#particles_ + 1] = {
                    x = cx, y = cy,
                    color = rainbowColors[i],
                    alpha = 0.95,
                    size = 3,
                    elapsed = 0,
                    delay = (i - 1) * 0.035,
                    maxLife = 0.55,
                    ptype = "ring",
                }
            end
            -- 星光散射（32 个，多色更密集）
            for i = 1, 10 do
                local angle = math.random() * math.pi * 2
                local speed = 80 + math.random() * 240
                local rc = rainbowColors[math.random(1, #rainbowColors)]
                particles_[#particles_ + 1] = {
                    x = cx, y = cy,
                    vx = math.cos(angle) * speed,
                    vy = math.sin(angle) * speed,
                    color = rc,
                    alpha = 1.0,
                    size = 4 + math.random() * 7,
                    elapsed = 0,
                    delay = math.random() * 0.08,
                    maxLife = 0.55 + math.random() * 0.35,
                    ptype = "burst",
                }
            end
            -- 中心大闪光（更大更亮）
            particles_[#particles_ + 1] = {
                x = cx, y = cy,
                color = { 255, 255, 255 },
                alpha = 1.0,
                size = l.cellSize * 0.5,
                elapsed = 0,
                maxLife = 0.35,
                ptype = "flash",
            }
            -- 额外冲击波
            particles_[#particles_ + 1] = {
                x = cx, y = cy,
                color = { 255, 200, 255 },
                alpha = 0.7,
                size = 5,
                elapsed = 0,
                delay = 0.05,
                maxLife = 0.4,
                ptype = "shockwave",
            }
            shakeTimer_ = 0.25
            shakeIntensity_ = 1.5

        else
            -- ======== 普通方块：标准散射 + 飞向分数 ========
            -- 散射粒子（14 个，更密集更亮）
            for i = 1, 5 do
                local angle = (i - 1) * (math.pi * 2 / 14) + (math.random() - 0.5) * 0.5
                local speed = 120 + math.random() * 180
                particles_[#particles_ + 1] = {
                    x = cx + (math.random() - 0.5) * 6,
                    y = cy + (math.random() - 0.5) * 6,
                    vx = math.cos(angle) * speed,
                    vy = math.sin(angle) * speed,
                    color = color,
                    alpha = 1.0,
                    size = 5 + math.random() * 6,
                    elapsed = 0,
                    maxLife = 0.45 + math.random() * 0.3,
                    ptype = "burst",
                }
            end
            -- 闪光环（更大更亮）
            particles_[#particles_ + 1] = {
                x = cx, y = cy,
                color = { 255, 255, 255 },
                alpha = 0.9,
                size = l.cellSize * 0.15,
                elapsed = 0,
                maxLife = 0.35,
                ptype = "ring",
            }
            -- 额外彩色闪光环
            particles_[#particles_ + 1] = {
                x = cx, y = cy,
                color = hi,
                alpha = 0.7,
                size = l.cellSize * 0.1,
                elapsed = 0,
                delay = 0.05,
                maxLife = 0.4,
                ptype = "ring",
            }
        end

        -- 飞向分数的粒子（所有方块都有，特殊的更多更大）
        local flyCount = (special ~= Board.SPECIAL_NONE) and 4 or 3
        local flySize = (special ~= Board.SPECIAL_NONE) and 10 or 8
        for i = 1, flyCount do
            particles_[#particles_ + 1] = {
                x = cx, y = cy,
                startX = cx, startY = cy,
                color = hi,
                alpha = 1.0,
                size = flySize + math.random() * 5,
                elapsed = 0,
                delay = math.random() * 0.12,
                maxLife = 0.5 + math.random() * 0.2,
                ptype = "fly",
            }
        end
    end

    -- 限制总粒子数
    while #particles_ > 800 do
        table.remove(particles_, 1)
    end
end

-- ============================================================================
-- 冰块受伤特效
-- ============================================================================

--- 触发冰块受伤特效（震动 + 冰屑飞散）
---@param damagedCells table[] { row, col, hp, destroyed }
function M.spawnIceDamageEffects(damagedCells, layout, getCellCenter)
    if not layout or #damagedCells == 0 then return end

    for _, ice in ipairs(damagedCells) do
        local cx, cy = getCellCenter(ice.row, ice.col)
        local cellSize = layout.cellSize

        -- 注册震动状态
        local k = ice.row * 100 + ice.col
        iceDamageFx_[k] = {
            timer = ice.destroyed and 0.3 or 0.25,
            intensity = ice.destroyed and 5 or 3.5,
            destroyed = ice.destroyed,
        }

        -- 冰屑飞散粒子
        local shardCount = ice.destroyed and 18 or 8
        for i = 1, shardCount do
            local angle = (i - 1) / shardCount * math.pi * 2 + (math.random() - 0.5) * 0.6
            local speed = ice.destroyed and (100 + math.random() * 160) or (50 + math.random() * 80)
            -- 冰屑三角碎片
            particles_[#particles_ + 1] = {
                x = cx + (math.random() - 0.5) * cellSize * 0.3,
                y = cy + (math.random() - 0.5) * cellSize * 0.3,
                vx = math.cos(angle) * speed,
                vy = math.sin(angle) * speed - 30,
                color = { 170 + math.random(50), 220 + math.random(35), 248 },
                alpha = 1.0,
                size = ice.destroyed and (3 + math.random() * 4) or (2 + math.random() * 3),
                elapsed = 0,
                maxLife = ice.destroyed and (0.5 + math.random() * 0.3) or (0.35 + math.random() * 0.2),
                ptype = "ice_shard",
                rotation = math.random() * math.pi * 2,
                rotSpeed = (math.random() - 0.5) * 12,
            }
        end

        -- 冰碎闪光
        particles_[#particles_ + 1] = {
            x = cx, y = cy,
            color = { 200, 235, 255 },
            alpha = ice.destroyed and 1.0 or 0.7,
            size = cellSize * (ice.destroyed and 0.35 or 0.2),
            elapsed = 0,
            maxLife = 0.25,
            ptype = "flash",
        }

        -- 破碎时额外冲击波
        if ice.destroyed then
            particles_[#particles_ + 1] = {
                x = cx, y = cy,
                color = { 150, 210, 245 },
                alpha = 0.6,
                size = 3,
                elapsed = 0,
                maxLife = 0.35,
                ptype = "shockwave",
            }
        end
    end
end

-- ============================================================================
-- 缓动函数（提前声明，供 updateParticles / draw 使用）
-- ============================================================================

local function easeOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end

local function easeOutBounce(t)
    if t < 1 / 2.75 then
        return 7.5625 * t * t
    elseif t < 2 / 2.75 then
        t = t - 1.5 / 2.75
        return 7.5625 * t * t + 0.75
    elseif t < 2.5 / 2.75 then
        t = t - 2.25 / 2.75
        return 7.5625 * t * t + 0.9375
    else
        t = t - 2.625 / 2.75
        return 7.5625 * t * t + 0.984375
    end
end

--- 更新粒子和屏幕震动
---@param dt number
local function updateParticles(dt)
    -- 更新屏幕震动
    if shakeTimer_ > 0 then
        shakeTimer_ = shakeTimer_ - dt
        local ratio = math.max(0, shakeTimer_ / 0.25)
        shakeOffX_ = (math.random() - 0.5) * 2 * shakeIntensity_ * ratio
        shakeOffY_ = (math.random() - 0.5) * 2 * shakeIntensity_ * ratio
        if shakeTimer_ <= 0 then
            shakeOffX_ = 0
            shakeOffY_ = 0
        end
    end

    -- 更新冰块受伤震动（per-cell）
    for k, fx in pairs(iceDamageFx_) do
        fx.timer = fx.timer - dt
        if fx.timer <= 0 then
            iceDamageFx_[k] = nil
        else
            local ratio = fx.timer / (fx.destroyed and 0.3 or 0.25)
            fx.offX = (math.random() - 0.5) * 2 * fx.intensity * ratio
            fx.offY = (math.random() - 0.5) * 2 * fx.intensity * ratio
        end
    end

    local i = 1
    while i <= #particles_ do
        local p = particles_[i]
        local remove = false

        -- 延迟处理
        if p.delay and p.delay > 0 then
            p.delay = p.delay - dt
            i = i + 1
        else
            p.elapsed = p.elapsed + dt
            local t = p.elapsed / p.maxLife

            if t >= 1.0 then
                remove = true
            elseif p.ptype == "burst" then
                -- 散射：移动 + 重力 + 淡出 + 缩小
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                p.vy = p.vy + 280 * dt
                p.vx = p.vx * 0.96
                p.alpha = 1.0 - t * t
                p.size = p.size * (1 - dt * 1.2)
                if p.size < 0.5 then remove = true end

            elseif p.ptype == "fly" then
                -- 飞向分数：二次贝塞尔曲线
                local ct = 1 - t
                local cpx = (p.startX + scoreTargetX_) * 0.5 + (math.random() - 0.5) * 10
                local cpy = math.min(p.startY, scoreTargetY_) - 40 - math.random() * 30
                p.x = ct * ct * p.startX + 2 * ct * t * cpx + t * t * scoreTargetX_
                p.y = ct * ct * p.startY + 2 * ct * t * cpy + t * t * scoreTargetY_
                if t > 0.7 then
                    local fadeT = (t - 0.7) / 0.3
                    p.alpha = 1.0 - fadeT
                    p.size = p.size * (1 - fadeT * 0.5)
                end

            elseif p.ptype == "ring" then
                -- 闪光环：更快扩散 + 淡出
                p.size = p.size + dt * 260
                p.alpha = 0.9 * (1 - t)

            elseif p.ptype == "shockwave" then
                -- 冲击波：快速扩散大环 + 淡出（更大范围）
                local maxR = (M._layout and (M._layout.cellSize * 3.2)) or 130
                p.size = maxR * easeOutQuad(t)
                p.alpha = 1.0 * (1 - t * t)

            elseif p.ptype == "flash" then
                -- 中心闪光：先膨胀后收缩淡出（更大范围）
                local maxR = (M._layout and (M._layout.cellSize * 1.6)) or 65
                if t < 0.3 then
                    p.size = maxR * (t / 0.3)
                else
                    p.size = maxR * (1 - (t - 0.3) / 0.7)
                end
                p.alpha = 1.0 - t

            elseif p.ptype == "beam_h" then
                -- 水平光束：闪烁淡出
                p.alpha = 1.0 - t * t

            elseif p.ptype == "beam_v" then
                -- 垂直光束：闪烁淡出
                p.alpha = 1.0 - t * t

            elseif p.ptype == "ice_shard" then
                -- 冰屑碎片：移动 + 重力 + 旋转 + 淡出 + 缩小
                p.x = p.x + p.vx * dt
                p.y = p.y + p.vy * dt
                p.vy = p.vy + 320 * dt      -- 重力
                p.vx = p.vx * 0.97           -- 空气阻力
                p.rotation = p.rotation + p.rotSpeed * dt
                p.alpha = 1.0 - t * t
                p.size = p.size * (1 - dt * 0.8)
                if p.size < 0.3 then remove = true end
            end

            if remove then
                table.remove(particles_, i)
            else
                i = i + 1
            end
        end
    end
end

--- 绘制粒子
---@param vg userdata
local function drawParticles(vg)
    for _,p in ipairs(particles_) do
        if not p.delay or p.delay<=0 then
            local c=p.color
            local a=math.floor(math.max(0,p.alpha)*210)
            if a>3 then
                nvgSave(vg); nvgGlobalAlpha(vg,a/255)
                if p.ptype=="beam_h" or p.ptype=="beam_v" then
                    nvgBeginPath(vg); nvgMoveTo(vg,p.x,p.y)
                    nvgLineTo(vg,p.endX or p.x,p.endY or p.y)
                    nvgStrokeColor(vg,Pen.color(C.ink)); nvgStrokeWidth(vg,5); nvgStroke(vg)
                    nvgStrokeColor(vg,Pen.color(C.orange)); nvgStrokeWidth(vg,2); nvgStroke(vg)
                elseif p.ptype=="ring" or p.ptype=="shockwave" then
                    Pen.circle(vg,p.x,p.y,math.max(0.1,p.size),nil,1.8,{c[1],c[2],c[3],160})
                elseif p.ptype~="flash" then
                    local r=math.max(0.8,math.min(5,p.size))
                    nvgBeginPath(vg); nvgMoveTo(vg,p.x,p.y-r)
                    nvgLineTo(vg,p.x+r*0.6,p.y); nvgLineTo(vg,p.x,p.y+r)
                    nvgLineTo(vg,p.x-r*0.6,p.y); nvgClosePath(vg)
                    Pen.paint(vg,{c[1],c[2],c[3],255},1)
                end
                nvgRestore(vg)
            end
        end
    end
end

--- 重置所有粒子和震动状态
function M.reset()
    particles_ = {}
    iceDamageFx_ = {}
    shakeTimer_ = 0
    shakeIntensity_ = 0
    shakeOffX_ = 0
    shakeOffY_ = 0
end

--- 设置布局（供 updateParticles 中 maxR 查询）
---@param layout table|nil
function M.setLayout(layout)
    M._layout = layout
end

--- 公共缓动函数（供外部动画使用）
M.easeOutQuad = easeOutQuad
M.easeOutBounce = easeOutBounce

--- 公共更新（每帧调用）
function M.update(dt)
    updateParticles(dt)
end

--- 公共绘制
function M.draw(vg)
    drawParticles(vg)
end

return M
