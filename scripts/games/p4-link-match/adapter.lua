--- 连连看 - 游戏生命周期适配器
--- 职责：NanoVG 上下文管理、事件订阅、屏幕切换（选关 ↔ 关卡）
local logger = require("shared.utils.logger")
local save = require("games.p4-link-match.save")
local levelSelect = require("games.p4-link-match.screens.level-select")
local gameplay = require("games.p4-link-match.screens.gameplay")
local SoundManager = require("shared.sound-manager")
local sounds = require("games.p4-link-match.sounds")
local uiTap = require("shared.utils.ui-tap")
local FoxMascot = require("shared.components.fox-mascot")
local Density = require("shared.utils.density")
local InputHandler = require("shared.utils.input-handler")
local bgManager = require("shared.background-manager")

local M = {}
local MODULE = "p4-link-match"

-- ============================================================================
-- 内部状态
-- ============================================================================

---@type userdata|nil NanoVG 上下文
local nvgCtx_ = nil
---@type number 字体句柄
local fontHandle_ = -1
---@type string 当前屏幕 "level_select" | "gameplay"
local screen_ = "level_select"
---@type table[] 关卡列表（来自 data/levels.lua）
local levels_ = {}
---@type table 存档数据
local saveData_ = {}
---@type table|nil 选关界面的点击区域
local selectHitAreas_ = nil
---@type number 累计游玩计时器
local playTimer_ = 0
---@type table|nil 公共输入处理器
local inputHandler_ = nil
--- 主线模式标志
local storylineMode_ = false
--- 主线模式参数 { levelData, onComplete, mode }
local storylineOpts_ = nil

-- ============================================================================
-- 关卡数据加载
-- ============================================================================

local function loadLevels()
    local levelsData = require("games.p4-link-match.data.levels")
    return levelsData.levels or {}
end

-- ============================================================================
-- 屏幕切换
-- ============================================================================

---@param levelIndex number|nil 定位到指定关卡所在页
local function gotoLevelSelect(levelIndex)
    gameplay.leave()
    screen_ = "level_select"
    selectHitAreas_ = nil
    if levelIndex then
        levelSelect.gotoPageForLevel(levelIndex)
    end
    logger.info(MODULE, "gotoLevelSelect", "switch to level select")
end

---@param levelIndex number
local function gotoLevel(levelIndex)
    local lv = levels_[levelIndex]
    if not lv then
        logger.warn(MODULE, "gotoLevel", "invalid index: " .. tostring(levelIndex))
        return
    end

    if storylineMode_ then
        -- 主线模式：独立回调，不记录存档
        local gameContainer = require("modules.game-container.init")
        gameplay.enter(lv, { completedLevels = {}, totalPlaySec = 0 }, {
            hasNextLevel = false,
            storylineMode = true,

            onLevelComplete = function(levelId, clearTimeMs, starRating)
                logger.info(MODULE, "onLevelComplete(storyline)",
                    levelId .. " time=" .. clearTimeMs .. "ms stars=" .. tostring(starRating))
                if storylineOpts_ and storylineOpts_.onComplete then
                    storylineOpts_.onComplete()
                end
                return false
            end,

            onRequestBack = function()
                gameContainer.exit("user_back")
            end,

            onRequestNextLevel = function()
                gameContainer.exit("user_back")
            end,
        })
    else
        -- 普通模式
        gameplay.enter(lv, saveData_, {
            onLevelComplete = function(levelId, clearTimeMs, starRating)
                local updated = save.recordCompletion(saveData_, levelId, clearTimeMs, starRating)
                save.save(saveData_)
                logger.info(MODULE, "onLevelComplete",
                    levelId .. " time=" .. clearTimeMs .. "ms stars=" .. tostring(starRating) ..
                    " newBest=" .. tostring(updated))
                return updated
            end,

            onRequestBack = function()
                gotoLevelSelect(levelIndex)
            end,

            onRequestNextLevel = function()
                for i, lv2 in ipairs(levels_) do
                    if lv2.levelId == lv.levelId then
                        if i < #levels_ and save.isUnlocked(saveData_, levels_[i + 1].levelId, levels_) then
                            gotoLevel(i + 1)
                        else
                            gotoLevelSelect(i)
                        end
                        return
                    end
                end
                gotoLevelSelect(levelIndex)
            end,
        })
    end

    screen_ = "gameplay"
    logger.info(MODULE, "gotoLevel", "enter level: " .. lv.levelId
        .. (storylineMode_ and " [storyline]" or ""))
end

-- ============================================================================
-- 事件处理（全局函数，P4LM_ 前缀）
-- ============================================================================

