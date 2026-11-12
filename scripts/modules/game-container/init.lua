--- 游戏容器模块
--- 负责：加载 adapter、驱动 Lifecycle 状态机、暂停/恢复、异常兜底
local logger = require("shared.utils.logger")
local LC = require("sdk.game-lifecycle.init")
local compliance = require("config.compliance")
local antiAddiction = require("shared.anti-addiction")

local M = {}
local MODULE = "game-container"

-- ============================================================================
-- 内部状态
-- ============================================================================
local state_ = LC.State.IDLE
local adapter_ = nil          -- 当前游戏 adapter
local gameConfig_ = nil       -- 当前游戏配置
local sessionId_ = nil        -- 当前会话 ID
local onExitCallback_ = nil   -- 退出后回调（通知外部返回大厅）

-- ============================================================================
-- 工具函数
-- ============================================================================

local function generateSessionId()
    return "s-" .. tostring(os.time()) .. "-" .. tostring(math.random(1000, 9999))
end

--- 强制重置到 IDLE，安全清理当前 adapter（异常恢复用）
local function forceReset(reason)
    local oldState = state_
    logger.warn(MODULE, "forceReset",
        "recovering from " .. oldState .. " | reason=" .. (reason or "unknown"),
        LC.ErrorCode.CRASH_RECOVER_FAIL)

    -- 安全清理 adapter（pcall 保护，避免清理过程再次异常）
    if adapter_ then
        local ok, err = pcall(function()
            if type(adapter_.onExit) == "function" then
                adapter_:onExit(LC.ExitReason.CRASH_RECOVER)
            end
        end)
        if not ok then
            logger.error(MODULE, "forceReset", "adapter onExit failed: " .. tostring(err))
        end
    end

    -- 卸载 adapter 模块缓存
    if gameConfig_ and gameConfig_.entryModule then
        package.loaded[gameConfig_.entryModule] = nil
    end

    adapter_ = nil
    gameConfig_ = nil
    sessionId_ = nil
    state_ = LC.State.IDLE

    logger.info(MODULE, "forceReset", oldState .. " -> IDLE (recovered)")
end

--- 尝试状态跳转，非法跳转会触发异常恢复
---@param newState string
---@return boolean
local function transition(newState)
    local validTargets = LC.VALID_TRANSITIONS[state_]
    if not validTargets or not validTargets[newState] then
        logger.error(MODULE, "transition",
            "invalid: " .. state_ .. " -> " .. newState,
            LC.ErrorCode.INVALID_TRANSITION)
        -- 非 IDLE 状态下的非法跳转说明状态已损坏，强制恢复
        if state_ ~= LC.State.IDLE then
            forceReset("invalid_transition:" .. state_ .. "->" .. newState)
        end
        return false
    end
    local oldState = state_
    state_ = newState
    logger.info(MODULE, "transition", oldState .. " -> " .. newState)
    return true
end

--- 安全调用 adapter 方法，带 pcall 保护
---@param methodName string
---@vararg any
---@return boolean, any
local function safeCall(methodName, ...)
    if not adapter_ then return false, "no adapter" end
    local method = adapter_[methodName]
    if type(method) ~= "function" then
        return true, nil  -- 方法不存在视为成功（可选接口）
    end
    local ok, result = pcall(method, adapter_, ...)
    if not ok then
        logger.error(MODULE, "safeCall", methodName .. " failed: " .. tostring(result))
        return false, result
    end
    return true, result
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 设置退出回调（main.lua 调用，用于返回大厅）
---@param callback function()
function M.setOnExitCallback(callback)
    onExitCallback_ = callback
end

--- 获取当前状态
---@return string
function M.getState()
    return state_
end

--- 获取当前游戏配置
---@return table|nil
function M.getGameConfig()
    return gameConfig_
end

--- 是否正在运行游戏
---@return boolean
function M.isRunning()
    return state_ == LC.State.RUNNING or state_ == LC.State.PAUSED or state_ == LC.State.PAUSING or state_ == LC.State.RESUMING
end

