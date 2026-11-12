--- 连连看 - 路径搜索算法
--- 职责：判断两个方块是否可通过 <=2 拐弯路径连通
--- 纯 Lua 逻辑，禁止引入渲染 API
---
--- 坐标约定：逻辑坐标 0-based (x,y)，x=列(右), y=行(下)
--- 外围虚拟空格：x in [-1, cols], y in [-1, rows]（始终视为空）
--- Lua 数组映射：board[y+1][x+1]

local M = {}

-- 四方向：右/下/左/上
local DIRS = {
    { dx = 1, dy = 0 },
    { dx = 0, dy = 1 },
    { dx = -1, dy = 0 },
    { dx = 0, dy = -1 },
}

--- 检查某个位置是否为空（可通行）
--- 外围虚拟空格始终为空，起点/终点被视为非空（不可穿过）
---@param board table 二维数组 board[y+1][x+1]，0=空, >0=方块
---@param x number 逻辑 x (0-based)
---@param y number 逻辑 y (0-based)
---@param rows number 棋盘行数
---@param cols number 棋盘列数
---@return boolean
local function isEmpty(board, x, y, rows, cols)
    -- 外围虚拟空格始终可通行
    if x < 0 or x >= cols or y < 0 or y >= rows then
        return true
    end
    return board[y + 1][x + 1] == 0
end

