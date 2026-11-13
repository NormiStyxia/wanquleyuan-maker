--- 推箱子 - 游戏生命周期适配器
--- 职责：NanoVG 上下文管理、事件订阅、屏幕切换（选关 ↔ 关卡）
local logger = require("shared.utils.logger")
local levelLoader = require("games.p1-puzzle-land.logic.level-loader")
local save = require("games.p1-puzzle-land.save")
local levelSelect = require("games.p1-puzzle-land.screens.level-select")
local gameplay = require("games.p1-puzzle-land.screens.gameplay")
local levelEditor = require("games.p1-puzzle-land.screens.level-editor")
local ScreenTransition = require("shared.components.screen-transition")
local SoundManager = require("shared.sound-manager")
local sounds = require("games.p1-puzzle-land.sounds")
local uiTap = require("shared.utils.ui-tap")
local FoxMascot = require("shared.components.fox-mascot")
local Density = require("shared.utils.density")
local InputHandler = require("shared.utils.input-handler")
local bgManager = require("shared.background-manager")

local M = {}
local MODULE = "p1-puzzle-land"

-- ============================================================================
-- 内部状态
-- ============================================================================

---@type userdata|nil NanoVG 上下文
local nvgCtx_ = nil
---@type number 字体句柄
local fontHandle_ = -1
---@type string 当前屏幕 "level_select" | "gameplay" | "editor"
local screen_ = "level_select"
---@type table[] 加载后的关卡列表（1-based）
local levels_ = {}
---@type table 存档数据
local saveData_ = {}
---@type table|nil 选关界面的点击区域
local selectHitAreas_ = nil
---@type number 累计游玩计时器
local playTimer_ = 0
---@type table|nil 公共输入处理器
local inputHandler_ = nil
---@type table|nil 编辑器界面的点击区域
local editorHitAreas_ = nil
--- 编辑器拖动中标记（区分拖动放置与按钮点击）
local editorDragging_ = false
--- 是否从编辑器进入试玩（返回时回到编辑器而非选关）
local editorTestPlay_ = false
--- 主线模式标志
local storylineMode_ = false
--- 主线模式参数 { levelData, onComplete, mode }
local storylineOpts_ = nil

-- ============================================================================
-- 屏幕切换
-- ============================================================================

--- 进入关卡选择界面（带转场）
---@param keepPage boolean|nil 是否保持当前页（从关卡返回时）
---@param levelIndex number|nil 定位到指定关卡所在页
local function gotoLevelSelect(keepPage, levelIndex)
    if ScreenTransition.isAnimating() then return end
    ScreenTransition.run(function()
        gameplay.leave()
        screen_ = "level_select"
        selectHitAreas_ = nil
        if levelIndex then
            levelSelect.gotoPageForLevel(levelIndex)
        end
        logger.info(MODULE, "gotoLevelSelect", "switch to level select")
    end)
end

--- 进入编辑器（带转场）
local function gotoEditor()
    if ScreenTransition.isAnimating() then return end
    ScreenTransition.run(function()
        gameplay.leave()
        screen_ = "editor"
        editorHitAreas_ = nil
        levelEditor.enter()
        logger.info(MODULE, "gotoEditor", "switch to level editor")
    end)
end

--- 从编辑器进入试玩（带转场）
local function gotoEditorTestPlay()
    if ScreenTransition.isAnimating() then return end

    local levelData, errMsg = levelEditor.buildPlayableLevel()
    if not levelData then
        logger.warn(MODULE, "gotoEditorTestPlay", "cannot play: " .. tostring(errMsg))
        return
    end

    ScreenTransition.run(function()
        editorTestPlay_ = true
        screen_ = "gameplay"

        gameplay.enter(levelData, {
            hasNextLevel = false,

            onLevelComplete = function(levelId, stars)
                logger.info(MODULE, "editorTestPlay", "level complete, stars=" .. stars)
            end,

            onRequestBack = function()
                -- 返回编辑器（而非选关）
                if ScreenTransition.isAnimating() then return end
                ScreenTransition.run(function()
                    gameplay.leave()
                    editorTestPlay_ = false
                    screen_ = "editor"
                    editorHitAreas_ = nil
                    logger.info(MODULE, "editorTestPlay", "back to editor")
                end)
            end,

            onRequestNextLevel = function()
                -- 试玩无下一关，返回编辑器
                if ScreenTransition.isAnimating() then return end
                ScreenTransition.run(function()
                    gameplay.leave()
                    editorTestPlay_ = false
                    screen_ = "editor"
                    editorHitAreas_ = nil
                    logger.info(MODULE, "editorTestPlay", "back to editor (from win)")
                end)
            end,
        })

        logger.info(MODULE, "gotoEditorTestPlay", "enter test play")
    end)
