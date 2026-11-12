--- 连连看 - 关卡选择界面
--- 职责：NanoVG 绘制关卡网格、处理点击选关
local save = require("games.p4-link-match.save")
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
--- 总页数
local totalPages_ = 1

-- 章节配色
local CHAPTER_COLORS = {
    newbie    = { 100, 190, 120 },
    advanced  = { 75, 150, 210 },
    challenge = { 220, 160, 50 },
    expert    = { 210, 100, 80 },
    master    = { 160, 80, 180 },
}

local STAR_COLOR = { 255, 200, 50 }
local STAR_EMPTY = { 200, 195, 180 }

--- 绘制迷你星星
local function drawMiniStar(vg, cx, cy, r, filled)
    nvgBeginPath(vg)
    local pts = 5
    for i = 0, pts * 2 - 1 do
        local angle = math.pi / 2 * (-1) + math.pi / pts * i
        local rr = (i % 2 == 0) and r or (r * 0.45)
        local px = cx + math.cos(angle) * rr
        local py = cy - math.sin(angle) * rr
        if i == 0 then
            nvgMoveTo(vg, px, py)
        else
            nvgLineTo(vg, px, py)
        end
    end
    nvgClosePath(vg)
    if filled then
        nvgFillColor(vg, nvgRGBA(STAR_COLOR[1], STAR_COLOR[2], STAR_COLOR[3], 255))
    else
        nvgFillColor(vg, nvgRGBA(STAR_EMPTY[1], STAR_EMPTY[2], STAR_EMPTY[3], 120))
    end
    nvgFill(vg)
end

-- 连连看主题色（绿色调）
local THEME_COLOR    = { 80, 170, 130 }
local BAR_COLOR_FROM = { 240, 150, 70 }
local BAR_COLOR_TO   = { 210, 110, 50 }
local FILL_FROM      = { 75, 190, 140 }
local FILL_TO        = { 100, 210, 170 }

-- ============================================================================
-- 绘制
-- ============================================================================

---@param vg userdata
---@param screenW number
---@param screenH number
---@param levels table[]
---@param saveData table
---@return table hitAreas
function M.draw(vg, screenW, screenH, levels, saveData, afterBg)
    -- 公共背景
    LSU.drawBackground(vg, screenW, screenH, THEME_COLOR, bgManager.getCurrent())

    if afterBg then afterBg() end

    -- 公共顶栏
    LSU.drawTopBar(vg, screenW, BAR_COLOR_FROM, BAR_COLOR_TO)

    -- 公共返回按钮
    local backBtn = LSU.drawBackButton(vg)

    -- 标题
    LSU.drawTopBarTitle(vg, screenW, "连连看 · 选择关卡")

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

            -- 棋盘尺寸标签
            nvgFontSize(vg, 11)
            nvgFillColor(vg, nvgRGBA(150, 140, 125, 180))
            nvgText(vg, cx + CELL_SIZE / 2, cy + CELL_SIZE / 2 + 5,
                lv.board.cols .. "x" .. lv.board.rows, nil)

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

    -- 公共分页指示器
    local pageRows = math.ceil((pageEndIdx - pageStartIdx + 1) / COLS)
    local indicatorY = startY + pageRows * (CELL_SIZE + CELL_GAP) + 8
    local prevBtn, nextBtn = LSU.drawPageIndicator(vg, screenW, indicatorY, currentPage_, totalPages_, THEME_COLOR)

    -- 公共底部装饰
    local footerY = indicatorY + (totalPages_ > 1 and 24 or 0) + 12
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
---@return string|nil action
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
