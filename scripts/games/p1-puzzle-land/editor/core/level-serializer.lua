--- 推箱子编辑器 - 关卡序列化器
--- 职责：导出/导入关卡数据、构建可玩关卡
--- 约束：通过 state 表引用共享编辑器状态

local levelLoader = require("games.p1-puzzle-land.logic.level-loader")
local logger = require("shared.utils.logger")
local MODULE = "level-serializer"
local M = {}

--- 导出为关卡数据格式（0-based，匹配 data/levels.lua）
---@param state table 共享编辑器状态
---@return string 格式化的 Lua 表字符串
function M.export(state)
    local parts = {}
    local function add(s) parts[#parts + 1] = s end

    -- 收集墙壁坐标
    local walls = {}
    local iceList = {}
    for y = 1, state.gridH do
        for x = 1, state.gridW do
            local cell = state.grid[y][x]
            if cell == "wall" then
                walls[#walls + 1] = "{" .. (x - 1) .. "," .. (y - 1) .. "}"
            elseif cell == "ice" then
                iceList[#iceList + 1] = "{" .. (x - 1) .. "," .. (y - 1) .. "}"
            end
        end
    end

    -- 玩家坐标（0-based）
    local px, py = 0, 0
    if state.playerPos then
        px = state.playerPos[1] - 1
        py = state.playerPos[2] - 1
    end

    add("{ width = " .. state.gridW .. ", height = " .. state.gridH)
    add("player = {" .. px .. "," .. py .. "}")

    -- walls
    add("walls = {" .. table.concat(walls, ",") .. "}")

    -- boxes
    local boxParts = {}
    for _, b in ipairs(state.boxPositions) do
        boxParts[#boxParts + 1] = "{" .. (b[1] - 1) .. "," .. (b[2] - 1) .. "}"
    end
    add("boxes = {" .. table.concat(boxParts, ",") .. "}")

    -- targets
    local targetParts = {}
    for _, t in ipairs(state.targetPositions) do
        targetParts[#targetParts + 1] = "{" .. (t[1] - 1) .. "," .. (t[2] - 1) .. "}"
    end
    add("targets = {" .. table.concat(targetParts, ",") .. "}")

    -- ice
    add("ice = {" .. table.concat(iceList, ",") .. "}")

    -- portals（0-based）
    local portalParts = {}
    local ptargetParts = {}
    for _, color in ipairs({ "red", "green", "blue" }) do
        local pp = state.portalPositions[color]
        local pt = state.portalTargetPositions[color]
        if pp and pt then
            portalParts[#portalParts + 1] = '{"' .. color .. '",' .. (pp[1] - 1) .. "," .. (pp[2] - 1) .. "}"
            ptargetParts[#ptargetParts + 1] = '{"' .. color .. '",' .. (pt[1] - 1) .. "," .. (pt[2] - 1) .. "}"
        end
    end
    if #portalParts > 0 then
        add("portals = {" .. table.concat(portalParts, ",") .. "}")
        add("portalTargets = {" .. table.concat(ptargetParts, ",") .. "}")
    end

    add("recommendedSteps = 0, solution = \"\"}")

    return table.concat(parts, ", ")
end

--- 从关卡数据字符串导入到编辑器
---@param state table 共享编辑器状态
---@param dataStr string 关卡数据字符串
---@return boolean success
---@return string|nil errMsg
function M.import(state, dataStr)
    local fn, err = load("return " .. dataStr)
    if not fn then
        return false, "数据格式错误: " .. (err or "未知错误")
    end

    local ok, data = pcall(fn)
    if not ok or type(data) ~= "table" then
        return false, "数据解析失败"
    end

    if not data.width or not data.height or not data.player then
        return false, "缺少必要字段(width/height/player)"
    end
    if data.width < state.MIN_SIZE or data.width > state.MAX_SIZE
        or data.height < state.MIN_SIZE or data.height > state.MAX_SIZE then
        return false, "尺寸超出范围(" .. state.MIN_SIZE .. "-" .. state.MAX_SIZE .. ")"
    end

    -- 应用尺寸
    state.gridW = data.width
    state.gridH = data.height

    -- 初始化空白网格
    state.grid = {}
    for y = 1, state.gridH do
        state.grid[y] = {}
        for x = 1, state.gridW do
            state.grid[y][x] = "floor"
        end
    end

    -- 放置墙壁（0-based → 1-based）
    if data.walls then
        for _, w in ipairs(data.walls) do
            local wx, wy = w[1] + 1, w[2] + 1
            if wx >= 1 and wx <= state.gridW and wy >= 1 and wy <= state.gridH then
                state.grid[wy][wx] = "wall"
            end
        end
    end

    -- 放置冰面
    if data.ice then
        for _, ic in ipairs(data.ice) do
            local ix, iy = ic[1] + 1, ic[2] + 1
            if ix >= 1 and ix <= state.gridW and iy >= 1 and iy <= state.gridH then
                state.grid[iy][ix] = "ice"
            end
        end
    end

    -- 放置玩家（0-based → 1-based）
    state.playerPos = { data.player[1] + 1, data.player[2] + 1 }

    -- 放置箱子
    state.boxPositions = {}
    if data.boxes then
        for _, b in ipairs(data.boxes) do
            state.boxPositions[#state.boxPositions + 1] = { b[1] + 1, b[2] + 1 }
        end
    end

    -- 放置目标
    state.targetPositions = {}
    if data.targets then
        for _, t in ipairs(data.targets) do
            state.targetPositions[#state.targetPositions + 1] = { t[1] + 1, t[2] + 1 }
        end
    end

    -- 放置传送门
    state.portalPositions = {}
    state.portalTargetPositions = {}
    if data.portals then
        for _, p in ipairs(data.portals) do
            local color = p[1]
            state.portalPositions[color] = { p[2] + 1, p[3] + 1 }
        end
    end
    if data.portalTargets then
        for _, pt in ipairs(data.portalTargets) do
            local color = pt[1]
            state.portalTargetPositions[color] = { pt[2] + 1, pt[3] + 1 }
        end
    end

    logger.info(MODULE, "import", "level imported: " .. state.gridW .. "x" .. state.gridH
        .. ", boxes=" .. #state.boxPositions .. ", targets=" .. #state.targetPositions)
    return true, nil
end

--- 构建 0-based 原始关卡数据表
---@param state table 共享编辑器状态
---@return table raw
function M.buildRawLevelData(state)
    local walls = {}
    local iceList = {}
    for y = 1, state.gridH do
        for x = 1, state.gridW do
            local cell = state.grid[y][x]
            if cell == "wall" then
                walls[#walls + 1] = { x - 1, y - 1 }
            elseif cell == "ice" then
                iceList[#iceList + 1] = { x - 1, y - 1 }
            end
        end
    end

    local px, py = 0, 0
    if state.playerPos then
        px = state.playerPos[1] - 1
        py = state.playerPos[2] - 1
    end

    local boxes = {}
    for i, b in ipairs(state.boxPositions) do
        boxes[i] = { b[1] - 1, b[2] - 1 }
    end

    local targets = {}
    for i, t in ipairs(state.targetPositions) do
        targets[i] = { t[1] - 1, t[2] - 1 }
    end

    local portals = {}
    local portalTargets = {}
    for _, color in ipairs({ "red", "green", "blue" }) do
        local pp = state.portalPositions[color]
        local pt = state.portalTargetPositions[color]
        if pp and pt then
            portals[#portals + 1] = { color, pp[1] - 1, pp[2] - 1 }
            portalTargets[#portalTargets + 1] = { color, pt[1] - 1, pt[2] - 1 }
        end
    end

    return {
        id = "editor-test",
        title = "编辑器试玩",
        difficulty = "normal",
        width = state.gridW,
        height = state.gridH,
        player = { px, py },
        walls = walls,
        boxes = boxes,
        targets = targets,
        ice = iceList,
        portals = #portals > 0 and portals or nil,
        portalTargets = #portalTargets > 0 and portalTargets or nil,
        recommendedSteps = 0,
        solution = "",
    }
end

--- 构建可玩的关卡数据（1-based，可直接传给 gameplay.enter）
---@param state table 共享编辑器状态
---@return table|nil level
---@return string|nil errMsg
function M.buildPlayableLevel(state)
    if not state.playerPos then
        return nil, "请先放置玩家!"
    end
    if #state.boxPositions == 0 then
        return nil, "请先放置箱子!"
    end
    if #state.boxPositions ~= #state.targetPositions then
        return nil, "箱子和目标数量不一致!"
    end

    local raw = M.buildRawLevelData(state)
    local level, err = levelLoader.load(raw)
    if not level then
        return nil, err or "关卡数据无效"
    end

    return level, nil
end

return M
