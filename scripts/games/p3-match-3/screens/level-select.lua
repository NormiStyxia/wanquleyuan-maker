--- 消消乐 - 关卡选择界面
--- 职责：NanoVG 绘制关卡网格、处理点击选关
local save = require("games.p3-match-3.save")
local LSU = require("shared.components.level-select-ui")
local bgManager = require("shared.background-manager")

local M = {}

local COLS = 3
local CELL_SIZE = 76
local CELL_GAP = 16
local ROWS_PER_PAGE = 5
local ITEMS_PER_PAGE = ROWS_PER_PAGE * COLS

--- 当前页码（1-based）
local currentPage_ = 1
--- 总页数（由 draw 计算并缓存）
local totalPages_ = 1

-- 章节配色
local CHAPTER_COLORS = {
    newbie    = { 60, 180, 110 },
    advanced  = { 60, 120, 200 },
    challenge = { 220, 150, 40 },
    expert    = { 210, 100, 80 },
    master    = { 160, 80, 180 },
}

-- 消消乐主题色（暖色调）
local THEME_COLOR    = { 235, 140, 60 }
local BAR_COLOR_FROM = { 240, 150, 70 }
local BAR_COLOR_TO   = { 210, 110, 50 }
local FILL_FROM      = { 245, 170, 60 }
local FILL_TO        = { 240, 200, 80 }

-- ============================================================================
-- 绘制
-- ============================================================================

---@param vg userdata
---@param screenW number
---@param screenH number
---@param levels table[] 关卡列表
---@param saveData table
---@return table hitAreas { backBtn, levelBtns[] }
function M.draw(vg, screenW, screenH, levels, saveData, afterBg)
    -- 公共背景
    LSU.drawBackground(vg, screenW, screenH, THEME_COLOR, bgManager.getCurrent())

    if afterBg then afterBg() end

    -- 公共顶栏
    LSU.drawTopBar(vg, screenW, BAR_COLOR_FROM, BAR_COLOR_TO)

    -- 公共返回按钮
    local backBtn = LSU.drawBackButton(vg)

    -- 标题
    LSU.drawTopBarTitle(vg, screenW, "消消乐 · 选择关卡")

    -- 进度统计
    local completed = save.countCompleted(saveData)
    local total = #levels
    local progressY = LSU.TOP_BAR_H + 16

    -- 公共进度条
    LSU.drawProgress(vg, screenW, progressY, completed, total, FILL_FROM, FILL_TO)

    -- 分页计算
    totalPages_ = math.max(1, math.ceil(#levels / ITEMS_PER_PAGE))
    if currentPage_ > totalPages_ then currentPage_ = totalPages_ end
    local pageStartIdx = (currentPage_ - 1) * ITEMS_PER_PAGE + 1
    local pageEndIdx = math.min(pageStartIdx + ITEMS_PER_PAGE - 1, #levels)

    -- 关卡网格
    local totalGridW = COLS * CELL_SIZE + (COLS - 1) * CELL_GAP
    local startX = (screenW - totalGridW) / 2
    local startY = progressY + 36

    local levelBtns = {}

    for i = pageStartIdx, pageEndIdx do
        local lv = levels[i]
        local pageLocal = i - pageStartIdx
        local row = math.floor(pageLocal / COLS)
        local col = pageLocal % COLS
        local cx = startX + col * (CELL_SIZE + CELL_GAP)
        local cy = startY + row * (CELL_SIZE + CELL_GAP)

        local unlocked = save.isUnlocked(saveData, lv.levelId, levels)
        local best = save.getLevelBest(saveData, lv.levelId)
        local chapterColor = CHAPTER_COLORS[lv.chapter] or { 120, 120, 120 }

        if unlocked then
            LSU.drawUnlockedCell(vg,cx,cy,CELL_SIZE,best ~= nil)

            -- 左侧章节色条
            nvgBeginPath(vg)
            nvgRoundedRect(vg, cx, cy + 6, 4, CELL_SIZE - 12, 2)
            nvgFillColor(vg, nvgRGBA(chapterColor[1], chapterColor[2], chapterColor[3],
                best and 200 or 100))
            nvgFill(vg)

            -- 关卡编号
            nvgFontFace(vg, "sans")
            nvgFontSize(vg, 24)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(70, 65, 55, 255))
            nvgText(vg, cx + CELL_SIZE / 2, cy + CELL_SIZE / 2 - 12, tostring(i), nil)

            -- 目标类型标签
            local goalLabel = ""
            if lv.goal.type == "score" then
                goalLabel = lv.goal.targetScore .. "分"
            elseif lv.goal.type == "collect_color" then
                goalLabel = "收集"
            elseif lv.goal.type == "trigger_special" then
                goalLabel = "特殊"
            end
            nvgFontSize(vg, 11)
            nvgFillColor(vg, nvgRGBA(150, 140, 125, 180))
            nvgText(vg, cx + CELL_SIZE / 2, cy + CELL_SIZE / 2 + 4, goalLabel, nil)

            -- 星级显示（矢量星星）
            if best then
                local starCount = best.bestStar or 0
                LSU.drawStarRow(vg, cx + CELL_SIZE / 2, cy + CELL_SIZE / 2 + 22, starCount, 3, 12)
            end
        else
            -- 公共锁定格子
            LSU.drawLockedCell(vg, cx, cy, CELL_SIZE, 14, THEME_COLOR)
        end

        levelBtns[i] = {
            x = cx, y = cy, w = CELL_SIZE, h = CELL_SIZE,
            levelIndex = i,
            unlocked = unlocked,
        }
    end

    -- 公共分页指示器（位置固定，不随单页行数变化）
    local indicatorY = LSU.getPageIndicatorY(screenH, startY, ROWS_PER_PAGE, CELL_SIZE, CELL_GAP)
    local prevBtn, nextBtn = LSU.drawPageIndicator(vg, screenW, indicatorY, currentPage_, totalPages_, THEME_COLOR)

    -- 公共底部装饰
    local footerY = indicatorY + 36
    LSU.drawGarden(vg, screenW, screenH, footerY)

    return {
        backBtn = backBtn,
        levelBtns = levelBtns,
        prevBtn = prevBtn,
        nextBtn = nextBtn,
    }
end

--- 检测点击命中
---@param mx number
---@param my number
---@param hitAreas table
---@return string|nil action "back" | "select_level" | "prev_page" | "next_page" | nil
---@return number|nil levelIndex
function M.hitTest(mx, my, hitAreas)
    return LSU.hitTest(mx, my, hitAreas)
end

-- ============================================================================
-- 分页控制
-- ============================================================================

function M.reset()
    currentPage_ = 1
end

---@param levelIndex number
function M.gotoPageForLevel(levelIndex)
    if levelIndex and levelIndex >= 1 then
        currentPage_ = math.ceil(levelIndex / ITEMS_PER_PAGE)
    end
end

function M.prevPage()
    if currentPage_ > 1 then
        currentPage_ = currentPage_ - 1
    end
end

function M.nextPage()
    if currentPage_ < totalPages_ then
        currentPage_ = currentPage_ + 1
    end
end

return M