--- 沿某方向从 (sx,sy) 延伸，返回所有可达的空格坐标列表
--- 不包括起始点本身，遇到非空格停止
---@param board table
---@param sx number
---@param sy number
---@param dir table { dx, dy }
---@param rows number
---@param cols number
---@return table[] 可达坐标 { {x,y}, ... }
local function raycast(board, sx, sy, dir, rows, cols)
    local result = {}
    local x, y = sx + dir.dx, sy + dir.dy
    -- 限制外围范围：最多延伸到 -1 和 rows/cols
    while x >= -1 and x <= cols and y >= -1 and y <= rows do
        if not isEmpty(board, x, y, rows, cols) then
            break
        end
        result[#result + 1] = { x = x, y = y }
        x = x + dir.dx
        y = y + dir.dy
    end
    return result
end

--- 查找两点间的连通路径（<=2 拐弯）
--- 策略：按拐弯次数分层搜索（0拐 → 1拐 → 2拐），优先返回拐弯最少的路径
---@param board table 二维数组，board[y+1][x+1]，0=空, >0=方块
---@param posA table { x, y } 起点（0-based 逻辑坐标）
---@param posB table { x, y } 终点（0-based 逻辑坐标）
---@param rows number 棋盘行数
---@param cols number 棋盘列数
---@return table|nil path 路径节点数组 { {x,y}, ... }（含起终点），nil=不连通
---@return number|nil turnCount 拐弯次数
function M.findPath(board, posA, posB, rows, cols)
    local ax, ay = posA.x, posA.y
    local bx, by = posB.x, posB.y

    -- 同一位置
    if ax == bx and ay == by then
        return nil, nil
    end

    -- 0 拐：直连（A 和 B 在同一行或同一列，中间全空）
    if ax == bx then
        -- 同列，检查 y 方向
        local minY = math.min(ay, by)
        local maxY = math.max(ay, by)
        local clear = true
        for y = minY + 1, maxY - 1 do
            if not isEmpty(board, ax, y, rows, cols) then
                clear = false
                break
            end
        end
        if clear then
            return { { x = ax, y = ay }, { x = bx, y = by } }, 0
        end
    elseif ay == by then
        -- 同行，检查 x 方向
        local minX = math.min(ax, bx)
        local maxX = math.max(ax, bx)
        local clear = true
        for x = minX + 1, maxX - 1 do
            if not isEmpty(board, x, ay, rows, cols) then
                clear = false
                break
            end
        end
        if clear then
            return { { x = ax, y = ay }, { x = bx, y = by } }, 0
        end
    end

    -- 1 拐：L 形（经过一个拐点）
    -- 拐点为 (ax, by) 或 (bx, ay)
    local function tryOneCorner(cx, cy)
        if not isEmpty(board, cx, cy, rows, cols) then
            return false
        end
        -- 检查 A->拐点 直连
        local clearA = true
        if cx == ax then
            local minY = math.min(ay, cy)
            local maxY = math.max(ay, cy)
            for y = minY + 1, maxY - 1 do
                if not isEmpty(board, ax, y, rows, cols) then
                    clearA = false; break
                end
            end
        else
            local minX = math.min(ax, cx)
            local maxX = math.max(ax, cx)
            for x = minX + 1, maxX - 1 do
                if not isEmpty(board, x, ay, rows, cols) then
                    clearA = false; break
                end
            end
        end
        if not clearA then return false end

        -- 检查 拐点->B 直连
        local clearB = true
        if cx == bx then
            local minY = math.min(cy, by)
            local maxY = math.max(cy, by)
            for y = minY + 1, maxY - 1 do
                if not isEmpty(board, bx, y, rows, cols) then
                    clearB = false; break
                end
            end
        else
            local minX = math.min(cx, bx)
            local maxX = math.max(cx, bx)
            for x = minX + 1, maxX - 1 do
                if not isEmpty(board, x, cy, rows, cols) then
                    clearB = false; break
                end
            end
        end
        return clearB
    end

    -- 拐点1: (ax, by)
    if tryOneCorner(ax, by) then
        return {
            { x = ax, y = ay },
            { x = ax, y = by },
            { x = bx, y = by },
        }, 1
    end
    -- 拐点2: (bx, ay)
    if tryOneCorner(bx, ay) then
        return {
            { x = ax, y = ay },
            { x = bx, y = ay },
            { x = bx, y = by },
        }, 1
    end

    -- 2 拐：Z/U 形（经过两个拐点，3段直线）
    -- 从 A 向四方向 raycast，对每个可达空格 C，检查 C->B 是否 1 拐可达
    local bestPath = nil
    local bestLen = math.huge

    for _, dir in ipairs(DIRS) do
        local reachable = raycast(board, ax, ay, dir, rows, cols)
        for _, c in ipairs(reachable) do
            -- 从 C 到 B 尝试 1 拐连接
            -- 拐点为 (c.x, by) 或 (bx, c.y)
            local function tryTwoCorner(mx, my)
                -- C -> M 直连
                if not isEmpty(board, mx, my, rows, cols) then return nil end

                local clearCM = true
                if mx == c.x then
                    local minY = math.min(c.y, my)
                    local maxY = math.max(c.y, my)
                    for y = minY + 1, maxY - 1 do
                        if not isEmpty(board, c.x, y, rows, cols) then
                            clearCM = false; break
                        end
                    end
                elseif my == c.y then
                    local minX = math.min(c.x, mx)
                    local maxX = math.max(c.x, mx)
                    for x = minX + 1, maxX - 1 do
                        if not isEmpty(board, x, c.y, rows, cols) then
                            clearCM = false; break
                        end
                    end
                else
                    return nil -- C 和 M 不共线
                end
                if not clearCM then return nil end

                -- M -> B 直连
                local clearMB = true
                if mx == bx then
                    local minY = math.min(my, by)
                    local maxY = math.max(my, by)
                    for y = minY + 1, maxY - 1 do
                        if not isEmpty(board, bx, y, rows, cols) then
                            clearMB = false; break
                        end
                    end
                elseif my == by then
                    local minX = math.min(mx, bx)
                    local maxX = math.max(mx, bx)
                    for x = minX + 1, maxX - 1 do
                        if not isEmpty(board, x, by, rows, cols) then
                            clearMB = false; break
                        end
                    end
                else
                    return nil
                end
                if not clearMB then return nil end

                return {
                    { x = ax, y = ay },
                    { x = c.x, y = c.y },
                    { x = mx, y = my },
                    { x = bx, y = by },
                }
            end

            -- 尝试两种拐点方向
            local p1 = tryTwoCorner(c.x, by)
            if p1 then
                local len = math.abs(c.x - ax) + math.abs(c.y - ay) +
                    math.abs(c.x - c.x) + math.abs(by - c.y) +
                    math.abs(bx - c.x) + math.abs(by - by)
                if len < bestLen then
                    bestPath = p1
                    bestLen = len
                end
            end

            local p2 = tryTwoCorner(bx, c.y)
            if p2 then
                local len = math.abs(c.x - ax) + math.abs(c.y - ay) +
                    math.abs(bx - c.x) + math.abs(c.y - c.y) +
                    math.abs(bx - bx) + math.abs(by - c.y)
                if len < bestLen then
                    bestPath = p2
                    bestLen = len
                end
            end
        end
    end

    if bestPath then
        return bestPath, 2
    end

    return nil, nil
end

--- 检查棋盘上是否存在至少一个可消除的配对
---@param board table 二维数组
---@param rows number
---@param cols number
---@return table|nil pair { posA, posB, path, turnCount } 找到的第一对
function M.findAnyPair(board, rows, cols)
    -- 按 patternId 分组
    local groups = {}
    for y = 0, rows - 1 do
        for x = 0, cols - 1 do
            local pid = board[y + 1][x + 1]
            if pid > 0 then
                if not groups[pid] then groups[pid] = {} end
                groups[pid][#groups[pid] + 1] = { x = x, y = y }
            end
        end
    end

    -- 对每组检查是否有可连通的配对
    for _, positions in pairs(groups) do
        for i = 1, #positions - 1 do
            for j = i + 1, #positions do
                local path, turns = M.findPath(board, positions[i], positions[j], rows, cols)
                if path then
                    return {
                        posA = positions[i],
                        posB = positions[j],
                        path = path,
                        turnCount = turns,
                    }
                end
            end
        end
    end

    return nil
end

return M
