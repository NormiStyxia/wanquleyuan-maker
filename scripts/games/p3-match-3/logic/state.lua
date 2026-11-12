--- 消消乐 - 状态机
--- 职责：管理游戏状态转移，防止动画期间并发交换
--- 状态：Idle / Swapping / SwapBack / Eliminating / Falling / ChainCheck / Settled / Cleared / Failed

local M = {}

-- 状态常量
M.IDLE = "Idle"
M.SWAPPING = "Swapping"
M.SWAP_BACK = "SwapBack"
M.ELIMINATING = "Eliminating"
M.FALLING = "Falling"
M.CHAIN_CHECK = "ChainCheck"
M.SETTLED = "Settled"
M.CLEARED = "Cleared"
M.FAILED = "Failed"

--- 创建状态机实例
---@return table
function M.new()
    return {
        current = M.IDLE,
    }
end

--- 当前是否可接受玩家交换操作
---@param sm table
---@return boolean
function M.canSwap(sm)
    return sm.current == M.IDLE
end

--- 是否为结束状态
---@param sm table
---@return boolean
function M.isEnded(sm)
    return sm.current == M.CLEARED or sm.current == M.FAILED
end

--- Idle -> Swapping
---@param sm table
---@return boolean
function M.toSwapping(sm)
    if sm.current ~= M.IDLE then return false end
    sm.current = M.SWAPPING
    return true
end

--- Swapping -> Eliminating（有效交换）
---@param sm table
---@return boolean
function M.toEliminating(sm)
    if sm.current ~= M.SWAPPING and sm.current ~= M.CHAIN_CHECK then return false end
    sm.current = M.ELIMINATING
    return true
end

--- Swapping -> SwapBack（无效交换）
---@param sm table
---@return boolean
function M.toSwapBack(sm)
    if sm.current ~= M.SWAPPING then return false end
    sm.current = M.SWAP_BACK
    return true
end

--- SwapBack -> Idle
---@param sm table
---@return boolean
function M.swapBackToIdle(sm)
    if sm.current ~= M.SWAP_BACK then return false end
    sm.current = M.IDLE
    return true
end

--- Eliminating -> Falling
---@param sm table
---@return boolean
function M.toFalling(sm)
    if sm.current ~= M.ELIMINATING then return false end
    sm.current = M.FALLING
    return true
end

--- Falling -> ChainCheck
---@param sm table
---@return boolean
function M.toChainCheck(sm)
    if sm.current ~= M.FALLING then return false end
    sm.current = M.CHAIN_CHECK
    return true
end

--- ChainCheck -> Settled（无新消除）
---@param sm table
---@return boolean
function M.toSettled(sm)
    if sm.current ~= M.CHAIN_CHECK then return false end
    sm.current = M.SETTLED
    return true
end

--- Settled -> Idle / Cleared / Failed
---@param sm table
---@param nextState string
---@return boolean
function M.fromSettled(sm, nextState)
    if sm.current ~= M.SETTLED then return false end
    if nextState ~= M.IDLE and nextState ~= M.CLEARED and nextState ~= M.FAILED then
        return false
    end
    sm.current = nextState
    return true
end

--- 强制重置到 Idle
---@param sm table
function M.reset(sm)
    sm.current = M.IDLE
end

return M
