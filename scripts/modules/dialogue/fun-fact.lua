--- 趣味小知识卡片 - NanoVG 渲染
--- 职责：通关后弹出 NPC 动物小知识的气泡卡片
local logger = require("shared.utils.logger")
local kinsoku = require("shared.utils.kinsoku")
local Paper = require("shared.components.story-paper")
local Art = require("shared.constants.art")

local M = {}
local MODULE = "fun-fact"

local SPEAKER_ROLES = {
    ["慧慧"] = "owl",
    ["泡泡"] = "cat",
    ["糖糖"] = "rabbit",
    ["豆豆"] = "raccoon",
    ["火火"] = "fox",
}

-- ============================================================================
-- 内部状态
-- ============================================================================

local active_ = false
---@type table|nil { speaker, text }
local data_ = nil
---@type table<string, number>|nil
local npcImages_ = nil
---@type number
local foxImage_ = -1
---@type function|nil
local onDismiss_ = nil
---@type string
local fontName_ = "adv"
---@type function|nil 显示时音效回调
local onShow_ = nil
---@type function|nil 关闭时音效回调
local onDismissSound_ = nil

-- 淡入动画进度 0→1
local fadeIn_ = 0
local wrappedText_, wrappedWidth_ = nil, 0
local PADDING = 22
local TEXT_FONT_SIZE = 18
local LINE_HEIGHT = 27
local BUTTON_W, BUTTON_H = 120, 52

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 显示小知识卡片
---@param factData table { speaker, text }
---@param opts table { npcImages, foxImage, fontName, onDismiss }
function M.show(factData, opts)
    if not factData or not factData.text then
        logger.warn(MODULE, "show", "no fact data")
        if opts and opts.onDismiss then opts.onDismiss() end
        return
    end

    data_ = factData
    npcImages_ = opts and opts.npcImages or {}
    foxImage_ = opts and opts.foxImage or -1
    fontName_ = opts and opts.fontName or "adv"
    onDismiss_ = opts and opts.onDismiss or nil
    onShow_ = opts and opts.onShow or nil
    onDismissSound_ = opts and opts.onDismissSound or nil

    wrappedText_, wrappedWidth_ = nil, 0
    fadeIn_ = 0
    active_ = true

    -- 触发显示音效
    if onShow_ then onShow_() end

    logger.info(MODULE, "show", "speaker=" .. factData.speaker)
end

--- 是否正在显示
---@return boolean
function M.isActive()
    return active_
end

--- 处理点击
---@param lx number
---@param ly number
---@return boolean 是否消费
function M.handleClick(lx, ly)
    if not active_ then return false end

    -- 统一关闭逻辑（点击卡片或遮罩外均可关闭）
    active_ = false
    data_ = nil
    if onDismissSound_ then onDismissSound_() end
    if onDismiss_ then
        local cb = onDismiss_
        onDismiss_ = nil
        cb()
    end
    return true
end

--- 每帧更新
---@param dt number
function M.update(dt)
    if not active_ then return end
    fadeIn_ = math.min(1, fadeIn_ + dt * 4)  -- 0.25 秒淡入
end

--- 渲染卡片
---@param vg userdata
---@param screenW number
---@param screenH number
function M.render(vg, screenW, screenH)
    if not active_ or not data_ then return end

    local role = SPEAKER_ROLES[data_.speaker] or "owl"
    local cardX, cardW, safe = Paper.width(screenW, 380)
    local textW = cardW - PADDING * 2
    nvgSave(vg)
    nvgGlobalAlpha(vg, fadeIn_)
    Paper.backdrop(vg, screenW, screenH)

    if not wrappedText_ or wrappedWidth_ ~= textW then
        nvgFontFace(vg, fontName_)
        nvgFontSize(vg, TEXT_FONT_SIZE)
        wrappedText_ = kinsoku.wrapNvg(vg, data_.text, textW)
        wrappedWidth_ = textW
    end
    local textH = Paper.lineCount(wrappedText_) * LINE_HEIGHT
    local cardH = PADDING + 88 + 22 + textH + 26 + BUTTON_H + PADDING
    local cardY = safe.top + (screenH - safe.top - safe.bottom - cardH) / 2 + (1 - fadeIn_) * 20
    Paper.card(vg, cardX, cardY, cardW, cardH)

    local image = role == "fox" and foxImage_ or (npcImages_ and npcImages_[role])
    Paper.portrait(vg, image, cardX + PADDING, cardY + PADDING, 80, 88)
    Paper.text(vg, fontName_, cardX + PADDING + 96, cardY + PADDING + 15, "你知道吗？", 22)
    Paper.text(vg, fontName_, cardX + PADDING + 96, cardY + PADDING + 49,
        (data_.speaker or "伙伴") .. "的小知识", 13, Art.colors.muted)
    Paper.rule(vg, cardX + PADDING, cardY + PADDING + 98, textW)
    Paper.paragraph(vg, fontName_, cardX + PADDING, cardY + PADDING + 110,
        wrappedText_, TEXT_FONT_SIZE, LINE_HEIGHT)
    Paper.button(vg, fontName_, cardX + (cardW - BUTTON_W) / 2,
        cardY + cardH - PADDING - BUTTON_H, BUTTON_W, BUTTON_H, "记住啦！")
    nvgRestore(vg)
end

--- 强制关闭
function M.stop()
    wrappedText_, wrappedWidth_ = nil, 0
    active_ = false
    data_ = nil
    onDismiss_ = nil
    onShow_ = nil
    onDismissSound_ = nil
end

return M
