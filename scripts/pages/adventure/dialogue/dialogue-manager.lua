--- 冒险地图对话管理器
--- 职责：构建对话/小知识选项、查找节点、触发通关后对话链
local Storyline = require("modules.storyline.init")
local Dialogue = require("modules.dialogue.init")
local FunFact = require("modules.dialogue.fun-fact")
local advSfx = require("pages.adventure.adventure-sfx")

local M = {}

-- ============================================================================
-- 全通关特殊对话
-- ============================================================================

local CELEBRATION_DIALOGUE = {
    { speaker = "慧慧", text = "火火，你完成了所有的挑战！" },
    { speaker = "泡泡", text = "喵~ 我就知道你能做到！" },
    { speaker = "糖糖", text = "好棒好棒！撒花庆祝！" },
    { speaker = "豆豆", text = "一对一对，全部完美通关！" },
    { speaker = "火火", text = "谢谢大家！这趟冒险太精彩了！" },
}

local CELEBRATION_FUNFACT = {
    speaker = "火火",
    text = "狐狸的尾巴不只是好看，冬天还能当被子盖！",
}

--- 自由模式解锁提示对话
local FREE_MODE_UNLOCK_DIALOGUE = {
    { speaker = "慧慧", text = "恭喜你完成了前四关的冒险！" },
    { speaker = "慧慧", text = "自由模式已经解锁啦！你可以在首页自由选择任意游戏进行挑战。" },
    { speaker = "火火", text = "太棒了！我要去试试！" },
}

-- ============================================================================
-- 选项构建
-- ============================================================================

--- 构建 Dialogue.start 的 opts
---@param npcImages table<string, number>
---@param foxImage number
---@param onComplete function|nil
---@param levelVars table<string, string|number>|nil
---@return table
function M.getDialogueOpts(npcImages, foxImage, onComplete, levelVars)
    return {
        npcImages = npcImages,
        foxImage = foxImage,
        fontName = "adv",
        onComplete = onComplete,
        levelVars = levelVars,
        onTick = function(role)
            advSfx.play("dialogue_tick")
        end,
        onAdvance = function()
            advSfx.play("dialogue_advance")
        end,
        onDialogueComplete = function()
            advSfx.play("dialogue_complete")
        end,
        onLineStart = function(role)
            advSfx.play("chat_" .. role)
        end,
    }
end

--- 构建 FunFact.show 的 opts
---@param npcImages table<string, number>
---@param foxImage number
---@param onDismiss function|nil
---@return table
function M.getFunFactOpts(npcImages, foxImage, onDismiss)
    return {
        npcImages = npcImages,
        foxImage = foxImage,
        fontName = "adv",
        onDismiss = onDismiss,
        onShow = function()
            advSfx.play("fun_fact_popup")
        end,
        onDismissSound = function()
            advSfx.play("fun_fact_dismiss")
        end,
    }
end

-- ============================================================================
-- 节点查找
-- ============================================================================

--- 查找节点配置
---@param nodeId string
---@return table|nil
function M.findNodeConfig(nodeId)
    local nodes = Storyline.getNodeList()
    for _, n in ipairs(nodes) do
        if n.node.nodeId == nodeId then
            return n.node
        end
    end
    return nil
end

-- ============================================================================
-- 通关后对话链
-- ============================================================================

--- 显示趣味小知识卡片（通关后触发）
---@param nodeId string
---@param isFirstClear boolean
---@param npcImages table
---@param foxImage number
function M.showFunFactForNode(nodeId, isFirstClear, npcImages, foxImage)
    local nodeConfig = M.findNodeConfig(nodeId)
    if not nodeConfig or not nodeConfig.funFact then return end

    -- 触发概率：首次通关 100%，重玩 50%
    if not isFirstClear and math.random() > 0.5 then
        return
    end

    FunFact.show(nodeConfig.funFact, M.getFunFactOpts(npcImages, foxImage, function()
        -- fun fact 关闭后，检查是否需要全通关庆祝
        if isFirstClear and Storyline.isAllCompleted() then
            advSfx.play("celebration_fanfare")
            Dialogue.start(CELEBRATION_DIALOGUE, M.getDialogueOpts(npcImages, foxImage, function()
                FunFact.show(CELEBRATION_FUNFACT, M.getFunFactOpts(npcImages, foxImage, nil))
            end))
        end
    end))
end

--- 从关卡配置中提取模板变量
---@param nodeConfig table 节点配置（含 levelFile, gameType）
---@return table<string, string|number>|nil
function M.extractLevelVars(nodeConfig)
    if not nodeConfig or not nodeConfig.levelFile then return nil end
    local ok, levelData = pcall(require, "config.storyline-levels." .. nodeConfig.levelFile)
    if not ok or not levelData then return nil end

    local vars = {}
    -- 消消乐：目标分数、时间
    if levelData.goal and levelData.goal.targetScore then
        vars.targetScore = levelData.goal.targetScore
    end
    if levelData.timeLimit then
        vars.timeLimit = levelData.timeLimit
    end
    -- 推箱子：推荐步数
    if levelData.recommendedSteps then
        vars.recommendedSteps = levelData.recommendedSteps
    end
    -- 记忆翻牌：翻回延迟、冷却时间
    if levelData.flipBackDelayMs then
        vars.flipBackDelayMs = levelData.flipBackDelayMs
    end
    if levelData.flipCooldownMs then
        vars.flipCooldownMs = levelData.flipCooldownMs
        vars.flipCooldownSec = string.format("%.1f", levelData.flipCooldownMs / 1000)
    end
    return next(vars) and vars or nil
end

--- 显示通关后对话（postDialogue → funFact → 庆祝）
---@param nodeId string
---@param isFirstClear boolean
---@param npcImages table
---@param foxImage number
function M.showPostDialogueForNode(nodeId, isFirstClear, npcImages, foxImage)
    local nodeConfig = M.findNodeConfig(nodeId)
    local levelVars = M.extractLevelVars(nodeConfig)

    --- 进入 funFact 之前，检查是否需要弹出自由模式解锁提示
    local function proceedAfterPostDialogue()
        if nodeId == "story-4" and isFirstClear then
            Dialogue.start(FREE_MODE_UNLOCK_DIALOGUE, M.getDialogueOpts(npcImages, foxImage, function()
                M.showFunFactForNode(nodeId, isFirstClear, npcImages, foxImage)
            end))
        else
            M.showFunFactForNode(nodeId, isFirstClear, npcImages, foxImage)
        end
    end

    if nodeConfig and nodeConfig.postDialogue and #nodeConfig.postDialogue > 0 then
        Dialogue.start(nodeConfig.postDialogue, M.getDialogueOpts(npcImages, foxImage, proceedAfterPostDialogue, levelVars))
    else
        proceedAfterPostDialogue()
    end
end

return M
