--- 连连看 - HUD 渲染器
--- 职责：绘制顶部信息栏（倒计时、剩余对数、评级）和底部操作按钮
local State = require("games.p4-link-match.logic.state")
local Colors = require("shared.constants.colors")
local Layout = require("shared.constants.layout")

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local M = {}

M.TOP_BAR_H = 54
M.BOTTOM_BAR_H = 0  -- 按钮已移至左上角，底部无需留白

local COLORS = {
    topBar = C.paper,
    topBarDark = C.paper,
    text = C.ink,
    textDim = C.muted,
    timerWarn = { 230, 80, 60 },
    starFilled = Colors.star.active,
    starEmpty = Colors.star.empty,
}

--- 绘制迷你星星（HUD 用）
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

--- 格式化时间（秒 -> MM:SS）
---@param sec number
---@return string
local function formatTime(sec)
    sec = math.max(0, math.floor(sec))
    local m = math.floor(sec / 60)
    local s = sec % 60
    return string.format("%d:%02d", m, s)
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

    -- 倒计时
    local remain = board:getRemainTime()
    local timeStr = formatTime(remain)
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    if remain <= 15 then
        -- 时间紧迫时红色闪烁
        local blink = math.sin(remain * math.pi * 2) * 0.3 + 0.7
        local wc = COLORS.timerWarn
        nvgFillColor(vg, nvgRGBA(wc[1], wc[2], wc[3], math.floor(255 * blink)))
    else
        nvgFillColor(vg, Pen.color(C.ink))
    end
    nvgText(vg, screenW / 2, M.TOP_BAR_H / 2 + 11, timeStr, nil)

    -- 剩余对数（左侧）
    local td = COLORS.textDim
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(td[1], td[2], td[3], td[4]))
    nvgText(vg, 16, M.TOP_BAR_H / 2 - 6, "剩余", nil)
    nvgFontSize(vg, 18)
    nvgFillColor(vg, Pen.color(C.ink))
    nvgText(vg, 16, M.TOP_BAR_H / 2 + 10, math.floor(board.remainPairs) .. "对", nil)

    -- 预估星级（右侧）
    if board.timerStarted and not board.cleared and not board.failed then
        local elapsed = board.elapsedMs / 1000
        local estStars
        if elapsed <= board.rankTime.a then estStars = 3
        elseif elapsed <= board.rankTime.b then estStars = 2
        else estStars = 1 end

        local starR = 7
        local starGap = Layout.STAR_GAP_HUD
        local starBaseX = screenW - 16 - starGap
        local starY = M.TOP_BAR_H / 2 + 10
        nvgFontSize(vg, 13)
        nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(td[1], td[2], td[3], td[4]))
        nvgText(vg, screenW - 16, M.TOP_BAR_H / 2 - 6, "评级", nil)
        for si = 1, 3 do
            drawMiniStar(vg, starBaseX + (si - 2) * starGap, starY, starR, si <= estStars)
        end
    end
end

--- 绘制操作按钮（左上角 HUD 下方，水平排列）
---@param vg userdata
---@param screenW number
---@param screenH number
---@param board table Board 实例
---@return table[] buttons { { x, y, w, h, action } }
function M.drawBottom(vg, screenW, screenH, board)
    local btnH = 44
    local btnW = 50
    local gap = 6
    local startX = 10
    local startY = M.TOP_BAR_H + 6

    local labels = {
        { text = "返回", action = "back", enabled = true },
        { text = "暂停", action = "pause", enabled = true },
        { text = "洗牌" .. board:getRemainShuffles(), action = "shuffle",
          enabled = board:getRemainShuffles() > 0 and State.canClick(board.sm) },
    }

    local buttons = {}

    for i, lbl in ipairs(labels) do
        local bx = startX + (i - 1) * (btnW + gap)
        Paper.button(vg,bx,startY,btnW,btnH,lbl.text,false,lbl.enabled)

        buttons[i] = { x = bx, y = startY, w = btnW, h = btnH, action = lbl.action, enabled = lbl.enabled }
    end

    return buttons
end

--- 绘制底部时间进度条（圆润儿童风格）+ 消除 +1 秒动画
---@param vg userdata
---@param screenW number
---@param screenH number
---@param board table Board 实例
---@param animTime number 累计动画时间（秒）
function M.drawTimeBar(vg, screenW, screenH, board, animTime)
    if not board.timerStarted or board.cleared then return end

    local barH = 12
    local radius = barH / 2
    local margin = 32                                 -- 左右留白
    local totalW = screenW - margin * 2               -- 进度条总宽度
    local barX = margin
    local barY = screenH - barH - 24                  -- 底部留一点间距

    local remain = board:getRemainTime()
    local total = board.timeLimit
    local ratio = math.max(0, math.min(1, remain / total))

    -- 进度条颜色
    local r, g, b
    if remain <= 10 then
        r, g, b = 220, 50, 40
    elseif remain <= 30 then
        local t = (remain - 10) / 20
        local pulse = math.sin(animTime * 4) * 0.5 + 0.5
        local blend = t + (1 - t) * pulse
        r = math.floor(240 - 20 * (1 - blend))
        g = math.floor(180 * blend + 50 * (1 - blend))
        b = 40
    else
        r, g, b = C.green[1], C.green[2], C.green[3]
    end

    -- 平涂纸条，填充宽度精确对应剩余时间。
    Pen.plaque(vg,barX,barY,totalW,barH,C.track,1.5)
    local fillW=totalW*ratio
    if fillW>0 then
        nvgSave(vg); nvgIntersectScissor(vg,barX,barY,fillW,barH)
        Pen.plaque(vg,barX,barY,totalW,barH,{r,g,b,255},0)
        nvgRestore(vg)
    end

    -- 倒计时文字（进度条上方居中）
    local timeStr = formatTime(remain)
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 13)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(r, g, b, 200))
    nvgText(vg, screenW / 2, barY - 10, timeStr, nil)

    -- +1 秒浮动动画
    if board.timeBonusTimer and board.timeBonusTimer > 0 then
        local t = 1.0 - board.timeBonusTimer          -- 0→1 进度
        local floatY = barY - 14 - t * 28             -- 向上飘
        local alpha = math.floor(255 * (1.0 - t))     -- 逐渐透明
        local scale = 1.0 + t * 0.06                   -- 微微放大

        nvgFontFace(vg, "sans")
        nvgFontSize(vg, 16 * scale)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(C.green[1], C.green[2], C.green[3], alpha))
        nvgText(vg, screenW / 2, floatY, "+1s", nil)
    end
end

return M
