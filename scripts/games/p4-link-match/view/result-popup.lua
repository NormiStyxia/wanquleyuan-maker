--- 连连看 - 结算弹窗
--- 职责：通关/失败后展示成绩与操作按钮
local celebrationFx = require("shared.components.celebration-effects")
local Colors = require("shared.constants.colors")
local Layout = require("shared.constants.layout")

local M = {}

local STAR_COLOR = Colors.star.active
local STAR_EMPTY = Colors.star.empty

--- 绘制五角星
local function drawStar(vg, cx, cy, outerR, innerR, filled, alpha)
    local a = math.floor((alpha or 1) * 255)
    local color = filled and STAR_COLOR or STAR_EMPTY
    nvgBeginPath(vg)
    for i = 0, 4 do
        local outerAngle = math.rad(i * 72 - 90)
        local innerAngle = math.rad(i * 72 - 90 + 36)
        local ox = cx + math.cos(outerAngle) * outerR
        local oy = cy + math.sin(outerAngle) * outerR
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
    nvgFillColor(vg, nvgRGBA(color[1], color[2], color[3], a))
    nvgFill(vg)
end

-- 庆祝特效状态
local celebration_ = nil

--- 启动庆祝特效
---@param screenW number
---@param screenH number
---@param starRating number
function M.startCelebration(screenW, screenH, starRating)
    local stars = starRating or 1
    celebration_ = celebrationFx.create(screenW, screenH, {
        enableRankAnim = false,
        fireworkCount = stars >= 3 and 5 or (stars >= 2 and 3 or 2),
        confettiCount = 30,
        elasticStyle = "sin",
    })
end

--- 更新庆祝特效
---@param dt number
function M.updateCelebration(dt)
    if celebration_ then
        celebrationFx.update(celebration_, dt)
    end
end

--- 停止庆祝特效
function M.stopCelebration()
    celebration_ = nil
end

--- 格式化时间
---@param ms number|nil
---@return string
local function formatTime(ms)
    if not ms then return "--" end
    local sec = math.floor(ms / 1000)
    local m = math.floor(sec / 60)
    local s = sec % 60
    return string.format("%d:%02d", m, s)
end

