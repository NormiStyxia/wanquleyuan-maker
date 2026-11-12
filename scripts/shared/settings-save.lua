--- 全局设置存档（音量等）
--- 存储路径: saves/settings.json

local logger = require("shared.utils.logger")
local OutfitManager = require("shared.outfit-manager")
local bgManager = require("shared.background-manager")
local realNameAuth = require("shared.real-name-auth")
---@diagnostic disable: undefined-global

local M = {}
local MODULE = "settings-save"

local SAVE_PATH = "saves/settings.json"

--- 默认设置
---@return table
local function defaults()
    return {
        bgmVolume = 0.35,
        sfxVolume = 1.0,
        outfit = "default",
        forcePlayTimeRestrict = false,  -- 强制非可游玩时间开关，开启时始终触发非可游玩限制
        useCloudAge = true,             -- 使用云存档年龄开关（默认开启），控制装扮购买是否按云存档年龄拦截付费
    }
end

--- 加载设置
---@return table
function M.load()
    if not fileSystem:FileExists(SAVE_PATH) then
        logger.info(MODULE, "load", "no settings file, using defaults")
        return defaults()
    end

    local file = File(SAVE_PATH, FILE_READ)
    if not file:IsOpen() then
        logger.warn(MODULE, "load", "cannot open settings file")
        return defaults()
    end

    local jsonStr = file:ReadString()
    file:Close()

    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok or type(data) ~= "table" then
        logger.warn(MODULE, "load", "settings file corrupted, using defaults")
        return defaults()
    end

    -- 合并默认值（向后兼容新增字段）
    local def = defaults()
    for k, v in pairs(def) do
        if data[k] == nil then data[k] = v end
    end

    logger.info(MODULE, "load", "bgm=" .. data.bgmVolume .. " sfx=" .. data.sfxVolume)
    return data
end

--- 保存设置（合并写入：与现有存档合并，避免部分字段保存覆盖丢失其他字段）
---@param data table { bgmVolume, sfxVolume, ... }
---@return boolean
function M.save(data)
    local merged = M.load()
    for k, v in pairs(data) do
        merged[k] = v
    end
    data = merged

    fileSystem:CreateDir("saves")
    local file = File(SAVE_PATH, FILE_WRITE)
    if not file:IsOpen() then
        logger.error(MODULE, "save", "cannot write settings file")
        return false
    end

    local ok, jsonStr = pcall(cjson.encode, data)
    if not ok then
        file:Close()
        logger.error(MODULE, "save", "encode failed")
        return false
    end

    file:WriteString(jsonStr)
    file:Close()
    logger.info(MODULE, "save", "bgm=" .. data.bgmVolume .. " sfx=" .. data.sfxVolume)
    return true
end

--- 清空所有游戏进度存档（主线 + 4 个游戏）
--- 同时清除本地文件和云端数据
--- 不清空设置存档（音量等）
---@return boolean
function M.clearAllProgress()
    -- 1. 删除本地文件
    local paths = {
        "saves/storyline_progress.json",
        "saves/p1-puzzle-land.json",
        "saves/p2-memory-flip.json",
        "saves/p3-match-3.json",
        "saves/p4-link-match.json",
    }
    for _, path in ipairs(paths) do
        if fileSystem:FileExists(path) then
            fileSystem:Delete(path)
            logger.info(MODULE, "clearAllProgress", "deleted: " .. path)
        end
    end

    -- 2. 清除云端数据（防止 syncFromCloud 恢复旧数据）
    if clientCloud then
        local cloudKeys = {
            "storyline_save",
            "p1_puzzle_save",
            "p2_flip_save",
            "p3_match3_save",
            "p4_link_save",
            "outfit_purchased",
            "bg_selected",
            "bg_purchased",
        }
        local batch = clientCloud:BatchSet()
        for _, key in ipairs(cloudKeys) do
            batch:Delete(key)
        end
        batch:Save("clear_all_progress", {
            ok = function()
                logger.info(MODULE, "clearAllProgress", "cloud data cleared")
            end,
            error = function(code, reason)
                logger.warn(MODULE, "clearAllProgress", "cloud clear failed: " .. tostring(code) .. " " .. tostring(reason))
            end,
        })
    end

    -- 3. 重置皮肤购买状态并切回默认皮肤
    OutfitManager.resetPurchases()

    -- 3.5. 重置背景购买状态并切回默认背景
    bgManager.resetPurchases()

    -- 4. 清除实名认证数据（本地 + 云端）
    realNameAuth.clearAuth()

    -- 4.5 清除云存档测试年龄（本地文件 + 云端 key）
    if fileSystem:FileExists("saves/cloud_age.json") then
        fileSystem:Delete("saves/cloud_age.json")
        logger.info(MODULE, "clearAllProgress", "deleted: saves/cloud_age.json")
    end
    if clientCloud then
        local ageBatch = clientCloud:BatchSet()
        ageBatch:Delete("cloud_test_age")
        ageBatch:Save("clear_cloud_age", {
            ok = function()
                logger.info(MODULE, "clearAllProgress", "cloud age cleared")
            end,
            error = function(code, reason)
                logger.warn(MODULE, "clearAllProgress", "cloud age clear failed: " .. tostring(code) .. " " .. tostring(reason))
            end,
        })
    end
    -- 重置 cloud-age 模块内存缓存
    require("shared.cloud-age").resetCache()

    logger.info(MODULE, "clearAllProgress", "all progress cleared")
    return true
