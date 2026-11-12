local Scenery=require("shared.rendering.game-scenery")
--- 连连看 - 游戏主界面
--- 职责：输入处理 -> 逻辑层调度 -> 渲染层绘制
local Board = require("games.p4-link-match.logic.board")
local boardRenderer = require("games.p4-link-match.view.board-renderer")
local hudRenderer = require("games.p4-link-match.view.hud-renderer")
local resultPopup = require("shared.components.result-popup")
local pauseOverlay = require("shared.components.pause-overlay")
local save = require("games.p4-link-match.save")
local LAYOUT = require("shared.constants.layout")
local logger = require("shared.utils.logger")
local uiTap = require("shared.utils.ui-tap")
local SoundManager = require("shared.sound-manager")
local bgManager = require("shared.background-manager")

local M = {}
local MODULE = "lm-gameplay"

---@type table|nil Board 实例
local board_ = nil
---@type table|nil 关卡数据
local levelData_ = nil
---@type table|nil 棋盘布局
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
---@param levelData table 关卡配置
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
    resultPopup.stopCelebration()
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
        " size=" .. levelData.board.cols .. "x" .. levelData.board.rows)
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
end

--- 是否活跃
function M.isActive()
    return board_ ~= nil
end

-- 暂停

function M.pause()
    if board_ and not board_.cleared and not board_.failed and not paused_ then
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

    -- 通关弹窗
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

    -- 失败弹窗
    if board_.failed and resultBtns_ then
        for _, btn in ipairs(resultBtns_) do
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                uiTap.play()
                if btn.action == "retry" then
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
                if not btn.enabled then return end
                uiTap.play()
                if btn.action == "shuffle" then
                    board_:useShuffle()
                elseif btn.action == "pause" then
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

    -- 点击棋盘方块
    if layout_ then
        local gx, gy = boardRenderer.hitTest(layout_, mx, my)
        if gx ~= nil and gy ~= nil then
            local wasCleared = board_.cleared
            local result = board_:clickTile(gx, gy)
            if result ~= "ignored" then
                logger.info(MODULE, "click", "x=" .. gx .. " y=" .. gy .. " result=" .. result)
            end
            if result == "matched" then
                SoundManager.play("bubble_pop_cute")
            end
            -- 立即消除模式下，通关在 clickTile 内触发
            if not wasCleared and board_.cleared then
                -- 主线模式：强制 3 星
                local displayStars = storylineMode_ and 3 or board_.starRating
                if onLevelComplete_ then
                    isNewBest_ = onLevelComplete_(
                        levelData_.levelId,
                        board_.clearTimeMs,
                        displayStars
                    )
                end
                resultPopup.startCelebration(lastScreenW_, lastScreenH_,
                    { ratingType = "stars", ratingValue = displayStars })
                SoundManager.play("level_cleared")
                SoundManager.play("success_fanfare")
                levelCompleteTimer_ = 0.5
            end
        end
    end
end

--- 重开
function M.restart()
    if not levelData_ then return end
    board_:restart()
    paused_ = false
    resultBtns_ = nil
    pauseBtns_ = nil
    isNewBest_ = false
    levelCompleteTimer_ = nil
    resultPopup.stopCelebration()
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
        elseif board_.cleared or board_.failed then
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

    local wasCleared = board_.cleared
    local wasFailed = board_.failed
    board_:update(dt)

    -- 庆祝特效更新
    resultPopup.updateCelebration(dt)

    -- 延迟播放 level_complete
    if levelCompleteTimer_ then
        levelCompleteTimer_ = levelCompleteTimer_ - dt
        if levelCompleteTimer_ <= 0 then
            SoundManager.play("level_complete")
            levelCompleteTimer_ = nil
        end
    end

    -- 通关回调（仅触发一次）
    if not wasCleared and board_.cleared then
        -- 主线模式：强制 3 星
        local displayStars = storylineMode_ and 3 or board_.starRating
        if onLevelComplete_ then
            isNewBest_ = onLevelComplete_(
                levelData_.levelId,
                board_.clearTimeMs,
                displayStars
            )
        end
        resultPopup.startCelebration(lastScreenW_, lastScreenH_,
            { ratingType = "stars", ratingValue = displayStars })
        SoundManager.play("level_cleared")
        SoundManager.play("success_fanfare")
        levelCompleteTimer_ = 0.5
    end

    -- 失败不需要庆祝特效
    if not wasFailed and board_.failed then
        SoundManager.play("level_failed")
        SoundManager.play("bounce_boing")
        logger.info(MODULE, "update", "level failed")
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
    -- 按钮在 HUD 下方（TOP_BAR_H + 6 + 28 = 88），棋盘从按钮下方开始
    layout_ = boardRenderer.calcLayout(screenW, screenH,
        board_.rows, board_.cols,
        hudRenderer.TOP_BAR_H + LAYOUT.BOARD_TOP_PADDING,
        LAYOUT.BOARD_BOTTOM_PADDING)

    Scenery.draw(vg,screenW,screenH,{x=layout_.startX,y=layout_.startY,w=layout_.gridW,h=layout_.gridH},bgConfig_,bgDecoTime_)
    -- 狐狸立绘（渲染在棋盘下方）
    if afterBg then afterBg() end

    -- HUD 顶部
    local levelTitle = levelData_.title or (levelData_.levelId:gsub("^L", "关卡") .. "  " ..
        board_.cols .. "x" .. board_.rows)
    hudRenderer.drawTop(vg, screenW, board_, levelTitle)

    -- 棋盘网格
    boardRenderer.drawBoard(vg, board_, layout_, bgDecoTime_)

    -- 连线动画
    boardRenderer.drawLinkLine(vg, board_, layout_)

    -- 洗牌动画
    boardRenderer.drawShuffleOverlay(vg, board_, screenW, screenH)

    -- 底部按钮
    bottomBtns_ = hudRenderer.drawBottom(vg, screenW, screenH, board_)

    -- 底部时间进度条
    hudRenderer.drawTimeBar(vg, screenW, screenH, board_, board_.elapsedMs / 1000)

    -- 通关弹窗
    if board_.cleared then
        local function fmtTime(ms)
            if not ms then return "--" end
            local sec = math.floor(ms / 1000)
            return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
        end
        local displayStars = storylineMode_ and 3 or board_.starRating
        resultBtns_ = resultPopup.drawCleared(vg, screenW, screenH, {
            ratingType = "stars",
            ratingValue = displayStars,
            stats = {
                { label = "用时", value = fmtTime(board_.clearTimeMs) },
                { label = "最佳", value = fmtTime(prevBestTimeMs_) },
                { label = "洗牌", value = tostring(board_.shufflesUsed) },
            },
            isNewBest = isNewBest_,
            hasNextLevel = hasNextLevel_,
            storylineMode = storylineMode_,
        })
    end

    -- 失败弹窗
    if board_.failed then
        resultBtns_ = resultPopup.drawFailed(vg, screenW, screenH, {
            title = "时间耗尽",
            message = "还剩 " .. tostring(board_.remainPairs) .. " 对未消除",
        })
    end

    -- 暂停菜单
    if paused_ then
        pauseBtns_ = pauseOverlay.draw(vg, screenW, screenH)
    end
end

return M
