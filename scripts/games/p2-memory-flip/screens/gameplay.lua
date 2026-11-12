local Scenery=require("shared.rendering.game-scenery")
--- 记忆翻牌 - 游戏主界面
--- 职责：输入处理 -> 逻辑层调度 -> 渲染层绘制
local Board = require("games.p2-memory-flip.logic.board")
local cardRenderer = require("games.p2-memory-flip.view.card-renderer")
local hudRenderer = require("games.p2-memory-flip.view.hud-renderer")
local resultPopup = require("shared.components.result-popup")
local pauseOverlay = require("shared.components.pause-overlay")
local save = require("games.p2-memory-flip.save")
local LAYOUT = require("shared.constants.layout")
local logger = require("shared.utils.logger")
local uiTap = require("shared.utils.ui-tap")
local SoundManager = require("shared.sound-manager")
local bgManager = require("shared.background-manager")

local M = {}
local MODULE = "mf-gameplay"

---@type table|nil Board 实例
local board_ = nil
---@type table|nil 关卡数据
local levelData_ = nil
---@type table|nil 卡牌布局
local layout_ = nil
---@type boolean 暂停状态
local paused_ = false
---@type table[]|nil 底部按钮
local bottomBtns_ = nil
---@type table[]|nil 结算弹窗按钮
local resultBtns_ = nil
---@type table[]|nil 暂停菜单按钮
local pauseBtns_ = nil
---@type table|nil 存档数据
local saveData_ = nil
---@type boolean 是否刷新纪录
local isNewBest_ = false
---@type number|nil 历史最佳时间
local prevBestTimeMs_ = nil
---@type number 上次渲染的屏幕宽
local lastScreenW_ = 400
---@type number 上次渲染的屏幕高
local lastScreenH_ = 600

-- 背景配置 + 装饰动画时间
---@type table|nil
local bgConfig_ = nil
---@type number
local bgDecoTime_ = 0

-- 延迟播放 level_complete 计时器（nil=不播放）
---@type number|nil
local levelCompleteTimer_ = nil

-- 回调
---@type function|nil
local onLevelComplete_ = nil
---@type function|nil
local onRequestBack_ = nil
---@type function|nil
local onRequestNextLevel_ = nil
---@type boolean
local hasNextLevel_ = true
---@type boolean
local storylineMode_ = false

-- 初始化/销毁

--- 进入关卡
---@param levelData table 关卡配置（来自 data/levels.lua）
---@param sData table 存档数据
---@param callbacks table
function M.enter(levelData, sData, callbacks)
    levelData_ = levelData
    saveData_ = sData
    board_ = Board.new(levelData)
    layout_ = nil
    paused_ = false
    bottomBtns_ = nil
    resultBtns_ = nil
    pauseBtns_ = nil
    isNewBest_ = false
    levelCompleteTimer_ = nil
    cardRenderer.resetAnims()
    cardRenderer.resetMatchEffects()
    bgConfig_ = bgManager.getBackgroundForLevel(levelData)
    bgDecoTime_ = 0

    -- 记录之前的最佳时间
    local prev = save.getLevelBest(sData, levelData.levelId)
    prevBestTimeMs_ = prev and prev.bestTimeMs or nil

    onLevelComplete_ = callbacks and callbacks.onLevelComplete
    onRequestBack_ = callbacks and callbacks.onRequestBack
    onRequestNextLevel_ = callbacks and callbacks.onRequestNextLevel
    hasNextLevel_ = callbacks and callbacks.hasNextLevel ~= false
    storylineMode_ = callbacks and callbacks.storylineMode or false

    logger.info(MODULE, "enter", "level=" .. levelData.levelId ..
        " cards=" .. levelData.cardCount)
end

--- 离开关卡
function M.leave()
    board_ = nil
    levelData_ = nil
    layout_ = nil
    paused_ = false
    bottomBtns_ = nil
    resultBtns_ = nil
    pauseBtns_ = nil
    levelCompleteTimer_ = nil
    resultPopup.stopCelebration()
    cardRenderer.resetMatchEffects()
end

--- 是否活跃
function M.isActive()
    return board_ ~= nil
end

-- 暂停

function M.pause()
    if board_ and not board_.cleared and not paused_ then
        paused_ = true
        board_:pauseTimer()
    end
end

function M.resume()
    if paused_ then
        paused_ = false
        if board_ then
            board_:resumeTimer()
        end
    end
end

function M.isPaused()
    return paused_
end

-- 输入处理

--- 处理点击
---@param mx number
---@param my number
function M.handleClick(mx, my)
    if not board_ then return end

    -- 暂停菜单
    if paused_ then
        local action = pauseOverlay.hitTest(mx, my, pauseBtns_)
        if action then uiTap.play() end
        if action == "resume" then
            M.resume()
        elseif action == "exit" then
            if onRequestBack_ then onRequestBack_() end
        end
        return
    end

    -- 结算弹窗
    if board_.cleared and resultBtns_ then
        for _, btn in ipairs(resultBtns_) do
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                uiTap.play()
                if btn.action == "next_level" then
                    if onRequestNextLevel_ then onRequestNextLevel_() end
                elseif btn.action == "retry" then
                    M.restart()
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
                if btn.action == "pause" then
                    M.pause()
                elseif btn.action == "restart" then
                    M.restart()
                elseif btn.action == "back" then
                    if onRequestBack_ then onRequestBack_() end
                end
                return
            end
        end
    end

    -- 点击卡牌
    if layout_ then
        local cardIndex = cardRenderer.hitTestCard(mx, my, layout_, board_)
        if cardIndex then
            local result = board_:flipCard(cardIndex)
            if result == "first_flip" then
                SoundManager.play("bloop_bounce")
                logger.info(MODULE, "flip", "card=" .. cardIndex .. " result=" .. result)
            elseif result == "checking" then
                -- 配对成功时不播放 bloop_bounce（由 bubble_pop_cute 替代）
                local c1 = board_.cards[board_.firstFlipped]
                local c2 = board_.cards[board_.secondFlipped]
                if c1.artKey ~= c2.artKey then
                    SoundManager.play("bloop_bounce")
                end
                logger.info(MODULE, "flip", "card=" .. cardIndex .. " result=" .. result)
            end
        end
    end
