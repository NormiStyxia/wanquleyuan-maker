--- 消消乐 - 棋盘逻辑引擎
--- 职责：消除判定、掉落补齐、连锁、死盘检测、特殊方块、计分
--- 约束：纯数据逻辑，零渲染依赖
local State = require("games.p3-match-3.logic.state")

local M = {}
M.__index = M

-- 方块特殊类型常量
M.SPECIAL_NONE = "none"
M.SPECIAL_LINE_H = "line_h"   -- 横向直线消除
M.SPECIAL_LINE_V = "line_v"   -- 纵向直线消除
M.SPECIAL_BOMB = "bomb"       -- 范围爆炸 3x3
M.SPECIAL_RAINBOW = "rainbow" -- 彩虹方块
M.SPECIAL_STONE = "stone"     -- 石头障碍物（不可消除、不可交换、不阻挡掉落）
M.SPECIAL_ICE = "ice"         -- 冰块障碍物（3生命值，相邻消除时减HP，归零消失）

-- 确定性随机数生成器（线性同余）

local RNG = {}
RNG.__index = RNG

function RNG.new(seed)
    return setmetatable({ state = seed or 12345 }, RNG)
end

function RNG:next()
    -- 线性同余参数（Numerical Recipes）
    self.state = (self.state * 1103515245 + 12345) % 2147483648
    return self.state
end

--- 生成 [min, max] 之间的整数
function RNG:nextInt(min, max)
    return min + (self:next() % (max - min + 1))
end

--- Fisher-Yates 洗牌
function RNG:shuffle(t)
    for i = #t, 2, -1 do
        local j = self:nextInt(1, i)
        t[i], t[j] = t[j], t[i]
    end
end

-- 加权随机颜色生成

