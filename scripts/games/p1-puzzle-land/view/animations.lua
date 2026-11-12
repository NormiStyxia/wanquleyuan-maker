--- 推箱子动画系统
--- 职责：管理分段动画队列、冰面滑行拖尾/粒子、位置插值
--- 约束：不依赖逻辑层，只消费事件列表
---
--- 动画项结构：
---   entity   = "box_1" | "player"
---   segments = { {from={x,y}, to={x,y}, duration, isSlide}, ... }
---   totalDuration, elapsed, done

local SoundManager = require("shared.sound-manager")
local ANIM = require("shared.constants.animations")

local M = {}
M.__index = M

local MOVE_DURATION  = ANIM.DURATION_INSTANT   -- 普通移动动画时长（秒）
local SLIDE_DURATION = 0.08   -- 冰面滑行单格时长（秒）

-- ============================================================================
-- 构造
-- ============================================================================

-- 目标命中特效参数（增强版 - 更明亮更震撼）
local TARGET_FX_DURATION = ANIM.DURATION_EFFECT   -- 特效总时长（更持久）
local TARGET_FX_RING_COUNT = 1    -- 扩散环数量（更多层）
local TARGET_FX_PARTICLE_COUNT = 6 -- 星光粒子数量（更密集）

-- 重置动画参数（增强版）
local RESET_PHASE1_DURATION = ANIM.DURATION_HOVER -- 阶段1：旧实体缩小消失
local RESET_PHASE2_DELAY    = ANIM.DURATION_INSTANT -- 阶段间隔（粒子飞散）
local RESET_PHASE2_DURATION = ANIM.DURATION_NORMAL -- 阶段2：新实体放大出现
local RESET_PARTICLE_COUNT  = 14   -- 每个实体消失/出现时的粒子数（更多）
local RESET_PARTICLE_LIFE   = 0.55 -- 粒子寿命（更持久）

-- 出生动画参数
local BIRTH_CELL_DURATION   = ANIM.DURATION_NORMAL -- 单个元素弹出时长
local BIRTH_MAX_DELAY       = ANIM.DURATION_TRANSITION -- 最远格子的延迟（秒）
local BIRTH_ENTITY_DELAY    = 0.12 -- 箱子/目标额外延迟（非通用时长）
local BIRTH_PLAYER_DELAY    = ANIM.DURATION_FAST -- 玩家额外延迟

-- 演出动画参数（增强版 - 更明显的反馈）
local BLOCKED_DURATION = ANIM.DURATION_NORMAL      -- 推不动时摇晃时长（更持久）
local BLOCKED_SHAKE_AMP = 0.06     -- 摇晃幅度（格子单位，更大）
local BLOCKED_SHAKE_FREQ = 18      -- 摇晃频率
local BOX_IMPACT_DURATION = ANIM.DURATION_HOVER   -- 箱子撞墙抖动时长（更持久）
local BOX_IMPACT_AMP = 0.04        -- 箱子抖动幅度（更大）
local BOX_IMPACT_FREQ = 22         -- 箱子抖动频率
local PUSH_DONE_DURATION = ANIM.DURATION_NORMAL    -- 推动完成角色动画时长

function M.new()
    local self = setmetatable({}, M)
    self.queue = {}           -- 动画队列
    self.particles = {}       -- 冰面粒子 { x, y, alpha, size, life, maxLife }
    self.targetEffects = {}   -- 目标命中特效 { x, y, elapsed, duration, particles, delay }
    self.celebration = nil    -- 通关庆祝特效状态
    self.onComplete = nil     -- 全部动画播完的回调
    self.playing = false

    -- 演出动画状态
    self.blockedAnim = nil     -- { dir, elapsed, duration } 推不动摇晃
    self.boxImpacts = {}       -- { boxIdx, pos, dir, elapsed, duration }[] 箱子撞墙
    self.pushDoneAnim = nil    -- { dir, elapsed, duration } 推完满足动画
    self.impactParticles = {}  -- { x, y, dx, dy, alpha, size, life, maxLife }[] 撞击粒子

    -- 重置动画状态
    self.resetAnim = nil       -- { phase, elapsed, oldEntities, newEntities, particles, onComplete }

    -- 出生动画状态
    self.birthAnim = nil       -- { elapsed, boardW, boardH, centerX, centerY, maxDist, totalDuration, onComplete }

    -- 灵动动画状态（呼吸/眨眼/方向追踪/落地弹跳）
    self.idleElapsed = 0
    self.lastMoveDir = { 0, -1 }          -- 默认朝上
    self.blinkTimer = 0
    self.nextBlinkAt = 2.0 + math.random() * 3.0
    self.isBlinking = false
    self.blinkElapsed = 0
    self.landingBounce = nil              -- { elapsed, duration, dx, dy }

    return self
end

-- ============================================================================
-- 事件消费：将逻辑层事件合并为分段动画
-- ============================================================================

