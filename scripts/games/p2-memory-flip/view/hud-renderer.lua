--- 记忆翻牌 - HUD 渲染器
--- 职责：绘制顶部信息栏（关卡名、计时、错误次数）和左上角操作按钮

local Colors = require("shared.constants.colors")
local Layout = require("shared.constants.layout")

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local M = {}

M.TOP_BAR_H = 54
M.BOTTOM_BAR_H = 0  -- 底部不再占空间

local COLORS = {
    topBar = C.paper,
    topBarDark = C.paper,
    text = C.ink,
    textDim = C.muted,
    btnBg = { 255, 255, 255, 25 },
    btnText = { 255, 245, 230, 230 },
    starFilled = Colors.star.active,
    starEmpty = Colors.star.empty,
}

--- 绘制小型五角星（HUD 用）
---@param vg userdata
---@param cx number
---@param cy number
---@param r number 外径
---@param filled boolean
local function drawMiniStar(vg, cx, cy, r, filled)
    local color = filled and COLORS.starFilled or COLORS.starEmpty
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

--- 绘制 HUD 顶部
---@param vg userdata
---@param screenW number
---@param board table Board 实例
---@param levelTitle string
function M.drawTop(vg, screenW, board, levelTitle)
    -- 渐变顶栏
    Paper.hud(vg,screenW,M.TOP_BAR_H)

    -- 关卡标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(COLORS.text[1], COLORS.text[2], COLORS.text[3], 255))
    nvgText(vg, screenW / 2, M.TOP_BAR_H / 2 - 8, levelTitle, nil)

    -- 计时
    local timeStr = board:formatTime()
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, Pen.color(C.ink))
    nvgText(vg, screenW / 2, M.TOP_BAR_H / 2 + 11, timeStr, nil)

    -- 错误次数（左侧，留出按钮空间）
    local mistakeX = 16
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    local td = COLORS.textDim
    nvgFillColor(vg, nvgRGBA(td[1], td[2], td[3], td[4]))
    nvgText(vg, mistakeX, M.TOP_BAR_H / 2 - 6, "错误", nil)
    nvgFontSize(vg, 18)
    nvgFillColor(vg, Pen.color(C.ink))
    nvgText(vg, mistakeX, M.TOP_BAR_H / 2 + 10, tostring(board.mistakeCount), nil)

    -- 预估星级（右侧）
    if board.timerStarted and not board.cleared then
        local stars = board:currentEstimatedStarRating()
        local starR = 7
        local starGap = Layout.STAR_GAP_HUD
        local totalW = 3 * starGap
        local baseX = screenW - 16 - totalW + starGap / 2
        local starCY = M.TOP_BAR_H / 2 + 4
        for i = 1, 3 do
            drawMiniStar(vg, baseX + (i - 1) * starGap, starCY, starR, i <= stars)
        end
    end
end

--- 绘制左上角操作按钮（顶栏下方）
---@param vg userdata
---@param screenW number
---@param screenH number
---@return table[] buttons { { x, y, w, h, action } }
function M.drawBottom(vg, screenW, screenH)
    local btnH = 44
    local btnW = 52
    local gap = 6
    local marginLeft = 8
    local marginTop = M.TOP_BAR_H + 6

    -- 返回、暂停 按钮，水平排列在左上角
    local labels = {
        { text = "返回", action = "back" },
        { text = "暂停", action = "pause" },
    }

    local buttons = {}

    for i, lbl in ipairs(labels) do
        local bx = marginLeft + (i - 1) * (btnW + gap)
        local by = marginTop

        Paper.button(vg,bx,by,btnW,btnH,lbl.text,false,true)

        buttons[i] = { x = bx, y = by, w = btnW, h = btnH, action = lbl.action }
    end

    return buttons
end

return M
