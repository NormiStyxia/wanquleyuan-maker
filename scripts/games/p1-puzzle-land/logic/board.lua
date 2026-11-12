--- 推箱子棋盘逻辑引擎
--- 职责：状态管理、移动/推动/冰面滑行规则、撤销/重置、胜利判定
--- 约束：纯数据逻辑，零渲染依赖，所有坐标 1-based

local M = {}
M.__index = M

-- 方向定义

---@type table<string, number[]>
local DIR_OFFSET = {
    up    = { 0, -1 },
    down  = { 0,  1 },
    left  = { -1, 0 },
    right = {  1, 0 },
}

-- 构造与重置

--- 创建棋盘实例
---@param levelData table 由 level-loader 加载的 1-based 关卡数据
---@return table board
function M.new(levelData)
    local self = setmetatable({}, M)
    self.levelData = levelData
    self:reset()
    return self
end

--- 重置到初始状态
---@return table[] events
function M:reset()
    self.width = self.levelData.width
    self.height = self.levelData.height
    self.player = { self.levelData.player[1], self.levelData.player[2] }
    self.boxes = {}
    for i, b in ipairs(self.levelData.boxes) do
        self.boxes[i] = { b[1], b[2] }
    end
    self.wallSet = self.levelData.wallSet
    self.iceSet = self.levelData.iceSet
    self.targetSet = self.levelData.targetSet
    self.portalMap = self.levelData.portalMap or {}
    self.portalTargetMap = self.levelData.portalTargetMap or {}
    self.steps = 0
    self.undoStack = {}
    self.won = false

    return { { type = "reset" } }
end

-- 查询

--- 位置的 key 字符串
---@param x number
---@param y number
---@return string
local function posKey(x, y)
    return x .. "," .. y
end

--- 是否在棋盘范围内
---@param x number
---@param y number
---@return boolean
function M:inBounds(x, y)
    return x >= 1 and x <= self.width and y >= 1 and y <= self.height
end

--- 是否是墙
---@param x number
---@param y number
---@return boolean
function M:isWall(x, y)
    return self.wallSet[posKey(x, y)] == true
end

--- 是否是冰面
---@param x number
---@param y number
---@return boolean
function M:isIce(x, y)
    return self.iceSet[posKey(x, y)] == true
end

--- 是否是目标点
---@param x number
---@param y number
---@return boolean
function M:isTarget(x, y)
    return self.targetSet[posKey(x, y)] == true
end

--- 获取指定位置的箱子索引，无则返回 nil
---@param x number
---@param y number
---@return number|nil
function M:getBoxAt(x, y)
    for i, b in ipairs(self.boxes) do
        if b[1] == x and b[2] == y then
            return i
        end
    end
    return nil
end

--- 格子是否可进入（空地、冰面、目标点都算可进入，墙和越界不行）
---@param x number
---@param y number
---@return boolean
function M:isCellFree(x, y)
    if not self:inBounds(x, y) then return false end
    if self:isWall(x, y) then return false end
    if self:getBoxAt(x, y) then return false end
    -- 玩家占据的位置不算 free（用于箱子滑行判定）
    if self.player[1] == x and self.player[2] == y then return false end
    return true
end

--- 箱子是否可进入目标格（不检查玩家位置）
---@param x number
---@param y number
---@return boolean
function M:canBoxEnter(x, y)
    if not self:inBounds(x, y) then return false end
    if self:isWall(x, y) then return false end
    if self:getBoxAt(x, y) then return false end
    return true
end

--- 获取传送门信息（如果该位置有传送门）
---@param x number
---@param y number
---@return table|nil portal { color, destX, destY }
function M:getPortal(x, y)
    return self.portalMap[posKey(x, y)]
end

--- 所有目标点是否被箱子覆盖
---@return boolean
function M:isComplete()
    for _, t in ipairs(self.levelData.targets) do
        if not self:getBoxAt(t[1], t[2]) then
            return false
        end
    end
    return true
end

--- 计算星级
---@return number stars 1-3
function M:calcStars()
    local rec = self.levelData.recommendedSteps
    if rec <= 0 then return 1 end
    if self.steps <= math.ceil(rec * 1.2) then return 3 end
    if self.steps <= math.ceil(rec * 1.6) then return 2 end
    return 1
end

-- 状态快照（用于 undo）

