--- 消消乐 - 动画控制器
--- 职责：管理交换/消除/掉落/抖动/combo 动画的状态和生命周期
--- 约束：不含渲染逻辑，仅控制动画状态

local ANIM = require("shared.constants.animations")
local M = {}

-- ============================================================================
-- 动画状态（公开属性，渲染层直接读取）
-- ============================================================================

---@type number 动画进度 0-1
M.progress = 0
---@type number 动画总时长（秒）
M.duration = 0.2

---@type table|nil { fromR, fromC, toR, toC }
M.swapAnim = nil
---@type boolean
M.swapAnimReverse = false

---@type table[] { row, col, colorId, special, alpha, scale }
M.elimAnims = {}

---@type table[] { col, fromRow, toRow, colorId, special, isNew, progress }
M.fallAnims = {}

---@type table|nil { row, col, dr, dc }
M.shakeAnim = nil

---@type number 彩虹方块动画时间
M.rainbowTime = 0

---@type table|nil { text, x, y, alpha, elapsed, duration, combo }
M.comboAnim = nil

-- ============================================================================
-- 启动动画
-- ============================================================================

--- 启动交换动画
function M.startSwap(fromR, fromC, toR, toC, durationMs, reverse)
    M.swapAnim = { fromR = fromR, fromC = fromC, toR = toR, toC = toC }
    M.duration = durationMs / 1000
    M.progress = 0
    M.swapAnimReverse = reverse or false
end

--- 启动抖动动画（无效交换，方块轻微移动后弹回）
---@param row number 方块行
---@param col number 方块列
---@param dr number 方向行偏移 (-1/0/1)
---@param dc number 方向列偏移 (-1/0/1)
---@param durationMs number 持续毫秒
function M.startShake(row, col, dr, dc, durationMs)
    M.shakeAnim = { row = row, col = col, dr = dr, dc = dc }
    M.duration = durationMs / 1000
    M.progress = 0
end

--- 启动消除动画
function M.startElim(cells, durationMs)
    M.elimAnims = {}
    for _, c in ipairs(cells) do
        M.elimAnims[#M.elimAnims + 1] = {
            row = c.row, col = c.col,
            colorId = c.colorId, special = c.special,
            alpha = 1.0, scale = 1.0,
        }
    end
    M.duration = durationMs / 1000
    M.progress = 0
end

--- 启动掉落动画
function M.startFall(cells, durationMsPerCell)
    M.fallAnims = {}
    local maxDist = 0
    for _, c in ipairs(cells) do
        local dist = math.abs(c.toRow - c.fromRow)
        if c.isNew then dist = dist + 1 end
        if dist > maxDist then maxDist = dist end
        M.fallAnims[#M.fallAnims + 1] = {
            col = c.col, fromRow = c.fromRow, toRow = c.toRow,
            colorId = c.colorId, special = c.special,
            isNew = c.isNew, progress = 0,
        }
    end
    M.duration = (durationMsPerCell / 1000) * math.max(1, maxDist)
    M.progress = 0
end

--- 启动 combo 文本动画
---@param combo number 连锁数
---@param screenW number 屏幕宽度
---@param boardY number|nil 棋盘 Y 坐标（用于定位）
function M.startCombo(combo, screenW, boardY)
    if combo < 2 then
        M.comboAnim = nil
        return
    end
    M.comboAnim = {
        text = combo .. " 连锁！",
        x = screenW / 2,
        y = boardY and (boardY - 30) or 200,
        alpha = 1.0,
        elapsed = 0,
        duration = ANIM.DURATION_LONG,
        combo = combo,
    }
end

-- ============================================================================
-- 查询 / 更新 / 清理
-- ============================================================================

--- 是否有动画在播放
function M.isAnimating()
    return M.progress < 1.0 and
        (M.swapAnim ~= nil or #M.elimAnims > 0 or #M.fallAnims > 0 or M.shakeAnim ~= nil)
end

--- 更新动画进度
---@param dt number
---@return boolean finished 是否完成
function M.update(dt)
    if M.duration <= 0 then
        M.progress = 1.0
    else
        M.progress = math.min(1.0, M.progress + dt / M.duration)
    end

    -- 彩虹方块动画时间
    M.rainbowTime = M.rainbowTime + dt

    -- 更新 combo 动画
    if M.comboAnim then
        M.comboAnim.elapsed = M.comboAnim.elapsed + dt
        M.comboAnim.alpha = math.max(0, 1.0 - M.comboAnim.elapsed / M.comboAnim.duration)
        M.comboAnim.y = M.comboAnim.y - dt * 40
        if M.comboAnim.elapsed >= M.comboAnim.duration then
            M.comboAnim = nil
        end
    end

    return M.progress >= 1.0
end

--- 清理动画（不含 combo）
function M.clearAnims()
    M.swapAnim = nil
    M.shakeAnim = nil
    M.elimAnims = {}
    M.fallAnims = {}
    M.progress = 0
end

--- 重置所有状态
function M.resetAll()
    M.clearAnims()
    M.comboAnim = nil
    M.rainbowTime = 0
end

return M
