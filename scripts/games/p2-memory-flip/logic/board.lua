--- 记忆翻牌 - 棋盘逻辑引擎
--- 职责：洗牌、配对判定、计时、统计
--- 约束：纯数据逻辑，零渲染依赖
local State = require("games.p2-memory-flip.logic.state")

local M = {}
M.__index = M

-- 卡牌状态
M.CARD_HIDDEN = "hidden"       -- 背面朝上
M.CARD_FLIPPED = "flipped"     -- 临时翻开（待判定）
M.CARD_MATCHED = "matched"     -- 已配对锁定

-- 图案池定义

local ART_POOLS = {
    shapes_easy = {
        "circle", "square", "triangle", "star",
        "diamond", "cross", "halfcircle", "heart",
        "house", "fish", "sun", "apple",
    },
    shapes_medium = {
        "circle", "square", "triangle", "star",
        "diamond", "cross", "halfcircle", "heart",
        "pentagon", "hexagon", "arrow", "lightning",
        "crescent", "shield", "plus", "minus",
        "house", "fish", "tree", "crown",
        "bell", "key", "flag", "sun",
        "apple", "mushroom", "cherry", "cloud",
    },
    shapes_hard = {
        "circle", "square", "triangle", "star",
        "diamond", "cross", "halfcircle", "heart",
        "pentagon", "hexagon", "arrow", "lightning",
        "crescent", "shield", "plus", "minus",
        "spiral", "gear", "hourglass", "gem",
        "flower", "leaf", "drop", "flame",
        "house", "fish", "tree", "jewel",
        "bowtie", "crown", "rocket", "bell",
        "anchor", "snowflake", "note", "sun",
        "moonstar", "key", "flag", "eye",
        "cloud", "umbrella", "mushroom", "apple",
        "cup", "mountain", "dice", "cherry",
        "star6", "donut", "lollipop", "boat",
        "plane", "envelope", "bulb", "clover",
        "arch", "target",
    },
}

-- 构造与重置

--- 洗牌算法 (Fisher-Yates)
---@param t table
---@param seed number|nil
local function shuffle(t, seed)
    if seed then math.randomseed(seed) end
    for i = #t, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
end

--- 创建棋盘实例
---@param levelData table 关卡配置
---@param seed number|nil 随机种子
---@return table board
function M.new(levelData, seed)
    local self = setmetatable({}, M)
    self.levelData = levelData
    self.rows = levelData.layout.rows
    self.cols = levelData.layout.cols
    self.cardCount = levelData.cardCount
    self.pairCount = levelData.cardCount / 2
    self.flipBackDelayMs = math.max(600, levelData.flipBackDelayMs or 600)
    self.rankTime = levelData.rankTime
    self.seed = seed or os.time()

    self:reset()
    return self
end

