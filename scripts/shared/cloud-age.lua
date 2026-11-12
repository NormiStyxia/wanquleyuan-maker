--- 云存档测试年龄模块
--- 用途：在设置中提供"测试账号年龄"入口，将选择结果保存到云存档（clientCloud），
---       下次进入游戏时读取。装扮购买流程根据该年龄档位 + "使用云存档年龄"开关
---       决定是否禁止付费（未实名 / 未满8 禁止）。
--- 存储：本地缓存 saves/cloud_age.json + clientCloud 云端持久化（key: cloud_test_age）

local logger = require("shared.utils.logger")
---@diagnostic disable: undefined-global

local M = {}
local MODULE = "cloud-age"

local SAVE_PATH = "saves/cloud_age.json"
local CLOUD_KEY = "cloud_test_age"

-- ============================================================================
-- 年龄档位定义
-- ============================================================================

M.BAND_UNVERIFIED = "unverified"   -- 未实名
M.BAND_UNDER8     = "under8"       -- 未满8
M.BAND_8TO12      = "8to12"        -- 8到12
M.BAND_12TO16     = "12to16"       -- 12到16
M.BAND_18PLUS     = "18plus"       -- 满18

--- 供 UI 展示的选项列表（顺序即选择弹窗中的顺序）
M.BANDS = {
    { id = M.BAND_UNVERIFIED, label = "未实名" },
    { id = M.BAND_UNDER8,     label = "未满8" },
    { id = M.BAND_8TO12,      label = "8到12" },
    { id = M.BAND_12TO16,     label = "12到16" },
    { id = M.BAND_18PLUS,     label = "满18" },
}

--- 禁止付费的档位集合
local BLOCKED_BANDS = {
    [M.BAND_UNVERIFIED] = true,
    [M.BAND_UNDER8]     = true,
}

--- 档位 ID → 中文标签
---@param band string|nil
---@return string
function M.bandLabel(band)
    if not band then return "未设置" end
    for _, b in ipairs(M.BANDS) do
        if b.id == band then return b.label end
    end
    return band
end

--- 校验档位 ID 是否合法
---@param band any
---@return boolean
local function isValidBand(band)
    if type(band) ~= "string" then return false end
    for _, b in ipairs(M.BANDS) do
        if b.id == band then return true end
    end
    return false
end

-- ============================================================================
-- 内部状态
-- ============================================================================

---@class CloudAgeData
---@field ageBand string|nil 年龄档位 ID
---@field updatedAt number|nil 更新时间戳（毫秒）

---@type CloudAgeData
local data_ = {
    ageBand = nil,
    updatedAt = nil,
}

-- ============================================================================
-- 存储
-- ============================================================================

--- 从本地缓存加载
---@return CloudAgeData
local function loadFromFile()
    if not fileSystem:FileExists(SAVE_PATH) then
        return { ageBand = nil, updatedAt = nil }
    end

    local file = File(SAVE_PATH, FILE_READ)
    if not file:IsOpen() then
        return { ageBand = nil, updatedAt = nil }
    end

    local jsonStr = file:ReadString()
    file:Close()

    local ok, decoded = pcall(cjson.decode, jsonStr)
    if not ok or type(decoded) ~= "table" then
        logger.warn(MODULE, "load", "cloud age data corrupted")
        return { ageBand = nil, updatedAt = nil }
    end

    if not isValidBand(decoded.ageBand) then
        decoded.ageBand = nil
    end
    return decoded
end

--- 保存到本地缓存
---@param d CloudAgeData
---@return boolean
local function saveToFile(d)
    fileSystem:CreateDir("saves")
    local file = File(SAVE_PATH, FILE_WRITE)
    if not file:IsOpen() then
        logger.error(MODULE, "save", "cannot write cloud age file")
        return false
    end
    local ok, jsonStr = pcall(cjson.encode, d)
    if not ok then
        file:Close()
        logger.error(MODULE, "save", "encode failed")
        return false
    end
    file:WriteString(jsonStr)
    file:Close()
    return true
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 初始化：从本地缓存加载年龄状态（同步，立即可用）
--- 启动后应尽快调用 syncFromCloud 拉取云端数据
function M.init()
    data_ = loadFromFile()
    logger.info(MODULE, "init", "local cache: ageBand=" .. tostring(data_.ageBand))
