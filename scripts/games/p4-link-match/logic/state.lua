--- 连连看 - 状态机
--- 职责：管理游戏状态转移，防止动画期间并发点击
--- 状态：Idle / OneSelected / Checking / Eliminating / Shuffling / Cleared / Failed

local M = {}

M.IDLE = "Idle"
M.ONE_SELECTED = "OneSelected"
M.CHECKING = "Checking"
M.ELIMINATING = "Eliminating"
M.SHUFFLING = "Shuffling"
M.CLEARED = "Cleared"
M.FAILED = "Failed"

--- 创建状态机实例
---@return table
function M.new()
    return {
        current = M.IDLE,
    }
end

--- 是否允许方块点击
---@param sm table
---@return boolean
function M.canClick(sm)
    return sm.current == M.IDLE or sm.current == M.ONE_SELECTED
end

--- Idle -> OneSelected
---@param sm table
---@return boolean
function M.toOneSelected(sm)
    if sm.current ~= M.IDLE then return false end
    sm.current = M.ONE_SELECTED
    return true
end

--- OneSelected -> Checking
---@param sm table
---@return boolean
function M.toChecking(sm)
    if sm.current ~= M.ONE_SELECTED then return false end
    sm.current = M.CHECKING
    return true
end

--- Checking -> Eliminating
---@param sm table
---@return boolean
function M.toEliminating(sm)
    if sm.current ~= M.CHECKING then return false end
    sm.current = M.ELIMINATING
    return true
end

--- Checking -> OneSelected（配对失败，第二个成为新选中）
---@param sm table
---@return boolean
function M.checkFailToOneSelected(sm)
    if sm.current ~= M.CHECKING then return false end
    sm.current = M.ONE_SELECTED
    return true
end

--- Eliminating -> Idle（消除完毕，继续游戏）
---@param sm table
---@return boolean
function M.eliminateToIdle(sm)
    if sm.current ~= M.ELIMINATING then return false end
    sm.current = M.IDLE
    return true
end

--- Eliminating -> Cleared（最后一对消除完毕）
---@param sm table
---@return boolean
function M.toCleared(sm)
    if sm.current ~= M.ELIMINATING then return false end
    sm.current = M.CLEARED
    return true
end

--- Idle/OneSelected -> Shuffling
---@param sm table
---@return boolean
function M.toShuffling(sm)
    if sm.current ~= M.IDLE and sm.current ~= M.ONE_SELECTED then return false end
    sm.current = M.SHUFFLING
    return true
end

--- Shuffling -> Idle
---@param sm table
---@return boolean
function M.shuffleToIdle(sm)
    if sm.current ~= M.SHUFFLING then return false end
    sm.current = M.IDLE
    return true
end

--- 任意状态 -> Failed
---@param sm table
function M.toFailed(sm)
    sm.current = M.FAILED
end

--- 重置到 Idle（Restart）
---@param sm table
function M.reset(sm)
    sm.current = M.IDLE
end

return M
