--- 主线系统 - 进度管理
--- 职责：管理主线关卡解锁/通关状态，提供节点查询接口
local logger = require("shared.utils.logger")
local save = require("modules.storyline.save")

local M = {}
local MODULE = "storyline"

-- ============================================================================
-- 内部状态
-- ============================================================================

---@type table[] 节点配置（来自 config/storyline.lua）
local nodes_ = {}

---@type table 进度数据（来自 save.lua）
local progress_ = nil

---@type boolean 是否已加载
local loaded_ = false

---@type boolean 是否正在云同步
local syncing_ = false

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 加载主线进度（本地 + 云同步）
---@param onReady function|nil 加载完成回调
function M.load(onReady)
    -- 加载节点配置
    nodes_ = require("config.storyline")

    -- 加载本地存档
    progress_ = save.load()
    loaded_ = true

    logger.info(MODULE, "load", "nodes=" .. #nodes_ .. " current=" .. progress_.currentNodeId)

    -- 异步云同步
    syncing_ = true
    save.syncFromCloud(progress_, function(updated)
        syncing_ = false
        if updated then
            logger.info(MODULE, "load", "cloud sync updated progress, current=" .. progress_.currentNodeId)
        end
        if onReady then onReady() end
    end)
end

--- 获取节点状态
---@param nodeId string
---@return string "locked" | "current" | "done"
function M.getNodeState(nodeId)
    if not loaded_ then return "locked" end

    -- 已完成
    if progress_.completedNodes[nodeId] then
        return "done"
    end

    -- 当前节点
    if progress_.currentNodeId == nodeId then
        return "current"
    end

    return "locked"
end

--- 获取当前节点配置
---@return table|nil 节点配置（含 gameType、levelFile 等）
function M.getCurrentNode()
    if not loaded_ then return nil end
    for _, node in ipairs(nodes_) do
        if node.nodeId == progress_.currentNodeId then
            return node
        end
    end
    return nil
end

--- 标记节点完成，推进到下一节点
---@param nodeId string
function M.completeNode(nodeId)
    if not loaded_ then return end

    -- 已完成的节点不重复记录
    if progress_.completedNodes[nodeId] then
        logger.info(MODULE, "completeNode", nodeId .. " already completed, skip")
        return
    end

    -- 记录完成
    progress_.completedNodes[nodeId] = {
        completedAt = os.time() * 1000,
    }

    -- 推进 currentNodeId 到下一个未完成的节点
    local found = false
    for _, node in ipairs(nodes_) do
        if node.nodeId == nodeId then
            found = true
        elseif found and not progress_.completedNodes[node.nodeId] then
            progress_.currentNodeId = node.nodeId
            logger.info(MODULE, "completeNode", nodeId .. " done, next=" .. node.nodeId)
            save.save(progress_)
            return
        end
    end

    -- 如果没有下一个节点，说明全部完成，保持在最后一个
    progress_.currentNodeId = nodeId
    logger.info(MODULE, "completeNode", nodeId .. " done, all completed!")
    save.save(progress_)
end

--- 获取所有节点及其状态（给地图页渲染用）
---@return table[] { node=<config>, state="locked"|"current"|"done" }
function M.getNodeList()
    local result = {}
    for _, node in ipairs(nodes_) do
        result[#result + 1] = {
            node = node,
            state = M.getNodeState(node.nodeId),
        }
    end
    return result
end

--- 是否全部通关
---@return boolean
function M.isAllCompleted()
    if not loaded_ then return false end
    for _, node in ipairs(nodes_) do
        if not progress_.completedNodes[node.nodeId] then
            return false
        end
    end
    return true
end

--- 判断节点是否可点击（已完成或当前节点）
---@param nodeId string
---@return boolean
function M.isPlayable(nodeId)
    local state = M.getNodeState(nodeId)
    return state == "done" or state == "current"
end

--- 是否正在云同步中
---@return boolean
function M.isSyncing()
    return syncing_
end

return M