end

-- ============================================================================
-- 辅助：写入本地存档文件
-- ============================================================================
local function writeLocalSave(path, data)
    fileSystem:CreateDir("saves")
    local file = File(path, FILE_WRITE)
    if not file:IsOpen() then
        logger.error(MODULE, "unlockAll", "cannot write " .. path)
        return false
    end
    local ok, jsonStr = pcall(cjson.encode, data)
    if not ok then
        file:Close()
        return false
    end
    file:WriteString(jsonStr)
    file:Close()
    return true
end

--- 解锁所有关卡（主线全部完成 + 4 个游戏全部 1 星/C 级通关）
--- 同时写入本地文件和云端
---@return boolean
function M.unlockAllLevels()
    local now = os.time() * 1000

    -- 1. 主线：35 个节点全部完成
    local storylineData = {
        currentNodeId = "story-35",
        completedNodes = {},
        updatedAt = now,
    }
    for i = 1, 35 do
        storylineData.completedNodes["story-" .. i] = { completedAt = now }
    end
    writeLocalSave("saves/storyline_progress.json", storylineData)

    -- 2. P1 推箱子：12 关，1 星
    local p1Data = {
        completedLevels = {},
        currentLevel = nil,
        totalPlaySec = 0,
        updatedAt = now,
    }
    for i = 1, 12 do
        p1Data.completedLevels[string.format("lv-%02d", i)] = 1
    end
    writeLocalSave("saves/p1-puzzle-land.json", p1Data)

    -- 3. P2 记忆翻牌：25 关，C 级
    local p2Data = {
        completedLevels = {},
        totalPlaySec = 0,
        updatedAt = now,
    }
    for i = 1, 25 do
        p2Data.completedLevels["L" .. i] = {
            bestTimeMs = 999999,
            bestRank = "C",
            clearCount = 1,
        }
    end
    writeLocalSave("saves/p2-memory-flip.json", p2Data)

    -- 4. P3 消消乐：25 关，1 星
    local p3Data = {
        completedLevels = {},
        totalPlaySec = 0,
        updatedAt = now,
    }
    for i = 1, 25 do
        p3Data.completedLevels["L" .. i] = {
            bestScore = 100,
            bestStar = 1,
            clearCount = 1,
        }
    end
    writeLocalSave("saves/p3-match-3.json", p3Data)

    -- 5. P4 连连看：30 关，C 级
    local p4Data = {
        completedLevels = {},
        totalPlaySec = 0,
        updatedAt = now,
    }
    for i = 1, 30 do
        p4Data.completedLevels["L" .. i] = {
            bestTimeMs = 999999,
            bestRank = "C",
            clearCount = 1,
        }
    end
    writeLocalSave("saves/p4-link-match.json", p4Data)

    -- 6. 同步到云端
    if clientCloud then
        clientCloud:BatchSet()
            :Set("storyline_save", storylineData)
            :Set("p1_puzzle_save", p1Data)
            :Set("p2_flip_save", p2Data)
            :Set("p3_match3_save", p3Data)
            :Set("p4_link_save", p4Data)
            :Save("unlock_all_levels", {
                ok = function()
                    logger.info(MODULE, "unlockAll", "cloud synced")
                end,
                error = function(code, reason)
                    logger.warn(MODULE, "unlockAll", "cloud failed: " .. tostring(code) .. " " .. tostring(reason))
                end,
            })
    end

    logger.info(MODULE, "unlockAll", "all levels unlocked (storyline 35 + p1 12 + p2 25 + p3 25 + p4 30)")
    return true
end

return M