---@return table snapshot
local function captureSnapshot(board)
    local boxesCopy = {}
    for i, b in ipairs(board.boxes) do
        boxesCopy[i] = { b[1], b[2] }
    end
    return {
        player = { board.player[1], board.player[2] },
        boxes = boxesCopy,
        steps = board.steps,
    }
end

-- 冰面滑行

--- 箱子在冰面上滑行，返回事件列表
---@param boxIdx number
---@param dx number
---@param dy number
---@return table[] events
function M:slideBox(boxIdx, dx, dy)
    local events = {}
    local box = self.boxes[boxIdx]

    while true do
        local nx, ny = box[1] + dx, box[2] + dy
        -- 还在冰面上且前方空闲才继续滑行
        if not self:isIce(box[1], box[2]) then break end
        if not self:canBoxEnter(nx, ny) then
            -- 箱子在冰面上撞到障碍物停下来
            local stopReason = "unknown"
            if not self:inBounds(nx, ny) or self:isWall(nx, ny) then
                stopReason = "wall"
            elseif self:getBoxAt(nx, ny) then
                stopReason = "box"
            end
            events[#events + 1] = {
                type = "box_stopped", boxIdx = boxIdx,
                pos = { box[1], box[2] }, dir = { dx, dy },
                stopReason = stopReason,
            }
            break
        end

        local from = { box[1], box[2] }
        box[1], box[2] = nx, ny
        events[#events + 1] = { type = "box_slide", boxIdx = boxIdx, from = from, to = { nx, ny }, reason = "ice" }
    end

    return events
end

--- 玩家在冰面上滑行，返回事件列表
---@param dx number
---@param dy number
---@return table[] events
function M:slidePlayer(dx, dy)
    local events = {}

    while true do
        local nx, ny = self.player[1] + dx, self.player[2] + dy
        if not self:isIce(self.player[1], self.player[2]) then break end
        if not self:inBounds(nx, ny) then break end
        if self:isWall(nx, ny) then break end
        if self:getBoxAt(nx, ny) then break end

        local from = { self.player[1], self.player[2] }
        self.player[1], self.player[2] = nx, ny
        events[#events + 1] = { type = "player_slide", from = from, to = { nx, ny }, reason = "ice" }
    end

    return events
end

-- 核心移动逻辑

--- 执行一次移动（原子操作）
---@param dir string "up"|"down"|"left"|"right"
---@return table[] events 事件列表
function M:applyMove(dir)
    if self.won then return { { type = "move_blocked" } } end

    local offset = DIR_OFFSET[dir]
    if not offset then return { { type = "move_blocked" } } end

    local dx, dy = offset[1], offset[2]
    local nx, ny = self.player[1] + dx, self.player[2] + dy

    -- 边界/墙体检查
    if not self:inBounds(nx, ny) or self:isWall(nx, ny) then
        return { { type = "move_blocked", reason = "wall", dir = dir } }
    end

    -- 检查前方是否有箱子
    local boxIdx = self:getBoxAt(nx, ny)
    if boxIdx then
        -- 箱子前方必须可进入
        local bx, by = nx + dx, ny + dy
        if not self:canBoxEnter(bx, by) then
            return { { type = "move_blocked", reason = "box_stuck", dir = dir,
                       boxIdx = boxIdx, boxPos = { nx, ny } } }
        end
    end

    -- 合法移动，保存 undo 快照
    local snapshot = captureSnapshot(self)
    self.undoStack[#self.undoStack + 1] = snapshot

    local events = {}

    -- 推箱子
    if boxIdx then
        local bx, by = nx + dx, ny + dy
        local oldBoxPos = { self.boxes[boxIdx][1], self.boxes[boxIdx][2] }
        local wasOnTarget = self:isTarget(oldBoxPos[1], oldBoxPos[2])

        self.boxes[boxIdx][1], self.boxes[boxIdx][2] = bx, by
        events[#events + 1] = { type = "box_push", boxIdx = boxIdx, from = oldBoxPos, to = { bx, by } }

        if wasOnTarget then
            events[#events + 1] = { type = "box_off_target", pos = { oldBoxPos[1], oldBoxPos[2] } }
        end

        -- 箱子冰面滑行
        local slideEvents = self:slideBox(boxIdx, dx, dy)
        for _, e in ipairs(slideEvents) do
            events[#events + 1] = e
        end

        -- 箱子传送门检测（滑行结束后检测最终位置）
        local finalBox = self.boxes[boxIdx]
        local boxPortal = self:getPortal(finalBox[1], finalBox[2])
        if boxPortal and self:canBoxEnter(boxPortal.destX, boxPortal.destY) then
            local fromPos = { finalBox[1], finalBox[2] }
            finalBox[1], finalBox[2] = boxPortal.destX, boxPortal.destY
            events[#events + 1] = {
                type = "box_teleport", boxIdx = boxIdx,
                from = fromPos, to = { finalBox[1], finalBox[2] },
                color = boxPortal.color,
            }
        end

        -- 箱子最终位置是否在目标点上
        finalBox = self.boxes[boxIdx]
        if self:isTarget(finalBox[1], finalBox[2]) then
            events[#events + 1] = { type = "box_on_target", pos = { finalBox[1], finalBox[2] } }
            -- 狐狸夸奖触发
            local FoxMascot = require("shared.components.fox-mascot")
            FoxMascot.notifySuccess()
        end

        -- 推动完成事件（用于角色演出）
        events[#events + 1] = { type = "push_complete", dir = dir, boxIdx = boxIdx }
    end

    -- 移动玩家
    local oldPlayer = { self.player[1], self.player[2] }
    self.player[1], self.player[2] = nx, ny
    -- 玩家移动事件插入到开头
    table.insert(events, 1, { type = "player_move", from = oldPlayer, to = { nx, ny } })

    -- 玩家冰面滑行
    local playerSlideEvents = self:slidePlayer(dx, dy)
    for _, e in ipairs(playerSlideEvents) do
        events[#events + 1] = e
    end

    -- 玩家传送门检测（移动/滑行结束后检测最终位置）
    local playerPortal = self:getPortal(self.player[1], self.player[2])
    if playerPortal then
        local destX, destY = playerPortal.destX, playerPortal.destY
        -- 目标位置必须空闲（无箱子、无墙）
        if self:inBounds(destX, destY) and not self:isWall(destX, destY) and not self:getBoxAt(destX, destY) then
            local fromPos = { self.player[1], self.player[2] }
            self.player[1], self.player[2] = destX, destY
            events[#events + 1] = {
                type = "player_teleport",
                from = fromPos, to = { destX, destY },
                color = playerPortal.color,
            }
        end
    end

    -- 步数 +1
    self.steps = self.steps + 1

    -- 胜利判定
    if self:isComplete() then
        self.won = true
        local stars = self:calcStars()
        events[#events + 1] = {
            type = "level_complete",
            steps = self.steps,
            stars = stars,
        }
    end

    return events
end

-- 撤销与重做

--- 撤销一步
---@return table[] events
function M:undo()
    if #self.undoStack == 0 then return {} end

    local prev = self.undoStack[#self.undoStack]
    self.undoStack[#self.undoStack] = nil

    local events = {}

    -- 玩家位置回退
    if self.player[1] ~= prev.player[1] or self.player[2] ~= prev.player[2] then
        events[#events + 1] = {
            type = "player_move",
            from = { self.player[1], self.player[2] },
            to = { prev.player[1], prev.player[2] },
        }
    end

    -- 箱子位置回退
    for i, box in ipairs(self.boxes) do
        local pb = prev.boxes[i]
        if box[1] ~= pb[1] or box[2] ~= pb[2] then
            events[#events + 1] = {
                type = "box_push",
                boxIdx = i,
                from = { box[1], box[2] },
                to = { pb[1], pb[2] },
            }
        end
    end

    -- 恢复状态
    self.player = prev.player
    self.boxes = prev.boxes
    self.steps = prev.steps
    self.won = false

    return events
end

-- 导出

--- 导出当前状态快照（用于存档/回放）
---@return table
function M:exportSnapshot()
    local levelLoader = require("games.p1-puzzle-land.logic.level-loader")
    local boxesExt = {}
    for i, b in ipairs(self.boxes) do
        boxesExt[i] = levelLoader.toExternal(b)
    end

    return {
        levelId = self.levelData.id,
        step = self.steps,
        player = levelLoader.toExternal(self.player),
        boxes = boxesExt,
        isWin = self.won,
    }
end

return M
