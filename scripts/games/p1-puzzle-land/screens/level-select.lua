--- 关卡选择界面
--- 职责：NanoVG 绘制关卡网格、处理点击选关
local boardRenderer = require("games.p1-puzzle-land.view.board-renderer")
local save = require("games.p1-puzzle-land.save")
local featureFlags = require("config.feature-flags")
local LSU = require("shared.components.level-select-ui")
local Paper = require("shared.components.game-paper")
local bgManager = require("shared.background-manager")

local M = {}

local COLORS = boardRenderer.COLORS

local COLS = 3
local CELL_SIZE = 76
local CELL_GAP = 16
local ROWS_PER_PAGE = 5
local ITEMS_PER_PAGE = ROWS_PER_PAGE * COLS

--- 当前页码（1-based）
local currentPage_ = 1
--- 总页数（由 draw 计算并缓存）
local totalPages_ = 1

-- 关卡格子的装饰色（未通关时的边框颜色）
local LEVEL_ACCENTS = {
    { 245, 175, 60 },   -- 琥珀
    { 230, 125, 70 },   -- 橙色
    { 200, 140, 90 },   -- 棕色
    { 220, 165, 55 },   -- 金色
    { 235, 150, 80 },   -- 暖橙
    { 210, 120, 60 },   -- 赤棕
}

-- 推箱子主题色
local THEME_COLOR    = { 140, 95, 55 }
local BAR_COLOR_FROM = { 140, 95, 55 }
local BAR_COLOR_TO   = { 110, 70, 40 }
local FILL_FROM      = { 245, 185, 60 }
local FILL_TO        = { 255, 155, 50 }

-- ============================================================================
-- 绘制
-- ============================================================================

--- 绘制关卡选择界面
---@param ctx userdata NanoVG 上下文
---@param screenW number
---@param screenH number
---@param levels table[] 关卡列表
---@param saveData table 存档数据
---@return table result { backBtn, levelBtns[] }
function M.draw(ctx, screenW, screenH, levels, saveData, afterBg)
    -- 公共背景
    LSU.drawBackground(ctx, screenW, screenH, THEME_COLOR, bgManager.getCurrent())

    if afterBg then afterBg() end

    -- 公共顶栏
    LSU.drawTopBar(ctx, screenW, BAR_COLOR_FROM, BAR_COLOR_TO)

    -- 公共返回按钮
    local backBtn = LSU.drawBackButton(ctx)

    -- 标题
    LSU.drawTopBarTitle(ctx, screenW, "推箱子 · 选择关卡")

    -- 进度统计
    local completed = save.countCompleted(saveData)
    local total = #levels
    local progressY = LSU.TOP_BAR_H + 16

    -- 公共进度条
    LSU.drawProgress(ctx, screenW, progressY, completed, total, FILL_FROM, FILL_TO)

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
        local pageLocal = i - pageStartIdx -- 0-based within page
        local row = math.floor(pageLocal / COLS)
        local col = pageLocal % COLS
        local cx = startX + col * (CELL_SIZE + CELL_GAP)
        local cy = startY + row * (CELL_SIZE + CELL_GAP)

        local unlocked = save.isUnlocked(saveData, lv.id, levels)
        local stars = save.getStars(saveData, lv.id)
        local accentIdx = ((i - 1) % #LEVEL_ACCENTS) + 1
        local accent = LEVEL_ACCENTS[accentIdx]

        if unlocked then
            LSU.drawUnlockedCell(ctx,cx,cy,CELL_SIZE,stars > 0)

            -- 左侧装饰竖条
            nvgBeginPath(ctx)
            nvgRoundedRect(ctx, cx, cy + 8, 4, CELL_SIZE - 16, 2)
            nvgFillColor(ctx, nvgRGBA(accent[1], accent[2], accent[3], stars > 0 and 180 or 80))
            nvgFill(ctx)

            -- 关卡编号
            nvgFontFace(ctx, "sans")
            nvgFontSize(ctx, 24)
            nvgTextAlign(ctx, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(ctx, nvgRGBA(100, 65, 30, 255))
            nvgText(ctx, cx + CELL_SIZE / 2, cy + CELL_SIZE / 2 - 10, tostring(i), nil)

            -- 星星评分（使用矢量星星）
            LSU.drawStarRow(ctx, cx + CELL_SIZE / 2, cy + CELL_SIZE / 2 + 18, stars, 3, 12)
        else
            -- 公共锁定格子
            LSU.drawLockedCell(ctx, cx, cy, CELL_SIZE, 14, THEME_COLOR)
        end

        levelBtns[i] = {
            x = cx, y = cy, w = CELL_SIZE, h = CELL_SIZE,
            levelIndex = i,
            unlocked = unlocked,
        }
    end

    -- 公共分页指示器（位置固定，不随单页行数变化）
    local indicatorY = LSU.getPageIndicatorY(screenH, startY, ROWS_PER_PAGE, CELL_SIZE, CELL_GAP)
    local prevBtn, nextBtn = LSU.drawPageIndicator(ctx, screenW, indicatorY, currentPage_, totalPages_, THEME_COLOR)

    -- 公共底部装饰
    local footerY = indicatorY + 36
    LSU.drawGarden(ctx, screenW, screenH, footerY)

    -- 编辑器入口按钮（仅测试模式下显示）
    local editorBtn = nil
    if featureFlags.isMasterEnabled() then
        local ebW, ebH = 104, 44
        local ebX = screenW - ebW - 12
        local ebY = screenH - ebH - 10

        Paper.button(ctx, ebX, ebY, ebW, ebH, "关卡工坊", false, true)

        editorBtn = { x = ebX, y = ebY, w = ebW, h = ebH }
    end

    return {
        backBtn = backBtn,
        levelBtns = levelBtns,
        prevBtn = prevBtn,
        nextBtn = nextBtn,
        editorBtn = editorBtn,
    }
end

--- 检测点击命中
---@param mx number 鼠标 x
---@param my number 鼠标 y
---@param hitAreas table draw() 返回的按钮区域
---@return string|nil action "back" | "select_level" | "prev_page" | "next_page" | "editor" | nil
---@return number|nil levelIndex
function M.hitTest(mx, my, hitAreas)
    return LSU.hitTest(mx, my, hitAreas)
end

-- ============================================================================
-- 分页控制
-- ============================================================================

--- 重置到第 1 页
function M.reset()
    currentPage_ = 1
end

--- 跳转到包含指定关卡的页
---@param levelIndex number 关卡索引（1-based）
function M.gotoPageForLevel(levelIndex)
    if levelIndex and levelIndex >= 1 then
        currentPage_ = math.ceil(levelIndex / ITEMS_PER_PAGE)
    end
end

--- 上一页
function M.prevPage()
    if currentPage_ > 1 then
        currentPage_ = currentPage_ - 1
    end
end

--- 下一页
function M.nextPage()
    if currentPage_ < totalPages_ then
        currentPage_ = currentPage_ + 1
    end
end

return M
