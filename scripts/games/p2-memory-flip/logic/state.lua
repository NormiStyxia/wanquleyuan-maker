--- 记忆翻牌 - 状态机
--- 职责：管理游戏状态转移，防止并发翻牌
--- 状态：Idle / OneFlipped / TwoFlippedChecking / Resolving / Cleared

local M = {}

-- 状态常量
M.IDLE = "Idle"
M.ONE_FLIPPED = "OneFlipped"
M.TWO_FLIPPED_CHECKING = "TwoFlippedChecking"
M.RESOLVING = "Resolving"
M.CLEARED = "Cleared"

--- 创建状态机实例
---@return table
function M.new()
    return {
        current = M.IDLE,
    }
end

--- 是否允许翻牌点击
---@param sm table 状态机实例
---@return boolean
function M.canFlip(sm)
    return sm.current == M.IDLE or sm.current == M.ONE_FLIPPED
end

--- 转换到 OneFlipped
---@param sm table
---@return boolean success
function M.toOneFlipped(sm)
    if sm.current ~= M.IDLE then return false end
    sm.current = M.ONE_FLIPPED
    return true
end

--- 转换到 TwoFlippedChecking
---@param sm table
---@return boolean success
function M.toTwoFlippedChecking(sm)
    if sm.current ~= M.ONE_FLIPPED then return false end
    sm.current = M.TWO_FLIPPED_CHECKING
    return true
end

--- 转换到 Resolving
---@param sm table
---@return boolean success
function M.toResolving(sm)
    if sm.current ~= M.TWO_FLIPPED_CHECKING then return false end
    sm.current = M.RESOLVING
    return true
end

--- 从 Resolving 回到 Idle
---@param sm table
---@return boolean success
function M.toIdle(sm)
    if sm.current ~= M.RESOLVING then return false end
    sm.current = M.IDLE
    return true
end

--- 转换到 Cleared
---@param sm table
---@return boolean success
function M.toCleared(sm)
    if sm.current ~= M.RESOLVING then return false end
    sm.current = M.CLEARED
    return true
end

--- 重置到 Idle
---@param sm table
function M.reset(sm)
    sm.current = M.IDLE
end

return M
