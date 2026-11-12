--- 公共关卡选择 UI 组件
--- 提供所有游戏共用的关卡选择界面绘制元素（儿童友好风格）
--- 各游戏只需调用这些函数即可获得统一、美观的关卡选择体验

local Colors = require("shared.constants.colors")
local bgManager = require("shared.background-manager")

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local Scenery = require("shared.rendering.game-scenery")
local C = Paper.colors
local M = {}

-- ============================================================================
-- 共享常量（儿童友好尺寸）
-- ============================================================================

M.TOP_BAR_H = 60          -- 顶栏高度（加大）
M.BACK_BTN_W = 80         -- 返回按钮宽（适配"< 返回"文字）
M.BACK_BTN_H = 44         -- 返回按钮高
M.PROGRESS_BAR_H = 8      -- 进度条高（加粗）
M.PAGE_ARROW_W = 44       -- 分页箭头宽（加大）
M.PAGE_ARROW_H = 44       -- 分页箭头高
M.LOCK_ICON_R = 7         -- 锁头图标半径（加大）

-- ============================================================================
-- 背景
-- ============================================================================

--- 使用玩家已选的手绘背景，与大厅、装扮预览保持一致。
--- themeColor 参数保留，兼容四个玩法的既有调用。
---@param vg userdata
---@param screenW number
---@param screenH number
---@param themeColor table|nil
---@param bgConfig table|nil
function M.drawBackground(vg, screenW, screenH, themeColor, bgConfig)
    bgManager.renderBackground(vg, screenW, screenH, 0, bgConfig or bgManager.getCurrent())
end

--- 只在关卡和翻页按钮下方的空位放独立手绘小景；短屏空间不足时自动隐藏。
function M.drawGarden(vg, screenW, screenH, contentBottom)
    return Scenery.draw(vg,screenW,screenH,{x=0,y=0,w=screenW,h=contentBottom},
        bgManager.getCurrent(),GetTime():GetElapsedTime())
end

-- ============================================================================
-- 顶栏
-- ============================================================================

--- 绘制渐变顶栏
---@param vg userdata
---@param screenW number
---@param colorFrom table {r,g,b} 渐变起始色
---@param colorTo table {r,g,b} 渐变结束色
function M.drawTopBar(vg,screenW,colorFrom,colorTo)
    Paper.hud(vg,screenW,M.TOP_BAR_H)
end



--- 绘制返回按钮，返回按钮的 hitArea
---@param vg userdata
---@return table backBtn {x,y,w,h}
function M.drawBackButton(vg)
    local w, h = M.BACK_BTN_W, M.BACK_BTN_H
    local x = 10
    local y = (M.TOP_BAR_H - h) / 2

    Paper.button(vg,x,y,w,h,"< 返回",false,true)

    return { x = x, y = y, w = w, h = h }
end

--- 绘制顶栏标题
---@param vg userdata
---@param screenW number
---@param title string
function M.drawTopBarTitle(vg, screenW, title)
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, Pen.color(C.ink))
    local available=screenW-2*(M.BACK_BTN_W+18)
    local width=nvgTextBounds(vg,0,0,title) or 0
    if width>available then nvgFontSize(vg,20*available/width) end
    nvgText(vg, screenW / 2, M.TOP_BAR_H / 2, title, nil)
end

-- ============================================================================
-- 进度条
-- ============================================================================

