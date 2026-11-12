local Scenery=require("shared.rendering.game-scenery")
--- 推箱子游戏主界面
--- 职责：输入处理 → 逻辑层调度 → 渲染层绘制
local Board = require("games.p1-puzzle-land.logic.board")
local Animations = require("games.p1-puzzle-land.view.animations")
local boardRenderer = require("games.p1-puzzle-land.view.board-renderer")
local logger = require("shared.utils.logger")
local SoundManager = require("shared.sound-manager")
local uiTap = require("shared.utils.ui-tap")
local resultPopup = require("shared.components.result-popup")
local bgManager = require("shared.background-manager")

local M = {}
local MODULE = "gameplay"

---@type table|nil
local board_ = nil
---@type table|nil
local anim_ = nil
---@type table|nil
local layout_ = nil
---@type table|nil
local levelData_ = nil
---@type boolean
local inputLocked_ = false
---@type boolean
local showWinDialog_ = false
---@type number
local winSteps_ = 0
---@type number
local winStars_ = 0
---@type table[]|nil
local bottomBtns_ = nil
---@type table[]|nil
local winBtns_ = nil
---@type number
local lastScreenW_ = 0
---@type number
local lastScreenH_ = 0

-- 滑动提示
---@type number 0~1 提示文字透明度
local hintAlpha_ = 1.0
---@type boolean 是否正在渐隐
local hintFading_ = false

-- 累积时间（用于传送门动画 + 背景装饰）
---@type number
local elapsedTime_ = 0

-- 背景配置
---@type table|nil
local bgConfig_ = nil

-- 延迟播放 level_complete 计时器（nil=不播放）
---@type number|nil
local levelCompleteTimer_ = nil

-- 是否有下一关
---@type boolean
local hasNextLevel_ = true
-- 是否主线模式
---@type boolean
local storylineMode_ = false

-- 回调
---@type function|nil
local onLevelComplete_ = nil   -- function(levelId, stars)
---@type function|nil
local onRequestBack_ = nil     -- function()
---@type function|nil
local onRequestNextLevel_ = nil -- function()

-- 初始化/销毁

--- 进入关卡
---@param levelData table 由 level-loader 加载的关卡数据
---@param callbacks table { onLevelComplete, onRequestBack, onRequestNextLevel }
function M.enter(levelData, callbacks)
    levelData_ = levelData
    board_ = Board.new(levelData)
    anim_ = Animations.new()
    inputLocked_ = true
    showWinDialog_ = false
    bottomBtns_ = nil
    winBtns_ = nil
    levelCompleteTimer_ = nil

    onLevelComplete_ = callbacks and callbacks.onLevelComplete
    onRequestBack_ = callbacks and callbacks.onRequestBack
    onRequestNextLevel_ = callbacks and callbacks.onRequestNextLevel
    hasNextLevel_ = callbacks and callbacks.hasNextLevel ~= false
    storylineMode_ = callbacks and callbacks.storylineMode or false

    hintAlpha_ = 1.0
    hintFading_ = false
    elapsedTime_ = 0
    bgConfig_ = bgManager.getBackgroundForLevel(levelData)

    -- 启动出生动画（格子从中心向外波纹弹出）
    anim_:startBirthAnim(board_.width, board_.height, function()
        inputLocked_ = false
    end)

    logger.info(MODULE, "enter", "level=" .. levelData.id)
end

--- 离开关卡
function M.leave()
    board_ = nil
    anim_ = nil
    layout_ = nil
    levelData_ = nil
    inputLocked_ = false
    showWinDialog_ = false
    bottomBtns_ = nil
    winBtns_ = nil
    levelCompleteTimer_ = nil
end

--- 是否活跃
function M.isActive()
    return board_ ~= nil
end

-- 输入处理

--- 处理方向输入
---@param dir string "up"|"down"|"left"|"right"
function M.handleDirection(dir)
    if not board_ or inputLocked_ or showWinDialog_ then return end

    local events = board_:applyMove(dir)

    -- 检查是否有移动阻止事件（推不动等）
    local isBlocked = false
    for _, evt in ipairs(events) do
        if evt.type == "move_blocked" then
            isBlocked = true
        end
    end

    -- 首次成功移动时触发提示渐隐
    if not isBlocked and not hintFading_ and hintAlpha_ > 0 then
        hintFading_ = true
    end

    -- 锁定输入
    inputLocked_ = true

    -- 检查是否有通关事件
    local completeEvt = nil
    for _, evt in ipairs(events) do
        if evt.type == "level_complete" then
            completeEvt = evt
        end
    end

    -- 播放动画（包括推不动时的演出动画）
    anim_:playEvents(events, function()
        inputLocked_ = false

        if completeEvt then
            showWinDialog_ = true
            winSteps_ = completeEvt.steps
            -- 主线模式：强制 3 星
            winStars_ = storylineMode_ and 3 or completeEvt.stars
            levelCompleteTimer_ = 0.5
            -- 启动庆祝特效
            if lastScreenW_ > 0 then
                resultPopup.startCelebration(lastScreenW_, lastScreenH_, {
                    ratingType = "stars",
                    ratingValue = winStars_,
                })
            end
            if onLevelComplete_ then
                onLevelComplete_(levelData_.id, winStars_)
            end
        end
    end)
end

--- 处理撤销
function M.handleUndo()
    if not board_ or inputLocked_ or showWinDialog_ then return end

    SoundManager.play("undo")
    inputLocked_ = true
    local events = board_:undo()

    anim_:playEvents(events, function()
        inputLocked_ = false
    end)
end