--- NanoVG 渲染回调
---@param eventType string
---@param eventData table
function P4LM_HandleNanoVGRender(eventType, eventData)
    if not nvgCtx_ then return end

    local logW, logH = Density.beginFrame(nvgCtx_)

    local function foxAfterBg()
        local foxOptions = screen_ == "level_select" and FoxMascot.getLevelSelectOptions(34) or { handdrawn = true }
        FoxMascot.render(nvgCtx_, logW, logH, 34, foxOptions)
    end

    if screen_ == "level_select" then
        selectHitAreas_ = levelSelect.draw(nvgCtx_, logW, logH, levels_, saveData_, foxAfterBg)
    elseif screen_ == "gameplay" then
        gameplay.render(nvgCtx_, logW, logH, foxAfterBg)
    end

    Density.endFrame(nvgCtx_)
end

--- 逻辑更新回调
---@param eventType string
---@param eventData UpdateEventData
function P4LM_HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    playTimer_ = playTimer_ + dt
    FoxMascot.update(dt)

    if screen_ == "gameplay" then
        gameplay.update(dt)
    end
end

--- 键盘事件回调
---@param eventType string
---@param eventData KeyDownEventData
function P4LM_HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()

    if screen_ == "gameplay" then
        gameplay.handleKeyDown(key)
    elseif screen_ == "level_select" then
        if key == KEY_ESCAPE then
            local gameContainer = require("modules.game-container.init")
            gameContainer.exit("user_back")
        end
    end
end

--- 鼠标/触屏事件：委托给公共输入处理器
function P4LM_HandleMouseButtonDown(eventType, eventData)
    if inputHandler_ then inputHandler_.handleMouseDown(eventType, eventData) end
end
function P4LM_HandleMouseButtonUp(eventType, eventData)
    if inputHandler_ then inputHandler_.handleMouseUp(eventType, eventData) end
end
function P4LM_HandleTouchBegin(eventType, eventData)
    if inputHandler_ then inputHandler_.handleTouchBegin(eventType, eventData) end
end
function P4LM_HandleTouchEnd(eventType, eventData)
    if inputHandler_ then inputHandler_.handleTouchEnd(eventType, eventData) end
end

-- ============================================================================
-- GameLifecycleAdapter 接口
-- ============================================================================