--- 绘制进度区域（文字 + 进度条）
---@param vg userdata
---@param screenW number
---@param y number 起始 Y
---@param completed number 已完成数
---@param total number 总数
---@param fillColorFrom table {r,g,b} 填充渐变起始色
---@param fillColorTo table {r,g,b} 填充渐变结束色
function M.drawProgress(vg, screenW, y, completed, total, fillColorFrom, fillColorTo)
    local padX = 20
    -- 文字和进度保持纸色底，避免落在背景的树丛或栅栏上。
    nvgBeginPath(vg);nvgRect(vg,0,M.TOP_BAR_H,screenW,y+27-M.TOP_BAR_H)
    nvgFillColor(vg,Pen.color(C.paper));nvgFill(vg)
    nvgBeginPath(vg);nvgMoveTo(vg,0,y+27);nvgLineTo(vg,screenW,y+27)
    nvgStrokeColor(vg,Pen.color(C.ink));nvgStrokeWidth(vg,1.5);nvgStroke(vg)

    -- 文字
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(140, 120, 90, 255))
    nvgText(vg, padX, y, "通关进度", nil)

    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(160, 135, 105, 255))
    nvgText(vg, screenW - padX, y, completed .. " / " .. total, nil)

    -- 进度条
    local barY = y + 14
    local barW = screenW - padX * 2
    local barH = M.PROGRESS_BAR_H
    local r = barH / 2
    local ratio = total > 0 and (completed / total) or 0

    Pen.plaque(vg,padX,barY,barW,barH,C.track,1)
    if ratio>0 then
        local fillW = barW * math.min(1, ratio)
        nvgSave(vg);nvgIntersectScissor(vg,padX,barY,fillW,barH)
        Pen.plaque(vg,padX,barY,barW,barH,C.green,0)
        nvgRestore(vg)
        local now = GetTime and GetTime():GetElapsedTime() or 0
        local tipR = 3.2 + math.sin(now * 4.0) * 0.5
        Pen.circle(vg, padX + math.max(r, fillW - r), barY + r, tipR, C.orange, 1.2, C.ink)
    end
end

-- ============================================================================
-- 锁定格子
-- ============================================================================

--- 已解锁的关卡使用相同纸框，成绩与章节标记仍由各玩法绘制。
function M.drawUnlockedCell(vg,x,y,size,completed)
    Paper.panel(vg,x,y,size,size,completed and {238,229,191,255} or C.paper)
end

--- 绘制锁定关卡格子
---@param vg userdata
---@param cx number 格子左上 X
---@param cy number 格子左上 Y
---@param cellSize number 格子尺寸
---@param radius number 圆角
---@param themeColor table|nil {r,g,b} 锁头着色（默认灰色）
function M.drawLockedCell(vg, cx, cy, cellSize, radius, themeColor)
    local tc = themeColor or { 190, 178, 160 }

    Paper.panel(vg,cx,cy,cellSize,cellSize,{223,216,192,255})

    -- 锁头图标（加大）
    local lockCx = cx + cellSize / 2
    local lockCy = cy + cellSize / 2 - 2
    local lr = M.LOCK_ICON_R

    -- 锁环
    nvgBeginPath(vg)
    nvgArc(vg, lockCx, lockCy - 5, lr, math.rad(180), math.rad(0), NVG_CW)
    nvgStrokeColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 180))
    nvgStrokeWidth(vg, 2.5)
    nvgStroke(vg)

    -- 锁体
    nvgBeginPath(vg)
    nvgRoundedRect(vg, lockCx - lr - 1, lockCy - 2, (lr + 1) * 2, lr * 2, 3)
    nvgFillColor(vg, nvgRGBA(tc[1], tc[2], tc[3], 180))
    nvgFill(vg)

    -- 钥匙孔
    nvgBeginPath(vg)
    nvgCircle(vg, lockCx, lockCy + 2, 2.5)
    nvgFillColor(vg, nvgRGBA(255, 248, 235, 220))
    nvgFill(vg)
end

-- ============================================================================
-- 矢量星星
-- ============================================================================

