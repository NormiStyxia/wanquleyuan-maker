--- 消消乐 - 存档系统
--- 职责：关卡进度持久化（本地缓存 + clientCloud 云同步）
local logger = require("shared.utils.logger")
local saveFile = require("shared.utils.save-file")
---@diagnostic disable: undefined-global

local M = {}
local MODULE = "m3-save"

local SAVE_PATH = "saves/p3-match-3.json"
local CLOUD_KEY = "p3_match3_save"

--- 默认存档结构
---@return table
local function defaultData()
    return {
        completedLevels = {},   -- { ["L1"] = { bestScore = 3200, bestStar = 2, clearCount = 1 } }
        totalPlaySec = 0,
        updatedAt = 0,
    }
end

--- 加载存档
---@return table saveData
function M.load()
    local data = saveFile.read(SAVE_PATH, MODULE)
    if not data then return defaultData() end

    local defaults = defaultData()
    for k, v in pairs(defaults) do
        if data[k] == nil then
            data[k] = v
        end
    end

    logger.info(MODULE, "load", "loaded, completed=" .. M.countCompleted(data))
    return data
end

--- 保存存档（本地 + 云端）
---@param data table
---@return boolean success
function M.save(data)
    data.updatedAt = os.time() * 1000

    if not saveFile.write(SAVE_PATH, data, MODULE) then return false end
    logger.info(MODULE, "save", "saved local, completed=" .. M.countCompleted(data))

    -- 同步写入云端（fire-and-forget）
    if clientCloud then
        clientCloud:Set(CLOUD_KEY, data, {
            ok = function()
                logger.info(MODULE, "save", "cloud synced")
            end,
            error = function(code, reason)
                logger.warn(MODULE, "save", "cloud failed: " .. tostring(code) .. " " .. tostring(reason))
            end,
        })
    end

    return true
end

--- 仅写入本地文件（不触发云同步，供 syncFromCloud 内部使用）
---@param data table
function M.saveLocal(data)
    saveFile.write(SAVE_PATH, data)
end

--- 记录关卡通关
---@param data table
---@param levelId string
---@param finalScore number
---@param starRating number 1-3
---@return boolean isNewBest 是否刷新了记录
function M.recordCompletion(data, levelId, finalScore, starRating)
    local prev = data.completedLevels[levelId]
    if not prev then
        data.completedLevels[levelId] = {
            bestScore = finalScore,
            bestStar = starRating,
            clearCount = 1,
        }
        return true
    end

    prev.clearCount = prev.clearCount + 1

    local updated = false
    if finalScore > prev.bestScore then
        prev.bestScore = finalScore
        updated = true
    end
    if starRating > prev.bestStar then
        prev.bestStar = starRating
        updated = true
    end
    return updated
end

--- 获取关卡最佳数据
---@param data table
---@param levelId string
---@return table|nil { bestScore, bestStar, clearCount }
function M.getLevelBest(data, levelId)
    return data.completedLevels[levelId]
end

--- 关卡是否已解锁（线性解锁：前一关通关即解锁）
---@param data table
---@param levelId string
---@param levelList table[] levels 数组
---@return boolean
function M.isUnlocked(data, levelId, levelList)
    for i, lv in ipairs(levelList) do
        if lv.levelId == levelId then
            if i == 1 then return true end
            local prevId = levelList[i - 1].levelId
            return data.completedLevels[prevId] ~= nil
        end
    end
    return false
end

--- 统计已通关数量
---@param data table
---@return number
function M.countCompleted(data)
    local count = 0
    for _ in pairs(data.completedLevels) do
        count = count + 1
    end
    return count
end

--- 生成 GameProgressSnapshot
---@param data table
---@param levelList table[]
---@return table
function M.toProgressSnapshot(data, levelList)
    local total = #levelList
    local completed = M.countCompleted(data)
    return {
        gameId = "p3-match-3",
        nodeId = "level-select",
        progressText = "已通关 " .. completed .. "/" .. total,
        elapsedSec = data.totalPlaySec,
        updatedAt = data.updatedAt,
    }
end

--- 从云端同步存档（启动时调用）
---@param data table 当前内存中的存档数据（会被 in-place 更新）
---@param onDone function|nil 回调 function(updated: boolean)
function M.syncFromCloud(data, onDone)
    if not clientCloud then
        logger.info(MODULE, "syncFromCloud", "clientCloud not available, skip")
        if onDone then onDone(false) end
        return
    end

    clientCloud:Get(CLOUD_KEY, {
        ok = function(values)
            local cloudData = values[CLOUD_KEY]
            if type(cloudData) ~= "table" then
                logger.info(MODULE, "syncFromCloud", "no cloud data")
                if onDone then onDone(false) end
                return
            end

            local cloudTime = cloudData.updatedAt or 0
            local localTime = data.updatedAt or 0

            if cloudTime > localTime then
                for k, v in pairs(cloudData) do
                    data[k] = v
                end
                M.saveLocal(data)
                logger.info(MODULE, "syncFromCloud", "cloud is newer, updated local. completed=" .. M.countCompleted(data))
                if onDone then onDone(true) end
            else
                logger.info(MODULE, "syncFromCloud", "local is up-to-date")
                if onDone then onDone(false) end
            end
        end,
        error = function(code, reason)
            logger.warn(MODULE, "syncFromCloud", "failed: " .. tostring(code) .. " " .. tostring(reason))
            if onDone then onDone(false) end
        end,
        timeout = function()
            logger.warn(MODULE, "syncFromCloud", "timeout")
            if onDone then onDone(false) end
        end,
    })
end

return M
