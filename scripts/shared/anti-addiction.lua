--- 防沉迷核心模块
--- 职责：
--- 1. 统一判断成年/未成年身份（实名认证优先，测试开关降级）
--- 2. 会话级游玩时长计时（30 分钟提醒 + 60 分钟强制退出）
--- 3. 宵禁时段检查（每日 20:00 至次日 08:00 禁止，仅未成年人）
--- 4. 提供 canEnterGame / isLocked / getBlockReason 等业务 API
local flags = require("config.feature-flags")
local compliance = require("config.compliance")
local realNameAuth = require("shared.real-name-auth")
local settingsSave = require("shared.settings-save")
local logger = require("shared.utils.logger")

local M = {}
local MODULE = "anti-addiction"

-- ============================================================================
-- 时长配置（秒）
-- ============================================================================
local REMIND_THRESHOLD   = 30 * 60   -- 30 分钟提醒
local LOCKOUT_THRESHOLD  = 60 * 60   -- 60 分钟强制退出
local CURFEW_START_HOUR  = 20        -- 禁止游玩开始（20:00）
local CURFEW_END_HOUR    = 8         -- 禁止游玩结束（次日 08:00）

-- ============================================================================
-- 时间工具（北京时间）
-- ============================================================================

--- 获取当前北京时间表
--- 当前运行环境系统时区已为北京时间，直接使用 os.date("*t")。
local function getBeijingDate()
    return os.date("*t")
end

--- 获取当前北京时间的小时数（0~23）
---@return number hour 北京时间小时（0~23）
local function getBeijingHour()
    return getBeijingDate().hour
end

--- 获取北京时间的 HH:MM 字符串（供 UI 显示）
---@return string "HH:MM"
local function getBeijingTimeStr()
    local t = getBeijingDate()
    return string.format("%02d:%02d", t.hour, t.min)
end

-- ============================================================================
-- 内部状态
-- ============================================================================
local sessionPlaySec_ = 0       -- 会话累计游玩秒数
local inGame_         = false   -- 是否在游戏中（控制计时）
local warned30_       = false   -- 是否已弹出 30 分钟提醒
local locked_         = false   -- 是否已触发 60 分钟锁定
local testLockout_    = false   -- F4 测试触发的强制下线锁定（无视成年人身份）

-- 回调：由 main.lua 注册，当需要弹窗时调用
---@type fun(popupType: string)|nil
local onPopupRequest_ = nil

-- 回调：由 main.lua 注册，当需要强制退出游戏时调用
---@type fun(reason: string)|nil
local onForceExit_ = nil

-- ============================================================================
-- 公共 API - 身份判断
-- ============================================================================

--- 当前玩家是否为成年人
--- 优先级：实名认证结果 > feature-flags 测试开关
---@return boolean
function M.isAdult()
    if not compliance.isEnabled() then
        return true
    end
    -- 已完成实名认证时，使用认证结果
    if realNameAuth.isVerified() then
        return realNameAuth.isAdult()
    end
    -- 未认证时降级到调试开关
    return flags.isEnabled("testIsAdult")
end

--- 当前玩家是否已完成实名认证
---@return boolean
function M.isVerified()
    return realNameAuth.isVerified()
end

-- ============================================================================
-- 公共 API - 宵禁检查
-- ============================================================================

--- 检查强制限制开关（用于测试）
---@return boolean
local function isForceRestrict()
    local settings = settingsSave.load()
    return settings.forcePlayTimeRestrict == true
end

--- 当前是否处于禁止游玩时段（仅对未成年人生效）
--- 规则：每日 20:00 至次日 08:00 禁止游玩
--- 成年人始终返回 false
--- 使用北京时间判断
---@return boolean true=当前禁止游玩
function M.isCurfew()
    if not compliance.isEnabled() then
        return false
    end
    -- 强制开关用于测试，无视身份
    if isForceRestrict() then
        return true
    end
    -- 成年人不受限制
    if M.isAdult() then
        return false
    end
    local bjDate = getBeijingDate()
    local hour = bjDate.hour
    local curfew = hour >= CURFEW_START_HOUR or hour < CURFEW_END_HOUR

    logger.info(MODULE, "isCurfew",
        "beijingTime=" .. getBeijingTimeStr() ..
        ", hour=" .. tostring(hour) ..
        ", curfewStart=" .. tostring(CURFEW_START_HOUR) ..
        ", curfewEnd=" .. tostring(CURFEW_END_HOUR) ..
        ", curfew=" .. tostring(curfew))

    return curfew
end

-- ============================================================================
-- 公共 API - 时长管理
-- ============================================================================

--- 是否已被 60 分钟强制退出锁定
---@return boolean
function M.isLocked()
    if testLockout_ then return true end
    if M.isAdult() then return false end
    return locked_
end

--- 获取会话累计游玩分钟数
---@return number
function M.getSessionPlayMin()
    return math.floor(sessionPlaySec_ / 60)
end