--- 绘制一行小星星
---@param vg userdata
---@param cx number 行中心 X
---@param cy number 行中心 Y
---@param earned number 已获得星星数
---@param total number 总星星数（一般 3）
---@param starSize number 单颗星星直径
function M.drawStarRow(vg, cx, cy, earned, total, starSize)
    local gap = starSize + 2
    local totalW = total * gap - 2
    local startX = cx - totalW / 2 + gap / 2
    local now = GetTime and GetTime():GetElapsedTime() or 0

    for i = 1, total do
        local sx = startX + (i - 1) * gap
        local active = i <= earned
        local pulse = active and (1.0 + math.sin(now * 3.2 + i * 1.1 + cx * 0.03) * 0.07) or 1.0
        M.drawMiniStar(vg, sx, cy, (starSize / 2) * pulse, (starSize * 0.22) * pulse, active)
    end
end

--- 绘制单颗矢量星星
---@param vg userdata
---@param cx number 中心 X
---@param cy number 中心 Y
---@param outerR number 外径
---@param innerR number 内径
---@param filled boolean 是否填充
function M.drawMiniStar(vg, cx, cy, outerR, innerR, filled)
    nvgBeginPath(vg)
    for i = 0, 4 do
        local outerAngle = math.rad(i * 72 - 90)
        local innerAngle = math.rad(i * 72 - 90 + 36)
        local ox = cx + math.cos(outerAngle) * outerR
        local oy = cy + math.sin(outerAngle) * outerR
        local ix = cx + math.cos(innerAngle) * innerR
        local iy = cy + math.sin(innerAngle) * innerR

        if i == 0 then nvgMoveTo(vg, ox, oy) else nvgLineTo(vg, ox, oy) end
        nvgLineTo(vg, ix, iy)
    end
    nvgClosePath(vg)

    if filled then
        nvgFillColor(vg, nvgRGBA(255, 210, 50, 255))
    else
        nvgFillColor(vg, nvgRGBA(210, 200, 185, 100))
    end
    nvgFill(vg)
end

-- ============================================================================
-- 分页指示器
-- ============================================================================

--- 计算固定在整页最大行数下方的分页指示器中心 Y（不随当页关卡数量变化）
---@param screenH number
---@param startY number
---@param rowsPerPage number
---@param cellSize number
---@param cellGap number
---@return number indicatorY
function M.getPageIndicatorY(screenH, startY, rowsPerPage, cellSize, cellGap)
    local gridBottom = startY + rowsPerPage * cellSize + (rowsPerPage - 1) * cellGap
    return math.min(gridBottom + 76, screenH - 36)
end

--- 绘制分页指示器（圆点 + 对称常驻箭头按钮）
---@param vg userdata
---@param screenW number
---@param y number 指示器垂直中心 Y
---@param current number 当前页（1-based）
---@param total number 总页数
---@param accentColor table {r,g,b} 强调色
---@return table|nil prevBtn
---@return table|nil nextBtn
function M.drawPageIndicator(vg, screenW, y, current, total, accentColor)
    if total <= 1 then return nil, nil end

    local ac = accentColor or { 130, 180, 230 }
    local dotR = 4
    local dotGap = 18
    local arrowW = M.PAGE_ARROW_W
    local arrowH = M.PAGE_ARROW_H

    -- 圆点严格水平居中
    local dotsW = (total - 1) * dotGap
    local dotsStartX = screenW / 2 - dotsW / 2
    local now = GetTime and GetTime():GetElapsedTime() or 0
    for p = 1, total do
        local dx = dotsStartX + (p - 1) * dotGap
        if p == current then
            local haloR = dotR + 2.5 + math.sin(now * 3.5) * 0.6
            nvgBeginPath(vg)
            nvgCircle(vg, dx, y, haloR)
            nvgStrokeColor(vg, nvgRGBA(ac[1], ac[2], ac[3], 110))
            nvgStrokeWidth(vg, 1.5)
            nvgStroke(vg)
        end
        nvgBeginPath(vg)
        nvgCircle(vg, dx, y, p == current and (dotR + 0.8) or dotR)
        if p == current then
            nvgFillColor(vg, nvgRGBA(ac[1], ac[2], ac[3], 235))
        else
            nvgFillColor(vg, nvgRGBA(200, 190, 175, 110))
        end
        nvgFill(vg)
    end

    -- 左右翻页按钮对称固定在圆点两侧；边界页置灰保留占位，避免翻页时左右晃动
    local sideGap = 20
    local prevX = math.max(8, screenW / 2 - dotsW / 2 - sideGap - arrowW)
    local nextX = math.min(screenW - 8 - arrowW, screenW / 2 + dotsW / 2 + sideGap)

    local canPrev = current > 1
    Paper.button(vg, prevX, y - arrowH / 2, arrowW, arrowH, "<", false, canPrev)
    local prevBtn = canPrev and { x = prevX, y = y - arrowH / 2, w = arrowW, h = arrowH } or nil

    local canNext = current < total
    Paper.button(vg, nextX, y - arrowH / 2, arrowW, arrowH, ">", false, canNext)
    local nextBtn = canNext and { x = nextX, y = y - arrowH / 2, w = arrowW, h = arrowH } or nil

    return prevBtn, nextBtn
