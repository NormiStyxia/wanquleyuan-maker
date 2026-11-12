--- 推箱子编辑器 - 网格管理器
--- 职责：网格初始化、实体管理、元素放置、尺寸调节
--- 约束：通过 state 表引用共享编辑器状态

local logger = require("shared.utils.logger")
local MODULE = "grid-manager"
local M = {}

-- ============================================================================
-- 辅助：查找/移除元素
-- ============================================================================

--- 查找位置列表中是否存在 (x,y)
---@param list number[][]
---@param x number
---@param y number
---@return number|nil index
function M.findInList(list, x, y)
    for i, pos in ipairs(list) do
        if pos[1] == x and pos[2] == y then
            return i
        end
    end
    return nil
end

--- 从位置列表中移除 (x,y)
---@param list number[][]
---@param x number
---@param y number
function M.removeFromList(list, x, y)
    local idx = M.findInList(list, x, y)
    if idx then
        table.remove(list, idx)
    end
end

--- 清除某个格子上的所有元素（box/target/player/portal/portalTarget）
---@param state table 共享编辑器状态
---@param x number
---@param y number
function M.clearEntitiesAt(state, x, y)
    M.removeFromList(state.boxPositions, x, y)
    M.removeFromList(state.targetPositions, x, y)
    if state.playerPos and state.playerPos[1] == x and state.playerPos[2] == y then
        state.playerPos = nil
    end
    -- 清除传送门/传送目标
    for _, color in ipairs({ "red", "green", "blue" }) do
        local pp = state.portalPositions[color]
        if pp and pp[1] == x and pp[2] == y then
            state.portalPositions[color] = nil
        end
        local pt = state.portalTargetPositions[color]
        if pt and pt[1] == x and pt[2] == y then
            state.portalTargetPositions[color] = nil
        end
    end
end

-- ============================================================================
-- 网格操作
-- ============================================================================

--- 初始化空白网格
---@param state table 共享编辑器状态
function M.initGrid(state)
    state.grid = {}
    for y = 1, state.gridH do
        state.grid[y] = {}
        for x = 1, state.gridW do
            if x == 1 or x == state.gridW or y == 1 or y == state.gridH then
                state.grid[y][x] = "wall"
            else
                state.grid[y][x] = "floor"
            end
        end
    end
    state.playerPos = nil
    state.boxPositions = {}
    state.targetPositions = {}
    state.portalPositions = {}
    state.portalTargetPositions = {}
    state.exportMessage = nil
    state.exportMessageTimer = 0
end

--- 在网格上放置元素
---@param state table 共享编辑器状态
---@param gx number 1-based grid x
---@param gy number 1-based grid y
function M.placeAt(state, gx, gy)
    if gx < 1 or gx > state.gridW or gy < 1 or gy > state.gridH then return end

    local tool = state.currentTool
    local grid = state.grid

    if tool == "wall" then
        M.clearEntitiesAt(state, gx, gy)
        grid[gy][gx] = "wall"
    elseif tool == "floor" then
        M.clearEntitiesAt(state, gx, gy)
        grid[gy][gx] = "floor"
    elseif tool == "ice" then
        M.clearEntitiesAt(state, gx, gy)
        grid[gy][gx] = "ice"
    elseif tool == "box" then
        if grid[gy][gx] == "wall" then return end
        M.removeFromList(state.boxPositions, gx, gy)
        if state.playerPos and state.playerPos[1] == gx and state.playerPos[2] == gy then
            state.playerPos = nil
        end
        state.boxPositions[#state.boxPositions + 1] = { gx, gy }
    elseif tool == "target" then
        if grid[gy][gx] == "wall" then return end
        M.removeFromList(state.targetPositions, gx, gy)
        if state.playerPos and state.playerPos[1] == gx and state.playerPos[2] == gy then
            state.playerPos = nil
        end
        state.targetPositions[#state.targetPositions + 1] = { gx, gy }
    elseif tool == "player" then
        if grid[gy][gx] == "wall" then return end
        M.removeFromList(state.boxPositions, gx, gy)
        M.removeFromList(state.targetPositions, gx, gy)
        state.playerPos = { gx, gy }
    elseif tool == "eraser" then
        M.clearEntitiesAt(state, gx, gy)
        grid[gy][gx] = "floor"
    else
        -- 传送门 / 传送目标工具
        local portalColor = state.TOOL_PORTAL_COLOR[tool]
        if portalColor then
            if grid[gy][gx] == "wall" then return end
            local isPortal = tool:sub(1, 6) == "portal"
            if isPortal then
                state.portalPositions[portalColor] = { gx, gy }
            else
                state.portalTargetPositions[portalColor] = { gx, gy }
            end
        end
    end
end

--- 调整网格宽度
---@param state table 共享编辑器状态
---@param delta integer 调整量
function M.adjustWidth(state, delta)
    local targetW = state.gridW + math.floor(delta)
    local newW = math.max(state.MIN_SIZE, math.min(state.MAX_SIZE, targetW))
    if newW == state.gridW then return end
    local grid = state.grid

    if newW > state.gridW then
        for y = 1, state.gridH do
            for x = state.gridW + 1, newW do
                if y == 1 or y == state.gridH or x == newW then
                    grid[y][x] = "wall"
                else
                    grid[y][x] = "floor"
                end
            end
            if state.gridW >= 2 then
                if y ~= 1 and y ~= state.gridH then
                    grid[y][state.gridW] = "floor"
                end
            end
        end
    else
        for y = 1, state.gridH do
            for x = newW + 1, state.gridW do
                grid[y][x] = nil
                M.clearEntitiesAt(state, x, y)
            end
            if y == 1 or y == state.gridH then
                grid[y][newW] = "wall"
            else
                grid[y][newW] = "wall"
            end
        end
    end

    state.gridW = newW
    logger.info(MODULE, "adjustWidth", "new grid=" .. state.gridW .. "x" .. state.gridH)
end

--- 调整网格高度
---@param state table 共享编辑器状态
---@param delta integer 调整量
function M.adjustHeight(state, delta)
    local targetH = state.gridH + math.floor(delta)
    local newH = math.max(state.MIN_SIZE, math.min(state.MAX_SIZE, targetH))
    if newH == state.gridH then return end
    local grid = state.grid

    if newH > state.gridH then
        for x = 2, state.gridW - 1 do
            grid[state.gridH][x] = "floor"
        end
        for y = state.gridH + 1, newH do
            grid[y] = {}
            for x = 1, state.gridW do
                if x == 1 or x == state.gridW or y == newH then
                    grid[y][x] = "wall"
                else
                    grid[y][x] = "floor"
                end
            end
        end
    else
        for y = newH + 1, state.gridH do
            for x = 1, state.gridW do
                M.clearEntitiesAt(state, x, y)
            end
            grid[y] = nil
        end
        for x = 1, state.gridW do
            grid[newH][x] = "wall"
        end
    end

    state.gridH = newH
    logger.info(MODULE, "adjustHeight", "new grid=" .. state.gridW .. "x" .. state.gridH)
end

return M