--- 将逻辑层事件列表转为分段动画
---@param events table[] 逻辑层返回的事件列表
---@param onComplete function|nil 全部播完回调
function M:playEvents(events, onComplete)
    self.queue = {}
    self.particles = {}
    self.targetEffects = {}
    self.onComplete = onComplete
    self.playing = false

    -- 重置演出动画状态
    self.blockedAnim = nil
    self.boxImpacts = {}
    self.pushDoneAnim = nil

    -- 灵动动画：新事件到来时重置空闲计时
    self.idleElapsed = 0
    self.landingBounce = nil

    -- 按实体分组，合并连续滑行为多段
    ---@type table<string, table>
    local entityMap = {}   -- entity -> { segments = {...} }
    local entityOrder = {} -- 保持顺序

    for _, evt in ipairs(events) do
        local entity, fromX, fromY, toX, toY, isSlide

        if evt.type == "player_move" or evt.type == "player_slide" then
            entity = "player"
            fromX, fromY = evt.from[1], evt.from[2]
            toX, toY = evt.to[1], evt.to[2]
            isSlide = (evt.type == "player_slide")
            SoundManager.play("bloop_bounce")
            -- 灵动动画：记录玩家移动方向
            local ddx = toX - fromX
            local ddy = toY - fromY
            if ddx ~= 0 then ddx = ddx > 0 and 1 or -1 end
            if ddy ~= 0 then ddy = ddy > 0 and 1 or -1 end
            self.lastMoveDir = { ddx, ddy }
        elseif evt.type == "box_push" or evt.type == "box_slide" then
            entity = "box_" .. (evt.boxIdx or 0)
            fromX, fromY = evt.from[1], evt.from[2]
            toX, toY = evt.to[1], evt.to[2]
            isSlide = (evt.type == "box_slide")
        elseif evt.type == "move_blocked" then
            SoundManager.play("wrong_buzzer_soft")
            -- 推不动时的摇晃演出
            self:_startBlockedAnim(evt.dir, evt.reason, evt.boxIdx, evt.boxPos)
        elseif evt.type == "box_stopped" then
            -- 箱子撞墙时的抖动演出
            self:_startBoxImpact(evt.boxIdx, evt.pos, evt.dir)
        elseif evt.type == "push_complete" then
            -- 推动完成时的满足演出
            self:_startPushDoneAnim(evt.dir)
        elseif evt.type == "box_off_target" then
            -- (sound removed)
        elseif evt.type == "box_teleport" or evt.type == "player_teleport" then
        elseif evt.type == "level_complete" then
            SoundManager.play("level_cleared")
            SoundManager.play("success_fanfare")
        end

        if entity then
            if not entityMap[entity] then
                entityMap[entity] = { segments = {} }
                entityOrder[#entityOrder + 1] = entity
            end

            local segs = entityMap[entity].segments
            local lastSeg = segs[#segs]

            -- 如果上一段也是滑行，且终点与本段起点连续，直接追加段
            -- （不合并为单段，保留逐格动画以便拖尾效果）
            table.insert(segs, {
                from = { fromX, fromY },
                to   = { toX, toY },
                duration = isSlide and SLIDE_DURATION or MOVE_DURATION,
                isSlide = isSlide,
            })
        end
    end

    -- 处理 box_on_target 事件：计算延迟（等箱子移动到位后触发）
    for _, evt in ipairs(events) do
        if evt.type == "box_on_target" then
            -- 计算该箱子动画的总时长作为延迟
            local delay = 0
            -- 找到对应箱子的动画项计算总时长
            for _, entity in ipairs(entityOrder) do
                if string.sub(entity, 1, 4) == "box_" then
                    local data = entityMap[entity]
                    local lastSeg = data.segments[#data.segments]
                    if lastSeg and lastSeg.to[1] == evt.pos[1] and lastSeg.to[2] == evt.pos[2] then
                        for _, seg in ipairs(data.segments) do
                            delay = delay + seg.duration
                        end
                        break
                    end
                end
            end

            self:_createTargetEffect(evt.pos[1], evt.pos[2], delay)
            SoundManager.play("bubble_pop_cute")
        end
    end

    -- 转化为动画项
    for _, entity in ipairs(entityOrder) do
        local data = entityMap[entity]
        local totalDur = 0
        for _, seg in ipairs(data.segments) do
            totalDur = totalDur + seg.duration
        end

        self.queue[#self.queue + 1] = {
            entity = entity,
            segments = data.segments,
            totalDuration = totalDur,
            elapsed = 0,
            done = false,
        }
    end

    if #self.queue > 0 then
        self.playing = true
    else
        if onComplete then onComplete() end
    end
end

-- ============================================================================
-- 动画位置查询（渲染器用）
-- ============================================================================

--- 获取正在动画中的实体插值位置
--- 返回 nil, nil 表示该实体不在动画中
---@param entity string 实体标识，如 "player" 或 "box_1"
---@return number|nil x
---@return number|nil y
function M:getAnimPos(entity)
    for _, anim in ipairs(self.queue) do
        if anim.entity == entity and not anim.done then
            return self:_interpolate(anim)
        end
    end
    return nil, nil
end

--- 获取冰面滑行信息（渲染器用于绘制拖尾等特效）
--- 返回 nil 表示该实体当前不在冰面滑行
---@param entity string
---@return table|nil info { trail = {{x,y,alpha}...}, dx, dy, progress }
function M:getSlideInfo(entity)
    for _, anim in ipairs(self.queue) do
        if anim.entity == entity and not anim.done then
            return self:_calcSlideInfo(anim)
        end
    end
    return nil
end

--- 获取当前所有粒子（渲染器绘制）
---@return table[] particles { x, y, alpha, size }
function M:getParticles()
    return self.particles
end

--- 获取当前活跃的目标命中特效列表（渲染器绘制）
---@return table[] effects { x, y, progress, rings, burstParticles }
function M:getTargetEffects()
    return self.targetEffects
end

--- 获取目标命中时箱子的缩放因子
--- 返回 nil 表示该位置没有命中特效
---@param gridX number 格子坐标 X
---@param gridY number 格子坐标 Y
---@return number|nil scale 缩放因子（1.0 = 正常）
function M:getTargetBounceScale(gridX, gridY)
    for _, fx in ipairs(self.targetEffects) do
        if fx.x == gridX and fx.y == gridY and fx.active then
            local t = fx.progress
            if t < 0 then return nil end  -- 延迟中
            -- 弹跳曲线：快速放大到 1.25，然后弹回 1.0
            if t < 0.3 then
                -- 放大阶段
                return 1.0 + 0.08 * (t / 0.3)
            elseif t < 0.6 then
                -- 缩回阶段（带过冲）
                local st = (t - 0.3) / 0.3
                return 1.08 - 0.1 * st
            else
                -- 稳定回弹
                local st = (t - 0.6) / 0.4
                return 0.98 + 0.02 * st
            end
        end
    end
    return nil
end

--- 是否正在播放动画
---@return boolean
function M:isPlaying()
    return self.playing
end

-- ============================================================================
-- 内部：插值与滑行信息
-- ============================================================================

--- 对分段动画计算当前插值位置
---@param anim table
---@return number x, number y
function M:_interpolate(anim)
    local time = anim.elapsed
    local accum = 0

    for _, seg in ipairs(anim.segments) do
        if time < accum + seg.duration then
            local localT = (time - accum) / seg.duration
            localT = math.max(0, math.min(localT, 1))

            if seg.isSlide then
                -- 冰面：线性插值（无摩擦感）
            else
                -- 普通移动：ease-out quad
                localT = 1 - (1 - localT) * (1 - localT)
            end

            local x = seg.from[1] + (seg.to[1] - seg.from[1]) * localT
            local y = seg.from[2] + (seg.to[2] - seg.from[2]) * localT
            return x, y
        end
        accum = accum + seg.duration
    end

    -- 超过总时长，返回最终位置
    local lastSeg = anim.segments[#anim.segments]
    return lastSeg.to[1], lastSeg.to[2]
end

--- 计算冰面滑行的拖尾信息
---@param anim table
---@return table|nil
function M:_calcSlideInfo(anim)
    local time = anim.elapsed
    local accum = 0
    local currentSegIdx = 0

    -- 找到当前段
    for i, seg in ipairs(anim.segments) do
        if time < accum + seg.duration then
            currentSegIdx = i
            break
        end
        accum = accum + seg.duration
    end

    if currentSegIdx == 0 then return nil end

    local currentSeg = anim.segments[currentSegIdx]
    if not currentSeg.isSlide then return nil end

    -- 计算拖尾：收集当前段及之前滑行段的位置
    local trail = {}
    local dx = currentSeg.to[1] - currentSeg.from[1]
    local dy = currentSeg.to[2] - currentSeg.from[2]

    -- 当前位置
    local curX, curY = self:_interpolate(anim)

    -- 之前已完成的滑行段起点作为拖尾点（越早越透明）
    local slideStart = currentSegIdx
    for i = currentSegIdx, 1, -1 do
        if anim.segments[i].isSlide then
            slideStart = i
        else
            break
        end
    end

    local trailCount = currentSegIdx - slideStart + 1
    for i = slideStart, currentSegIdx do
        local seg = anim.segments[i]
        local age = currentSegIdx - i  -- 0 = 当前段, 1 = 上一段 ...
        local alpha = math.max(0.1, 1.0 - age * 0.3)
        trail[#trail + 1] = {
            x = seg.from[1],
            y = seg.from[2],
            alpha = alpha * 0.5,
        }
    end

    -- 当前段的进度
    local localT = (time - accum) / currentSeg.duration
    localT = math.max(0, math.min(localT, 1))

    return {
        trail = trail,
        curX = curX,
        curY = curY,
        dx = dx,
        dy = dy,
        progress = localT,
        segCount = trailCount,
    }
end

-- ============================================================================
-- 更新
-- ============================================================================

--- 每帧更新
---@param dt number 帧间隔（秒）
function M:update(dt)
    -- 目标命中特效独立于动画队列，始终更新
    self:_updateTargetEffects(dt)

    -- 通关庆祝特效独立更新
    if self.celebration then
        self:_updateCelebration(dt)
    end

    -- 演出动画始终更新（独立于移动动画队列）
    self:_updatePerformanceAnims(dt)

    -- 重置动画独立更新
    self:_updateResetAnim(dt)

    -- 出生动画独立更新
    self:_updateBirthAnim(dt)

    -- 灵动动画始终更新（呼吸/眨眼/落地弹跳）
    self:_updateAmbientAnims(dt)

    if not self.playing then
        -- 持续衰减已有粒子
        self:_updateParticles(dt)
        return
    end

    local allDone = true
    for _, anim in ipairs(self.queue) do
        if not anim.done then
            anim.elapsed = anim.elapsed + dt
            if anim.elapsed >= anim.totalDuration then
                anim.done = true
            else
                allDone = false
                -- 在冰面滑行期间产生粒子
                self:_spawnSlideParticles(anim)
            end
        end
    end

    self:_updateParticles(dt)

    -- 移动动画和演出动画都完成才算整体完成
    if allDone and not self:_isPerformancePlaying() then
        self.playing = false
        -- 灵动动画：移动结束时触发落地弹跳
        if #self.queue > 0 then
            local lastAnim = self.queue[#self.queue]
            if lastAnim.entity == "player" then
                local lastSeg = lastAnim.segments[#lastAnim.segments]
                local ddx = lastSeg.to[1] - lastSeg.from[1]
                local ddy = lastSeg.to[2] - lastSeg.from[2]
                self.landingBounce = { elapsed = 0, duration = 0.25, dx = ddx, dy = ddy }
            end
        end
        self.queue = {}
        if self.onComplete then
            self.onComplete()
        end
    end
end

-- ============================================================================
-- 粒子系统（冰面特效）
-- ============================================================================

--- 在滑行路径上产生冰花粒子
---@param anim table
function M:_spawnSlideParticles(anim)
    local time = anim.elapsed
    local accum = 0

    for _, seg in ipairs(anim.segments) do
        if time < accum + seg.duration then
            if seg.isSlide then
                local localT = (time - accum) / seg.duration
                local x = seg.from[1] + (seg.to[1] - seg.from[1]) * localT
                local y = seg.from[2] + (seg.to[2] - seg.from[2]) * localT

                -- 每帧在箱子附近产生 1-2 个冰花粒子
                for _ = 1, 2 do
                    local offX = (math.random() - 0.5) * 0.6
                    local offY = (math.random() - 0.5) * 0.6
                    self.particles[#self.particles + 1] = {
                        x = x + offX,
                        y = y + offY,
                        alpha = 0.6 + math.random() * 0.4,
                        size = 0.03 + math.random() * 0.04,
                        life = 0.25 + math.random() * 0.2,
                        maxLife = 0.45,
                    }
                end
            end
            return
        end
        accum = accum + seg.duration
    end
end

--- 更新粒子生命周期
---@param dt number
function M:_updateParticles(dt)
    local i = 1
    while i <= #self.particles do
        local p = self.particles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            -- 快速移除：交换到末尾
            self.particles[i] = self.particles[#self.particles]
            self.particles[#self.particles] = nil
        else
            p.alpha = (p.life / p.maxLife) * 0.8
            i = i + 1
        end
    end
end

-- ============================================================================
-- 目标命中特效
-- ============================================================================

--- 创建一个目标命中特效
---@param gridX number 目标格子 X
---@param gridY number 目标格子 Y
---@param delay number 延迟秒数（等移动动画播完）
function M:_createTargetEffect(gridX, gridY, delay)
    -- 生成爆发粒子（金色星光，向外扩散，更大更快）
    local burstParticles = {}
    for i = 1, TARGET_FX_PARTICLE_COUNT do
        local angle = (i - 1) / TARGET_FX_PARTICLE_COUNT * math.pi * 2
        local speed = 1.2 + math.random() * 0.9
        burstParticles[i] = {
            angle = angle,
            speed = speed,
            dist = 0,          -- 当前扩散距离（格子单位）
            size = 0.06 + math.random() * 0.05,
            alpha = 1.0,
        }
    end

    -- 扩散环（更多层，更大间距）
    local rings = {}
    for i = 1, TARGET_FX_RING_COUNT do
        rings[i] = {
            delay = (i - 1) * 0.06,  -- 每个环错开一点
            radius = 0,
            alpha = 1.0,
        }
    end

    self.targetEffects[#self.targetEffects + 1] = {
        x = gridX,
        y = gridY,
        elapsed = -delay,          -- 负数表示延迟中
        duration = TARGET_FX_DURATION,
        progress = 0,
        active = true,
        rings = rings,
        burstParticles = burstParticles,
    }
end

--- 更新目标命中特效
---@param dt number
function M:_updateTargetEffects(dt)
    local i = 1
    while i <= #self.targetEffects do
        local fx = self.targetEffects[i]
        fx.elapsed = fx.elapsed + dt

        if fx.elapsed < 0 then
            -- 仍在延迟中
            fx.progress = -1
            i = i + 1
        elseif fx.elapsed >= fx.duration then
            -- 特效完成，移除
            self.targetEffects[i] = self.targetEffects[#self.targetEffects]
            self.targetEffects[#self.targetEffects] = nil
        else
            local t = fx.elapsed / fx.duration
            fx.progress = t

            -- 更新扩散环（更大范围）
            for _, ring in ipairs(fx.rings) do
                local ringT = math.max(0, (fx.elapsed - ring.delay) / (fx.duration - ring.delay))
                ring.radius = ringT * 0.85  -- 最大扩散 0.85 格（更大）
                ring.alpha = math.max(0, 1.0 - ringT * 1.3)
            end

            -- 更新爆发粒子（更远扩散）
            for _, p in ipairs(fx.burstParticles) do
                p.dist = t * p.speed * 0.7  -- 扩散距离（更远）
                p.alpha = math.max(0, 1.0 - t * 1.1)
            end

            i = i + 1
        end
    end
end

-- ============================================================================
-- 通关庆祝特效
-- ============================================================================

local CELEBRATION_DURATION = ANIM.DURATION_CELEBRATE   -- 庆祝总时长（更持久）
local FIREWORK_COUNT = 8           -- 烟花波次（更多波次）
local CONFETTI_COUNT = 100         -- 彩带粒子数量（更密集）
local STAR_BURST_COUNT = 20        -- 星星爆发数（更多星星）

--- 启动通关庆祝特效
---@param screenW number 屏幕宽度
---@param screenH number 屏幕高度
---@param stars number 获得的星星数量（1-3）
function M:startCelebration(screenW, screenH, stars)
    local cel = {
        elapsed = 0,
        duration = CELEBRATION_DURATION,
        screenW = screenW,
        screenH = screenH,
        stars = stars,
        active = true,
        -- 弹窗动画
        dialogScale = 0,
        dialogAlpha = 0,
        -- 星星
        starAnims = {},
        -- 烟花
        fireworks = {},
        -- 彩带
        confetti = {},
    }

    -- 初始化星星弹跳动画（每颗星星依次弹出）
    for i = 1, 3 do
        cel.starAnims[i] = {
            delay = 0.25 + (i - 1) * 0.18,  -- 依次延迟
            scale = 0,
            alpha = 0,
            rotation = 0,
            earned = i <= stars,
        }
    end

    -- 初始化烟花（分几波，在屏幕不同位置爆发）
    for i = 1, FIREWORK_COUNT do
        local fw = {
            x = 0.15 + math.random() * 0.7,   -- 归一化屏幕坐标
            y = 0.1 + math.random() * 0.35,
            delay = 0.1 + (i - 1) * 0.35 + math.random() * 0.15,
            elapsed = 0,
            duration = 0.8,
            active = false,
            sparks = {},
        }
        -- 每个烟花 16-22 个火花（更密集更大）
        local sparkCount = 16 + math.random(6)
        for j = 1, sparkCount do
            local angle = (j - 1) / sparkCount * math.pi * 2 + math.random() * 0.3
            fw.sparks[j] = {
                angle = angle,
                speed = 90 + math.random() * 130,
                size = 3 + math.random() * 4,
                -- 随机鲜艳色系（更亮更饱和）
                r = 200 + math.random(55),
                g = 100 + math.random(155),
                b = 50 + math.random(150),
            }
        end
        cel.fireworks[i] = fw
    end

    -- 初始化彩带（从上方飘落的彩色纸片，更大更鲜艳）
    for i = 1, CONFETTI_COUNT do
        cel.confetti[i] = {
            x = math.random() * screenW,
            y = -10 - math.random() * screenH * 0.5,  -- 起始在屏幕上方
            vx = (math.random() - 0.5) * 80,
            vy = 50 + math.random() * 100,
            width = 4 + math.random() * 7,
            height = 8 + math.random() * 10,
            rotation = math.random() * math.pi * 2,
            rotSpeed = (math.random() - 0.5) * 10,
            -- 更鲜艳饱和的彩色
            r = math.random(150, 255),
            g = math.random(100, 255),
            b = math.random(80, 255),
            alpha = 0.85 + math.random() * 0.15,
            delay = math.random() * 0.6,
        }
    end

    self.celebration = cel
end

--- 获取当前庆祝状态（渲染器用）
---@return table|nil celebration
function M:getCelebration()
    return self.celebration
end

--- 庆祝是否正在播放
---@return boolean
function M:isCelebrating()
    return self.celebration ~= nil and self.celebration.active
end

--- 停止庆祝
function M:stopCelebration()
    self.celebration = nil
end

--- 更新通关庆祝特效
---@param dt number
function M:_updateCelebration(dt)
    local cel = self.celebration
    if not cel or not cel.active then return end

    cel.elapsed = cel.elapsed + dt

    -- 弹窗缩放弹出（弹性曲线）
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

    -- 更新星星弹跳
    for _, star in ipairs(cel.starAnims) do
        local st = cel.elapsed - star.delay
        if st > 0 then
            local t = math.min(1, st / 0.35)
            if star.earned then
                -- 弹性弹出
                if t < 0.5 then
                    star.scale = (t / 0.5) * 1.4
                    star.rotation = (1 - t / 0.5) * 0.3
                elseif t < 0.75 then
                    local bt = (t - 0.5) / 0.25
                    star.scale = 1.4 - 0.5 * bt
                    star.rotation = -0.1 * (1 - bt)
                else
                    local bt = (t - 0.75) / 0.25
                    star.scale = 0.9 + 0.1 * bt
                    star.rotation = 0
                end
                star.alpha = math.min(1, st / 0.1)
            else
                -- 未获得的星星：淡入但灰暗
                star.scale = math.min(1, t * 1.2)
                star.alpha = math.min(0.4, st / 0.2)
                star.rotation = 0
            end
        end
    end

    -- 更新烟花
    for _, fw in ipairs(cel.fireworks) do
        if cel.elapsed >= fw.delay then
            if not fw.active then
                fw.active = true
                fw.elapsed = 0
            end
            fw.elapsed = fw.elapsed + dt
        end
    end

    -- 更新彩带
    for _, c in ipairs(cel.confetti) do
        if cel.elapsed >= c.delay then
            c.x = c.x + c.vx * dt
            c.y = c.y + c.vy * dt
            c.vx = c.vx + (math.random() - 0.5) * 20 * dt  -- 轻微横向漂移
            c.rotation = c.rotation + c.rotSpeed * dt

            -- 逐渐淡出（最后0.5秒）
            if cel.elapsed > cel.duration - 0.5 then
                c.alpha = c.alpha * 0.95
            end
        end
    end

    -- 特效结束（但不自动清除，留给调用者判断弹窗关闭时清除）
    if cel.elapsed >= cel.duration then
        -- 停止产生新特效，但保持 active 以便弹窗继续渲染
    end
end

-- ============================================================================
-- 演出动画：推不动时角色摇晃 + 箱子抖动
-- ============================================================================

local DIR_OFFSET = {
    up    = { 0, -1 },
    down  = { 0,  1 },
    left  = { -1, 0 },
    right = {  1, 0 },
}

--- 启动"推不动"摇晃动画
---@param dir string 方向
---@param reason string "wall"|"box_stuck"
---@param boxIdx number|nil 被推的箱子索引（仅 box_stuck）
---@param boxPos number[]|nil 箱子位置（仅 box_stuck）
function M:_startBlockedAnim(dir, reason, boxIdx, boxPos)
    self.blockedAnim = {
        dir = dir,
        reason = reason or "wall",
        elapsed = 0,
        duration = BLOCKED_DURATION,
    }

    -- 如果是推不动箱子，箱子也做小幅抖动
    if reason == "box_stuck" and boxIdx and boxPos then
        self.boxImpacts[#self.boxImpacts + 1] = {
            boxIdx = boxIdx,
            pos = { boxPos[1], boxPos[2] },
            dir = DIR_OFFSET[dir] or { 0, 0 },
            elapsed = 0,
            duration = BLOCKED_DURATION,
            amp = BOX_IMPACT_AMP * 0.6,  -- 稍微小一些
        }
    end

    -- 演出也算在播放中（防止输入中断）
    self.playing = true
end

--- 获取推不动时角色的偏移量（渲染器用）
---@return number|nil offsetX, number|nil offsetY, number|nil squish, number|nil eyeCross
function M:getBlockedOffset()
    if not self.blockedAnim then return nil, nil, nil, nil end
    local ba = self.blockedAnim
    local t = ba.elapsed / ba.duration
    -- 衰减振荡
    local decay = 1 - t
    local shake = math.sin(ba.elapsed * BLOCKED_SHAKE_FREQ * math.pi * 2) * decay * BLOCKED_SHAKE_AMP

    local d = DIR_OFFSET[ba.dir] or { 0, 0 }
    local ox = d[1] * shake
    local oy = d[2] * shake

    -- 身体的挤压效果（发力感）：推的方向上压扁
    local squish = 1.0 + decay * 0.08 * math.abs(math.sin(ba.elapsed * BLOCKED_SHAKE_FREQ * math.pi))

    -- X 眼效果：前 70% 保持 X 眼，后 30% 渐退恢复
    local eyeCross
    if t < 0.7 then
        eyeCross = 1.0
    else
        eyeCross = 1.0 - (t - 0.7) / 0.3
    end

    return ox, oy, squish, eyeCross
end

-- ============================================================================
-- 演出动画：箱子撞墙抖动
-- ============================================================================

--- 启动箱子撞墙抖动
---@param boxIdx number
---@param pos number[] 箱子停下来的位置
---@param dir number[] {dx, dy}
function M:_startBoxImpact(boxIdx, pos, dir)
    -- 产生撞击粒子
    local cx, cy = pos[1], pos[2]
    local dx, dy = dir[1], dir[2]
    for _ = 1, 6 do
        local spread = (math.random() - 0.5) * 0.5
        local speed = 0.3 + math.random() * 0.5
        self.impactParticles[#self.impactParticles + 1] = {
            x = cx + dx * 0.5,
            y = cy + dy * 0.5,
            vx = dx * speed + spread,
            vy = dy * speed + spread,
            alpha = 0.8 + math.random() * 0.2,
            size = 0.02 + math.random() * 0.03,
            life = 0.2 + math.random() * 0.15,
            maxLife = 0.35,
        }
    end

    self.boxImpacts[#self.boxImpacts + 1] = {
        boxIdx = boxIdx,
        pos = { pos[1], pos[2] },
        dir = { dx, dy },
        elapsed = 0,
        duration = BOX_IMPACT_DURATION,
        amp = BOX_IMPACT_AMP,
    }
end

--- 获取箱子撞击时的偏移量（渲染器用）
---@param boxIdx number
---@return number|nil offsetX, number|nil offsetY
function M:getBoxImpactOffset(boxIdx)
    for _, imp in ipairs(self.boxImpacts) do
        if imp.boxIdx == boxIdx and imp.elapsed < imp.duration then
            local t = imp.elapsed / imp.duration
            local decay = 1 - t
            local shake = math.sin(imp.elapsed * BOX_IMPACT_FREQ * math.pi * 2) * decay * imp.amp
            return imp.dir[1] * shake, imp.dir[2] * shake
        end
    end
    return nil, nil
end

--- 获取撞击粒子列表（渲染器用）
---@return table[]
function M:getImpactParticles()
    return self.impactParticles
end

-- ============================================================================
-- 演出动画：推动完成满足动画
-- ============================================================================

--- 启动推动完成动画（角色微微弹跳+眯眼）
---@param dir string
function M:_startPushDoneAnim(dir)
    self.pushDoneAnim = {
        dir = dir,
        elapsed = 0,
        duration = PUSH_DONE_DURATION,
    }
end

--- 获取推完后的演出信息（渲染器用）
---@return table|nil info { bounceY, eyeSquint, progress }
function M:getPushDoneInfo()
    if not self.pushDoneAnim then return nil end
    local pd = self.pushDoneAnim
    local t = pd.elapsed / pd.duration

    -- 微弹跳：先上后下
    local bounceY = 0
    if t < 0.4 then
        bounceY = -math.sin(t / 0.4 * math.pi) * 0.1
    end

    -- 眯眼效果：0→1→0
    local eyeSquint = 0
    if t < 0.3 then
        eyeSquint = t / 0.3
    elseif t < 0.7 then
        eyeSquint = 1.0
    else
        eyeSquint = 1.0 - (t - 0.7) / 0.3
    end

    return {
        bounceY = bounceY,
        eyeSquint = math.max(0, math.min(1, eyeSquint)),
        progress = t,
        dir = pd.dir,
    }
end

-- ============================================================================
-- 演出动画更新
-- ============================================================================

--- 更新所有演出动画（在 update 中调用）
---@param dt number
function M:_updatePerformanceAnims(dt)
    -- 更新推不动摇晃
    if self.blockedAnim then
        self.blockedAnim.elapsed = self.blockedAnim.elapsed + dt
        if self.blockedAnim.elapsed >= self.blockedAnim.duration then
            self.blockedAnim = nil
        end
    end

    -- 更新箱子撞击
    local i = 1
    while i <= #self.boxImpacts do
        local imp = self.boxImpacts[i]
        imp.elapsed = imp.elapsed + dt
        if imp.elapsed >= imp.duration then
            self.boxImpacts[i] = self.boxImpacts[#self.boxImpacts]
            self.boxImpacts[#self.boxImpacts] = nil
        else
            i = i + 1
        end
    end

    -- 更新撞击粒子
    i = 1
    while i <= #self.impactParticles do
        local p = self.impactParticles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            self.impactParticles[i] = self.impactParticles[#self.impactParticles]
            self.impactParticles[#self.impactParticles] = nil
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vx = p.vx * 0.92  -- 阻尼
            p.vy = p.vy * 0.92
            p.alpha = (p.life / p.maxLife) * 0.9
            i = i + 1
        end
    end

    -- 更新推完满足动画
    if self.pushDoneAnim then
        self.pushDoneAnim.elapsed = self.pushDoneAnim.elapsed + dt
        if self.pushDoneAnim.elapsed >= self.pushDoneAnim.duration then
            self.pushDoneAnim = nil
        end
    end
end

--- 检测演出动画是否还在播放
---@return boolean
function M:_isPerformancePlaying()
    if self.blockedAnim then return true end
    if #self.boxImpacts > 0 then return true end
    -- pushDoneAnim 不阻塞输入，仅作视觉演出
    return false
end

-- ============================================================================
-- 重置关卡动画（两阶段：消失 → 出现）
-- ============================================================================

--- 生成爆散粒子（从实体位置向外飞散）
---@param cx number 格子坐标 X
---@param cy number 格子坐标 Y
---@param color table {r,g,b} 粒子颜色
---@param outward boolean true=向外飞散，false=向内聚拢
---@return table[] particles
local function _spawnResetParticles(cx, cy, color, outward)
    local result = {}
    for i = 1, RESET_PARTICLE_COUNT do
        local angle = (i - 1) / RESET_PARTICLE_COUNT * math.pi * 2 + (math.random() - 0.5) * 0.4
        local speed = 0.8 + math.random() * 1.2
        local dir = outward and 1 or -1
        result[#result + 1] = {
            x = cx,
            y = cy,
            vx = math.cos(angle) * speed * dir,
            vy = math.sin(angle) * speed * dir,
            alpha = 0.9 + math.random() * 0.1,
            size = 0.03 + math.random() * 0.04,
            life = RESET_PARTICLE_LIFE + math.random() * 0.15,
            maxLife = RESET_PARTICLE_LIFE + 0.15,
            r = color[1],
            g = color[2],
            b = color[3],
        }
    end
    return result
end

--- 启动重置关卡动画
---@param oldPlayer number[] 旧的玩家位置 {x, y}
---@param oldBoxes table[] 旧的箱子位置列表 { {x,y}, ... }
---@param newPlayer number[] 新的玩家位置 {x, y}
---@param newBoxes table[] 新的箱子位置列表 { {x,y}, ... }
---@param onComplete function 动画完成回调
function M:startResetAnim(oldPlayer, oldBoxes, newPlayer, newBoxes, onComplete)
    -- 收集旧实体信息
    local oldEntities = {}
    oldEntities[#oldEntities + 1] = {
        type = "player", x = oldPlayer[1], y = oldPlayer[2],
    }
    for i, box in ipairs(oldBoxes) do
        oldEntities[#oldEntities + 1] = {
            type = "box", idx = i, x = box[1], y = box[2],
        }
    end

    -- 收集新实体信息
    local newEntities = {}
    newEntities[#newEntities + 1] = {
        type = "player", x = newPlayer[1], y = newPlayer[2],
    }
    for i, box in ipairs(newBoxes) do
        newEntities[#newEntities + 1] = {
            type = "box", idx = i, x = box[1], y = box[2],
        }
    end

    self.resetAnim = {
        phase = 1,           -- 1=消失, 2=出现
        elapsed = 0,
        oldEntities = oldEntities,
        newEntities = newEntities,
        particles = {},
        onComplete = onComplete,
        phase1Done = false,
        phase2Started = false,
    }

    self.playing = true
end

--- 获取重置动画状态（渲染器用）
---@return table|nil resetInfo { phase, progress, oldEntities, newEntities, particles }
function M:getResetAnim()
    if not self.resetAnim then return nil end
    local ra = self.resetAnim

    local progress = 0
    if ra.phase == 1 then
        progress = math.min(1, ra.elapsed / RESET_PHASE1_DURATION)
    elseif ra.phase == 2 then
        progress = math.min(1, ra.elapsed / RESET_PHASE2_DURATION)
    end

    return {
        phase = ra.phase,
        progress = progress,
        oldEntities = ra.oldEntities,
        newEntities = ra.newEntities,
        particles = ra.particles,
    }
end

--- 重置动画是否正在播放
---@return boolean
function M:isResetPlaying()
    return self.resetAnim ~= nil
end

--- 更新重置动画
---@param dt number
function M:_updateResetAnim(dt)
    local ra = self.resetAnim
    if not ra then return end

    ra.elapsed = ra.elapsed + dt

    if ra.phase == 1 then
        -- 阶段1：旧实体缩小消失
        local p1 = ra.elapsed / RESET_PHASE1_DURATION
        if p1 >= 1 and not ra.phase1Done then
            ra.phase1Done = true
            -- 在旧位置产生爆散粒子
            local boxColor = { 230, 160, 55 }
            local playerColor = { 255, 125, 60 }
            for _, ent in ipairs(ra.oldEntities) do
                local color = ent.type == "player" and playerColor or boxColor
                local newParticles = _spawnResetParticles(ent.x, ent.y, color, true)
                for _, p in ipairs(newParticles) do
                    ra.particles[#ra.particles + 1] = p
                end
            end
        end

        -- 阶段1完成 + 间隔等待完毕 → 进入阶段2
        if ra.elapsed >= RESET_PHASE1_DURATION + RESET_PHASE2_DELAY then
            ra.phase = 2
            ra.elapsed = 0
            -- 在新位置产生聚拢粒子
            local boxColor = { 230, 160, 55 }
            local playerColor = { 255, 125, 60 }
            for _, ent in ipairs(ra.newEntities) do
                local color = ent.type == "player" and playerColor or boxColor
                local newParticles = _spawnResetParticles(ent.x, ent.y, color, false)
                for _, p in ipairs(newParticles) do
                    ra.particles[#ra.particles + 1] = p
                end
            end
        end
    elseif ra.phase == 2 then
        -- 阶段2：新实体放大出现
        if ra.elapsed >= RESET_PHASE2_DURATION then
            -- 动画完成
            local cb = ra.onComplete
            self.resetAnim = nil
            self.playing = false
            if cb then cb() end
            return
        end
    end

    -- 更新粒子物理
    local i = 1
    while i <= #ra.particles do
        local p = ra.particles[i]
        p.life = p.life - dt
        if p.life <= 0 then
            ra.particles[i] = ra.particles[#ra.particles]
            ra.particles[#ra.particles] = nil
        else
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vx = p.vx * 0.90
            p.vy = p.vy * 0.90
            p.alpha = (p.life / p.maxLife) * 0.9
            i = i + 1
        end
    end
end

-- ============================================================================
-- 出生动画（进入关卡时格子从中心向外波纹弹出）
-- ============================================================================

--- 弹性过冲曲线（与 resetAnim 一致）
---@param t number 0~1 归一化进度
---@return number scale 缩放值
local function _elasticScale(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    if t < 0.6 then
        return (t / 0.6) * 1.15
    elseif t < 0.8 then
        local bt = (t - 0.6) / 0.2
        return 1.15 - 0.2 * bt
    else
        local bt = (t - 0.8) / 0.2
        return 0.95 + 0.05 * bt
    end
end

--- 启动出生动画
---@param boardW number 棋盘宽度（格子数）
---@param boardH number 棋盘高度（格子数）
---@param onComplete function|nil 动画完成回调
function M:startBirthAnim(boardW, boardH, onComplete)
    local cx = (boardW + 1) / 2
    local cy = (boardH + 1) / 2
    -- 最大曼哈顿距离
    local maxDist = math.max(
        math.abs(1 - cx) + math.abs(1 - cy),
        math.abs(boardW - cx) + math.abs(boardH - cy)
    )
    if maxDist < 1 then maxDist = 1 end

    local totalDuration = BIRTH_MAX_DELAY + BIRTH_PLAYER_DELAY + BIRTH_CELL_DURATION

    self.birthAnim = {
        elapsed = 0,
        boardW = boardW,
        boardH = boardH,
        centerX = cx,
        centerY = cy,
        maxDist = maxDist,
        totalDuration = totalDuration,
        onComplete = onComplete,
    }
end

--- 获取出生动画缩放值
--- 返回 nil 表示动画未激活（正常绘制），0~1 表示缩放值
---@param gx number 格子 X 坐标
---@param gy number 格子 Y 坐标
---@param layer string "cell"|"target"|"box"|"player"
---@return number|nil scale
function M:getBirthScale(gx, gy, layer)
    local ba = self.birthAnim
    if not ba then return nil end

    -- 计算到中心的曼哈顿距离，归一化
    local dist = math.abs(gx - ba.centerX) + math.abs(gy - ba.centerY)
    local normDist = dist / ba.maxDist  -- 0~1

    -- 基础延迟：距离越远延迟越大
    local delay = normDist * BIRTH_MAX_DELAY

    -- 层级额外延迟
    if layer == "target" then
        delay = delay + BIRTH_ENTITY_DELAY * 0.5
    elseif layer == "box" then
        delay = delay + BIRTH_ENTITY_DELAY
    elseif layer == "player" then
        delay = delay + BIRTH_PLAYER_DELAY
    end

    -- 计算该元素的局部进度
    local localElapsed = ba.elapsed - delay
    if localElapsed <= 0 then return 0 end

    local t = localElapsed / BIRTH_CELL_DURATION
    return _elasticScale(t)
end

--- 出生动画是否正在播放
---@return boolean
function M:isBirthPlaying()
    return self.birthAnim ~= nil
end

--- 更新出生动画
---@param dt number
function M:_updateBirthAnim(dt)
    local ba = self.birthAnim
    if not ba then return end

    ba.elapsed = ba.elapsed + dt

    if ba.elapsed >= ba.totalDuration then
        local cb = ba.onComplete
        self.birthAnim = nil
        if cb then cb() end
    end
end

-- ============================================================================
-- 灵动动画：呼吸 / 眨眼 / 落地弹跳
-- ============================================================================

--- 每帧更新灵动动画状态
---@param dt number
function M:_updateAmbientAnims(dt)
    -- 空闲计时（用于呼吸动画幅度渐入）
    self.idleElapsed = self.idleElapsed + dt

    -- 眨眼计时
    if self.isBlinking then
        self.blinkElapsed = self.blinkElapsed + dt
        if self.blinkElapsed >= 0.15 then
            self.isBlinking = false
            self.blinkElapsed = 0
            self.blinkTimer = 0
            self.nextBlinkAt = 1.5 + math.random() * 3.0
        end
    else
        self.blinkTimer = self.blinkTimer + dt
        if self.blinkTimer >= self.nextBlinkAt then
            self.isBlinking = true
            self.blinkElapsed = 0
        end
    end

    -- 落地弹跳衰减
    if self.landingBounce then
        self.landingBounce.elapsed = self.landingBounce.elapsed + dt
        if self.landingBounce.elapsed >= self.landingBounce.duration then
            self.landingBounce = nil
        end
    end
end

--- 获取玩家灵动动画信息（渲染器用）
---@return table info { breathScale, blinkProgress, eyeDirX, eyeDirY, landSquishX, landSquishY, tilt }
function M:getPlayerAnimInfo()
    local info = {
        breathScale = 1.0,
        blinkProgress = 0,
        eyeDirX = 0,
        eyeDirY = 0,
        landSquishX = 1.0,
        landSquishY = 1.0,
        tilt = 0,
    }

    -- 呼吸：空闲时轻微缩放，idle 越久幅度越大（最大 ±3%）
    local breathAmp = math.min(1.0, self.idleElapsed / 1.5) * 0.03
    local breathCycle = math.sin(self.idleElapsed * 2.5)
    info.breathScale = 1.0 + breathCycle * breathAmp

    -- 眨眼
    if self.isBlinking then
        local t = self.blinkElapsed / 0.15
        -- 0→1→0 的快速闭合曲线
        info.blinkProgress = 1.0 - math.abs(t * 2 - 1)
    end

    -- 眼球方向（基于最后移动方向）
    info.eyeDirX = self.lastMoveDir[1] * 0.55
    info.eyeDirY = self.lastMoveDir[2] * 0.55

    -- 落地弹跳：到达时沿移动方向压扁-反弹
    if self.landingBounce then
        local lb = self.landingBounce
        local t = lb.elapsed / lb.duration
        -- 弹性衰减曲线
        local bounce = math.sin(t * math.pi * 2.5) * (1 - t) * 0.15
        if math.abs(lb.dx) > 0 then
            -- 水平移动：X 方向压扁
            info.landSquishX = 1.0 - bounce
            info.landSquishY = 1.0 + bounce
        else
            -- 垂直移动：Y 方向压扁
            info.landSquishX = 1.0 + bounce
            info.landSquishY = 1.0 - bounce
        end
        -- 轻微倾斜
        info.tilt = math.sin(t * math.pi * 3) * (1 - t) * 0.08
    end

    return info
end

return M