end

--- 从云端同步年龄状态（异步）
--- 云端有数据时覆盖本地，并写入本地缓存
---@param onDone fun(ageBand: string|nil)|nil 同步完成回调
function M.syncFromCloud(onDone)
    if not clientCloud then
        logger.info(MODULE, "syncFromCloud", "clientCloud not available, skip")
        if onDone then onDone(data_.ageBand) end
        return
    end

    clientCloud:Get(CLOUD_KEY, {
        ok = function(values)
            local cloudData = values[CLOUD_KEY]
            if type(cloudData) == "table" and isValidBand(cloudData.ageBand) then
                -- 云端有数据，覆盖本地
                data_ = cloudData
                saveToFile(data_)
                logger.info(MODULE, "syncFromCloud", "cloud synced, ageBand=" .. tostring(data_.ageBand))
            else
                logger.info(MODULE, "syncFromCloud", "no cloud age data")
            end
            if onDone then onDone(data_.ageBand) end
        end,
        error = function(code, reason)
            logger.warn(MODULE, "syncFromCloud", "failed: " .. tostring(code) .. " " .. tostring(reason))
            if onDone then onDone(data_.ageBand) end
        end,
        timeout = function()
            logger.warn(MODULE, "syncFromCloud", "timeout")
            if onDone then onDone(data_.ageBand) end
        end,
    })
end

--- 获取当前云存档年龄档位
---@return string|nil 档位 ID，未设置返回 nil
function M.getAgeBand()
    return data_.ageBand
end

--- 设置年龄档位并保存到云存档
---@param band string 档位 ID（见 M.BANDS）
---@param onDone fun(success: boolean)|nil 结果回调（本地保存成功即为 true）
function M.setAgeBand(band, onDone)
    if not isValidBand(band) then
        logger.warn(MODULE, "setAgeBand", "invalid band: " .. tostring(band))
        if onDone then onDone(false) end
        return
    end

    data_ = {
        ageBand = band,
        updatedAt = os.time() * 1000,
    }
    saveToFile(data_)

    -- 同步到云端（失败不影响本地生效，下次启动以云端为准）
    if clientCloud then
        clientCloud:Set(CLOUD_KEY, data_, {
            ok = function()
                logger.info(MODULE, "setAgeBand", "cloud synced: " .. band)
            end,
            error = function(code, reason)
                logger.warn(MODULE, "setAgeBand", "cloud sync failed: " .. tostring(code) .. " " .. tostring(reason))
            end,
        })
    end

    logger.info(MODULE, "setAgeBand", "ageBand=" .. band)
    if onDone then onDone(true) end
end

--- 指定档位是否属于禁止付费档（未实名 / 未满8）
---@param band string|nil
---@return boolean
function M.isBlockedBand(band)
    return band ~= nil and BLOCKED_BANDS[band] == true
end

--- 当前是否应禁止装扮付费
--- 规则："使用云存档年龄"开关开启 且 云存档有数据 且 档位为未实名/未满8 → 禁止
---@return boolean blocked
function M.isPurchaseBlocked()
    -- 延迟加载避免循环依赖（settings-save → background-manager → purchase-popup → cloud-age）
    local settingsSave = require("shared.settings-save")
    local settings = settingsSave.load()
    if settings.useCloudAge ~= true then
        return false
    end
    return M.isBlockedBand(data_.ageBand)
end

--- 清空本地缓存（配合 clearAllProgress 使用，文件与云端由调用方删除）
function M.resetCache()
    data_ = { ageBand = nil, updatedAt = nil }
    logger.info(MODULE, "resetCache", "cache cleared")
end

return M
