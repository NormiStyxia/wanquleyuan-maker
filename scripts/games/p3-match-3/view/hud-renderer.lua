--- 消消乐 - HUD 渲染器
--- 职责：绘制顶部信息栏（关卡名、步数、分数、目标进度）和底部按钮

local Board = require("games.p3-match-3.logic.board")
local Colors = require("shared.constants.colors")

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local M = {}

M.TOP_BAR_H = 54
M.BOTTOM_BAR_H = 0

local COLORS = {
    topBar = C.paper,
    topBarDark = C.paper,
    text = C.ink,
    textDim = C.muted,
    progressBg = { 255, 255, 255, 40 },
    progressFill = { 100, 220, 140 },
    stepsWarn = { 255, 100, 80 },
}

-- 方块颜色名（简短显示用）
local COLOR_NAMES = {
    [0] = "任意",
    [1] = "红", [2] = "蓝", [3] = "绿",
    [4] = "黄", [5] = "紫", [6] = "粉",
}

local COLOR_DOTS = {
    [1] = { 231, 76, 60 },
    [2] = { 52, 152, 219 },
    [3] = { 46, 204, 113 },
    [4] = { 241, 196, 15 },
    [5] = { 155, 89, 182 },
    [6] = { 255, 182, 193 },
}

-- ============================================================================
-- 绘制 HUD 顶部
-- ============================================================================

---@param vg userdata
---@param screenW number
---@param board table Board 实例
---@param levelTitle string
function M.drawTop(vg, screenW, board, levelTitle)
    Paper.hud(vg,screenW,M.TOP_BAR_H)

    -- 关卡标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 15)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(COLORS.text[1], COLORS.text[2], COLORS.text[3], 200))
    nvgText(vg, screenW / 2, 14, levelTitle, nil)

    -- 时间（左侧）
    local timeColor = COLORS.text
    if board.remainTime <= 10 then
        timeColor = COLORS.stepsWarn
    end
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    local td = COLORS.textDim
    nvgFillColor(vg, nvgRGBA(td[1], td[2], td[3], td[4]))
    nvgText(vg, 14, 14, "时间", nil)
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(timeColor[1], timeColor[2], timeColor[3], 255))
    nvgText(vg, 14, 34, tostring(math.ceil(board.remainTime)), nil)

    -- 分数（右侧）
    nvgFontSize(vg, 12)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(td[1], td[2], td[3], td[4]))
    nvgText(vg, screenW - 14, 14, "分数", nil)
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(COLORS.text[1], COLORS.text[2], COLORS.text[3], 255))
    nvgText(vg, screenW - 14, 34, tostring(board.score), nil)

    -- 目标进度（中间下方）
    M._drawGoalProgress(vg, screenW, board)
end

--- 绘制目标进度
function M._drawGoalProgress(vg, screenW, board)
    local g = board.goal
    local barY = 29
    local barW = math.min(180, screenW * 0.4)
    local barH = 6
    local barX = (screenW - barW) / 2

    -- 进度条背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, barX, barY, barW, barH, 3)
    nvgFillColor(vg, nvgRGBA(COLORS.progressBg[1], COLORS.progressBg[2],
        COLORS.progressBg[3], COLORS.progressBg[4]))
    nvgFill(vg)

    -- 星级进度检测
    local starProgress = board:getStarProgress()

    -- 进度条填充
    local ratio = board:getGoalRatio()
    if ratio > 0 then
        local fillW = math.max(barH, barW * math.min(1, ratio))
        local pf = starProgress and Colors.star.active or COLORS.progressFill
        nvgBeginPath(vg)
        nvgRoundedRect(vg, barX, barY, fillW, barH, 3)
        nvgFillColor(vg, nvgRGBA(pf[1], pf[2], pf[3], 230))
        nvgFill(vg)
    end

    -- 目标文本 / 星级进度文本
    local goalText
    if starProgress then
        if starProgress.stars >= 3 then
            goalText = "★★★"
        else
            local nextStar = starProgress.stars + 1
            goalText = "距" .. nextStar .. "星还需 " .. starProgress.needed .. " 分"
        end
    else
        goalText = M._formatGoalText(board)
    end
    nvgFontSize(vg, 11)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    local sc = Colors.star.active
    local textColor = starProgress and { sc[1], sc[2], sc[3], 255 } or C.ink
    nvgFillColor(vg, nvgRGBA(textColor[1], textColor[2], textColor[3], textColor[4]))
    nvgText(vg, screenW / 2, barY + barH + 10, goalText, nil)
end

--- 格式化目标文本
function M._formatGoalText(board)
    local g = board.goal
    if g.type == "score" then
        return "目标：" .. board.score .. " / " .. g.targetScore
    elseif g.type == "collect_color" then
        local parts = {}
        for _, t in ipairs(g.targets) do
            local cur = board.goalProgress[t.colorId] or 0
            local name = COLOR_NAMES[t.colorId] or ("C" .. t.colorId)
            parts[#parts + 1] = name .. " " .. cur .. "/" .. t.count
        end
        return "收集：" .. table.concat(parts, "  ")
    elseif g.type == "trigger_special" then
        local cur = board.goalProgress.count or 0
        local name = g.specialType == "line" and "直线"
            or g.specialType == "bomb" and "爆炸"
            or g.specialType == "rainbow" and "彩虹"
            or g.specialType
        return name .. " " .. cur .. "/" .. g.targetCount
    end
    return ""
end

-- ============================================================================
-- 右上角"完成关卡"按钮（自由模式达标后显示）
-- ============================================================================

--- 绘制完成关卡按钮
---@param vg userdata
---@param screenW number
---@param pulse number 0~1 脉冲动画值
---@return table btn { x, y, w, h, action }
function M.drawFinishButton(vg, screenW, pulse)
    local btnW = 80
    local btnH = 30
    local btnX = screenW - btnW - 10
    local btnY = M.TOP_BAR_H + 8

    Paper.button(vg,btnX,btnY,btnW,44,"完成关卡",true,true)
    btnH = 44

    return { x = btnX, y = btnY, w = btnW, h = btnH, action = "finish" }
end

-- ============================================================================
-- 绘制底部按钮
-- ============================================================================

---@param vg userdata
---@param screenW number
---@param screenH number
---@return table[] buttons { { x, y, w, h, action } }
function M.drawBottom(vg, screenW, screenH)
    local btnH = 44
    local btnW = 56
    local gap = 8
    local buttons = {}

    -- 左上角（HUD 下方）放置 返回 和 重开 按钮，水平排列
    local startX = 12
    local startY = M.TOP_BAR_H + 8

    local labels = {
        { text = "返回", action = "back" },
        { text = "暂停", action = "pause" },
    }

    for i, lbl in ipairs(labels) do
        local bx = startX + (i - 1) * (btnW + gap)
        Paper.button(vg,bx,startY,btnW,btnH,lbl.text,false,lbl.enabled)

        buttons[i] = { x = bx, y = startY, w = btnW, h = btnH, action = lbl.action }
    end

    return buttons
end

return M
