local Scenery=require("shared.rendering.game-scenery")
--- 消消乐 - 游戏主界面
--- 职责：输入处理 -> 逻辑层调度 -> 动画状态机驱动 -> 渲染层绘制
local Board = require("games.p3-match-3.logic.board")
local State = require("games.p3-match-3.logic.state")
local boardRenderer = require("games.p3-match-3.view.board-renderer")
local hudRenderer = require("games.p3-match-3.view.hud-renderer")
local resultPopup = require("shared.components.result-popup")
local pauseOverlay = require("shared.components.pause-overlay")

local save = require("games.p3-match-3.save")
local LAYOUT = require("shared.constants.layout")
local logger = require("shared.utils.logger")
local SoundManager = require("shared.sound-manager")
local uiTap = require("shared.utils.ui-tap")
local bgManager = require("shared.background-manager")

local M = {}
local MODULE = "m3-gameplay"

-- 内部状态

---@type table|nil Board 实例
local board_ = nil
---@type table|nil 关卡数据
local levelData_ = nil
---@type table[]|nil 底部按钮命中区
local bottomBtns_ = nil
---@type table[]|nil 结算弹窗按钮命中区
local resultBtns_ = nil
---@type table|nil 存档数据引用
local saveData_ = nil
---@type boolean 是否刷新纪录
local isNewBest_ = false
---@type number|nil 历史最佳分数
local prevBestScore_ = nil
---@type number 上次渲染的屏幕尺寸
local lastScreenW_ = 400
---@type number
local lastScreenH_ = 600

---@type boolean 是否暂停
local paused_ = false
---@type table[]|nil 暂停菜单按钮命中区
local pauseBtns_ = nil

-- 自由模式"完成关卡"按钮
---@type table|nil 完成按钮命中区 { x, y, w, h, action }
local finishBtn_ = nil
---@type number 脉冲动画累计时间
local finishPulse_ = 0
---@type boolean 目标达成是否已处理（主线模式用，防重入）
local goalReachedHandled_ = false

-- 等待交换动画完成后执行消除
---@type boolean
local pendingSwapValid_ = false
-- 等待交换回退动画完成后回到 Idle
---@type boolean
local pendingSwapBack_ = false

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
    bottomBtns_ = nil
    resultBtns_ = nil
    pauseBtns_ = nil
    paused_ = false
    isNewBest_ = false
    pendingSwapValid_ = false
    pendingSwapBack_ = false
    levelCompleteTimer_ = nil

    finishBtn_ = nil
    finishPulse_ = 0
    goalReachedHandled_ = false

    boardRenderer.resetAll()
    bgConfig_ = bgManager.getBackgroundForLevel(levelData)
    bgDecoTime_ = 0

    -- 记录之前的最佳分数
    local prev = save.getLevelBest(sData, levelData.levelId)
    prevBestScore_ = prev and prev.bestScore or nil

    onLevelComplete_ = callbacks and callbacks.onLevelComplete
    onRequestBack_ = callbacks and callbacks.onRequestBack
    onRequestNextLevel_ = callbacks and callbacks.onRequestNextLevel
    hasNextLevel_ = callbacks and callbacks.hasNextLevel ~= false
    storylineMode_ = callbacks and callbacks.storylineMode or false

    logger.info(MODULE, "enter", "level=" .. levelData.levelId ..
        " time=" .. levelData.timeLimit .. "s")
end

--- 离开关卡
function M.leave()
    board_ = nil
    levelData_ = nil
    bottomBtns_ = nil
    resultBtns_ = nil
    pauseBtns_ = nil
    paused_ = false
    levelCompleteTimer_ = nil
    boardRenderer.resetAll()
    resultPopup.stopCelebration()
end

--- 是否活跃
function M.isActive()
    return board_ ~= nil
end

--- 暂停游戏
function M.pause()
    if not board_ or paused_ then return end
    if board_.cleared or board_.failed then return end
    paused_ = true
    pauseBtns_ = nil
    logger.info(MODULE, "pause", "game paused")
end

--- 恢复游戏
function M.resume()
    if not paused_ then return end
    paused_ = false
    pauseBtns_ = nil
    logger.info(MODULE, "resume", "game resumed")
end

--- 是否暂停
function M.isPaused()
    return paused_
end

-- 交换逻辑