end

--- 进入关卡（带转场 + 出生动画）
---@param levelIndex number 关卡索引（levels_ 中的下标）
local function gotoLevel(levelIndex)
    if ScreenTransition.isAnimating() then return end

    local lv = levels_[levelIndex]
    if not lv then
        logger.warn(MODULE, "gotoLevel", "invalid index: " .. tostring(levelIndex))
        return
    end

    ScreenTransition.run(function()
        if storylineMode_ then
            -- 主线模式：不更新游戏存档，通关回调走主线逻辑
            gameplay.enter(lv, {
                hasNextLevel = false,
                storylineMode = true,

                onLevelComplete = function(levelId, stars)
                    if storylineOpts_ and storylineOpts_.onComplete then
                        storylineOpts_.onComplete()
                    end
                    logger.info(MODULE, "onLevelComplete[storyline]", levelId .. " stars=" .. stars)
                end,

                onRequestBack = function()
                    local gameContainer = require("modules.game-container.init")
                    gameContainer.exit("user_back")
                end,

                onRequestNextLevel = function()
                    local gameContainer = require("modules.game-container.init")
                    gameContainer.exit("user_back")
                end,
            })
        else
            -- 正常模式：原有逻辑
            saveData_.currentLevel = lv.id

            gameplay.enter(lv, {
                hasNextLevel = levelIndex < #levels_,

                onLevelComplete = function(levelId, stars)
                    local updated = save.recordCompletion(saveData_, levelId, stars)
                    if updated then
                        save.save(saveData_)
                    end
                    logger.info(MODULE, "onLevelComplete", levelId .. " stars=" .. stars)
                end,

                onRequestBack = function()
                    gotoLevelSelect(true, levelIndex)
                end,

                onRequestNextLevel = function()
                    for i, lv2 in ipairs(levels_) do
                        if lv2.id == lv.id then
                            if i < #levels_ and save.isUnlocked(saveData_, levels_[i + 1].id, levels_) then
                                gotoLevel(i + 1)
                            else
                                gotoLevelSelect(true, i)
                            end
                            return
                        end
                    end
                    gotoLevelSelect(true, levelIndex)
                end,
            })
        end

        screen_ = "gameplay"
        logger.info(MODULE, "gotoLevel", "enter level: " .. lv.id .. (storylineMode_ and " [storyline]" or ""))
    end)
end

-- ============================================================================
-- 事件处理（UrhoX SubscribeToEvent 要求全局函数名字符串）
-- ============================================================================

--- NanoVG 渲染回调
---@param eventType string
---@param eventData table
function P1PZ_HandleNanoVGRender(eventType, eventData)
    if not nvgCtx_ then return end

    local logW, logH = Density.beginFrame(nvgCtx_)

    local function foxAfterBg()
        local foxOptions = screen_ == "level_select" and FoxMascot.getLevelSelectOptions(0) or { handdrawn = true }
        FoxMascot.render(nvgCtx_, logW, logH, 0, foxOptions)
    end

    if screen_ == "level_select" then
        selectHitAreas_ = levelSelect.draw(nvgCtx_, logW, logH, levels_, saveData_, foxAfterBg)
    elseif screen_ == "gameplay" then
        gameplay.render(nvgCtx_, logW, logH, foxAfterBg)
    elseif screen_ == "editor" then
        editorHitAreas_ = levelEditor.render(nvgCtx_, logW, logH)
        FoxMascot.render(nvgCtx_, logW, logH, 0, {handdrawn=true})
    end

    Density.endFrame(nvgCtx_)