end

-- ============================================================================
-- 底部装饰
-- ============================================================================

--- 绘制底部装饰线 + 提示文字
---@param vg userdata
---@param screenW number
---@param y number 装饰起始 Y
---@param text string|nil 提示文字（默认 "更多关卡即将开放"）
---@param accentColor table|nil {r,g,b}
function M.drawFooter(vg, screenW, y, text, accentColor)
    local ac = accentColor or { 200, 185, 165 }
    local lineW = 45

    -- 装饰线
    nvgBeginPath(vg)
    nvgMoveTo(vg, screenW / 2 - lineW, y)
    nvgLineTo(vg, screenW / 2 + lineW, y)
    nvgStrokeColor(vg, nvgRGBA(ac[1], ac[2], ac[3], 70))
    nvgStrokeWidth(vg, 1)
    nvgStroke(vg)

    -- 装饰菱形
    nvgSave(vg)
    nvgTranslate(vg, screenW / 2, y)
    nvgRotate(vg, math.rad(45))
    nvgBeginPath(vg)
    nvgRect(vg, -4, -4, 8, 8)
    nvgFillColor(vg, nvgRGBA(ac[1], ac[2], ac[3], 60))
    nvgFill(vg)
    nvgRestore(vg)

    -- 文字
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(ac[1], ac[2], ac[3], 120))
    nvgText(vg, screenW / 2, y + 18, text or "更多关卡即将开放", nil)
end

-- ============================================================================
-- hitTest 工具
-- ============================================================================

--- 通用 hitTest
---@param mx number
---@param my number
---@param hitAreas table { backBtn, levelBtns[], prevBtn?, nextBtn?, editorBtn? }
---@return string|nil action
---@return number|nil levelIndex
function M.hitTest(mx, my, hitAreas)
    if not hitAreas then return nil, nil end

    local bb = hitAreas.backBtn
    if bb and mx >= bb.x and mx <= bb.x + bb.w and my >= bb.y and my <= bb.y + bb.h then
        return "back", nil
    end

    local eb = hitAreas.editorBtn
    if eb and mx >= eb.x and mx <= eb.x + eb.w and my >= eb.y and my <= eb.y + eb.h then
        return "editor", nil
    end

    local pb = hitAreas.prevBtn
    if pb and mx >= pb.x and mx <= pb.x + pb.w and my >= pb.y and my <= pb.y + pb.h then
        return "prev_page", nil
    end

    local nb = hitAreas.nextBtn
    if nb and mx >= nb.x and mx <= nb.x + nb.w and my >= nb.y and my <= nb.y + nb.h then
        return "next_page", nil
    end

    if hitAreas.levelBtns then
        for _, btn in pairs(hitAreas.levelBtns) do
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                if btn.unlocked then
                    return "select_level", btn.levelIndex
                end
                return nil, nil
            end
        end
    end

    return nil, nil
end

return M