--- 尝试执行一次交换
---@param r1 number
---@param c1 number
---@param r2 number
---@param c2 number
local function attemptSwap(r1, c1, r2, c2)
    if not board_ then return end

    local result = board_:trySwap(r1, c1, r2, c2)

    if result == "valid" then
        -- 有效交换：播放交换动画，完成后触发消除
        boardRenderer.startSwapAnim(r1, c1, r2, c2, board_.animTiming.swapMs, false)
        pendingSwapValid_ = true
        pendingSwapBack_ = false
        boardRenderer.clearSelected()
        logger.info(MODULE, "swap", "valid (" .. r1 .. "," .. c1 .. ")->(" .. r2 .. "," .. c2 .. ")")

    elseif result == "invalid" then
        -- 无效交换：播放抖动动画（方块轻移后弹回，表示推不动）
        SoundManager.play("wrong_buzzer_soft")
        State.toSwapBack(board_.stateMachine)
        local dr = r2 - r1
        local dc = c2 - c1
        boardRenderer.startShakeAnim(r1, c1, dr, dc, board_.animTiming.swapBackMs)
        pendingSwapValid_ = false
        pendingSwapBack_ = true
        boardRenderer.clearSelected()
        logger.info(MODULE, "swap", "invalid, shake anim")

    else
        -- rejected: 当前不允许交换（动画中等）
    end
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
            paused_ = false
            if onRequestBack_ then onRequestBack_() end
        end
        return
    end

    -- 结算弹窗
    if (board_.cleared or board_.failed) and resultBtns_ then
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

    -- 完成关卡按钮（自由模式达标后）
    if finishBtn_ then
        local btn = finishBtn_
        if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
            uiTap.play()
            if board_:finishLevel() then
                M._triggerCleared()
            end
            return
        end
    end

    -- 底部按钮
    if bottomBtns_ then
        for _, btn in ipairs(bottomBtns_) do
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                uiTap.play()
                if btn.action == "restart" then
                    M.restart()
                elseif btn.action == "back" then
                    if onRequestBack_ then onRequestBack_() end
                elseif btn.action == "pause" then
                    M.pause()
                end
                return
            end
        end
    end

    -- 棋盘点击（选中 + 交换）
    if State.canSwap(board_.stateMachine) then
        local row, col = boardRenderer.hitTest(mx, my)
        if row and col then
            local sel = boardRenderer.getSelected()
            if sel then
                -- 已有选中，尝试交换
                local dr = math.abs(sel.row - row)
                local dc = math.abs(sel.col - col)
                if dr + dc == 1 then
                    attemptSwap(sel.row, sel.col, row, col)
                elseif sel.row == row and sel.col == col then
                    -- 点击同一个，取消选中
                    boardRenderer.clearSelected()
                else
                    -- 点击不相邻的，切换选中
                    boardRenderer.setSelected({ row = row, col = col })
                end
            else
                -- 无选中，设置选中
                boardRenderer.setSelected({ row = row, col = col })
            end
        end
    end
end

--- 处理拖拽手势（滑动交换）
---@param startX number 起始屏幕坐标
---@param startY number
---@param endX number 结束屏幕坐标
---@param endY number
function M.handleDrag(startX, startY, endX, endY)
    if not board_ then return end
    if paused_ then return end
    if board_.cleared or board_.failed then return end
    if not State.canSwap(board_.stateMachine) then return end

    local row, col = boardRenderer.hitTest(startX, startY)
    if not row then return end

    local dr, dc = boardRenderer.getDragDirection(startX, startY, endX, endY)
    if dr == 0 and dc == 0 then return end

    local targetR = row + dr
    local targetC = col + dc

    attemptSwap(row, col, targetR, targetC)
end

--- 重开
function M.restart()
    if not levelData_ then return end
    board_ = Board.new(levelData_)
    resultBtns_ = nil
    pauseBtns_ = nil
    paused_ = false
    isNewBest_ = false
    pendingSwapValid_ = false
    pendingSwapBack_ = false
    levelCompleteTimer_ = nil
    finishBtn_ = nil
    finishPulse_ = 0
    goalReachedHandled_ = false
    boardRenderer.resetAll()
    resultPopup.stopCelebration()
    local prev = save.getLevelBest(saveData_, levelData_.levelId)
    prevBestScore_ = prev and prev.bestScore or nil
    logger.info(MODULE, "restart", "level=" .. levelData_.levelId)
end

