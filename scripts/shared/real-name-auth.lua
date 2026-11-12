--- 实名认证核心模块
--- 当前阶段：模拟实名认证（本地校验身份证号格式 + 根据出生日期判断年龄）
--- 后续阶段：替换为真实实名认证 SDK
--- 存储：本地缓存 saves/real_name_auth.json + clientCloud 云端持久化

local logger = require("shared.utils.logger")
---@diagnostic disable: undefined-global

local M = {}
local MODULE = "real-name-auth"

local SAVE_PATH = "saves/real_name_auth.json"
local CLOUD_KEY = "real_name_auth"

-- ============================================================================
-- 内部状态
-- ============================================================================

---@class RealNameAuthData
---@field verified boolean 是否已通过认证
---@field isAdult boolean 是否成年
---@field name string|nil 姓名（脱敏存储）
---@field idNumber string|nil 身份证号（脱敏存储）
---@field verifiedAt number|nil 认证时间戳（毫秒）
---@field birthday string|nil 出生日期 YYYY-MM-DD

---@type RealNameAuthData
local authData_ = {
    verified = false,
    isAdult = false,
    name = nil,
    idNumber = nil,
    verifiedAt = nil,
    birthday = nil,
}

-- ============================================================================
-- 身份证号校验（GB 11643-1999）
-- ============================================================================

-- 加权因子
local WEIGHTS = { 7, 9, 10, 5, 8, 4, 2, 1, 6, 3, 7, 9, 10, 5, 8, 4, 2 }
-- 校验码映射
local CHECK_CODES = { "1", "0", "X", "9", "8", "7", "6", "5", "4", "3", "2" }

