--- 主线系统 - 存档读写
--- 职责：主线进度持久化（本地缓存 + clientCloud 云同步）
local logger = require("shared.utils.logger")
---@diagnostic disable: undefined-global

local M = {}
local MODULE = "storyline-save"

local SAVE_PATH = "saves/storyline_progress.json"
local CLOUD_KEY = "storyline_save"

--- 默认存档结构
---@return table
local function defaultData()
    return {
        currentNodeId = "story-1",
        completedNodes = {},  -- { ["story-1"] = { completedAt = 1234567890 }, ... }
        updatedAt = 0,
    }
end

--- 加载本地存档
---@return table
function M.load()
    if not fileSystem:FileExists(SAVE_PATH) then
        logger.info(MODULE, "load", "no save file, using defaults")
        return defaultData()
    end

    local file = File(SAVE_PATH, FILE_READ)
    if not file:IsOpen() then
        logger.warn(MODULE, "load", "cannot open save file")
        return defaultData()
    end

    local jsonStr = file:ReadString()
    file:Close()

    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok or type(data) ~= "table" then
        logger.warn(MODULE, "load", "save file corrupted, using defaults")
        return defaultData()
    end

    -- 合并默认值（向后兼容新增字段）
    local defaults = defaultData()
    for k, v in pairs(defaults) do
        if data[k] == nil then
            data[k] = v
        end
    end

    local count = 0
    for _ in pairs(data.completedNodes) do count = count + 1 end
    logger.info(MODULE, "load", "loaded, completed=" .. count)
    return data
end

--- 仅写入本地文件（不触发云同步，供 syncFromCloud 内部使用）
---@param data table
function M.saveLocal(data)
    fileSystem:CreateDir("saves")
    local file = File(SAVE_PATH, FILE_WRITE)
    if not file:IsOpen() then return end

    local ok, jsonStr = pcall(cjson.encode, data)
    if ok then
        file:WriteString(jsonStr)
    end
    file:Close()
end

--- 保存存档（本地 + 云端）
---@param data table
---@return boolean success
function M.save(data)
    data.updatedAt = os.time() * 1000

    fileSystem:CreateDir("saves")
    local file = File(SAVE_PATH, FILE_WRITE)
    if not file:IsOpen() then
        logger.error(MODULE, "save", "cannot write save file")
        return false
    end

    local ok, jsonStr = pcall(cjson.encode, data)
    if not ok then
        file:Close()
        logger.error(MODULE, "save", "encode failed: " .. tostring(jsonStr))
        return false
    end

    file:WriteString(jsonStr)
    file:Close()

    local count = 0
    for _ in pairs(data.completedNodes) do count = count + 1 end
    logger.info(MODULE, "save", "saved local, completed=" .. count)

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
                -- 云端更新，覆盖本地
                for k, v in pairs(cloudData) do
                    data[k] = v
                end
                M.saveLocal(data)
                local count = 0
                for _ in pairs(data.completedNodes) do count = count + 1 end
                logger.info(MODULE, "syncFromCloud", "cloud is newer, updated local. completed=" .. count)
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