end

--- 逻辑更新回调
---@param eventType string
---@param eventData UpdateEventData
function P1PZ_HandleUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()

    playTimer_ = playTimer_ + dt
    FoxMascot.update(dt)

    if screen_ == "gameplay" then
        gameplay.update(dt)
    elseif screen_ == "editor" then
        levelEditor.update(dt)
    end
end

--- 键盘事件回调
---@param eventType string
---@param eventData KeyDownEventData
function P1PZ_HandleKeyDown(eventType, eventData)
    local key = eventData["Key"]:GetInt()
    local qualifiers = eventData["Qualifiers"]:GetInt()

    -- 编辑器模态框优先处理
    if screen_ == "editor" and levelEditor.isModalShowing() then
        levelEditor.handleKeyForModal(key, qualifiers)
        return
    end

    if screen_ == "level_select" then
        if key == KEY_ESCAPE then
            -- 返回大厅由 game-container 处理（adapter 不直接调 exit）
        end
    elseif screen_ == "gameplay" then
        gameplay.handleKeyDown(key)
    end
end

--- 文本输入事件回调（用于编辑器导入模态框）
---@param eventType string
---@param eventData table
function P1PZ_HandleTextInput(eventType, eventData)
    if screen_ ~= "editor" then return end
    if not levelEditor.isModalShowing() then return end

    local text = eventData["Text"]:GetString()
    if text and #text > 0 then
        levelEditor.handleTextInput(text)
    end
end

--- 鼠标/触屏事件：委托给公共输入处理器
function P1PZ_HandleMouseButtonDown(eventType, eventData)
    if inputHandler_ then inputHandler_.handleMouseDown(eventType, eventData) end
end
function P1PZ_HandleMouseButtonUp(eventType, eventData)
    if inputHandler_ then inputHandler_.handleMouseUp(eventType, eventData) end
end

--- 鼠标移动：编辑器拖动放置
---@param eventType string
---@param eventData table
function P1PZ_HandleMouseMove(eventType, eventData)
    if screen_ ~= "editor" or not editorDragging_ then return end

    local mx = eventData["X"]:GetInt()
    local my = eventData["Y"]:GetInt()
    mx, my = Density.toGameCoords(mx, my)

    levelEditor.moveDrag(mx, my, editorHitAreas_)
end

function P1PZ_HandleTouchBegin(eventType, eventData)
    if inputHandler_ then inputHandler_.handleTouchBegin(eventType, eventData) end
end
function P1PZ_HandleTouchEnd(eventType, eventData)
    if inputHandler_ then inputHandler_.handleTouchEnd(eventType, eventData) end
end

--- 触摸移动：编辑器拖动放置
---@param eventType string
---@param eventData table
function P1PZ_HandleTouchMove(eventType, eventData)
    if screen_ ~= "editor" or not editorDragging_ then return end

    local tid = eventData["TouchID"]:GetInt()
    local ts = inputHandler_ and inputHandler_.touchStart
    if ts and tid ~= ts.id then return end

    local tx = eventData["X"]:GetInt()
    local ty = eventData["Y"]:GetInt()
    tx, ty = Density.toGameCoords(tx, ty)

    levelEditor.moveDrag(tx, ty, editorHitAreas_)
end

-- ============================================================================
-- GameLifecycleAdapter 接口
-- ============================================================================