---@param ctx table GameEnterContext
function M:onEnter(ctx)
    logger.info(MODULE, "onEnter", "gameId=" .. ctx.gameId .. " session=" .. ctx.sessionId)

    -- 主线模式检测
    if ctx.storylineOpts and ctx.storylineOpts.levelData then
        storylineMode_ = true
        storylineOpts_ = ctx.storylineOpts
        levels_ = { ctx.storylineOpts.levelData }
        saveData_ = {}
        logger.info(MODULE, "onEnter", "[storyline] using external level data")
    else
        storylineMode_ = false
        storylineOpts_ = nil
        -- 加载关卡数据
        levels_ = loadLevels()
        if #levels_ == 0 then
            logger.error(MODULE, "onEnter", "no levels loaded!")
            return
        end
        -- 加载存档（本地缓存 + 云端同步）
        saveData_ = save.load()
        save.syncFromCloud(saveData_, function(updated)
            if updated then
                logger.info(MODULE, "onEnter", "cloud save synced, progress updated")
            end
        end)
    end

    playTimer_ = 0

    -- 创建 NanoVG 上下文
    nvgCtx_ = nvgCreate(1)
    if not nvgCtx_ then
        logger.error(MODULE, "onEnter", "failed to create NanoVG context")
        return
    end

    -- 初始化字体
    fontHandle_ = nvgCreateFont(nvgCtx_, "sans", "Fonts/LongZhuTi-Regular.ttf")
    if fontHandle_ < 0 then
        logger.warn(MODULE, "onEnter", "font load failed, text may not render")
    end

    -- 订阅事件
    SubscribeToEvent(nvgCtx_, "NanoVGRender", "P4LM_HandleNanoVGRender")
    FoxMascot.init(nvgCtx_)
    SubscribeToEvent("Update", "P4LM_HandleUpdate")
    SubscribeToEvent("KeyDown", "P4LM_HandleKeyDown")
    SubscribeToEvent("MouseButtonDown", "P4LM_HandleMouseButtonDown")
    SubscribeToEvent("MouseButtonUp", "P4LM_HandleMouseButtonUp")
    SubscribeToEvent("TouchBegin", "P4LM_HandleTouchBegin")
    SubscribeToEvent("TouchEnd", "P4LM_HandleTouchEnd")

    -- 初始化音效系统
    SoundManager.init(sounds)

    -- 创建公共输入处理器
    inputHandler_ = InputHandler.create({
        getScreen = function() return screen_ end,
        levelSelect = levelSelect,
        getSelectHitAreas = function() return selectHitAreas_ end,
        gotoLevel = gotoLevel,
        onGameplayClick = function(startX, startY)
            gameplay.handleClick(startX, startY)
        end,
        onPointerUp = nil,
    })

    if storylineMode_ then
        -- 主线模式：跳过选关，直接进入关卡
        screen_ = "gameplay"
        gotoLevel(1)
        logger.info(MODULE, "onEnter", "[storyline] direct enter level")
    else
        -- 普通模式：显示选关界面
        screen_ = "level_select"
        selectHitAreas_ = nil
        levelSelect.reset()
        -- 进入选关时狐狸问候
        local selectGreetings = {
            "连连看开始！找出相同的图案连起来~",
            "眼力大考验！选一关来挑战吧~",
            "把一样的图案连在一起，你能行的！",
            "连连看可以锻炼观察力哦~",
            "选个关卡，看看你的眼力有多好！",
        }
        FoxMascot.showMessage(selectGreetings[math.random(1, #selectGreetings)])
        logger.info(MODULE, "onEnter", "ready, levels=" .. #levels_)
    end
end

---@param ctx table
function M:onResume(ctx)
    logger.info(MODULE, "onResume", "resumed")
    if screen_ == "gameplay" then
        gameplay.resume()
    end
end

---@param reason string
---@return table|nil snapshot
function M:onPause(reason)
    logger.info(MODULE, "onPause", "reason=" .. reason)

    if screen_ == "gameplay" then
        gameplay.pause()
    end

    if storylineMode_ then
        playTimer_ = 0
        return nil
    end

    saveData_.totalPlaySec = saveData_.totalPlaySec + math.floor(playTimer_)
    playTimer_ = 0
    save.save(saveData_)

    return save.toProgressSnapshot(saveData_, levels_)
end

---@param trigger string
---@return table|nil snapshot
function M:onSaveProgress(trigger)
    logger.info(MODULE, "onSaveProgress", "trigger=" .. trigger)

    if storylineMode_ then
        playTimer_ = 0
        return nil
    end

    saveData_.totalPlaySec = saveData_.totalPlaySec + math.floor(playTimer_)
    playTimer_ = 0
    save.save(saveData_)

    return save.toProgressSnapshot(saveData_, levels_)
end

---@param reason string
---@return table|nil snapshot
function M:onExit(reason)
    logger.info(MODULE, "onExit", "reason=" .. reason
        .. (storylineMode_ and " [storyline]" or ""))

    -- 保存进度（主线模式跳过）
    if not storylineMode_ then
        saveData_.totalPlaySec = saveData_.totalPlaySec + math.floor(playTimer_)
        playTimer_ = 0
        save.save(saveData_)
    end

    -- 先取消事件订阅（防止清理资源期间回调访问已释放对象）
    UnsubscribeFromEvent("Update")
    UnsubscribeFromEvent("KeyDown")
    UnsubscribeFromEvent("MouseButtonDown")
    UnsubscribeFromEvent("MouseButtonUp")
    UnsubscribeFromEvent("TouchBegin")
    UnsubscribeFromEvent("TouchEnd")

    -- 清理游戏逻辑
    gameplay.leave()

    -- 关闭音效系统
    SoundManager.shutdown()

    -- 清理狐狸立绘
    FoxMascot.cleanup()

    -- 清除主题背景图缓存（handle 与上下文绑定，必须在销毁前清除）
    require("shared.rendering.piece-sprites").release(nvgCtx_)
    bgManager.clearThemeCache(nvgCtx_)

    -- 销毁 NanoVG 上下文
    if nvgCtx_ then
        nvgDelete(nvgCtx_)
        nvgCtx_ = nil
    end

    -- 清理全局事件处理函数
    P4LM_HandleNanoVGRender = nil
    P4LM_HandleUpdate = nil
    P4LM_HandleKeyDown = nil
    P4LM_HandleMouseButtonDown = nil
    P4LM_HandleMouseButtonUp = nil
    P4LM_HandleTouchBegin = nil
    P4LM_HandleTouchEnd = nil

    -- 清理状态
    screen_ = "level_select"
    levels_ = {}
    saveData_ = {}
    selectHitAreas_ = nil
    fontHandle_ = -1
    if inputHandler_ then inputHandler_.reset() end
    inputHandler_ = nil
    storylineMode_ = false
    storylineOpts_ = nil

    logger.info(MODULE, "onExit", "cleanup done")
    return nil
end

--- 获取游戏 UI（NanoVG 自绘，不使用 UI 树）
---@return nil
function M:getUI()
    return nil
end

return M