--- 重置棋盘
function M:reset()
    self.seed = self.seed or os.time()

    -- 从图案池中选取 pairCount 个不重复图案
    local poolName = self.levelData.artPool or "shapes_easy"
    local pool = ART_POOLS[poolName] or ART_POOLS.shapes_easy
    local selected = {}
    local poolCopy = {}
    for i, v in ipairs(pool) do poolCopy[i] = v end
    shuffle(poolCopy, self.seed)

    for i = 1, self.pairCount do
        selected[i] = poolCopy[((i - 1) % #poolCopy) + 1]
    end

    -- 每种图案出现 2 次，生成牌面列表
    local cardKeys = {}
    for _, key in ipairs(selected) do
        cardKeys[#cardKeys + 1] = key
        cardKeys[#cardKeys + 1] = key
    end
    shuffle(cardKeys, self.seed + 1)

    -- 生成卡牌数组（1-based，按行优先排列）
    self.cards = {}
    for i = 1, self.cardCount do
        self.cards[i] = {
            index = i,
            artKey = cardKeys[i],
            state = M.CARD_HIDDEN,
            row = math.ceil(i / self.cols),
            col = ((i - 1) % self.cols) + 1,
        }
    end

    -- 游戏状态
    self.stateMachine = State.new()
    self.firstFlipped = nil     -- 第一张翻开的卡牌 index
    self.secondFlipped = nil    -- 第二张翻开的卡牌 index
    self.matchedCount = 0       -- 已配对数量
    self.mistakeCount = 0       -- 错误次数
    self.attemptCount = 0       -- 尝试次数（每翻两张算一次）

    -- 计时
    self.timerStarted = false
    self.elapsedSec = 0
    self.clearTimeMs = nil

    -- 翻回计时器
    self.flipBackTimer = nil    -- { remaining: number (sec) }
    -- 配对成功高亮计时器
    self.matchHighlightTimer = nil

    -- 结果
    self.cleared = false
    self.starRating = 0
end

-- 计时

--- 更新计时器
---@param dt number 帧间隔（秒）
function M:update(dt)
    -- 计时
    if self.timerStarted and not self.cleared then
        self.elapsedSec = self.elapsedSec + dt
    end

    -- 翻回延迟
    if self.flipBackTimer then
        self.flipBackTimer.remaining = self.flipBackTimer.remaining - dt
        if self.flipBackTimer.remaining <= 0 then
            self.flipBackTimer = nil
            self:_resolveFlipBack()
        end
    end

    -- 配对成功高亮
    if self.matchHighlightTimer then
        self.matchHighlightTimer.remaining = self.matchHighlightTimer.remaining - dt
        if self.matchHighlightTimer.remaining <= 0 then
            self.matchHighlightTimer = nil
            self:_resolveMatch()
        end
    end
end

-- 翻牌操作

--- 尝试翻开一张卡牌
---@param cardIndex number 卡牌索引（1-based）
---@return string|nil result "first_flip" / "checking" / "ignored" / nil
function M:flipCard(cardIndex)
    local card = self.cards[cardIndex]
    if not card then return "ignored" end

    -- 不能翻已配对或已翻开的卡
    if card.state ~= M.CARD_HIDDEN then return "ignored" end

    -- 状态机检查
    if not State.canFlip(self.stateMachine) then return "ignored" end

    local sm = self.stateMachine

    if sm.current == State.IDLE then
        -- 翻开第一张
        card.state = M.CARD_FLIPPED
        self.firstFlipped = cardIndex
        State.toOneFlipped(sm)

        -- 第一次翻牌开始计时
        if not self.timerStarted then
            self.timerStarted = true
        end

        return "first_flip"

    elseif sm.current == State.ONE_FLIPPED then
        -- 翻开第二张
        card.state = M.CARD_FLIPPED
        self.secondFlipped = cardIndex
        State.toTwoFlippedChecking(sm)
        self.attemptCount = self.attemptCount + 1

        -- 立即判定
        local card1 = self.cards[self.firstFlipped]
        local card2 = self.cards[self.secondFlipped]

        State.toResolving(sm)

        if card1.artKey == card2.artKey then
            -- 配对成功 → 启动高亮计时器
            self.matchHighlightTimer = { remaining = 0.25 }
        else
            -- 配对失败 → 启动翻回计时器
            self.mistakeCount = self.mistakeCount + 1
            self.flipBackTimer = { remaining = self.flipBackDelayMs / 1000 }
        end

        return "checking"
    end

    return "ignored"
end

--- 内部：翻回失败的卡牌
function M:_resolveFlipBack()
    if self.firstFlipped then
        self.cards[self.firstFlipped].state = M.CARD_HIDDEN
    end
    if self.secondFlipped then
        self.cards[self.secondFlipped].state = M.CARD_HIDDEN
    end
    self.firstFlipped = nil
    self.secondFlipped = nil
    State.toIdle(self.stateMachine)
end

--- 内部：确认配对成功
function M:_resolveMatch()
    if self.firstFlipped then
        self.cards[self.firstFlipped].state = M.CARD_MATCHED
    end
    if self.secondFlipped then
        self.cards[self.secondFlipped].state = M.CARD_MATCHED
    end
    self.matchedCount = self.matchedCount + 1
    -- 狐狸夸奖触发
    local FoxMascot = require("shared.components.fox-mascot")
    FoxMascot.notifySuccess()
    self.firstFlipped = nil
    self.secondFlipped = nil

    -- 检查通关
    if self.matchedCount >= self.pairCount then
        self.cleared = true
        self.clearTimeMs = math.floor(self.elapsedSec * 1000)
        self.starRating = self:_calcStarRating(self.elapsedSec)
        State.toCleared(self.stateMachine)
    else
        State.toIdle(self.stateMachine)
    end
end

--- 计算星级评价（1/2/3星）
--- 时间阈值复用 rankTime: a → 3星, b → 2星, 其余 → 1星
---@param timeSec number
---@return number starRating 1|2|3
function M:_calcStarRating(timeSec)
    local rt = self.rankTime
    if timeSec <= rt.a then return 3 end
    if timeSec <= rt.b then return 2 end
    return 1
end

-- 查询

--- 获取格式化时间字符串 mm:ss.SS
---@param ms number|nil 毫秒，nil 时使用当前 elapsedSec
---@return string
function M:formatTime(ms)
    local totalMs = ms or math.floor(self.elapsedSec * 1000)
    local totalSec = totalMs / 1000
    local min = math.floor(totalSec / 60)
    local sec = totalSec - min * 60
    return string.format("%02d:%05.2f", min, sec)
end

--- 获取当前预估星级
---@return number starRating 1|2|3
function M:currentEstimatedStarRating()
    return self:_calcStarRating(self.elapsedSec)
end

--- 是否正在高亮动画中
---@return boolean
function M:isHighlighting()
    return self.matchHighlightTimer ~= nil
end

--- 暂停计时
function M:pauseTimer()
    self.timerStarted = false
end

--- 恢复计时
function M:resumeTimer()
    if not self.cleared then
        self.timerStarted = true
    end
end

return M