---@param ctx table GameEnterContext
function M:onEnter(ctx)
    logger.info(MODULE, "onEnter", "gameId=" .. ctx.gameId .. " session=" .. ctx.sessionId)

    -- 检查是否为主线关卡模式
    if ctx.storylineOpts and ctx.storylineOpts.levelData then
        storylineMode_ = true
        storylineOpts_ = ctx.storylineOpts
        -- 主线关卡数据是原始格式（0-based 坐标、walls 数组），
        -- 必须经过 levelLoader.load() 转换为引擎内部格式（1-based、wallSet 哈希表等）
        local converted, loadErr = levelLoader.load(ctx.storylineOpts.levelData)
        if not converted then
            logger.error(MODULE, "onEnter", "storyline level load failed: " .. tostring(loadErr))
            return
        end
        levels_ = { converted }
        saveData_ = {}
        logger.info(MODULE, "onEnter", "storyline mode, levelId=" .. tostring(converted.id))
    else
        storylineMode_ = false
        storylineOpts_ = nil
        -- 正常模式：加载关卡数据
        levels_ = levelLoader.loadAll()
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

    -- 初始化字体（只调用一次）
    fontHandle_ = nvgCreateFont(nvgCtx_, "sans", "Fonts/LongZhuTi-Regular.ttf")
    if fontHandle_ < 0 then
        logger.warn(MODULE, "onEnter", "font load failed, text may not render")
    end

    -- 订阅事件（UrhoX 要求全局函数名字符串）
    SubscribeToEvent(nvgCtx_, "NanoVGRender", "P1PZ_HandleNanoVGRender")
    FoxMascot.init(nvgCtx_)
    SubscribeToEvent("Update", "P1PZ_HandleUpdate")
    SubscribeToEvent("KeyDown", "P1PZ_HandleKeyDown")
    SubscribeToEvent("MouseButtonDown", "P1PZ_HandleMouseButtonDown")
    SubscribeToEvent("MouseButtonUp", "P1PZ_HandleMouseButtonUp")
    SubscribeToEvent("TouchBegin", "P1PZ_HandleTouchBegin")
    SubscribeToEvent("TouchEnd", "P1PZ_HandleTouchEnd")
    SubscribeToEvent("MouseMove", "P1PZ_HandleMouseMove")
    SubscribeToEvent("TouchMove", "P1PZ_HandleTouchMove")
    SubscribeToEvent("TextInput", "P1PZ_HandleTextInput")

    -- 初始化音效系统
    SoundManager.init(sounds)

    -- 创建公共输入处理器
    inputHandler_ = InputHandler.create({
        getScreen = function() return screen_ end,
        levelSelect = levelSelect,
        getSelectHitAreas = function() return selectHitAreas_ end,
        gotoLevel = gotoLevel,
        swipeMinDist = 20,
        extraActions = { editor = gotoEditor },

        onPointerDown = function(x, y)
            if screen_ == "editor" then
                editorDragging_ = levelEditor.beginDrag(x, y, editorHitAreas_)
            end
        end,

        onPointerUp = function(startX, startY, endX, endY, dx, dy, dist)
            if screen_ == "editor" then
                if levelEditor.isModalShowing() then
                    levelEditor.endDrag()
                    editorDragging_ = false
                    levelEditor.handleModalClick(startX, startY)
                else
                    local wasDragging = levelEditor.endDrag()
                    editorDragging_ = false
                    if not wasDragging then
                        local action = levelEditor.handleClick(startX, startY, editorHitAreas_)
                        if action then uiTap.play() end
                        if action == "back" then
                            gotoLevelSelect(true)
                        elseif action == "test_play" then
                            gotoEditorTestPlay()
                        end
                    end
                end
                return true
            end
            return false
        end,

        onGameplaySwipe = function(startX, startY, endX, endY, dist)
            local dx = endX - startX
            local dy = endY - startY
            if math.abs(dx) >= math.abs(dy) then
                gameplay.handleDirection(dx > 0 and "right" or "left")
            else
                gameplay.handleDirection(dy > 0 and "down" or "up")
            end
        end,

        onGameplayClick = function(startX, startY)
            gameplay.handleClick(startX, startY)
        end,
    })

    if storylineMode_ then
        -- 主线模式：跳过选关界面，直接进入关卡
        -- 注意：不能调用 gotoLevel(1)，因为它内部有 ScreenTransition.run()，
        -- 而此时 adventure 页面的 ScreenTransition 仍在动画中，会被 isAnimating() 拦截。
        -- 直接调用 gameplay.enter() 即可。
        screen_ = "gameplay"
        local lv = levels_[1]
        if lv then
            local gameContainer = require("modules.game-container.init")
            gameplay.enter(lv, {
                hasNextLevel = false,
                storylineMode = true,
                onLevelComplete = function(levelId, stars)
                    if storylineOpts_ and storylineOpts_.onComplete then
                        storylineOpts_.onComplete()
                    end
                    logger.info(MODULE, "onLevelComplete[storyline]", levelId .. " stars=" .. stars)
                end,
                onRequestBack = function()
                    gameContainer.exit("user_back")
                end,
                onRequestNextLevel = function()
                    gameContainer.exit("user_back")
                end,
            })
            logger.info(MODULE, "onEnter", "storyline gameplay started: " .. lv.id)
        end
    else
        -- 正常模式：显示选关界面
        screen_ = "level_select"
        selectHitAreas_ = nil
        levelSelect.reset()
        -- 进入选关时狐狸问候
        local selectGreetings = {
            "推箱子时间到！选一关试试吧~",
            "动动脑筋，把箱子推到正确位置！",
            "哪一关想挑战？我看好你哦！",
            "推箱子可以锻炼空间思维呢~",
            "选个关卡，大展身手吧！",
        }
        FoxMascot.showMessage(selectGreetings[math.random(1, #selectGreetings)])
    end

    logger.info(MODULE, "onEnter", "ready, levels=" .. #levels_ .. (storylineMode_ and " [storyline]" or ""))
end

---@param ctx table
function M:onResume(ctx)
    logger.info(MODULE, "onResume", "resumed")
end

---@param reason string
---@return table|nil snapshot
function M:onPause(reason)
    logger.info(MODULE, "onPause", "reason=" .. reason)

    if storylineMode_ then
        playTimer_ = 0
        return nil
    end

    -- 暂停时保存进度
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
    logger.info(MODULE, "onExit", "reason=" .. reason)

    -- 保存进度（主线模式不保存游戏存档）
    if not storylineMode_ then
        saveData_.totalPlaySec = (saveData_.totalPlaySec or 0) + math.floor(playTimer_)
        playTimer_ = 0
        save.save(saveData_)
    else
        playTimer_ = 0
    end

    -- 先取消事件订阅（防止清理资源期间回调访问已释放对象）
    UnsubscribeFromEvent("Update")
    UnsubscribeFromEvent("KeyDown")
    UnsubscribeFromEvent("MouseButtonDown")
    UnsubscribeFromEvent("MouseButtonUp")
    UnsubscribeFromEvent("TouchBegin")
    UnsubscribeFromEvent("TouchEnd")
    UnsubscribeFromEvent("MouseMove")
    UnsubscribeFromEvent("TouchMove")
    UnsubscribeFromEvent("TextInput")

    -- 清理游戏逻辑
    gameplay.leave()
    levelEditor.leave()

    -- 关闭音效系统
    SoundManager.shutdown()

    -- 清理狐狸立绘
    FoxMascot.cleanup()

    -- 清除主题背景图缓存（handle 与上下文绑定，必须在销毁前清除）
    require("shared.rendering.piece-sprites").release(nvgCtx_)
    bgManager.clearThemeCache(nvgCtx_)

    -- 销毁 NanoVG 上下文（同时清理 NanoVGRender 订阅）
    if nvgCtx_ then
        nvgDelete(nvgCtx_)
        nvgCtx_ = nil
    end

    -- 清理全局事件处理函数
    P1PZ_HandleNanoVGRender = nil
    P1PZ_HandleUpdate = nil
    P1PZ_HandleKeyDown = nil
    P1PZ_HandleMouseButtonDown = nil
    P1PZ_HandleMouseButtonUp = nil
    P1PZ_HandleTouchBegin = nil
    P1PZ_HandleTouchEnd = nil
    P1PZ_HandleMouseMove = nil
    P1PZ_HandleTouchMove = nil
    P1PZ_HandleTextInput = nil

    -- 清理状态
    screen_ = "level_select"
    levels_ = {}
    saveData_ = {}
    selectHitAreas_ = nil
    editorHitAreas_ = nil
    editorDragging_ = false
    editorTestPlay_ = false
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
