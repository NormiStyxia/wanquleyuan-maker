--- 连连看 - 棋盘逻辑
--- 职责：棋盘生成、洗牌、配对消除、死盘检测、计时
--- 纯 Lua 逻辑，禁止引入渲染 API
local Pathfinder = require("games.p4-link-match.logic.pathfinder")
local State = require("games.p4-link-match.logic.state")
local logger = require("shared.utils.logger")

local M = {}
M.__index = M
local MODULE = "lm-board"

-- 图案池定义（优先使用独立手绘图案集，保证各关卡图标风格与视觉体量统一）
local ART_POOLS = {
    shapes_easy = {
        "circle", "square", "triangle", "star",
        "diamond", "cross", "heart", "flower",
    },
    shapes_medium = {
        "circle", "square", "triangle", "star",
        "diamond", "cross", "heart", "flower",
        "leaf", "apple", "sun", "house",
        "cloud", "fish", "halfcircle", "pentagon",
    },
    shapes_hard = {
        "circle", "square", "triangle", "star",
        "diamond", "cross", "heart", "flower",
        "leaf", "apple", "sun", "house",
        "cloud", "fish", "halfcircle",
        "pentagon", "hexagon", "arrow", "lightning",
        "crescent", "shield", "plus", "minus",
        "spiral", "gear", "hourglass", "gem",
        "flame", "tree", "jewel",
        "bowtie", "crown", "rocket", "bell",
        "anchor", "snowflake", "note",
        "moonstar", "key", "flag", "eye",
        "umbrella", "mushroom",
        "cup", "mountain", "hand", "dice",
        "cherry", "star6", "star7", "donut",
        "lollipop", "boat", "plane", "envelope",
        "bulb", "moon", "clover", "arch",
        "target",
    },
}

--- 简易伪随机数生成器（支持固定 seed 复现）
local function createRng(seed)
    local s = seed or os.time()
    return {
        seed = s,
        next = function(self)
            -- xorshift32
            self.seed = self.seed ~ (self.seed << 13)
            self.seed = self.seed ~ (self.seed >> 17)
            self.seed = self.seed ~ (self.seed << 5)
            self.seed = self.seed & 0x7FFFFFFF
            return self.seed
        end,
        --- 返回 [1, n] 的整数
        range = function(self, n)
            return (self:next() % n) + 1
        end,
    }
end

--- Fisher-Yates 洗牌
---@param arr table
---@param rng table
local function shuffle(arr, rng)
    for i = #arr, 2, -1 do
        local j = rng:range(i)
        arr[i], arr[j] = arr[j], arr[i]
    end
end

