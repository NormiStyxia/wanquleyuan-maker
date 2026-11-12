--- 记忆翻牌 - 翻转动画控制器
--- 职责：管理卡牌翻转动画状态机（进度、正反面判定）
local Board = require("games.p2-memory-flip.logic.board")
local ANIM = require("shared.constants.animations")

local M = {}

local FLIP_DURATION = ANIM.DURATION_FAST   -- 翻转动画时长（秒），流畅感

--- 每张卡牌的动画状态: { progress=0..1, fromFace="back"/"front", toFace="back"/"front" }
---@type table<number, table>
local animStates = {}

--- 上一帧每张卡牌的逻辑状态（用于检测变化）
---@type table<number, string>
local prevCardStates = {}

--- 重置动画状态（新关卡/重开时调用）
function M.reset()
    animStates = {}
    prevCardStates = {}
end

--- 检测状态变化并启动翻转动画，返回本帧新配对的卡牌列表
---@param board table Board 实例
---@return table newlyMatched 本帧新配对的卡牌数组（可能为空）
function M.detectChanges(board)
    local newlyMatched = {}

    for _, card in ipairs(board.cards) do
        local prevState = prevCardStates[card.index]
        local curState = card.state

        if prevState and prevState ~= curState then
            local fromFace, toFace
            if prevState == Board.CARD_HIDDEN and (curState == Board.CARD_FLIPPED or curState == Board.CARD_MATCHED) then
                fromFace = "back"
                toFace = "front"
            elseif (prevState == Board.CARD_FLIPPED or prevState == Board.CARD_MATCHED) and curState == Board.CARD_HIDDEN then
                fromFace = "front"
                toFace = "back"
            elseif prevState == Board.CARD_FLIPPED and curState == Board.CARD_MATCHED then
                fromFace = nil
                toFace = nil
                newlyMatched[#newlyMatched + 1] = card
            end

            if fromFace and toFace then
                animStates[card.index] = {
                    progress = 0,
                    fromFace = fromFace,
                    toFace = toFace,
                }
            end
        end

        prevCardStates[card.index] = curState
    end

    return newlyMatched
end

--- 推进所有活跃动画
---@param dt number
function M.advance(dt)
    local toRemove = {}
    for idx, anim in pairs(animStates) do
        anim.progress = anim.progress + dt / FLIP_DURATION
        if anim.progress >= 1.0 then
            toRemove[#toRemove + 1] = idx
        end
    end
    for _, idx in ipairs(toRemove) do
        animStates[idx] = nil
    end
end

--- 获取卡牌当前动画的显示信息
---@param cardIndex number
---@param logicState string 逻辑层的当前状态
---@return string displayFace "back"/"front" 当前应显示的面
---@return number scaleX 0..1 水平缩放比
function M.getCardDisplay(cardIndex, logicState)
    local anim = animStates[cardIndex]
    if not anim then
        local face = (logicState == Board.CARD_HIDDEN) and "back" or "front"
        return face, 1.0
    end

    local p = math.min(anim.progress, 1.0)
    if p < 0.5 then
        local scaleX = math.cos(p * math.pi)
        return anim.fromFace, scaleX
    else
        local scaleX = -math.cos(p * math.pi)
        return anim.toFace, scaleX
    end
end

--- 检查指定卡牌是否正在播放翻转动画
---@param cardIndex number
---@return boolean
function M.isAnimating(cardIndex)
    return animStates[cardIndex] ~= nil
end

return M
