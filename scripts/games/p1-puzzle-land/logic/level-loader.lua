--- 关卡加载器
--- 职责：加载关卡数据、0-based → 1-based 坐标转换、数据校验
local logger = require("shared.utils.logger")

local M = {}
local MODULE = "level-loader"

-- ============================================================================
-- 坐标转换（JSON/数据 0-based ↔ Lua 1-based）
-- ============================================================================

--- 0-based 坐标 → 1-based
---@param pos number[]
---@return number[]
function M.toInternal(pos)
    return { pos[1] + 1, pos[2] + 1 }
end

--- 1-based 坐标 → 0-based
---@param pos number[]
---@return number[]
function M.toExternal(pos)
    return { pos[1] - 1, pos[2] - 1 }
end

--- 批量转换坐标列表（0-based → 1-based）
---@param positions number[][]
---@return number[][]
local function convertPositions(positions)
    local result = {}
    for i = 1, #positions do
        result[i] = M.toInternal(positions[i])
    end
    return result
end

-- ============================================================================
-- 校验
-- ============================================================================

--- 校验单个关卡数据的合法性
---@param raw table 原始关卡数据
---@return boolean ok
---@return string|nil errMsg
local function validate(raw)
    if type(raw) ~= "table" then
        return false, "SKB-003: level data is not a table"
    end

    -- 必填字段检查
    local required = { "id", "width", "height", "player", "boxes", "targets" }
    for _, field in ipairs(required) do
        if raw[field] == nil then
            return false, "SKB-003: missing required field '" .. field .. "'"
        end
    end

    local w, h = raw.width, raw.height

    -- 坐标边界检查（0-based）
    local function inBounds(pos, name)
        if type(pos) ~= "table" or #pos < 2 then
            return false, "SKB-003: " .. name .. " is not a valid position"
        end
        if pos[1] < 0 or pos[1] >= w or pos[2] < 0 or pos[2] >= h then
            return false, "SKB-003: " .. name .. " (" .. pos[1] .. "," .. pos[2] .. ") out of bounds"
        end
        return true, nil
    end

    local ok, err = inBounds(raw.player, "player")
    if not ok then return false, err end

    for i, box in ipairs(raw.boxes) do
        ok, err = inBounds(box, "box[" .. i .. "]")
        if not ok then return false, err end
    end

    for i, target in ipairs(raw.targets) do
        ok, err = inBounds(target, "target[" .. i .. "]")
        if not ok then return false, err end
    end

    -- 箱子数量 == 目标点数量
    if #raw.boxes ~= #raw.targets then
        return false, "SKB-003: boxes count (" .. #raw.boxes .. ") != targets count (" .. #raw.targets .. ")"
    end

    -- 冰面坐标检查
    if raw.ice then
        for i, pos in ipairs(raw.ice) do
            ok, err = inBounds(pos, "ice[" .. i .. "]")
            if not ok then return false, err end
        end
    end

    -- 传送门坐标检查
    if raw.portals then
        for i, p in ipairs(raw.portals) do
            ok, err = inBounds({ p[2], p[3] }, "portal[" .. i .. "]")
            if not ok then return false, err end
        end
    end
    if raw.portalTargets then
        for i, p in ipairs(raw.portalTargets) do
            ok, err = inBounds({ p[2], p[3] }, "portalTarget[" .. i .. "]")
            if not ok then return false, err end
        end
    end

    return true, nil
end

-- ============================================================================
-- 加载
-- ============================================================================

--- 加载并转换单个关卡
---@param raw table 原始关卡数据（0-based）
---@return table|nil level 转换后的关卡数据（1-based），失败返回 nil
---@return string|nil errMsg
function M.load(raw)
    local ok, err = validate(raw)
    if not ok then
        logger.error(MODULE, "load", err)
        return nil, err
    end

    -- 构建墙体查找集合（1-based key = "x,y"）
    local wallSet = {}
    if raw.walls then
        for _, pos in ipairs(raw.walls) do
            local p = M.toInternal(pos)
            wallSet[p[1] .. "," .. p[2]] = true
        end
    end

    -- 构建冰面查找集合
    local iceSet = {}
    if raw.ice then
        for _, pos in ipairs(raw.ice) do
            local p = M.toInternal(pos)
            iceSet[p[1] .. "," .. p[2]] = true
        end
    end

    -- 构建目标点查找集合
    local targetSet = {}
    local targets = convertPositions(raw.targets)
    for _, t in ipairs(targets) do
        targetSet[t[1] .. "," .. t[2]] = true
    end

    -- 构建传送门和传送目标映射
    -- portalMap: posKey -> { color, destX, destY }  (门 → 目标)
    -- portalTargetMap: posKey -> color  (目标位置标记)
    -- portalList: { {color, x, y} }  (用于渲染)
    -- portalTargetList: { {color, x, y} }  (用于渲染)
    local portalMap = {}
    local portalTargetMap = {}
    local portalList = {}
    local portalTargetList = {}
    if raw.portals and raw.portalTargets then
        -- 先收集传送目标，按颜色索引
        local targetByColor = {}
        for _, pt in ipairs(raw.portalTargets) do
            local color = pt[1]
            local pos = M.toInternal({ pt[2], pt[3] })
            targetByColor[color] = pos
            portalTargetMap[pos[1] .. "," .. pos[2]] = color
            portalTargetList[#portalTargetList + 1] = { color, pos[1], pos[2] }
        end
        -- 建立门 → 目标映射
        for _, p in ipairs(raw.portals) do
            local color = p[1]
            local pos = M.toInternal({ p[2], p[3] })
            local dest = targetByColor[color]
            if dest then
                portalMap[pos[1] .. "," .. pos[2]] = { color = color, destX = dest[1], destY = dest[2] }
            end
            portalList[#portalList + 1] = { color, pos[1], pos[2] }
        end
    end

    local level = {
        id = raw.id,
        title = raw.title or raw.id,
        themeBackground = raw.themeBackground,
        difficulty = raw.difficulty or "normal",
        width = raw.width,
        height = raw.height,
        player = M.toInternal(raw.player),
        boxes = convertPositions(raw.boxes),
        targets = targets,
        wallSet = wallSet,
        iceSet = iceSet,
        targetSet = targetSet,
        portalMap = portalMap,
        portalTargetMap = portalTargetMap,
        portalList = portalList,
        portalTargetList = portalTargetList,
        recommendedSteps = raw.recommendedSteps or 0,
        solution = raw.solution or "",
    }

    logger.info(MODULE, "load", "loaded: " .. level.id
        .. " (" .. level.width .. "x" .. level.height .. ")"
        .. " boxes=" .. #level.boxes
        .. " targets=" .. #level.targets)

    return level, nil
end

--- 加载全部关卡列表
---@return table[] levels
function M.loadAll()
    local ok, rawLevels = pcall(require, "games.p1-puzzle-land.data.levels")
    if not ok or type(rawLevels) ~= "table" then
        logger.error(MODULE, "loadAll", "failed to load levels data: " .. tostring(rawLevels))
        return {}
    end

    local levels = {}
    for i = 1, #rawLevels do
        local level, err = M.load(rawLevels[i])
        if level then
            levels[#levels + 1] = level
        else
            logger.warn(MODULE, "loadAll", "skip level index " .. i .. ": " .. (err or "unknown"))
        end
    end

    logger.info(MODULE, "loadAll", "total loaded: " .. #levels)
    return levels
end

return M