--- 处理重置
function M.handleReset()
    if not board_ or not levelData_ then return end
    if inputLocked_ and not showWinDialog_ then return end

    SoundManager.play("reset")
    -- 捕获旧位置（重置前）
    local oldPlayer = { board_.player[1], board_.player[2] }
    local oldBoxes = {}
    for i, box in ipairs(board_.boxes) do
        oldBoxes[i] = { box[1], box[2] }
    end

    -- 停止庆祝/重建动画系统
    resultPopup.stopCelebration()
    showWinDialog_ = false

    -- 执行逻辑重置
    board_:reset()
    anim_ = Animations.new()

    -- 新位置（从关卡数据读取）
    local newPlayer = { levelData_.player[1], levelData_.player[2] }
    local newBoxes = {}
    for i, box in ipairs(levelData_.boxes) do
        newBoxes[i] = { box[1], box[2] }
    end

    -- 启动重置动画，锁定输入
    inputLocked_ = true
    anim_:startResetAnim(oldPlayer, oldBoxes, newPlayer, newBoxes, function()
        inputLocked_ = false
    end)
end

--- 处理键盘事件
---@param key number 按键码
function M.handleKeyDown(key)
    if not board_ then return end

    if showWinDialog_ then
        if key == KEY_RETURN or key == KEY_SPACE then
            if onRequestNextLevel_ then onRequestNextLevel_() end
        elseif key == KEY_R then
            M.handleReset()
        end
        return
    end

    if key == KEY_UP or key == KEY_W then
        M.handleDirection("up")
    elseif key == KEY_DOWN or key == KEY_S then
        M.handleDirection("down")
    elseif key == KEY_LEFT or key == KEY_A then
        M.handleDirection("left")
    elseif key == KEY_RIGHT or key == KEY_D then
        M.handleDirection("right")
    elseif key == KEY_Z then
        M.handleUndo()
    elseif key == KEY_R then
        M.handleReset()
    elseif key == KEY_ESCAPE then
        if onRequestBack_ then onRequestBack_() end
    end
end

--- 处理鼠标/触摸点击
---@param mx number
---@param my number
function M.handleClick(mx, my)
    if not board_ then return end

    -- 通关弹窗按钮
    if showWinDialog_ and winBtns_ then
        for _, btn in ipairs(winBtns_) do
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                uiTap.play()
                if btn.action == "retry" then
                    M.handleReset()
                elseif btn.action == "next_level" then
                    if onRequestNextLevel_ then onRequestNextLevel_() end
                elseif btn.action == "back" then
                    if onRequestBack_ then onRequestBack_() end
                end
                return
            end
        end
        return
    end

    -- 底部按钮
    if bottomBtns_ then
        for _, btn in ipairs(bottomBtns_) do
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                uiTap.play()
                if btn.action == "undo" then
                    M.handleUndo()
                elseif btn.action == "reset" then
                    M.handleReset()
                elseif btn.action == "back" then
                    if onRequestBack_ then onRequestBack_() end
                end
                return
            end
        end
    end
end

-- 更新 & 渲染

--- 每帧更新
---@param dt number
function M.update(dt)
    if anim_ then
        anim_:update(dt)
    end
    resultPopup.updateCelebration(dt)

    elapsedTime_ = elapsedTime_ + dt

    -- 延迟播放 level_complete
    if levelCompleteTimer_ then
        levelCompleteTimer_ = levelCompleteTimer_ - dt
        if levelCompleteTimer_ <= 0 then
            SoundManager.play("level_complete")
            levelCompleteTimer_ = nil
        end
    end

    -- 提示文字渐隐
    if hintFading_ and hintAlpha_ > 0 then
        hintAlpha_ = hintAlpha_ - dt * 1.5  -- ~0.67 秒淡出
        if hintAlpha_ <= 0 then
            hintAlpha_ = 0
            hintFading_ = false
        end
    end
end

--- NanoVG 渲染
---@param ctx userdata
---@param screenW number
---@param screenH number
function M.render(ctx, screenW, screenH, afterBg)
    if not board_ or not levelData_ then return end

    -- 保存屏幕尺寸（通关回调需要）
    lastScreenW_ = screenW
    lastScreenH_ = screenH

    -- 计算布局
    layout_ = boardRenderer.calcLayout(screenW, screenH, board_.width, board_.height)

    -- 绘制背景
    bgManager.renderBackground(ctx, screenW, screenH, elapsedTime_, bgConfig_)

    Scenery.draw(ctx,screenW,screenH,{x=layout_.offsetX,y=layout_.offsetY,w=layout_.boardW,h=layout_.boardH},bgConfig_,elapsedTime_)
    if afterBg then afterBg() end

    -- 绘制 HUD
    boardRenderer.drawHUD(ctx, screenW, board_, levelData_.title, layout_)

    -- 绘制棋盘
    boardRenderer.drawBoard(ctx, board_, anim_, layout_, elapsedTime_)

    -- 绘制底部按钮
    bottomBtns_ = boardRenderer.drawBottomButtons(ctx, screenW, screenH, layout_)

    -- 绘制滑动提示
    if hintAlpha_ > 0 then
        boardRenderer.drawHintText(ctx, screenW, screenH, layout_, hintAlpha_)
    end

    -- 通关弹窗（带庆祝特效）
    if showWinDialog_ then
        winBtns_ = resultPopup.drawCleared(ctx, screenW, screenH, {
            ratingType = "stars",
            ratingValue = winStars_,
            stats = {
                { label = "步数", value = tostring(winSteps_) },
            },
            storylineMode = storylineMode_,
            hasNextLevel = hasNextLevel_,
        })
    end
end

return M
