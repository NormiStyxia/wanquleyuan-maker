--- 游戏生命周期 SDK
--- 定义状态、退出原因、保存触发器、错误码等常量
local M = {}

-- ============================================================================
-- 状态枚举
-- ============================================================================
M.State = {
    IDLE      = "IDLE",
    ENTERING  = "ENTERING",
    RUNNING   = "RUNNING",
    PAUSING   = "PAUSING",
    PAUSED    = "PAUSED",
    RESUMING  = "RESUMING",
    EXITING   = "EXITING",
}

-- ============================================================================
-- 合法状态跳转表
-- ============================================================================
M.VALID_TRANSITIONS = {
    IDLE      = { ENTERING = true },
    ENTERING  = { RUNNING = true, IDLE = true },     -- IDLE 用于 enter 失败回退
    RUNNING   = { PAUSING = true, EXITING = true },
    PAUSING   = { PAUSED = true },
    PAUSED    = { RESUMING = true, EXITING = true },
    RESUMING  = { RUNNING = true },
    EXITING   = { IDLE = true },
}

-- ============================================================================
-- 退出原因
-- ============================================================================
M.ExitReason = {
    USER_BACK       = "user_back",
    HOME_SWITCH     = "home_switch",
    APP_BACKGROUND  = "app_background",
    CRASH_RECOVER   = "crash_recover",
    ERROR           = "error",
}

-- ============================================================================
-- 保存触发器
-- ============================================================================
M.SaveTrigger = {
    CHECKPOINT = "checkpoint",
    PAUSE      = "pause",
    EXIT       = "exit",
    INTERVAL   = "interval",
}

-- ============================================================================
-- 进入来源
-- ============================================================================
M.EntryFrom = {
    HOME_CONTINUE   = "home_continue",
    HOME_RANDOM     = "home_random",
    HOME_RECOMMEND  = "home_recommend",
    LIBRARY         = "library",
}

-- ============================================================================
-- 错误码
-- ============================================================================
M.ErrorCode = {
    INVALID_TRANSITION  = "GL-001",
    LIFECYCLE_TIMEOUT   = "GL-002",
    SAVE_FAILED         = "GL-003",
    SNAPSHOT_INVALID    = "GL-004",
    ADAPTER_MISSING     = "GL-005",
    CRASH_RECOVER_FAIL  = "GL-006",
}

-- ============================================================================
-- 超时配置（毫秒）
-- ============================================================================
M.Timeout = {
    ENTER = 3000,
    PAUSE = 2000,
    EXIT  = 2000,
    SAVE  = 2000,
}

return M
