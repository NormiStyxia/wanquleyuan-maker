--- 记忆翻牌 - 关卡选择界面
--- 职责：NanoVG 绘制关卡网格、处理点击选关
local save = require("games.p2-memory-flip.save")
local LSU = require("shared.components.level-select-ui")
local Layout = require("shared.constants.layout")
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
    newbie    = { 100, 190, 120 },
    advanced  = { 75, 150, 210 },
    challenge = { 220, 160, 50 },
    expert    = { 210, 100, 80 },
    master    = { 160, 80, 180 },
    legendary = { 200, 150, 50 },
    supreme   = { 180, 60, 70 },
    ultimate  = { 120, 50, 160 },
}

local STAR_COLOR = { 255, 215, 0 }
local STAR_EMPTY = { 200, 195, 185 }

--- 绘制小型五角星（关卡选择用）
local function drawMiniStar(vg, cx, cy, r, filled)
    local color = filled and STAR_COLOR or STAR_EMPTY
    local innerR = r * 0.45
    nvgBeginPath(vg)
    for i = 0, 4 do
        local outerAngle = math.rad(i * 72 - 90)
        local innerAngle = math.rad(i * 72 - 90 + 36)
        local ox = cx + math.cos(outerAngle) * r
        local oy = cy + math.sin(outerAngle) * r
        local ix = cx + math.cos(innerAngle) * innerR
        local iy = cy + math.sin(innerAngle) * innerR
        if i == 0 then
            nvgMoveTo(vg, ox, oy)
        else
            nvgLineTo(vg, ox, oy)
        end
        nvgLineTo(vg, ix, iy)
    end
    nvgClosePath(vg)
    nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], 255))
    nvgFill(vg)
end

-- 记忆翻牌主题色
local THEME_COLOR    = { 75, 150, 210 }
local BAR_COLOR_FROM = { 240, 150, 70 }
local BAR_COLOR_TO   = { 210, 110, 50 }
local FILL_FROM      = { 75, 160, 220 }
local FILL_TO        = { 100, 200, 140 }

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
    LSU.drawTopBarTitle(vg, screenW, "记忆翻牌 · 选择关卡")

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

            -- 卡片数标签
            nvgFontSize(vg, 11)
            nvgFillColor(vg, nvgRGBA(150, 140, 125, 180))
            nvgText(vg, cx + CELL_SIZE / 2, cy + CELL_SIZE / 2 + 5, lv.cardCount .. "张", nil)

            -- 星级显示
            if best then
                local stars = best.bestStar or 0
                local starR = 6
                local starGap = Layout.STAR_GAP_LEVEL_SELECT
                local starCx = cx + CELL_SIZE / 2
                local starCy = cy + CELL_SIZE / 2 + 22
                for si = 1, 3 do
                    drawMiniStar(vg, starCx + (si - 2) * starGap, starCy, starR, si <= stars)
                end
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