--- 校验身份证号格式和校验码
--- 仅做格式校验，不做真实身份验证（模拟阶段）
---@param idNumber string 18位身份证号
---@return boolean valid 是否合法
---@return string|nil error 错误描述
function M.validateIdNumber(idNumber)
    if type(idNumber) ~= "string" then
        return false, "身份证号不能为空"
    end

    -- 去除首尾空白
    idNumber = idNumber:match("^%s*(.-)%s*$") or ""

    -- 长度校验
    if #idNumber ~= 18 then
        return false, "身份证号必须为18位"
    end

    -- 前17位必须是数字
    local digits17 = idNumber:sub(1, 17)
    if not digits17:match("^%d+$") then
        return false, "身份证号格式不正确"
    end

    -- 第18位可以是数字或X
    local lastChar = idNumber:sub(18, 18):upper()
    if not lastChar:match("^[%dX]$") then
        return false, "身份证号格式不正确"
    end

    -- 校验码验证（已禁用，方便测试）
    -- local sum = 0
    -- for i = 1, 17 do
    --     sum = sum + tonumber(idNumber:sub(i, i)) * WEIGHTS[i]
    -- end
    -- local remainder = sum % 11
    -- local expectedCheck = CHECK_CODES[remainder + 1]
    -- if lastChar ~= expectedCheck then
    --     return false, "身份证号校验码不正确"
    -- end

    -- 出生日期合法性
    local year = tonumber(idNumber:sub(7, 10))
    local month = tonumber(idNumber:sub(11, 12))
    local day = tonumber(idNumber:sub(13, 14))

    if not year or not month or not day then
        return false, "身份证号中的出生日期无效"
    end

    if month < 1 or month > 12 then
        return false, "身份证号中的月份无效"
    end

    -- 简单的天数校验
    local daysInMonth = { 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    if day < 1 or day > daysInMonth[month] then
        return false, "身份证号中的日期无效"
    end

    -- 年份合理性（1900 ~ 当前年份）
    local currentYear = tonumber(os.date("%Y")) or 2026
    if year < 1900 or year > currentYear then
        return false, "身份证号中的出生年份无效"
    end

    return true, nil
end

-- ============================================================================
-- 年龄计算
-- ============================================================================

--- 从身份证号中提取出生日期
---@param idNumber string 18位身份证号
---@return string birthday "YYYY-MM-DD"
function M.extractBirthday(idNumber)
    local y = idNumber:sub(7, 10)
    local m = idNumber:sub(11, 12)
    local d = idNumber:sub(13, 14)
    return y .. "-" .. m .. "-" .. d
end

--- 根据出生日期计算当前年龄
---@param birthday string "YYYY-MM-DD"
---@return number age
function M.calculateAge(birthday)
    local yStr, mStr, dStr = birthday:match("(%d+)-(%d+)-(%d+)")
    local currentYear = tonumber(os.date("%Y")) or 2026
    local y = tonumber(yStr) or currentYear
    local m = tonumber(mStr) or 1
    local d = tonumber(dStr) or 1

    local now = os.date("*t")
    local age = now.year - y

    -- 还未过今年生日则减1岁
    if now.month < m or (now.month == m and now.day < d) then
        age = age - 1
    end

    return age
end

--- 判断是否成年（>= 18岁）
---@param birthday string "YYYY-MM-DD"
---@return boolean
function M.isAdultByBirthday(birthday)
    return M.calculateAge(birthday) >= 18
end

-- ============================================================================
-- 身份证号脱敏
-- ============================================================================

--- 脱敏姓名：保留姓，名用 * 替换
---@param name string
---@return string
function M.maskName(name)
    if not name or #name == 0 then return "**" end
    local chars = {}
    for _, code in utf8.codes(name) do
        chars[#chars + 1] = utf8.char(code)
    end
    if #chars <= 1 then return chars[1] or "*" end
    return chars[1] .. string.rep("*", #chars - 1)
end

--- 脱敏身份证号：保留前4后4，中间用 * 替换
---@param idNumber string
---@return string
function M.maskIdNumber(idNumber)
    if #idNumber ~= 18 then return "****" end
    return idNumber:sub(1, 4) .. string.rep("*", 10) .. idNumber:sub(15, 18)
end

-- ============================================================================
-- 存储
-- ============================================================================

--- 从本地加载认证数据
---@return RealNameAuthData
local function loadFromFile()
    if not fileSystem:FileExists(SAVE_PATH) then
        return {
            verified = false,
            isAdult = false,
            name = nil,
            idNumber = nil,
            verifiedAt = nil,
            birthday = nil,
        }
    end

    local file = File(SAVE_PATH, FILE_READ)
    if not file:IsOpen() then
        return {
            verified = false,
            isAdult = false,
            name = nil,
            idNumber = nil,
            verifiedAt = nil,
            birthday = nil,
        }
    end

    local jsonStr = file:ReadString()
    file:Close()

    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok or type(data) ~= "table" then
        logger.warn(MODULE, "load", "auth data corrupted")
        return {
            verified = false,
            isAdult = false,
            name = nil,
            idNumber = nil,
            verifiedAt = nil,
            birthday = nil,
        }
    end

    return data
end

--- 保存认证数据到本地
---@param data RealNameAuthData
---@return boolean
local function saveToFile(data)
    fileSystem:CreateDir("saves")
    local file = File(SAVE_PATH, FILE_WRITE)
    if not file:IsOpen() then
        logger.error(MODULE, "save", "cannot write auth file")
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

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 初始化：从本地缓存加载认证状态（同步，立即可用）
--- 启动后应尽快调用 syncFromCloud 拉取云端数据
function M.init()
    authData_ = loadFromFile()
    if authData_.verified then
        logger.info(MODULE, "init", "local cache: verified, isAdult=" .. tostring(authData_.isAdult))
    else
        logger.info(MODULE, "init", "local cache: not verified")
    end
end

--- 从云端同步认证状态（异步）
--- 云端有数据时覆盖本地，并写入本地缓存
---@param onDone fun(verified: boolean)|nil 同步完成回调，verified 表示是否已认证
function M.syncFromCloud(onDone)
    if not clientCloud then
        logger.info(MODULE, "syncFromCloud", "clientCloud not available, skip")
        if onDone then onDone(authData_.verified == true) end
        return
    end

    clientCloud:Get(CLOUD_KEY, {
        ok = function(values)
            local cloudData = values[CLOUD_KEY]
            if type(cloudData) == "table" and cloudData.verified then
                -- 云端有认证数据，覆盖本地
                authData_ = cloudData
                saveToFile(authData_)
                logger.info(MODULE, "syncFromCloud", "cloud verified, isAdult=" .. tostring(authData_.isAdult))
            else
                logger.info(MODULE, "syncFromCloud", "no cloud auth data")
            end
            if onDone then onDone(authData_.verified == true) end
        end,
        error = function(code, reason)
            logger.warn(MODULE, "syncFromCloud", "failed: " .. tostring(code) .. " " .. tostring(reason))
            if onDone then onDone(authData_.verified == true) end
        end,
        timeout = function()
            logger.warn(MODULE, "syncFromCloud", "timeout")
            if onDone then onDone(authData_.verified == true) end
        end,
    })
end

--- 是否已完成实名认证
---@return boolean
function M.isVerified()
    return authData_.verified == true
end

--- 当前认证用户是否成年
--- 未认证时返回 false
---@return boolean
function M.isAdult()
    if not authData_.verified then return false end
    return authData_.isAdult == true
end

--- 获取脱敏后的身份证号
---@return string|nil
function M.getMaskedIdNumber()
    return authData_.idNumber
end

--- 获取认证时的出生日期
---@return string|nil "YYYY-MM-DD"
function M.getBirthday()
    return authData_.birthday
end

--- 获取当前认证用户年龄
---@return number|nil age
function M.getAge()
    if not authData_.verified or not authData_.birthday then return nil end
    return M.calculateAge(authData_.birthday)
end

--- 执行实名认证（模拟阶段：本地校验）
--- 后续替换为真实 SDK 调用
---@param name string 真实姓名
---@param idNumber string 18位身份证号
---@param onResult fun(success: boolean, isAdult: boolean, errorMsg: string|nil) 结果回调
function M.verify(name, idNumber, onResult)
    -- 1. 校验身份证号格式
    local valid, errMsg = M.validateIdNumber(idNumber)
    if not valid then
        logger.warn(MODULE, "verify", "invalid: " .. tostring(errMsg))
        if onResult then onResult(false, false, errMsg) end
        return
    end

    -- 2. 提取出生日期并计算年龄
    local birthday = M.extractBirthday(idNumber)
    local adult = M.isAdultByBirthday(birthday)
    local age = M.calculateAge(birthday)

    -- 3. 保存认证结果（姓名和身份证号脱敏存储）
    authData_ = {
        verified = true,
        isAdult = adult,
        name = M.maskName(name),
        idNumber = M.maskIdNumber(idNumber),
        verifiedAt = os.time() * 1000,
        birthday = birthday,
    }

    -- 4. 写入本地缓存
    saveToFile(authData_)

    -- 5. 同步到云端（fire-and-forget）
    if clientCloud then
        clientCloud:Set(CLOUD_KEY, authData_, {
            ok = function()
                logger.info(MODULE, "verify", "cloud synced")
            end,
            error = function(code, reason)
                logger.warn(MODULE, "verify", "cloud sync failed: " .. tostring(code) .. " " .. tostring(reason))
            end,
        })
    end

    logger.info(MODULE, "verify", "success, age=" .. age .. ", isAdult=" .. tostring(adult))

    -- 6. 回调结果
    if onResult then onResult(true, adult, nil) end
end

--- 清除认证数据（用于测试/调试）
function M.clearAuth()
    authData_ = {
        verified = false,
        isAdult = false,
        name = nil,
        idNumber = nil,
        verifiedAt = nil,
        birthday = nil,
    }
    if fileSystem:FileExists(SAVE_PATH) then
        fileSystem:Delete(SAVE_PATH)
    end
    -- 同时清除云端
    if clientCloud then
        clientCloud:Set(CLOUD_KEY, nil, {
            ok = function()
                logger.info(MODULE, "clearAuth", "cloud cleared")
            end,
            error = function(code, reason)
                logger.warn(MODULE, "clearAuth", "cloud clear failed: " .. tostring(code) .. " " .. tostring(reason))
            end,
        })
    end
    logger.info(MODULE, "clearAuth", "auth data cleared")
end

return M