--- 创建新棋盘实例
---@param levelData table 关卡配置
---@return table board 实例
function M.new(levelData)
    local self = setmetatable({}, M)

    self.rows = levelData.board.rows
    self.cols = levelData.board.cols
    self.totalTiles = self.rows * self.cols
    self.patternCount = levelData.patternCount
    self.artPool = levelData.artPool
    self.timeLimit = levelData.timeLimit
    self.maxHints = levelData.hints
    self.maxShuffles = levelData.shuffles
    self.rankTime = levelData.rankTime

    -- 状态
    self.sm = State.new()
    self.grid = {}              -- grid[y+1][x+1] = patternId (0=空)
    self.remainPairs = 0
    self.hintsUsed = 0
    self.shufflesUsed = 0
    self.elapsedMs = 0
    self.timerStarted = false   -- 首次点击后开始计时
    self.paused = false
    self.cleared = false
    self.failed = false
    self.starRating = 0
    self.clearTimeMs = 0

    -- 选中状态
    self.selectedPos = nil      -- { x, y }

    -- 动画数据（不阻塞操作，渲染层消费后自动清理）
    self.activeEffects = {}     -- 消除特效队列
    self.shuffleTimer = 0
    self.hintPair = nil         -- { posA, posB } 提示高亮
    self.hintTimer = 0
    self.idleTimer = 0          -- 空闲计时器：无操作超 10 秒自动提示

    -- 获取艺术池对应的图案列表
    local pool = ART_POOLS[self.artPool] or ART_POOLS.shapes_easy
    local patterns = {}
    for i = 1, self.patternCount do
        patterns[i] = pool[i] or pool[((i - 1) % #pool) + 1]
    end
    self.patterns = patterns    -- patternId -> artKey 映射（1-based）

    -- 随机种子
    self.seed = levelData.seed or os.time()
    self.rng = createRng(self.seed)

    -- 生成初始棋盘
    self:generateBoard()

    logger.info(MODULE, "new", "level=" .. levelData.levelId ..
        " size=" .. self.cols .. "x" .. self.rows ..
        " patterns=" .. self.patternCount ..
        " tiles=" .. self.totalTiles ..
        " seed=" .. self.seed)

    return self
end

--- 生成棋盘方块布局
function M:generateBoard()
    local total = self.totalTiles
    -- 每种图案分配次数（必须为偶数）
    local countPer = math.floor(total / self.patternCount)
    -- 确保 countPer 为偶数
    if countPer % 2 ~= 0 then
        countPer = countPer - 1
    end

    -- 构建图案数组
    local tiles = {}
    local assigned = 0
    for pid = 1, self.patternCount do
        for _ = 1, countPer do
            tiles[#tiles + 1] = pid
            assigned = assigned + 1
        end
    end
    -- 补齐剩余（轮流给前面的图案各补 2 个）
    local pidIdx = 1
    while assigned < total do
        tiles[#tiles + 1] = pidIdx
        tiles[#tiles + 1] = pidIdx
        assigned = assigned + 2
        pidIdx = pidIdx + 1
        if pidIdx > self.patternCount then pidIdx = 1 end
    end

    -- 洗牌并填入棋盘，确保无死盘
    local success = false
    for attempt = 1, 100 do
        shuffle(tiles, self.rng)

        -- 填入 grid
        self.grid = {}
        local idx = 1
        for y = 1, self.rows do
            self.grid[y] = {}
            for x = 1, self.cols do
                self.grid[y][x] = tiles[idx]
                idx = idx + 1
            end
        end

        -- 检查是否有至少一个可消除配对
        local pair = Pathfinder.findAnyPair(self.grid, self.rows, self.cols)
        if pair then
            success = true
            break
        end

        logger.info(MODULE, "generateBoard", "attempt " .. attempt .. " deadlock, reshuffling")
    end

    if not success then
        logger.error(MODULE, "generateBoard", "LM-005: failed to generate non-deadlock board after 100 attempts")
    end

    self.remainPairs = total / 2
end

--- 获取指定位置的 patternId
---@param x number 0-based
---@param y number 0-based
---@return number patternId (0=空)
function M:getTile(x, y)
    if x < 0 or x >= self.cols or y < 0 or y >= self.rows then
        return 0
    end
    return self.grid[y + 1][x + 1]
end

--- 获取指定位置的图案 artKey
---@param x number 0-based
---@param y number 0-based
---@return string|nil artKey
function M:getArtKey(x, y)
    local pid = self:getTile(x, y)
    if pid <= 0 then return nil end
    return self.patterns[pid]
end

--- 获取指定位置的 patternId 用的颜色索引
---@param x number 0-based
---@param y number 0-based
---@return number colorIndex (1-based)
function M:getColorIndex(x, y)
    local pid = self:getTile(x, y)
    if pid <= 0 then return 0 end
    return pid
end

--- 处理方块点击
---@param x number 0-based 逻辑坐标
---@param y number 0-based 逻辑坐标
---@return string result "selected"|"deselected"|"matched"|"mismatched"|"ignored"
function M:clickTile(x, y)
    if not State.canClick(self.sm) then
        return "ignored"
    end

    -- 任何有效点击清除提示显示（idleTimer 不重置，由消除逻辑控制）
    self.hintPair = nil
    self.hintTimer = 0

    local pid = self:getTile(x, y)
    if pid <= 0 then
        -- 点击空格：取消选中
        if self.selectedPos then
            self.selectedPos = nil
            State.reset(self.sm)
        end
        return "deselected"
    end

    -- 无选中：选中第一个
    if self.sm.current == State.IDLE then
        self.selectedPos = { x = x, y = y }
        State.toOneSelected(self.sm)
        -- 首次点击开始计时
        if not self.timerStarted then
            self.timerStarted = true
        end
        return "selected"
    end

    -- 已有选中
    if self.sm.current == State.ONE_SELECTED then
        local sel = self.selectedPos

        -- 点击同一方块：取消选中
        if sel.x == x and sel.y == y then
            self.selectedPos = nil
            State.reset(self.sm)
            return "deselected"
        end

        State.toChecking(self.sm)

        local selPid = self:getTile(sel.x, sel.y)
        if selPid == pid then
            -- 同图案，检查路径
            local path, turns = Pathfinder.findPath(
                self.grid, sel, { x = x, y = y }, self.rows, self.cols)
            if path then
                -- 配对成功 -> 立即消除方块，特效不阻塞操作
                local artA = self:getArtKey(sel.x, sel.y)
                local colorA = self:getColorIndex(sel.x, sel.y)
                local artB = self:getArtKey(x, y)
                local colorB = self:getColorIndex(x, y)

                -- 立即从网格移除
                self.grid[sel.y + 1][sel.x + 1] = 0
                self.grid[y + 1][x + 1] = 0
                self.remainPairs = self.remainPairs - 1

                -- 成功消除奖励：剩余时间 +1 秒
                self.elapsedMs = math.max(0, self.elapsedMs - 1000)
                self.timeBonusTimer = 1.0  -- +1 动画持续 1 秒

                -- 将视觉特效推入队列
                self.activeEffects[#self.activeEffects + 1] = {
                    timer = 0,
                    path = path,
                    posA = { x = sel.x, y = sel.y, artKey = artA, colorIdx = colorA },
                    posB = { x = x, y = y, artKey = artB, colorIdx = colorB },
                }

                self.selectedPos = nil
                self.hintPair = nil

                -- 成功消除：空闲计数 -3（最低 0）
                self.idleTimer = math.max(0, self.idleTimer - 3)

                -- 判断通关
                if self.remainPairs <= 0 then
                    self.cleared = true
                    self.clearTimeMs = self.elapsedMs
                    self.starRating = self:calcStarRating(self.clearTimeMs)
                    State.toCleared(self.sm)
                    -- 狐狸夸奖触发
                    local FoxMascot = require("shared.components.fox-mascot")
                    FoxMascot.notifySuccess()
                    return "matched"
                end

                State.reset(self.sm)

                -- 死盘检测
                local pair2 = Pathfinder.findAnyPair(self.grid, self.rows, self.cols)
                if not pair2 then
                    self:autoShuffle()
                end

                -- 狐狸夸奖触发
                local FoxMascot = require("shared.components.fox-mascot")
                FoxMascot.notifySuccess()
                return "matched"
            end
        end

        -- 配对失败或图案不同：第二个成为新选中
        self.selectedPos = { x = x, y = y }
        State.checkFailToOneSelected(self.sm)
        return "mismatched"
    end

    return "ignored"
end

--- 执行消除（连线动画结束后调用）
function M:doEliminate()
    if not self.elimPair then return end

    local a = self.elimPair.posA
    local b = self.elimPair.posB
    self.grid[a.y + 1][a.x + 1] = 0
    self.grid[b.y + 1][b.x + 1] = 0
    self.remainPairs = self.remainPairs - 1
    self.selectedPos = nil
    self.linePath = nil
    self.elimPair = nil

    -- 判断通关
    if self.remainPairs <= 0 then
        self.cleared = true
        self.clearTimeMs = self.elapsedMs
        self.starRating = self:calcStarRating(self.clearTimeMs)
        State.toCleared(self.sm)
        logger.info(MODULE, "doEliminate", "CLEARED! time=" .. self.clearTimeMs .. "ms stars=" .. self.starRating)
        return
    end

    State.eliminateToIdle(self.sm)

    -- 死盘检测
    local pair = Pathfinder.findAnyPair(self.grid, self.rows, self.cols)
    if not pair then
        logger.info(MODULE, "doEliminate", "deadlock detected, auto-shuffling")
        self:autoShuffle()
    end
end

--- 计算星级评价
---@param timeMs number
---@return number starRating 1|2|3
function M:calcStarRating(timeMs)
    local sec = timeMs / 1000
    if sec <= self.rankTime.a then return 3 end
    if sec <= self.rankTime.b then return 2 end
    return 1
end

--- 使用提示
---@return boolean success
function M:useHint()
    if self.hintsUsed >= self.maxHints then return false end
    if self.cleared or self.failed then return false end
    if not State.canClick(self.sm) then return false end

    local pair = Pathfinder.findAnyPair(self.grid, self.rows, self.cols)
    if not pair then return false end

    self.hintsUsed = self.hintsUsed + 1
    self.hintPair = { posA = pair.posA, posB = pair.posB }
    self.hintTimer = 0
    logger.info(MODULE, "useHint", "hint #" .. self.hintsUsed)
    return true
end

--- 使用洗牌（玩家主动）
---@return boolean success
function M:useShuffle()
    if self.shufflesUsed >= self.maxShuffles then return false end
    if self.cleared or self.failed then return false end
    if not (self.sm.current == State.IDLE or self.sm.current == State.ONE_SELECTED) then
        return false
    end

    self.shufflesUsed = self.shufflesUsed + 1
    self.selectedPos = nil
    self.hintPair = nil
    State.toShuffling(self.sm)
    self.shuffleTimer = 0
    self:reshuffleRemaining()
    logger.info(MODULE, "useShuffle", "shuffle #" .. self.shufflesUsed)
    return true
end

--- 自动洗牌（死盘触发，不消耗次数）
function M:autoShuffle()
    self.selectedPos = nil
    self.hintPair = nil
    State.toShuffling(self.sm)
    self.shuffleTimer = 0
    self:reshuffleRemaining()
    logger.info(MODULE, "autoShuffle", "auto shuffle triggered")
end

--- 重新排列剩余方块位置
function M:reshuffleRemaining()
    -- 收集剩余方块
    local tiles = {}
    local positions = {}
    for y = 0, self.rows - 1 do
        for x = 0, self.cols - 1 do
            local pid = self.grid[y + 1][x + 1]
            if pid > 0 then
                tiles[#tiles + 1] = pid
                positions[#positions + 1] = { x = x, y = y }
            end
        end
    end

    -- 洗牌并重新填入
    local success = false
    for attempt = 1, 100 do
        shuffle(tiles, self.rng)

        -- 清空并重填
        for y = 1, self.rows do
            for x = 1, self.cols do
                self.grid[y][x] = 0
            end
        end
        for i, pos in ipairs(positions) do
            self.grid[pos.y + 1][pos.x + 1] = tiles[i]
        end

        -- 检查是否有可消除配对
        local pair = Pathfinder.findAnyPair(self.grid, self.rows, self.cols)
        if pair then
            success = true
            break
        end
    end

    if not success then
        logger.error(MODULE, "reshuffleRemaining", "LM-005: reshuffle failed after 100 attempts")
    end
end

--- 暂停计时
function M:pauseTimer()
    self.paused = true
end

--- 恢复计时
function M:resumeTimer()
    self.paused = false
end

--- 每帧更新
---@param dt number 秒
function M:update(dt)
    if self.cleared or self.failed then return end

    -- 计时
    if self.timerStarted and not self.paused then
        self.elapsedMs = self.elapsedMs + dt * 1000
    end

    -- 超时判定
    if self.timerStarted and not self.paused then
        local remainTime = self.timeLimit - self.elapsedMs / 1000
        if remainTime <= 0 then
            self.failed = true
            State.toFailed(self.sm)
            logger.info(MODULE, "update", "FAILED! remainPairs=" .. self.remainPairs)
            return
        end
    end

    -- +1 秒动画计时
    if self.timeBonusTimer and self.timeBonusTimer > 0 then
        self.timeBonusTimer = self.timeBonusTimer - dt
        if self.timeBonusTimer <= 0 then
            self.timeBonusTimer = 0
        end
    end

    -- 提示高亮持续显示，hintTimer 持续递增用于驱动脉冲动画
    -- 玩家点击时在 clickTile() 中清除 hintPair
    if self.hintPair then
        self.hintTimer = self.hintTimer + dt
    end

    -- 空闲自动提示：10 秒无操作自动显示可消对
    if self.timerStarted and not self.paused and not self.hintPair then
        self.idleTimer = self.idleTimer + dt
        if self.idleTimer >= 10.0 and State.canClick(self.sm) then
            local pair = Pathfinder.findAnyPair(self.grid, self.rows, self.cols)
            if pair then
                self.hintPair = { posA = pair.posA, posB = pair.posB }
                self.hintTimer = 0
                self.idleTimer = 0
                logger.info(MODULE, "update", "auto-hint triggered (10s idle)")
            end
        end
    end

    -- 消除特效计时（不阻塞操作）
    for i = #self.activeEffects, 1, -1 do
        local fx = self.activeEffects[i]
        fx.timer = fx.timer + dt
        if fx.timer >= 0.6 then
            table.remove(self.activeEffects, i)
        end
    end

    -- 洗牌动画计时
    if self.sm.current == State.SHUFFLING then
        self.shuffleTimer = self.shuffleTimer + dt
        if self.shuffleTimer >= 0.5 then
            State.shuffleToIdle(self.sm)
            self.shuffleTimer = 0
        end
    end
end

--- 获取剩余时间（秒）
---@return number
function M:getRemainTime()
    local remain = self.timeLimit - self.elapsedMs / 1000
    return math.max(0, remain)
end

--- 获取剩余提示次数
---@return number
function M:getRemainHints()
    return self.maxHints - self.hintsUsed
end

--- 获取剩余洗牌次数
---@return number
function M:getRemainShuffles()
    return self.maxShuffles - self.shufflesUsed
end

--- 重置（Restart）
function M:restart()
    self.sm = State.new()
    self.elapsedMs = 0
    self.timerStarted = false
    self.paused = false
    self.cleared = false
    self.failed = false
    self.starRating = 0
    self.clearTimeMs = 0
    self.selectedPos = nil
    self.activeEffects = {}
    self.shuffleTimer = 0
    self.hintPair = nil
    self.hintTimer = 0
    self.idleTimer = 0
    self.hintsUsed = 0
    self.shufflesUsed = 0
    self.rng = createRng(os.time())
    self.seed = self.rng.seed
    self:generateBoard()
end

return M