--- 绘制通关弹窗
---@param vg userdata
---@param screenW number
---@param screenH number
---@param board table Board 实例
---@param bestTimeMs number|nil
---@param isNewBest boolean
---@return table[] buttons
function M.drawCleared(vg, screenW, screenH, board, bestTimeMs, isNewBest, opts)
    local cel = celebration_

    -- 弹性动画参数
    local dScale = 1.0
    local dAlpha = 1.0
    if cel then
        dScale = cel.dialogScale
        dAlpha = cel.dialogAlpha
    end

    if dScale < 0.01 then
        if cel then
            celebrationFx.drawFireworks(vg, cel, screenW, screenH, true)
            celebrationFx.drawConfetti(vg, cel, screenH)
        end
        return {}
    end

    -- 半透明遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(120 * dAlpha)))
    nvgFill(vg)

    -- 烟花
    if cel then
        celebrationFx.drawFireworks(vg, cel, screenW, screenH, true)
    end

    -- 弹窗尺寸
    local popW = math.min(280, screenW - 40)
    local popH = 340
    local cx = screenW / 2
    local cy = screenH / 2

    nvgSave(vg)
    nvgTranslate(vg, cx, cy)
    nvgScale(vg, dScale, dScale)
    nvgTranslate(vg, -cx, -cy)

    local popX = (screenW - popW) / 2
    local popY = (screenH - popH) / 2
    local a255 = math.floor(dAlpha * 255)

    -- 金色光晕
    if cel then
        local glowR = math.max(popW, popH) * 0.65
        local glowPaint = nvgRadialGradient(vg, cx, cy - 20, glowR * 0.3, glowR,
            nvgRGBA(255, 215, 0, math.floor(dAlpha * 0.35 * 255)),
            nvgRGBA(255, 215, 0, 0))
        nvgBeginPath(vg)
        nvgRect(vg, cx - glowR, cy - 20 - glowR, glowR * 2, glowR * 2)
        nvgFillPaint(vg, glowPaint)
        nvgFill(vg)
    end

    -- 阴影
    nvgBeginPath(vg)
    nvgRoundedRect(vg, popX + 2, popY + 3, popW, popH, 16)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(25 * dAlpha)))
    nvgFill(vg)

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, popX, popY, popW, popH, 16)
    nvgFillColor(vg, nvgRGBA(255, 252, 245, math.min(250, a255)))
    nvgFill(vg)

    -- 主线模式参数
    local isStoryline = opts and opts.storylineMode or false
    local hasNextLevel = opts and opts.hasNextLevel
    if hasNextLevel == nil then hasNextLevel = true end

    -- 星级（主线模式强制 3 星）
    local displayStars = isStoryline and 3 or board.starRating

    -- 顶部色带（基于星级选色）
    local stripColor
    if displayStars >= 3 then stripColor = { 255, 215, 0 }
    elseif displayStars >= 2 then stripColor = { 100, 200, 100 }
    else stripColor = { 100, 180, 230 } end

    nvgBeginPath(vg)
    nvgRoundedRect(vg, popX, popY, popW, 60, 16)
    local stripPaint = nvgLinearGradient(vg, popX, popY, popX + popW, popY,
        nvgRGBA(stripColor[1], stripColor[2], stripColor[3], math.min(240, a255)),
        nvgRGBA(math.min(255, stripColor[1] + 30), math.min(255, stripColor[2] + 20),
            math.min(255, stripColor[3] + 30), math.min(240, a255)))
    nvgFillPaint(vg, stripPaint)
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRect(vg, popX, popY + 44, popW, 16)
    nvgFillPaint(vg, stripPaint)
    nvgFill(vg)

    -- 标题
    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 28)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, a255))
    nvgText(vg, cx, popY + 30, isStoryline and "关卡完成！" or "通关！", nil)

    -- 星级显示
    local starY = popY + 90
    local starGap = Layout.STAR_GAP_RESULT
    local starR = 18
    for si = 1, 3 do
        local sx = cx + (si - 2) * starGap
        drawStar(vg, sx, starY, starR, starR * 0.45, si <= displayStars, dAlpha)
    end

    -- 新纪录标记
    if isNewBest then
        nvgFontSize(vg, 15)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(240, 90, 90, a255))
        nvgText(vg, cx, popY + 114, "新纪录！", nil)
    end

    -- 成绩信息
    local infoY = popY + 130
    local lineH = 24
    nvgFontSize(vg, 17)

    -- 用时
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(140, 115, 95, a255))
    nvgText(vg, popX + 24, infoY, "用时", nil)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(80, 55, 35, a255))
    nvgText(vg, popX + popW - 24, infoY, formatTime(board.clearTimeMs), nil)

    -- 历史最佳
    infoY = infoY + lineH
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(140, 115, 95, a255))
    nvgText(vg, popX + 24, infoY, "最佳", nil)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(80, 55, 35, a255))
    nvgText(vg, popX + popW - 24, infoY, formatTime(bestTimeMs), nil)

    -- 提示/洗牌使用
    infoY = infoY + lineH
    nvgTextAlign(vg, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(140, 115, 95, a255))
    nvgText(vg, popX + 24, infoY, "提示/洗牌", nil)
    nvgTextAlign(vg, NVG_ALIGN_RIGHT + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(80, 55, 35, a255))
    nvgText(vg, popX + popW - 24, infoY,
        tostring(board.hintsUsed) .. "/" .. tostring(board.shufflesUsed), nil)

    -- 按钮区
    local btnW, btnH = 200, 42
    local btnGap = 10

    local btnVisible = true
    if cel and cel.elapsed < 0.5 then btnVisible = false end

    local buttons = {}
    if btnVisible then
        local btnAlpha = a255
        if cel and cel.elapsed < 0.8 then
            btnAlpha = math.floor(math.min(1, (cel.elapsed - 0.5) / 0.3) * dAlpha * 255)
        end

        local btnDefs = {}
        if isStoryline then
            btnDefs[#btnDefs + 1] = {
                label = "完成关卡", action = "back",
                bg = { 75, 180, 100 }, bgHi = { 110, 210, 130 },
                fg = { 255, 255, 255 }, shadow = { 45, 130, 65 }, isPrimary = true,
            }
            btnDefs[#btnDefs + 1] = {
                label = "再来一次", action = "retry",
                bg = { 235, 170, 65 }, bgHi = { 250, 200, 110 },
                fg = { 100, 65, 15 }, shadow = { 195, 130, 40 }, isPrimary = false,
            }
        else
            if hasNextLevel then
                btnDefs[#btnDefs + 1] = {
                    label = "下一关", action = "next_level",
                    bg = { 255, 140, 66 }, bgHi = { 255, 175, 110 },
                    fg = { 255, 255, 255 }, shadow = { 200, 100, 35 }, isPrimary = true,
                }
            end
            btnDefs[#btnDefs + 1] = {
                label = "再来一次", action = "retry",
                bg = { 235, 170, 65 }, bgHi = { 250, 200, 110 },
                fg = { 100, 65, 15 }, shadow = { 195, 130, 40 }, isPrimary = false,
            }
            btnDefs[#btnDefs + 1] = {
                label = "返回", action = "back",
                bg = { 220, 215, 205 }, bgHi = { 240, 235, 228 },
                fg = { 100, 90, 75 }, shadow = { 185, 178, 165 }, isPrimary = false,
            }
        end

        local totalBtnH = #btnDefs * btnH + (#btnDefs - 1) * btnGap
        local btnStartY = popY + popH - totalBtnH - 18
        local btnX = popX + (popW - btnW) / 2

        for i, def in ipairs(btnDefs) do
            local by = btnStartY + (i - 1) * (btnH + btnGap)

            nvgBeginPath(vg)
            nvgRoundedRect(vg, btnX, by + 2, btnW, btnH, 8)
            nvgFillColor(vg, nvgRGBA(def.shadow[1], def.shadow[2], def.shadow[3],
                math.floor(btnAlpha * 0.6)))
            nvgFill(vg)

            nvgBeginPath(vg)
            nvgRoundedRect(vg, btnX, by, btnW, btnH, 8)
            local btnPaint = nvgLinearGradient(vg, btnX, by, btnX, by + btnH,
                nvgRGBA(def.bgHi[1], def.bgHi[2], def.bgHi[3], btnAlpha),
                nvgRGBA(def.bg[1], def.bg[2], def.bg[3], btnAlpha))
            nvgFillPaint(vg, btnPaint)
            nvgFill(vg)

            nvgBeginPath(vg)
            nvgRoundedRect(vg, btnX + 4, by + 2, btnW - 8, btnH * 0.35, 4)
            nvgFillColor(vg, nvgRGBA(255, 255, 255, math.floor(btnAlpha * 0.2)))
            nvgFill(vg)

            if def.isPrimary then
                nvgBeginPath(vg)
                nvgRoundedRect(vg, btnX, by, btnW, btnH, 8)
                nvgStrokeColor(vg, nvgRGBA(255, 180, 100, math.floor(btnAlpha * 0.5)))
                nvgStrokeWidth(vg, 1.5)
                nvgStroke(vg)
            end

            nvgFontSize(vg, 17)
            nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
            nvgFillColor(vg, nvgRGBA(def.fg[1], def.fg[2], def.fg[3], btnAlpha))
            nvgText(vg, btnX + btnW / 2, by + btnH / 2, def.label, nil)

            buttons[i] = { x = btnX, y = by, w = btnW, h = btnH, action = def.action }
        end
    end

    nvgRestore(vg)

    -- 彩带（最上层）
    if cel then
        celebrationFx.drawConfetti(vg, cel, screenH)
    end

    return buttons