--- 获取剩余可玩分钟数
---@return number
function M.getRemainingMin()
    if M.isAdult() then return 999 end
    local remaining = math.max(0, LOCKOUT_THRESHOLD - sessionPlaySec_)
    return math.ceil(remaining / 60)
end

--- 是否允许进入游戏
---@return boolean allowed
---@return string|nil blockReason "curfew"|"time_limit"|nil
function M.canEnterGame()
    if not compliance.isEnabled() then
        return true, nil
    end
    if testLockout_ then
        return false, "time_limit"
    end
    -- 成年人无限制
    if M.isAdult() then
        return true, nil
    end
    -- 宵禁时段
    if M.isCurfew() then
        return false, "curfew"
    end
    -- 时长锁定
    if locked_ then
        return false, "time_limit"
    end
    return true, nil
end

--- 获取拦截原因（供 UI 显示）
---@return string|nil "curfew"|"time_limit"|nil
function M.getBlockReason()
    if testLockout_ then return "time_limit" end
    if M.isAdult() then return nil end
    if M.isCurfew() then return "curfew" end
    if locked_ then return "time_limit" end
    return nil
end

-- ============================================================================
-- 公共 API - 游戏进入/退出通知
-- ============================================================================

--- 进入游戏时调用（开始计时）
function M.onGameEnter()
    if M.isAdult() then return end
    inGame_ = true
    logger.info(MODULE, "onGameEnter", "timer started, sessionSec=" .. math.floor(sessionPlaySec_))
end

--- 退出游戏时调用（暂停计时）
function M.onGameExit()
    inGame_ = false
    logger.info(MODULE, "onGameExit", "timer paused, sessionSec=" .. math.floor(sessionPlaySec_))
end

-- ============================================================================
-- 公共 API - 回调注册
-- ============================================================================

--- 注册弹窗请求回调
--- popupType: "remind_30" | "force_60" | "curfew_exit"
---@param fn fun(popupType: string)
function M.setOnPopupRequest(fn)
    onPopupRequest_ = fn
end

--- 注册强制退出回调
---@param fn fun(reason: string)
function M.setOnForceExit(fn)
    onForceExit_ = fn
end

-- ============================================================================
-- 公共 API - 初始化 & 每帧更新
-- ============================================================================

--- 初始化（在 main.lua Start() 中调用）
function M.init()
    sessionPlaySec_ = 0
    inGame_ = false
    warned30_ = false
    locked_ = false
    testLockout_ = false
    -- 诊断日志：打印系统时间 vs 北京时间，方便排查时区问题
    local sysHour = os.date("*t").hour
    local bjHour = getBeijingHour()
    logger.info(MODULE, "init", "session timer reset | sysHour=" .. sysHour .. " beijingHour=" .. bjHour .. " beijingTime=" .. getBeijingTimeStr())
end

--- 每帧更新（在 main.lua PostUpdate 中调用）
---@param dt number 帧间隔（秒）
function M.update(dt)
    -- 成年人不做任何处理
    if M.isAdult() then return end

    -- 游戏中计时
    if inGame_ and not locked_ then
        sessionPlaySec_ = sessionPlaySec_ + dt

        -- 30 分钟提醒（仅一次）
        if not warned30_ and sessionPlaySec_ >= REMIND_THRESHOLD then
            warned30_ = true
            logger.info(MODULE, "update", "30min remind triggered")
            if onPopupRequest_ then
                onPopupRequest_("remind_30")
            end
        end

        -- 60 分钟强制退出
        if not locked_ and sessionPlaySec_ >= LOCKOUT_THRESHOLD then
            locked_ = true
            inGame_ = false
            logger.info(MODULE, "update", "60min lockout triggered")
            if onPopupRequest_ then
                onPopupRequest_("force_60")
            end
            if onForceExit_ then
                onForceExit_("time_limit")
            end
        end
    end

    -- 游戏中跨入宵禁时段自动退出
    if inGame_ and M.isCurfew() then
        inGame_ = false
        logger.info(MODULE, "update", "curfew hit during game")
        if onPopupRequest_ then
            onPopupRequest_("curfew_exit")
        end
        if onForceExit_ then
            onForceExit_("curfew")
        end
    end
end

--- 触发 60 分钟强制退出（仅供测试热键使用）
function M.triggerTestForceLockout()
    if not compliance.isEnabled() then return end
    sessionPlaySec_ = LOCKOUT_THRESHOLD
    warned30_ = true
    locked_ = true
    testLockout_ = true
    inGame_ = false
    logger.info(MODULE, "triggerTestForceLockout", "F4 test lockout triggered")
    if onPopupRequest_ then
        onPopupRequest_("force_60")
    end
    if onForceExit_ then
        onForceExit_("time_limit")
    end
end

--- 获取当前北京时间字符串（供 UI 显示）
---@return string "HH:MM"
function M.getBeijingTimeStr()
    return getBeijingTimeStr()
end

--- 重置计时（仅供调试用）
function M.resetTimer()
    sessionPlaySec_ = 0
    warned30_ = false
    locked_ = false
    testLockout_ = false
    inGame_ = false
    logger.info(MODULE, "resetTimer", "all timers reset")
end

return M