end

--- 重开
function M.restart()
    if not levelData_ then return end
    board_ = Board.new(levelData_)
    paused_ = false
    resultBtns_ = nil
    pauseBtns_ = nil
    isNewBest_ = false
    levelCompleteTimer_ = nil
    cardRenderer.resetAnims()
    resultPopup.stopCelebration()
    cardRenderer.resetMatchEffects()
    local prev = save.getLevelBest(saveData_, levelData_.levelId)
    prevBestTimeMs_ = prev and prev.bestTimeMs or nil
    logger.info(MODULE, "restart", "level=" .. levelData_.levelId)
end

--- 处理键盘事件
---@param key number
function M.handleKeyDown(key)
    if not board_ then return end

    if key == KEY_ESCAPE then
        if paused_ then
            M.resume()
        elseif board_.cleared then
            if onRequestBack_ then onRequestBack_() end
        else
            M.pause()
        end
    elseif key == KEY_R then
        M.restart()
    end
end

-- 更新 & 渲染

--- 每帧更新
---@param dt number
function M.update(dt)
    if not board_ or paused_ then return end

    bgDecoTime_ = bgDecoTime_ + dt
    local wasClear = board_.cleared
    local prevMatchedCount = board_.matchedCount
    board_:update(dt)
    cardRenderer.updateAnims(dt, board_, layout_)
    cardRenderer.updateMatchEffects(dt)
    cardRenderer.updateBackGlow(dt)

    -- 配对成功音效（matchedCount 增加时触发）
    if board_.matchedCount > prevMatchedCount then
        SoundManager.play("bubble_pop_cute")
    end

    -- 延迟播放 level_complete
    if levelCompleteTimer_ then
        levelCompleteTimer_ = levelCompleteTimer_ - dt
        if levelCompleteTimer_ <= 0 then
            SoundManager.play("level_complete")
            levelCompleteTimer_ = nil
        end
    end

    -- 庆祝特效更新
    resultPopup.updateCelebration(dt)

    -- 通关回调（仅触发一次）+ 启动庆祝特效
    if not wasClear and board_.cleared then
        -- 主线模式：强制 3 星
        local displayStars = storylineMode_ and 3 or board_.starRating
        if onLevelComplete_ then
            isNewBest_ = onLevelComplete_(
                levelData_.levelId,
                board_.clearTimeMs,
                displayStars
            )
        end
        -- 启动庆祝特效
        resultPopup.startCelebration(lastScreenW_ or 400, lastScreenH_ or 600,
            { ratingType = "stars", ratingValue = displayStars })
        SoundManager.play("level_cleared")
        SoundManager.play("success_fanfare")
        levelCompleteTimer_ = 0.5
    end
end

--- NanoVG 渲染
---@param vg userdata
---@param screenW number
---@param screenH number
function M.render(vg, screenW, screenH, afterBg)
    if not board_ or not levelData_ then return end

    lastScreenW_ = screenW
    lastScreenH_ = screenH

    -- 背景
    bgManager.renderBackground(vg, screenW, screenH, bgDecoTime_, bgConfig_)


    -- 计算布局
    layout_ = cardRenderer.calcLayout(screenW, screenH,
        board_.rows, board_.cols, hudRenderer.TOP_BAR_H + LAYOUT.BOARD_TOP_PADDING)

    Scenery.draw(vg,screenW,screenH,{x=layout_.startX,y=layout_.startY,w=layout_.gridW,h=layout_.gridH},bgConfig_,bgDecoTime_)
    if afterBg then afterBg() end

    -- HUD
    local levelTitle = levelData_.title or (levelData_.levelId:gsub("^L", "关卡") .. "  " .. levelData_.cardCount .. "张")
    hudRenderer.drawTop(vg, screenW, board_, levelTitle)

    -- 卡牌网格
    cardRenderer.drawCards(vg, board_, layout_)

    -- 底部按钮
    bottomBtns_ = hudRenderer.drawBottom(vg, screenW, screenH)

    -- 结算弹窗
    if board_.cleared then
        local displayStars = storylineMode_ and 3 or board_.starRating
        resultBtns_ = resultPopup.drawCleared(vg, screenW, screenH, {
            ratingType = "stars",
            ratingValue = displayStars,
            stats = {
                { label = "本次用时", value = board_:formatTime(board_.clearTimeMs) },
                { label = "历史最佳", value = prevBestTimeMs_ and board_:formatTime(prevBestTimeMs_) or "--" },
                { label = "错误次数", value = tostring(board_.mistakeCount) },
            },
            isNewBest = isNewBest_,
            hasNextLevel = hasNextLevel_,
            storylineMode = storylineMode_,
        })
    end

    -- 暂停菜单
    if paused_ then
        pauseBtns_ = pauseOverlay.draw(vg, screenW, screenH)
    end
end

return M