end

--- 绘制失败弹窗
---@param vg userdata
---@param screenW number
---@param screenH number
---@param board table
---@return table[] buttons
function M.drawFailed(vg, screenW, screenH, board)
    -- 半透明遮罩
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 140))
    nvgFill(vg)

    local popW = math.min(260, screenW - 40)
    local popH = 220
    local cx = screenW / 2
    local popX = (screenW - popW) / 2
    local popY = (screenH - popH) / 2

    -- 阴影
    nvgBeginPath(vg)
    nvgRoundedRect(vg, popX + 2, popY + 3, popW, popH, 16)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, 25))
    nvgFill(vg)

    -- 背景
    nvgBeginPath(vg)
    nvgRoundedRect(vg, popX, popY, popW, popH, 16)
    nvgFillColor(vg, nvgRGBA(255, 252, 245, 250))
    nvgFill(vg)

    -- 红色顶部色带
    nvgBeginPath(vg)
    nvgRoundedRect(vg, popX, popY, popW, 60, 16)
    local failPaint = nvgLinearGradient(vg, popX, popY, popX + popW, popY,
        nvgRGBA(240, 90, 90, 235), nvgRGBA(255, 130, 100, 235))
    nvgFillPaint(vg, failPaint)
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgRect(vg, popX, popY + 44, popW, 16)
    nvgFillPaint(vg, failPaint)
    nvgFill(vg)

    nvgFontFace(vg, "sans")
    nvgFontSize(vg, 26)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
    nvgText(vg, cx, popY + 26, "时间耗尽", nil)

    -- 剩余信息
    nvgFontSize(vg, 17)
    nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(140, 115, 95, 255))
    nvgText(vg, cx, popY + 80, "还剩 " .. tostring(board.remainPairs) .. " 对未消除", nil)

    -- 按钮
    local btnW, btnH = 200, 42
    local btnGap = 12
    local btnX = popX + (popW - btnW) / 2
    local buttons = {}

    local btnDefs = {
        { label = "再试一次", action = "retry",
          bg = { 255, 140, 66 }, bgHi = { 255, 175, 110 },
          fg = { 255, 255, 255 }, shadow = { 200, 100, 35 } },
        { label = "返回", action = "back",
          bg = { 235, 225, 215 }, bgHi = { 245, 238, 230 },
          fg = { 100, 80, 60 }, shadow = { 200, 188, 175 } },
    }

    local totalBtnH = #btnDefs * btnH + (#btnDefs - 1) * btnGap
    local btnStartY = popY + popH - totalBtnH - 18

    for i, def in ipairs(btnDefs) do
        local by = btnStartY + (i - 1) * (btnH + btnGap)

        nvgBeginPath(vg)
        nvgRoundedRect(vg, btnX, by + 2, btnW, btnH, 8)
        nvgFillColor(vg, nvgRGBA(def.shadow[1], def.shadow[2], def.shadow[3], 150))
        nvgFill(vg)

        nvgBeginPath(vg)
        nvgRoundedRect(vg, btnX, by, btnW, btnH, 8)
        local btnPaint = nvgLinearGradient(vg, btnX, by, btnX, by + btnH,
            nvgRGBA(def.bgHi[1], def.bgHi[2], def.bgHi[3], 255),
            nvgRGBA(def.bg[1], def.bg[2], def.bg[3], 255))
        nvgFillPaint(vg, btnPaint)
        nvgFill(vg)

        nvgFontSize(vg, 17)
        nvgTextAlign(vg, NVG_ALIGN_CENTER + NVG_ALIGN_MIDDLE)
        nvgFillColor(vg, nvgRGBA(def.fg[1], def.fg[2], def.fg[3], 255))
        nvgText(vg, btnX + btnW / 2, by + btnH / 2, def.label, nil)

        buttons[i] = { x = btnX, y = by, w = btnW, h = btnH, action = def.action }
    end

    return buttons
end

return M