--- 处理键盘事件
---@param key number
function M.handleKeyDown(key)
    if not board_ then return end

    if key == KEY_ESCAPE then
        if board_.cleared or board_.failed then
            if onRequestBack_ then onRequestBack_() end
        elseif paused_ then
            M.resume()
        else
            M.pause()
        end
        return
    end

    if paused_ then return end

    if key == KEY_R then
        M.restart()
    end
end

-- 更新（动画状态机驱动核心）

--- 每帧更新
---@param dt number
function M.update(dt)
    if not board_ then return end
    if paused_ then return end

    bgDecoTime_ = bgDecoTime_ + dt

    -- 倒计时更新
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

    -- 棋盘动画更新
    local animFinished = boardRenderer.updateAnim(dt)

    local state = board_.stateMachine.current

    -- 状态机驱动：动画完成后推进逻辑
    if animFinished then
        if state == State.SWAPPING and pendingSwapValid_ then
            -- 交换动画完成 → 执行消除
            pendingSwapValid_ = false
            local result = board_:confirmSwapAndEliminate()
            if #result.eliminated > 0 then
                boardRenderer.startElimAnim(result.eliminated, board_.animTiming.eliminateMs)
                -- 粒子特效：设置分数目标位置 & 生成粒子
                boardRenderer.setScoreTarget(lastScreenW_ - 14, 34)
                boardRenderer.spawnElimParticles(result.eliminated)
                SoundManager.play("bubble_pop_cute")
                -- 冰块伤害特效
                if board_.iceDamagedCells and #board_.iceDamagedCells > 0 then
                    boardRenderer.spawnIceDamageEffects(board_.iceDamagedCells)
                end
                if board_.comboText then
                    boardRenderer.startComboAnim(board_.comboText.combo, lastScreenW_)
                end
            else
                -- 无消除（理论上不会到这里，但防御性处理）
                board_:confirmEliminateAndFall()
            end

        elseif state == State.SWAP_BACK and pendingSwapBack_ then
            -- 回退动画完成 → 回到 Idle
            pendingSwapBack_ = false
            board_:confirmSwapBack()
            boardRenderer.clearAnims()

        elseif state == State.ELIMINATING then
            -- 消除动画完成 → 执行掉落
            local falling = board_:confirmEliminateAndFall()
            if #falling > 0 then
                boardRenderer.startFallAnim(falling, board_.animTiming.fallMs)
            else
                -- 无掉落，直接检查连锁
                M._doChainCheck()
            end

        elseif state == State.FALLING then
            -- 掉落动画完成 → 检查连锁
            boardRenderer.clearAnims()
            M._doChainCheck()
        end
    end

    -- IDLE 状态下倒计时归零 → 根据是否达标判定通关/失败
    if not board_.cleared and not board_.failed
        and board_.remainTime <= 0
        and board_.stateMachine.current == State.IDLE then
        if board_:finishLevel() then
            M._triggerCleared()
        else
            board_.failed = true
            board_.starRating = 0
            board_.stateMachine.current = State.FAILED
            SoundManager.play("level_failed")
            SoundManager.play("bounce_boing")
            logger.info(MODULE, "failed", "time up, score=" .. board_.score)
        end
    end

    -- 自由模式完成按钮脉冲动画
    if board_.goalReached and not storylineMode_ and not board_.cleared then
        finishPulse_ = finishPulse_ + dt
    end
end

--- 触发通关（内部辅助，抽取公共逻辑）
function M._triggerCleared()
    -- 主线模式：达标即 3 星
    if storylineMode_ then
        board_.starRating = 3
    end
    if onLevelComplete_ then
        isNewBest_ = onLevelComplete_(
            levelData_.levelId,
            board_.finalScore,
            board_.starRating
        )
    end
    resultPopup.startCelebration(lastScreenW_, lastScreenH_,
        { ratingType = "stars", ratingValue = board_.starRating })
    SoundManager.play("level_cleared")
    SoundManager.play("success_fanfare")
    levelCompleteTimer_ = 0.5
    logger.info(MODULE, "cleared", "score=" .. board_.finalScore ..
        " stars=" .. board_.starRating .. " newBest=" .. tostring(isNewBest_))
end