local function buildWeightedPool(tilePool)
    local pool = {}
    local totalWeight = 0
    for _, entry in ipairs(tilePool) do
        totalWeight = totalWeight + entry.weight
    end
    for _, entry in ipairs(tilePool) do
        pool[#pool + 1] = { colorId = entry.colorId, cumWeight = 0 }
    end
    local cum = 0
    for i, entry in ipairs(tilePool) do
        cum = cum + entry.weight
        pool[i].cumWeight = cum
    end
    pool.totalWeight = totalWeight
    return pool
end

local function randomColor(rng, weightedPool)
    local roll = rng:nextInt(1, weightedPool.totalWeight)
    for _, entry in ipairs(weightedPool) do
        if roll <= entry.cumWeight then
            return entry.colorId
        end
    end
    return weightedPool[1].colorId
end

-- 构造

--- 检查指定位置是否为石头
---@param r number
---@param c number
---@return boolean
function M:_isStone(r, c)
    local tile = self.grid[r] and self.grid[r][c]
    return tile ~= nil and tile.special == M.SPECIAL_STONE
end

--- 检查指定位置是否为冰块
---@param r number
---@param c number
---@return boolean
function M:_isIce(r, c)
    local tile = self.grid[r] and self.grid[r][c]
    return tile ~= nil and tile.special == M.SPECIAL_ICE
end

--- 检查指定位置是否为障碍物（石头或冰块）
---@param r number
---@param c number
---@return boolean
function M:_isObstacle(r, c)
    local tile = self.grid[r] and self.grid[r][c]
    if tile == nil then return false end
    return tile.special == M.SPECIAL_STONE or tile.special == M.SPECIAL_ICE
end

--- 创建棋盘实例
---@param levelData table 关卡配置
---@param seed number|nil 随机种子（nil 时用 os.time）
---@return table board
function M.new(levelData, seed)
    local self = setmetatable({}, M)
    self.levelData = levelData
    self.rows = levelData.board.rows
    self.cols = levelData.board.cols
    self.timeLimit = levelData.timeLimit
    self.remainTime = levelData.timeLimit
    self.goal = levelData.goal
    self.scoreRule = levelData.scoreRule
    self.animTiming = levelData.animTiming
    self.starScore = levelData.starScore

    self.seed = seed or os.time()
    self.rng = RNG.new(self.seed)
    self.weightedPool = buildWeightedPool(levelData.tilePool)

    -- 石头位置集合 key(r*100+c) -> true
    self.stoneSet = {}
    if levelData.stonePositions then
        for _, pos in ipairs(levelData.stonePositions) do
            self.stoneSet[pos[1] * 100 + pos[2]] = true
        end
    end

    -- 冰块位置集合 key(r*100+c) -> true
    self.iceSet = {}
    if levelData.icePositions then
        for _, pos in ipairs(levelData.icePositions) do
            self.iceSet[pos[1] * 100 + pos[2]] = true
        end
    end

    -- 棋盘 grid[row][col] = { colorId, special }
    self.grid = {}

    -- 计分 & 目标进度
    self.score = 0
    self.combo = 0
    self.goalProgress = {}  -- 按目标类型填充
    self.stepScore = 0      -- 当前步的得分（用于显示）

    -- 状态机
    self.stateMachine = State.new()

    -- 交换动画用
    self.swapFrom = nil     -- { row, col }
    self.swapTo = nil       -- { row, col }

    -- 消除事件列表（供渲染层读取）
    self.eliminatedCells = {}   -- { { row, col, colorId, special } }
    self.fallingCells = {}      -- { { col, fromRow, toRow, colorId, special, isNew } }
    self.specialCreated = {}    -- { { row, col, special, colorId } }
    self.comboText = nil        -- combo 提示
    self.iceDamagedCells = {}   -- { { row, col, hp, destroyed } } 冰块受损事件

    -- 结果
    self.cleared = false
    self.failed = false
    self.finalScore = 0
    self.starRating = 0
    self.goalReached = false  -- 目标已达成（但游戏未结束）

    -- 初始化目标进度
    self:_initGoalProgress()

    -- 生成初始棋盘
    self:_generateBoard()

    return self
end

--- 重置（重开关卡）
function M:reset()
    self.rng = RNG.new(self.seed)
    self.remainTime = self.timeLimit
    self.score = 0
    self.combo = 0
    self.stepScore = 0
    self.cleared = false
    self.failed = false
    self.finalScore = 0
    self.starRating = 0
    self.goalReached = false
    self.swapFrom = nil
    self.swapTo = nil
    self.eliminatedCells = {}
    self.fallingCells = {}
    self.specialCreated = {}
    self.comboText = nil
    self.iceDamagedCells = {}

    -- 重建冰块集合（重开时恢复所有冰块）
    self.iceSet = {}
    if self.levelData.icePositions then
        for _, pos in ipairs(self.levelData.icePositions) do
            self.iceSet[pos[1] * 100 + pos[2]] = true
        end
    end

    State.reset(self.stateMachine)
    self:_initGoalProgress()
    self:_generateBoard()
end

--- 每帧更新倒计时
---@param dt number 帧间隔（秒）
function M:update(dt)
    if self.cleared or self.failed then return end
    self.remainTime = math.max(0, self.remainTime - dt)
end

-- 目标进度

function M:_initGoalProgress()
    local g = self.goal
    if g.type == "score" then
        self.goalProgress = { score = 0 }
    elseif g.type == "collect_color" then
        self.goalProgress = {}
        for _, t in ipairs(g.targets) do
            self.goalProgress[t.colorId] = 0
        end
    elseif g.type == "trigger_special" then
        self.goalProgress = { count = 0 }
    end
end

--- 目标是否完成
function M:isGoalMet()
    local g = self.goal
    if g.type == "score" then
        return self.score >= g.targetScore
    elseif g.type == "collect_color" then
        for _, t in ipairs(g.targets) do
            local cur = self.goalProgress[t.colorId] or 0
            if cur < t.count then return false end
        end
        return true
    elseif g.type == "trigger_special" then
        return (self.goalProgress.count or 0) >= g.targetCount
    end
    return false
end

-- 棋盘生成

function M:_generateBoard()
    -- 生成无初始消除的棋盘
    for _ = 1, 100 do
        self:_fillBoardRandom()
        if not self:_hasAnyMatch() then
            if self:_hasValidMove() then
                return
            end
        end
    end
    -- 降级：直接使用最后一次生成（极罕见）
end

function M:_fillBoardRandom()
    self.grid = {}
    for r = 1, self.rows do
        self.grid[r] = {}
        for c = 1, self.cols do
            local posKey = r * 100 + c
            if self.stoneSet[posKey] then
                -- 石头位置：放置石头方块
                self.grid[r][c] = { colorId = 0, special = M.SPECIAL_STONE }
            elseif self.iceSet[posKey] then
                -- 冰块位置：放置冰块（3 生命值）
                self.grid[r][c] = { colorId = 0, special = M.SPECIAL_ICE, hp = 3 }
            else
                -- 避免生成时产生 3 连
                local color
                for _ = 1, 20 do
                    color = randomColor(self.rng, self.weightedPool)
                    if not self:_wouldMatchAt(r, c, color) then
                        break
                    end
                end
                self.grid[r][c] = { colorId = color, special = M.SPECIAL_NONE }
            end
        end
    end
end

--- 检查在 (r,c) 放置 colorId 是否会形成 3 连
function M:_wouldMatchAt(r, c, colorId)
    -- 检查水平左侧
    if c >= 3 then
        local g = self.grid[r]
        if g[c - 1] and g[c - 2]
            and g[c - 1].colorId == colorId
            and g[c - 2].colorId == colorId then
            return true
        end
    end
    -- 检查垂直上方
    if r >= 3 then
        if self.grid[r - 1] and self.grid[r - 2]
            and self.grid[r - 1][c] and self.grid[r - 2][c]
            and self.grid[r - 1][c].colorId == colorId
            and self.grid[r - 2][c].colorId == colorId then
            return true
        end
    end
    return false
end

-- 消除判定

--- 检测棋盘上所有匹配（返回匹配列表）
---@return table[] matches 每个 match = { cells = {{r,c},...}, dir = "h"|"v", len = n }
function M:_findAllMatches()
    local matches = {}
    local visited_h = {}
    local visited_v = {}

    local function key(r, c) return r * 100 + c end

    -- 水平扫描
    for r = 1, self.rows do
        local c = 1
        while c <= self.cols do
            local tile = self.grid[r][c]
            if tile and tile.colorId > 0 then
                local color = tile.colorId
                local endC = c
                while endC + 1 <= self.cols do
                    local next = self.grid[r][endC + 1]
                    if next and next.colorId == color then
                        endC = endC + 1
                    else
                        break
                    end
                end
                local len = endC - c + 1
                if len >= 3 then
                    local cells = {}
                    for cc = c, endC do
                        cells[#cells + 1] = { r, cc }
                        visited_h[key(r, cc)] = true
                    end
                    matches[#matches + 1] = { cells = cells, dir = "h", len = len }
                end
                c = endC + 1
            else
                c = c + 1
            end
        end
    end

    -- 垂直扫描
    for c = 1, self.cols do
        local r = 1
        while r <= self.rows do
            local tile = self.grid[r][c]
            if tile and tile.colorId > 0 then
                local color = tile.colorId
                local endR = r
                while endR + 1 <= self.rows do
                    local next = self.grid[endR + 1][c]
                    if next and next.colorId == color then
                        endR = endR + 1
                    else
                        break
                    end
                end
                local len = endR - r + 1
                if len >= 3 then
                    local cells = {}
                    for rr = r, endR do
                        cells[#cells + 1] = { rr, c }
                        visited_v[key(rr, c)] = true
                    end
                    matches[#matches + 1] = { cells = cells, dir = "v", len = len }
                end
                r = endR + 1
            else
                r = r + 1
            end
        end
    end

    return matches
end

--- 棋盘上是否存在匹配
function M:_hasAnyMatch()
    local matches = self:_findAllMatches()
    return #matches > 0
end

-- 特殊方块生成判定

--- 分析匹配组，决定生成什么特殊方块
---@param matches table[] 匹配列表
---@param swapTarget table|nil { row, col } 玩家交换终点
---@return table[] specials { { row, col, special, colorId } }
function M:_determineSpecials(matches, swapTarget)
    if #matches == 0 then return {} end

    local specials = {}

    -- 收集所有被消除的格子集合
    local function key(r, c) return r * 100 + c end
    local allCells = {}  -- key -> true
    for _, m in ipairs(matches) do
        for _, cell in ipairs(m.cells) do
            allCells[key(cell[1], cell[2])] = true
        end
    end

    -- 检查是否有交叉（T/L 形）：同一个格子同时在水平和垂直匹配中
    local hCells = {}  -- key -> match 的 cells 列表
    local vCells = {}
    for _, m in ipairs(matches) do
        for _, cell in ipairs(m.cells) do
            local k = key(cell[1], cell[2])
            if m.dir == "h" then
                if not hCells[k] then hCells[k] = {} end
                hCells[k][#hCells[k] + 1] = m
            else
                if not vCells[k] then vCells[k] = {} end
                vCells[k][#vCells[k] + 1] = m
            end
        end
    end

    -- 5 连直线 -> 彩虹
    for _, m in ipairs(matches) do
        if m.len >= 5 then
            -- 检查是否纯直线（不是交叉的一部分构成 5+）
            local spawnR, spawnC
            if swapTarget then
                -- 优先在交换终点生成
                for _, cell in ipairs(m.cells) do
                    if cell[1] == swapTarget.row and cell[2] == swapTarget.col then
                        spawnR, spawnC = cell[1], cell[2]
                        break
                    end
                end
            end
            if not spawnR then
                -- 取中间位置
                local mid = math.ceil(#m.cells / 2)
                spawnR, spawnC = m.cells[mid][1], m.cells[mid][2]
            end
            specials[#specials + 1] = {
                row = spawnR, col = spawnC,
                special = M.SPECIAL_RAINBOW,
                colorId = self.grid[spawnR][spawnC].colorId,
            }
            m._handled = true
        end
    end

    -- T/L 形（交叉点，两条匹配共享至少一个格子）-> 爆炸
    for k, hList in pairs(hCells) do
        if vCells[k] then
            local r = math.floor(k / 100)
            local c = k % 100
            -- 检查相关的 match 未被 5 连处理
            local anyHandled = false
            for _, m in ipairs(hList) do if m._handled then anyHandled = true end end
            if not anyHandled then
                for _, m in ipairs(vCells[k]) do if m._handled then anyHandled = true end end
            end
            if not anyHandled then
                specials[#specials + 1] = {
                    row = r, col = c,
                    special = M.SPECIAL_BOMB,
                    colorId = self.grid[r][c].colorId,
                }
                -- 标记这些 match 已处理
                for _, m in ipairs(hList) do m._handled = true end
                for _, m in ipairs(vCells[k]) do m._handled = true end
            end
        end
    end

    -- 4 连 -> 直线消除（方向与匹配垂直）
    for _, m in ipairs(matches) do
        if not m._handled and m.len == 4 then
            local spawnR, spawnC
            if swapTarget then
                for _, cell in ipairs(m.cells) do
                    if cell[1] == swapTarget.row and cell[2] == swapTarget.col then
                        spawnR, spawnC = cell[1], cell[2]
                        break
                    end
                end
            end
            if not spawnR then
                spawnR, spawnC = m.cells[2][1], m.cells[2][2]
            end
            local sType = m.dir == "h" and M.SPECIAL_LINE_V or M.SPECIAL_LINE_H
            specials[#specials + 1] = {
                row = spawnR, col = spawnC,
                special = sType,
                colorId = self.grid[spawnR][spawnC].colorId,
            }
            m._handled = true
        end
    end

    return specials
end

-- 消除执行

--- 执行一轮消除，返回被消除的格子和生成的特殊方块
---@param swapTarget table|nil
---@return table result { eliminated, specials, score }
function M:_executeElimination(swapTarget)
    local matches = self:_findAllMatches()

    -- 收集所有要消除的格子
    local function key(r, c) return r * 100 + c end
    local toEliminate = {}  -- key -> { row, col, colorId, special }
    local elimOrder = {}

    -- 彩虹方块特殊处理：即使没有普通匹配，彩虹方块本身也要加入消除队列
    -- 以触发其全色消除效果
    if swapTarget and self.swapFrom then
        local positions = { self.swapFrom, self.swapTo }
        for _, pos in ipairs(positions) do
            if pos then
                local tile = self.grid[pos.row][pos.col]
                if tile and tile.special == M.SPECIAL_RAINBOW then
                    local k = key(pos.row, pos.col)
                    if not toEliminate[k] then
                        toEliminate[k] = {
                            row = pos.row, col = pos.col,
                            colorId = tile.colorId,
                            special = tile.special,
                        }
                        elimOrder[#elimOrder + 1] = toEliminate[k]
                    end
                end
            end
        end
    end

    if #matches == 0 and #elimOrder == 0 then
        return { eliminated = {}, specials = {}, score = 0 }
    end

    self.combo = self.combo + 1
    -- 狐狸夸奖触发
    local FoxMascot = require("shared.components.fox-mascot")
    FoxMascot.notifySuccess()

    -- 决定特殊方块
    local specials = self:_determineSpecials(matches, swapTarget)

    for _, m in ipairs(matches) do
        for _, cell in ipairs(m.cells) do
            local r, c = cell[1], cell[2]
            local k = key(r, c)
            if not toEliminate[k] then
                local tile = self.grid[r][c]
                toEliminate[k] = {
                    row = r, col = c,
                    colorId = tile.colorId,
                    special = tile.special,
                }
                elimOrder[#elimOrder + 1] = toEliminate[k]
            end
        end
    end

    -- 触发已有特殊方块的效果（含连锁：被波及的特殊方块也会触发）
    local triggeredKeys = {}  -- 已触发过特效的特殊方块 key，避免无限循环
    local processIdx = 1
    while processIdx <= #elimOrder do
        local info = elimOrder[processIdx]
        processIdx = processIdx + 1

        if info.special ~= M.SPECIAL_NONE and not triggeredKeys[key(info.row, info.col)] then
            triggeredKeys[key(info.row, info.col)] = true
            local extra = self:_triggerSpecialEffect(info.row, info.col, info.special, info.colorId, toEliminate)
            for _, e in ipairs(extra) do
                local k = key(e.row, e.col)
                if not toEliminate[k] then
                    toEliminate[k] = e
                    elimOrder[#elimOrder + 1] = e  -- 新加入的格子会在后续循环中被检查
                end
            end
        end
    end

    -- 计分
    local baseScore = #elimOrder * self.scoreRule.basePerTile
    local comboMul = math.min(
        1 + self.scoreRule.comboBonusRate * (self.combo - 1),
        self.scoreRule.comboCap
    )
    local roundScore = math.floor(baseScore * comboMul)

    -- 特殊方块触发加分
    for _, info in ipairs(elimOrder) do
        if info.special == M.SPECIAL_LINE_H or info.special == M.SPECIAL_LINE_V then
            roundScore = roundScore + 80
        elseif info.special == M.SPECIAL_BOMB then
            roundScore = roundScore + 120
        elseif info.special == M.SPECIAL_RAINBOW then
            roundScore = roundScore + 200
        end
    end

    self.score = self.score + roundScore
    self.stepScore = self.stepScore + roundScore

    -- 更新目标进度
    self:_updateGoalProgress(elimOrder)

    -- 更新特殊方块触发计数
    for _, info in ipairs(elimOrder) do
        if info.special ~= M.SPECIAL_NONE then
            self:_trackSpecialTrigger(info.special)
        end
    end

    -- 放置特殊方块（不被消除的位置）
    local specialPositions = {}
    for _, sp in ipairs(specials) do
        specialPositions[key(sp.row, sp.col)] = sp
    end

    -- 清除被消除的格子
    for _, info in ipairs(elimOrder) do
        local k = key(info.row, info.col)
        if not specialPositions[k] then
            self.grid[info.row][info.col] = nil
        end
    end

    -- 放置特殊方块
    for _, sp in ipairs(specials) do
        self.grid[sp.row][sp.col] = {
            colorId = sp.colorId,
            special = sp.special,
        }
        -- 从消除列表中移除该位置（它变成了特殊方块，不消失）
        local k = key(sp.row, sp.col)
        toEliminate[k] = nil
    end

    -- 重建消除列表（去除特殊方块位置）
    local finalElim = {}
    for _, info in ipairs(elimOrder) do
        local k = key(info.row, info.col)
        if not specialPositions[k] then
            finalElim[#finalElim + 1] = info
        end
    end

    -- ====== 冰块邻接伤害 ======
    -- 被消除的格子四周如果有冰块，冰块 HP-1；HP 归零则消失
    local iceDamage = {}  -- key -> 累计伤害次数
    local dirs = { {-1, 0}, {1, 0}, {0, -1}, {0, 1} }
    for _, info in ipairs(elimOrder) do
        for _, d in ipairs(dirs) do
            local nr, nc = info.row + d[1], info.col + d[2]
            if nr >= 1 and nr <= self.rows and nc >= 1 and nc <= self.cols then
                if self:_isIce(nr, nc) then
                    local ik = key(nr, nc)
                    iceDamage[ik] = (iceDamage[ik] or 0) + 1
                end
            end
        end
    end

    self.iceDamagedCells = {}
    for ik, dmg in pairs(iceDamage) do
        local ir = math.floor(ik / 100)
        local ic = ik % 100
        local tile = self.grid[ir][ic]
        if tile and tile.special == M.SPECIAL_ICE then
            tile.hp = math.max(0, (tile.hp or 3) - dmg)
            if tile.hp <= 0 then
                -- 冰块破碎消失
                self.grid[ir][ic] = nil
                self.iceSet[ik] = nil
                self.iceDamagedCells[#self.iceDamagedCells + 1] = {
                    row = ir, col = ic, hp = 0, destroyed = true,
                }
            else
                -- 冰块受损但存活
                self.iceDamagedCells[#self.iceDamagedCells + 1] = {
                    row = ir, col = ic, hp = tile.hp, destroyed = false,
                }
            end
        end
    end

    -- combo 文本
    if self.combo >= 2 then
        self.comboText = { combo = self.combo, score = roundScore }
    end

    return {
        eliminated = finalElim,
        specials = specials,
        score = roundScore,
    }
end

--- 特殊方块命中某格时处理障碍物（石头摧毁、冰块秒杀）
--- 返回 true 表示该格已被处理（不需要再加入普通消除列表）
---@param nr number 行
---@param nc number 列
---@param extra table 消除列表
---@return boolean handled
function M:_specialHitCell(nr, nc, extra)
    local tile = self.grid[nr][nc]
    if not tile then return true end

    if tile.special == M.SPECIAL_STONE then
        -- 石头：直接摧毁
        local ik = nr * 100 + nc
        self.grid[nr][nc] = nil
        self.stoneSet[ik] = nil
        extra[#extra + 1] = {
            row = nr, col = nc, colorId = 0, special = M.SPECIAL_STONE,
        }
        return true
    elseif tile.special == M.SPECIAL_ICE then
        -- 冰块：秒杀（HP 直接归零）
        local ik = nr * 100 + nc
        tile.hp = 0
        self.grid[nr][nc] = nil
        self.iceSet[ik] = nil
        -- 记录冰块秒杀到 iceDamagedCells（供渲染层播放碎裂动画）
        self.iceDamagedCells = self.iceDamagedCells or {}
        self.iceDamagedCells[#self.iceDamagedCells + 1] = {
            row = nr, col = nc, hp = 0, destroyed = true,
        }
        return true
    end
    return false
end

--- 触发特殊方块效果
function M:_triggerSpecialEffect(r, c, special, colorId, alreadyElim)
    local extra = {}
    local function key(r2, c2) return r2 * 100 + c2 end

    if special == M.SPECIAL_LINE_H then
        -- 消除整行（可摧毁石头、秒杀冰块）
        for cc = 1, self.cols do
            local k = key(r, cc)
            if not alreadyElim[k] and self.grid[r][cc] then
                if not self:_specialHitCell(r, cc, extra) then
                    extra[#extra + 1] = {
                        row = r, col = cc,
                        colorId = self.grid[r][cc].colorId,
                        special = self.grid[r][cc].special,
                    }
                end
            end
        end
    elseif special == M.SPECIAL_LINE_V then
        -- 消除整列（可摧毁石头、秒杀冰块）
        for rr = 1, self.rows do
            local k = key(rr, c)
            if not alreadyElim[k] and self.grid[rr][c] then
                if not self:_specialHitCell(rr, c, extra) then
                    extra[#extra + 1] = {
                        row = rr, col = c,
                        colorId = self.grid[rr][c].colorId,
                        special = self.grid[rr][c].special,
                    }
                end
            end
        end
    elseif special == M.SPECIAL_BOMB then
        -- 消除 3x3（可摧毁石头、秒杀冰块）
        for dr = -1, 1 do
            for dc = -1, 1 do
                local nr, nc = r + dr, c + dc
                if nr >= 1 and nr <= self.rows and nc >= 1 and nc <= self.cols then
                    local k = key(nr, nc)
                    if not alreadyElim[k] and self.grid[nr][nc] then
                        if not self:_specialHitCell(nr, nc, extra) then
                            extra[#extra + 1] = {
                                row = nr, col = nc,
                                colorId = self.grid[nr][nc].colorId,
                                special = self.grid[nr][nc].special,
                            }
                        end
                    end
                end
            end
        end
    elseif special == M.SPECIAL_RAINBOW then
        -- 消除所有同色方块（以交换对象的颜色为准，跳过障碍物）
        local targetColor = colorId
        if targetColor > 0 then
            for rr = 1, self.rows do
                for cc = 1, self.cols do
                    local k = key(rr, cc)
                    if not alreadyElim[k] and self.grid[rr][cc]
                        and not self:_isObstacle(rr, cc)
                        and self.grid[rr][cc].colorId == targetColor then
                        extra[#extra + 1] = {
                            row = rr, col = cc,
                            colorId = self.grid[rr][cc].colorId,
                            special = self.grid[rr][cc].special,
                        }
                    end
                end
            end
        end
    end

    return extra
end

--- 更新目标进度
function M:_updateGoalProgress(eliminated)
    local g = self.goal
    if g.type == "score" then
        self.goalProgress.score = self.score
    elseif g.type == "collect_color" then
        for _, info in ipairs(eliminated) do
            for _, t in ipairs(g.targets) do
                if t.colorId == 0 or t.colorId == info.colorId then
                    self.goalProgress[t.colorId] = (self.goalProgress[t.colorId] or 0) + 1
                end
            end
        end
    end
end

--- 追踪特殊方块触发（目标类型 trigger_special）
function M:_trackSpecialTrigger(special)
    local g = self.goal
    if g.type ~= "trigger_special" then return end

    local match = false
    if g.specialType == "line" and (special == M.SPECIAL_LINE_H or special == M.SPECIAL_LINE_V) then
        match = true
    elseif g.specialType == "bomb" and special == M.SPECIAL_BOMB then
        match = true
    elseif g.specialType == "rainbow" and special == M.SPECIAL_RAINBOW then
        match = true
    end

    if match then
        self.goalProgress.count = (self.goalProgress.count or 0) + 1
    end
end

-- 掉落与补齐

--- 执行一次掉落，返回掉落信息
--- 石头不参与掉落，其他方块跳过石头位置下落
---@return table[] fallingCells
function M:_executeFalling()
    local falling = {}

    for c = 1, self.cols do
        -- 收集该列的非障碍物位置（从下到上）和现存的非障碍物方块
        local nonObstaclePos = {}   -- 非障碍物位置，从下到上
        local existTiles = {}       -- 现存非障碍物方块，从下到上

        for r = self.rows, 1, -1 do
            if self:_isObstacle(r, c) then
                -- 障碍物（石头/冰块）位置跳过，保持不动
            else
                nonObstaclePos[#nonObstaclePos + 1] = r
                if self.grid[r][c] then
                    existTiles[#existTiles + 1] = { tile = self.grid[r][c], fromRow = r }
                end
            end
        end

        -- 清空所有非障碍物格子
        for _, r in ipairs(nonObstaclePos) do
            self.grid[r][c] = nil
        end

        -- 将现存方块放入最低的非障碍物位置
        for i, info in ipairs(existTiles) do
            local targetRow = nonObstaclePos[i]
            self.grid[targetRow][c] = info.tile
            if info.fromRow ~= targetRow then
                falling[#falling + 1] = {
                    col = c, fromRow = info.fromRow, toRow = targetRow,
                    colorId = info.tile.colorId,
                    special = info.tile.special,
                    isNew = false,
                }
            end
        end

        -- 剩余非障碍物空位用新方块补齐
        for i = #existTiles + 1, #nonObstaclePos do
            local targetRow = nonObstaclePos[i]
            local color = randomColor(self.rng, self.weightedPool)
            self.grid[targetRow][c] = { colorId = color, special = M.SPECIAL_NONE }
            falling[#falling + 1] = {
                col = c, fromRow = targetRow - (i - #existTiles), toRow = targetRow,
                colorId = color,
                special = M.SPECIAL_NONE,
                isNew = true,
            }
        end
    end

    return falling
end

-- 死盘检测 & 洗牌

--- 检查是否存在有效交换
function M:_hasValidMove()
    for r = 1, self.rows do
        for c = 1, self.cols do
            -- 跳过障碍物格子（石头、冰块）
            if self:_isObstacle(r, c) then goto continue end
            -- 右交换（跳过障碍物目标）
            if c < self.cols and not self:_isObstacle(r, c + 1) then
                self:_swapTiles(r, c, r, c + 1)
                if self:_hasAnyMatch() then
                    self:_swapTiles(r, c, r, c + 1)
                    return true
                end
                self:_swapTiles(r, c, r, c + 1)
            end
            -- 下交换（跳过障碍物目标）
            if r < self.rows and not self:_isObstacle(r + 1, c) then
                self:_swapTiles(r, c, r + 1, c)
                if self:_hasAnyMatch() then
                    self:_swapTiles(r, c, r + 1, c)
                    return true
                end
                self:_swapTiles(r, c, r + 1, c)
            end
            ::continue::
        end
    end
    return false
end

--- 交换两个格子
function M:_swapTiles(r1, c1, r2, c2)
    self.grid[r1][c1], self.grid[r2][c2] = self.grid[r2][c2], self.grid[r1][c1]
end

--- 洗牌（保留现有方块，重新排列；障碍物不参与洗牌）
---@return boolean success
function M:_shuffle()
    -- 收集所有非障碍物方块和它们的位置
    local tiles = {}
    local positions = {}
    for r = 1, self.rows do
        for c = 1, self.cols do
            if self.grid[r][c] and not self:_isObstacle(r, c) then
                tiles[#tiles + 1] = self.grid[r][c]
                positions[#positions + 1] = { r, c }
            end
        end
    end

    -- 尝试最多 100 次重排
    for _ = 1, 100 do
        self.rng:shuffle(tiles)

        -- 重新放置到非障碍物位置
        for i, pos in ipairs(positions) do
            self.grid[pos[1]][pos[2]] = tiles[i]
        end

        -- 验证：无初始消除 + 至少 1 个可行步
        if not self:_hasAnyMatch() and self:_hasValidMove() then
            return true
        end
    end

    return false -- M3-005
end

-- 玩家交换操作（公开接口）

--- 尝试交换两个相邻格子
---@param r1 number
---@param c1 number
---@param r2 number
---@param c2 number
---@return string result "valid" | "invalid" | "rejected"
function M:trySwap(r1, c1, r2, c2)
    if not State.canSwap(self.stateMachine) then
        return "rejected"
    end

    -- 检查相邻
    local dr = math.abs(r1 - r2)
    local dc = math.abs(c1 - c2)
    if dr + dc ~= 1 then
        return "rejected"
    end

    -- 检查边界
    if r1 < 1 or r1 > self.rows or c1 < 1 or c1 > self.cols then return "rejected" end
    if r2 < 1 or r2 > self.rows or c2 < 1 or c2 > self.cols then return "rejected" end

    -- 检查方块是否存在
    local tile1 = self.grid[r1][c1]
    local tile2 = self.grid[r2][c2]
    if not tile1 or not tile2 then return "rejected" end

    -- 障碍物（石头、冰块）不可交换
    if self:_isObstacle(r1, c1) or self:_isObstacle(r2, c2) then
        return "rejected"
    end

    -- 彩虹方块特殊处理：与任何颜色交换都有效
    local isRainbowSwap = (tile1.special == M.SPECIAL_RAINBOW or tile2.special == M.SPECIAL_RAINBOW)

    State.toSwapping(self.stateMachine)
    self.swapFrom = { row = r1, col = c1 }
    self.swapTo = { row = r2, col = c2 }

    -- 模拟交换
    self:_swapTiles(r1, c1, r2, c2)

    if isRainbowSwap or self:_hasAnyMatch() then
        -- 有效交换
        self.combo = 0
        self.stepScore = 0
        self.comboText = nil

        -- 处理彩虹方块交换的特殊逻辑
        if isRainbowSwap then
            self:_handleRainbowSwap(r1, c1, r2, c2, tile1, tile2)
        end

        return "valid"
    else
        -- 无效交换，回退
        self:_swapTiles(r1, c1, r2, c2)
        return "invalid"
    end
end

--- 处理彩虹方块交换
function M:_handleRainbowSwap(r1, c1, r2, c2, origTile1, origTile2)
    -- 彩虹方块交换后，需要给彩虹方块设置目标颜色
    local rainbowR, rainbowC, targetColor
    if origTile1.special == M.SPECIAL_RAINBOW then
        rainbowR, rainbowC = r2, c2  -- 彩虹方块被交换到了 (r2,c2)
        targetColor = origTile2.colorId
        -- 把彩虹方块的 colorId 设为目标色以便消除逻辑使用
        self.grid[r2][c2].colorId = targetColor
    end
    if origTile2.special == M.SPECIAL_RAINBOW then
        rainbowR, rainbowC = r1, c1
        targetColor = origTile1.colorId
        self.grid[r1][c1].colorId = targetColor
    end
end

--- 确认交换有效后开始消除（由动画系统在交换动画完成后调用）
---@return table result { eliminated, specials, score }
function M:confirmSwapAndEliminate()
    local target = self.swapTo
    local result = self:_executeElimination(target)
    self.eliminatedCells = result.eliminated
    self.specialCreated = result.specials
    State.toEliminating(self.stateMachine)
    return result
end

--- 交换回退完成后回到 Idle
function M:confirmSwapBack()
    State.swapBackToIdle(self.stateMachine)
    self.swapFrom = nil
    self.swapTo = nil
end

--- 消除动画完成后执行掉落
function M:confirmEliminateAndFall()
    local falling = self:_executeFalling()
    self.fallingCells = falling
    self.eliminatedCells = {}
    State.toFalling(self.stateMachine)
    return falling
end

--- 掉落动画完成后检查连锁
---@return string result "chain" | "settled"
function M:confirmFallAndCheck()
    self.fallingCells = {}
    State.toChainCheck(self.stateMachine)

    if self:_hasAnyMatch() then
        -- 有新消除（连锁）
        local result = self:_executeElimination(nil)
        self.eliminatedCells = result.eliminated
        self.specialCreated = result.specials
        State.toEliminating(self.stateMachine)
        return "chain"
    else
        -- 无新消除，结算
        State.toSettled(self.stateMachine)
        return "settled"
    end
end

--- 结算后检查胜负条件
---@return string result "continue" | "cleared" | "failed"
function M:settleStep()
    -- 检查死盘
    if not self:_hasValidMove() then
        local ok = self:_shuffle()
        if not ok then
            -- 极端情况：洗牌失败
        end
    end

    if self.remainTime <= 0 then
        -- 时间到：根据是否达标判定通关/失败
        self.finalScore = self.score
        if self:isGoalMet() then
            self.cleared = true
            self.starRating = self:_calcStarRating(self.finalScore)
            State.fromSettled(self.stateMachine, State.CLEARED)
            return "cleared"
        else
            self.failed = true
            self.starRating = 0
            State.fromSettled(self.stateMachine, State.FAILED)
            return "failed"
        end
    else
        -- 时间未到，检查目标是否已达成
        if not self.goalReached and self:isGoalMet() then
            self.goalReached = true
        end
        -- 继续
        State.fromSettled(self.stateMachine, State.IDLE)
        self.swapFrom = nil
        self.swapTo = nil
        return self.goalReached and "goal_reached" or "continue"
    end
end

--- 计算星级
function M:_calcStarRating(finalScore)
    if finalScore >= self.starScore.three then return 3 end
    if finalScore >= self.starScore.two then return 2 end
    return 1
end

--- 提前结束关卡（目标已达成时调用，仅 IDLE 状态可用）
---@return boolean success
function M:finishLevel()
    if self.cleared or self.failed then return false end
    if self.stateMachine.current ~= State.IDLE then return false end
    if not self:isGoalMet() then return false end
    self.finalScore = self.score
    self.cleared = true
    self.starRating = self:_calcStarRating(self.finalScore)
    self.stateMachine.current = State.CLEARED
    return true
end

--- 获取当前星级进度（达标后用于 HUD 显示）
---@return table|nil { stars=number, needed=number } 未达标返回 nil
function M:getStarProgress()
    if not self:isGoalMet() then return nil end
    if self.score >= self.starScore.three then
        return { stars = 3, needed = 0 }
    elseif self.score >= self.starScore.two then
        return { stars = 2, needed = self.starScore.three - self.score }
    else
        return { stars = 1, needed = self.starScore.two - self.score }
    end
end

-- 查询接口

--- 获取格子
---@param r number
---@param c number
---@return table|nil tile { colorId, special }
function M:getTile(r, c)
    if r < 1 or r > self.rows or c < 1 or c > self.cols then return nil end
    return self.grid[r][c]
end

--- 获取目标描述文本
---@return string
function M:getGoalText()
    local g = self.goal
    if g.type == "score" then
        return "得分 " .. g.targetScore
    elseif g.type == "collect_color" then
        local parts = {}
        for _, t in ipairs(g.targets) do
            local cur = self.goalProgress[t.colorId] or 0
            if t.colorId == 0 then
                parts[#parts + 1] = "任意 " .. cur .. "/" .. t.count
            else
                parts[#parts + 1] = "C" .. t.colorId .. " " .. cur .. "/" .. t.count
            end
        end
        return table.concat(parts, "  ")
    elseif g.type == "trigger_special" then
        local cur = self.goalProgress.count or 0
        local name = g.specialType == "line" and "直线"
            or g.specialType == "bomb" and "爆炸"
            or g.specialType == "rainbow" and "彩虹"
            or g.specialType
        return name .. " " .. cur .. "/" .. g.targetCount
    end
    return ""
end

--- 获取目标进度比例 0-1
---@return number
function M:getGoalRatio()
    local g = self.goal
    if g.type == "score" then
        return math.min(1, self.score / g.targetScore)
    elseif g.type == "collect_color" then
        local total, done = 0, 0
        for _, t in ipairs(g.targets) do
            total = total + t.count
            done = done + math.min(t.count, self.goalProgress[t.colorId] or 0)
        end
        return total > 0 and (done / total) or 0
    elseif g.type == "trigger_special" then
        return math.min(1, (self.goalProgress.count or 0) / g.targetCount)
    end
    return 0
end

return M