--- 进入游戏
---@param gameConfig table 游戏配置（来自 game-registry）
---@param from string|nil 进入来源（home_continue 等）
---@param opts table|nil 可选参数（主线模式：{ levelData, onComplete, mode }）
---@return boolean 是否成功进入
function M.enter(gameConfig, from, opts)
    -- 防沉迷前置检查：未成年人宵禁/时长锁定时禁止进入
    if compliance.isEnabled() then
        local allowed, blockReason = antiAddiction.canEnterGame()
        if not allowed then
            logger.warn(MODULE, "enter", "blocked by anti-addiction: " .. (blockReason or "unknown"))
            return false
        end
    end

    if not transition(LC.State.ENTERING) then
        return false
    end

    gameConfig_ = gameConfig
    sessionId_ = generateSessionId()

    -- 加载 adapter
    local ok, adapterOrErr = pcall(require, gameConfig.entryModule)
    if not ok or type(adapterOrErr) ~= "table" then
        logger.error(MODULE, "enter",
            "failed to load adapter for " .. gameConfig.gameId .. ": " .. tostring(adapterOrErr),
            LC.ErrorCode.ADAPTER_MISSING)
        transition(LC.State.IDLE)
        gameConfig_ = nil
        adapter_ = nil
        return false
    end
    adapter_ = adapterOrErr

    -- 调用 onEnter
    local ctx = {
        gameId = gameConfig.gameId,
        sessionId = sessionId_,
        from = from or LC.EntryFrom.HOME_RECOMMEND,
        storylineOpts = opts,  -- 透传给 adapter（主线模式参数）
    }

    local callOk, _ = safeCall("onEnter", ctx)
    if not callOk then
        logger.error(MODULE, "enter", "onEnter failed", LC.ErrorCode.LIFECYCLE_TIMEOUT)
        transition(LC.State.IDLE)
        gameConfig_ = nil
        adapter_ = nil
        return false
    end

    transition(LC.State.RUNNING)

    -- 通知防沉迷模块：游戏开始，启动计时
    antiAddiction.onGameEnter()

    logger.info(MODULE, "enter", "success: " .. gameConfig.gameId)
    return true
end

--- 暂停游戏
---@param reason string|nil 暂停原因
---@return boolean
function M.pause(reason)
    if state_ ~= LC.State.RUNNING then return false end
    if not transition(LC.State.PAUSING) then return false end

    safeCall("onPause", reason or "user_pause")
    transition(LC.State.PAUSED)
    return true
end

--- 恢复游戏
---@return boolean
function M.resume()
    if state_ ~= LC.State.PAUSED then return false end
    if not transition(LC.State.RESUMING) then return false end

    local ctx = {
        gameId = gameConfig_ and gameConfig_.gameId or "",
        sessionId = sessionId_ or "",
        from = "resume",
    }
    safeCall("onResume", ctx)
    transition(LC.State.RUNNING)
    return true
end

--- 退出游戏
---@param reason string|nil 退出原因
function M.exit(reason)
    local exitReason = reason or LC.ExitReason.USER_BACK

    -- 从 RUNNING 或 PAUSED 正常退出；其他非 IDLE 状态走强制恢复
    if state_ ~= LC.State.RUNNING and state_ ~= LC.State.PAUSED then
        if state_ ~= LC.State.IDLE then
            logger.warn(MODULE, "exit", "abnormal exit from state: " .. state_)
            forceReset("exit_from_" .. state_)
            if onExitCallback_ then pcall(onExitCallback_) end
        else
            logger.warn(MODULE, "exit", "already IDLE, nothing to exit")
        end
        return
    end

    if not transition(LC.State.EXITING) then return end

    -- 通知防沉迷模块：游戏退出，暂停计时
    antiAddiction.onGameExit()

    -- 尝试保存进度
    safeCall("onSaveProgress", LC.SaveTrigger.EXIT)

    -- 调用 onExit
    safeCall("onExit", exitReason)

    -- 清理
    adapter_ = nil
    -- 卸载 adapter 模块缓存，下次进入重新加载
    if gameConfig_ and gameConfig_.entryModule then
        package.loaded[gameConfig_.entryModule] = nil
    end

    local gameId = gameConfig_ and gameConfig_.gameId or "unknown"
    gameConfig_ = nil
    sessionId_ = nil

    transition(LC.State.IDLE)
    logger.info(MODULE, "exit", gameId .. " | reason=" .. exitReason)

    -- 通知外部返回大厅
    if onExitCallback_ then
        pcall(onExitCallback_)
    end
end

--- 强制恢复到 IDLE 状态（外部异常恢复入口）
--- 当检测到游戏异常卡死时，外部可调用此方法强制回收
---@param reason string|nil 恢复原因
function M.forceReset(reason)
    if state_ == LC.State.IDLE then return end
    forceReset(reason or "external")
    if onExitCallback_ then pcall(onExitCallback_) end
end

--- 获取当前游戏的 UI（如果 adapter 提供了 getUI 方法）
---@return any|nil UI 节点
function M.getGameUI()
    if not adapter_ then return nil end
    if type(adapter_.getUI) == "function" then
        local ok, ui = pcall(adapter_.getUI, adapter_)
        if ok then return ui end
    end
    return nil
end

return M