--- 连锁检查（内部方法）
function M._doChainCheck()
    if not board_ then return end

    local checkResult = board_:confirmFallAndCheck()

    if checkResult == "chain" then
        -- 有连锁消除，启动新一轮消除动画
        boardRenderer.startElimAnim(board_.eliminatedCells, board_.animTiming.eliminateMs)
        boardRenderer.setScoreTarget(lastScreenW_ - 14, 34)
        boardRenderer.spawnElimParticles(board_.eliminatedCells)
        SoundManager.play("bubble_pop_cute")
        -- 冰块伤害特效
        if board_.iceDamagedCells and #board_.iceDamagedCells > 0 then
            boardRenderer.spawnIceDamageEffects(board_.iceDamagedCells)
        end
        if board_.comboText then
            boardRenderer.startComboAnim(board_.comboText.combo, lastScreenW_)
        end
    elseif checkResult == "settled" then
        -- 无连锁，结算当前步
        boardRenderer.clearAnims()
        local stepResult = board_:settleStep()

        if stepResult == "cleared" then
            -- 时间到 + 目标达成 → 通关
            M._triggerCleared()

        elseif stepResult == "goal_reached" then
            -- 目标已达成（时间未到）
            if storylineMode_ and not goalReachedHandled_ then
                -- 主线模式：立即结束
                goalReachedHandled_ = true
                board_:finishLevel()
                M._triggerCleared()
            end
            -- 自由模式：board_.goalReached 已为 true，render 会显示完成按钮

        elseif stepResult == "failed" then
            -- 失败
            SoundManager.play("level_failed")
            SoundManager.play("bounce_boing")
            logger.info(MODULE, "failed", "score=" .. board_.score)

        else
            -- 继续游戏
        end
    end
end

-- NanoVG 渲染

---@param vg userdata
---@param screenW number
---@param screenH number
function M.render(vg, screenW, screenH, afterBg)
    if not board_ or not levelData_ then return end

    lastScreenW_ = screenW
    lastScreenH_ = screenH

    -- 背景
    bgManager.renderBackground(vg, screenW, screenH, bgDecoTime_, bgConfig_)


    -- 计算棋盘布局
    local sceneryLayout=boardRenderer.calcLayout(screenW, screenH,
        board_.rows, board_.cols,
        hudRenderer.TOP_BAR_H + LAYOUT.BOARD_TOP_PADDING,
        hudRenderer.BOTTOM_BAR_H + LAYOUT.BOARD_BOTTOM_PADDING)
    Scenery.draw(vg,screenW,screenH,{x=sceneryLayout.x,y=sceneryLayout.y,w=sceneryLayout.totalW,h=sceneryLayout.totalH},bgConfig_,bgDecoTime_)
    if afterBg then afterBg() end

    -- HUD 顶部
    local levelTitle = levelData_.title or (levelData_.levelId:gsub("^L", "关卡") .. "  " .. levelData_.timeLimit .. "秒")
    hudRenderer.drawTop(vg, screenW, board_, levelTitle)

    -- 棋盘
    boardRenderer.draw(vg, board_, screenW, screenH)

    -- HUD 底部
    bottomBtns_ = hudRenderer.drawBottom(vg, screenW, screenH)

    -- 自由模式达标后：右上角完成按钮
    finishBtn_ = nil
    if board_.goalReached and not storylineMode_ and not board_.cleared and not board_.failed then
        local pulse = math.sin(finishPulse_ * 3) * 0.5 + 0.5
        finishBtn_ = hudRenderer.drawFinishButton(vg, screenW, pulse)
    end

    -- 暂停遮罩（在结算弹窗之前，优先级低于结算）
    if paused_ and not board_.cleared and not board_.failed then
        pauseBtns_ = pauseOverlay.draw(vg, screenW, screenH)
    end

    -- 结算弹窗
    if board_.cleared then
        resultBtns_ = resultPopup.drawCleared(vg, screenW, screenH, {
            ratingType = "stars",
            ratingValue = board_.starRating,
            stats = {
                { label = "本次得分", value = tostring(board_.finalScore) },
                { label = "历史最佳", value = prevBestScore_ and tostring(prevBestScore_) or "--" },
                { label = "剩余时间", value = tostring(math.ceil(board_.remainTime)) .. "秒" },
                { label = "目标完成", value = board_:getGoalText(), color = { 46, 204, 113 } },
            },
            isNewBest = isNewBest_,
            hasNextLevel = hasNextLevel_,
            storylineMode = storylineMode_,
        })
    elseif board_.failed then
        resultBtns_ = resultPopup.drawFailed(vg, screenW, screenH, {
            title = "时间到！",
            message = "未完成目标：" .. board_:getGoalText(),
            subMessage = "得分：" .. tostring(board_.score),
        })
    end

end

return M
