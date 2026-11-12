--- 剧情对话系统 - NanoVG 渲染
--- 职责：打字机效果对话框、NPC/主角立绘、点击推进、序列回调
local logger = require("shared.utils.logger")
local kinsoku = require("shared.utils.kinsoku")
local ANIM = require("shared.constants.animations")
local Layout = require("shared.constants.layout")
local Art = require("shared.constants.art")
local Paper = require("shared.components.story-paper")
local Pen = require("shared.components.handdrawn")

local M = {}
local MODULE = "dialogue"

-- ============================================================================
-- 角色数据
-- ============================================================================

--- 说话者名称 → 角色 role 映射
local SPEAKER_ROLES = {
    ["慧慧"] = "owl",
    ["泡泡"] = "cat",
    ["糖糖"] = "rabbit",
    ["豆豆"] = "raccoon",
    ["火火"] = "fox",
}

--- 角色 role → 名称颜色 { r, g, b }（引用共享常量）
local Colors = require("shared.constants.colors")
local ROLE_COLORS = Colors.character

-- ============================================================================
-- 内部状态
-- ============================================================================

local active_ = false

---@type table<string, string>|nil 模板变量（关卡数据）
local levelVars_ = nil

---@type table[]|nil 对话行列表 { speaker, text }
local lines_ = nil
---@type number 当前行索引（1-based）
local lineIdx_ = 0
---@type number 打字机已显示字符数
local charCount_ = 0
---@type number 打字机累计时间
local charTimer_ = 0
---@type boolean 当前行是否已完整显示
local lineComplete_ = false

--- 打字速度（秒/字符）
local CHAR_SPEED = ANIM.DIALOGUE_CHAR_SPEED

---@type table<string, number> role -> nvg image handle
local npcImages_ = nil
---@type number fox image handle
local foxImage_ = -1
---@type function|nil 全部对话完成回调
local onComplete_ = nil
---@type string NanoVG 字体名
local fontName_ = "adv"

-- 音效回调（由调用方通过 opts 注入）
---@type function|nil 每个字符显示时触发 (role: string)
local onTick_ = nil
---@type function|nil 推进到下一行时触发
local onAdvance_ = nil
---@type function|nil 全部对话完成时触发（在 onComplete_ 之前）
local onDialogueComplete_ = nil
---@type function|nil 每行开始时触发 (role: string) —— 用于播放角色语音
local onLineStart_ = nil

-- 避头尾处理缓存
---@type string|nil 当前行经过避头尾处理后的文本
local wrappedText_ = nil
---@type number 缓存的文本区宽度（宽度变化时需重新处理）
local wrappedTextAreaW_ = 0
---@type number 缓存的行索引
local wrappedLineIdx_ = 0

-- 对话框布局常量
local BOX_MARGIN_BOTTOM = 24
local BOX_PADDING = 20
local PORTRAIT_MARGIN = 14
local NAME_FONT_SIZE = 21
local TEXT_FONT_SIZE = Layout.FONT_SIZE_TITLE     -- 对话字号
local HINT_FONT_SIZE = Layout.FONT_SIZE_CAPTION   -- 提示字号
local TEXT_LINE_HEIGHT = TEXT_FONT_SIZE * 1.5
local C = Art.colors

local function resetWrap()
    wrappedText_, wrappedTextAreaW_, wrappedLineIdx_ = nil, 0, 0
end

-- 动画时间戳
local animTime_ = 0

-- ============================================================================
-- UTF-8 子串工具
-- ============================================================================

--- 计算 UTF-8 字符串的字符数
---@param s string
---@return number
local function utf8Len(s)
    local count = 0
    local i = 1
    local len = #s
    while i <= len do
        local b = string.byte(s, i)
        if b < 0x80 then i = i + 1
        elseif b < 0xE0 then i = i + 2
        elseif b < 0xF0 then i = i + 3
        else i = i + 4 end
        count = count + 1
    end
    return count
end

--- 取 UTF-8 字符串的前 n 个字符
---@param s string
---@param n number
---@return string
local function utf8Sub(s, n)
    local count = 0
    local i = 1
    local len = #s
    while i <= len and count < n do
        local b = string.byte(s, i)
        if b < 0x80 then i = i + 1
        elseif b < 0xE0 then i = i + 2
        elseif b < 0xF0 then i = i + 3
        else i = i + 4 end
        count = count + 1
    end
    return string.sub(s, 1, i - 1)
end

-- ============================================================================
-- 模板变量替换
-- ============================================================================

--- 将文本中的 {key} 占位符替换为 levelVars 中的值
---@param text string
---@param vars table<string, string|number>
---@return string
local function resolveVars(text, vars)
    return (text:gsub("{(%w+)}", function(key)
        local v = vars[key]
        return v ~= nil and tostring(v) or ("{" .. key .. "}")
    end))
end

--- 对对话行列表做模板替换，返回新列表（不修改原始数据）
---@param lines table[]
---@param vars table<string, string|number>|nil
---@return table[]
local function resolveDialogueLines(lines, vars)
    if not vars then return lines end
    local resolved = {}
    for i, line in ipairs(lines) do
        resolved[i] = { speaker = line.speaker, text = resolveVars(line.text, vars) }
    end
    return resolved
end

-- ============================================================================
-- 公开接口
-- ============================================================================

--- 开始一段对话
---@param lines table[] 对话行 { { speaker="xxx", text="yyy" }, ... }
---@param opts table 选项 { npcImages, foxImage, fontName, onComplete, levelVars }
function M.start(lines, opts)
    if not lines or #lines == 0 then
        logger.warn(MODULE, "start", "empty lines")
        if opts and opts.onComplete then opts.onComplete() end
        return
    end

    levelVars_ = opts and opts.levelVars or nil
    lines_ = resolveDialogueLines(lines, levelVars_)
    npcImages_ = opts and opts.npcImages or {}
    foxImage_ = opts and opts.foxImage or -1
    fontName_ = opts and opts.fontName or "adv"
    onComplete_ = opts and opts.onComplete or nil

    -- 音效回调
    onTick_ = opts and opts.onTick or nil
    onAdvance_ = opts and opts.onAdvance or nil
    onDialogueComplete_ = opts and opts.onDialogueComplete or nil
    onLineStart_ = opts and opts.onLineStart or nil

    lineIdx_ = 1
    charCount_ = 0
    charTimer_ = 0
    lineComplete_ = false
    resetWrap()
    animTime_ = 0
    active_ = true

    -- 触发首行角色语音
    local firstRole = SPEAKER_ROLES[lines[1].speaker] or "fox"
    if onLineStart_ then onLineStart_(firstRole) end

    logger.info(MODULE, "start", "lines=" .. #lines)
end

--- 是否正在显示对话
---@return boolean
function M.isActive()
    return active_
end

--- 处理点击（推进对话）
---@return boolean 是否消费了点击事件
function M.handleClick()
    if not active_ then return false end

    if not lineComplete_ then
        -- 打字机进行中 → 立即显示完整文字
        local line = lines_[lineIdx_]
        if line then
            local srcText = wrappedText_ or line.text
            charCount_ = utf8Len(srcText)
            lineComplete_ = true
        end
    else
        -- 已完整显示 → 进入下一行
        lineIdx_ = lineIdx_ + 1
        if lineIdx_ > #lines_ then
            -- 全部对话完成
            active_ = false
            lines_ = nil
            if onDialogueComplete_ then onDialogueComplete_() end
            if onComplete_ then
                local cb = onComplete_
                onComplete_ = nil
                cb()
            end
        else
            -- 推进到下一行
            if onAdvance_ then onAdvance_() end
            charCount_ = 0
            charTimer_ = 0
            lineComplete_ = false
            resetWrap()
            -- 触发新行角色语音
            local nextLine = lines_[lineIdx_]
            if nextLine and onLineStart_ then
                local role = SPEAKER_ROLES[nextLine.speaker] or "fox"
                onLineStart_(role)
            end
        end
    end

    return true
end

--- 每帧更新打字机
---@param dt number
function M.update(dt)
    if not active_ then return end

    animTime_ = animTime_ + dt

    if lineComplete_ then return end

    local line = lines_[lineIdx_]
    if not line then return end

    -- 使用避头尾处理后的文本计算总字符数（含插入的 \n）
    local srcText = wrappedText_ or line.text
    local totalChars = utf8Len(srcText)
    charTimer_ = charTimer_ + dt
    local newCount = math.floor(charTimer_ / CHAR_SPEED)
    if newCount > totalChars then newCount = totalChars end

    if newCount ~= charCount_ then
        charCount_ = newCount
        -- 打字机音效
        if onTick_ then
            local role = SPEAKER_ROLES[line.speaker] or "fox"
            onTick_(role)
        end
    end

    if charCount_ >= totalChars then
        lineComplete_ = true
    end
end

--- 渲染对话框（在 NanoVG BeginFrame/EndFrame 之间调用）
---@param vg userdata NanoVG 上下文
---@param screenW number 逻辑宽度
---@param screenH number 逻辑高度
function M.render(vg, screenW, screenH)
    if not active_ or not lines_ then return end

    local line = lines_[lineIdx_]
    if not line then return end

    local role = SPEAKER_ROLES[line.speaker] or "fox"
    local isFox = (role == "fox")
    local nameColor = ROLE_COLORS[role] or { 200, 140, 50 }

    nvgSave(vg)
    Paper.backdrop(vg, screenW, screenH)

    local boxX, boxW, safe = Paper.width(screenW)
    local portraitW = math.max(78, math.min(112, boxW * 0.28))
    local textAreaW = boxW - BOX_PADDING * 2 - portraitW - PORTRAIT_MARGIN
    local textAreaX = boxX + BOX_PADDING + (isFox and 0 or portraitW + PORTRAIT_MARGIN)

    -- 先用完整台词量行，再放置卡片；打字过程中高度不变。
    if wrappedLineIdx_ ~= lineIdx_ or wrappedTextAreaW_ ~= textAreaW then
        nvgFontFace(vg, fontName_)
        nvgFontSize(vg, TEXT_FONT_SIZE)
        wrappedText_ = kinsoku.wrapNvg(vg, line.text, textAreaW)
        wrappedLineIdx_, wrappedTextAreaW_ = lineIdx_, textAreaW
    end
    local textH = Paper.lineCount(wrappedText_) * TEXT_LINE_HEIGHT
    local boxH = BOX_PADDING + 38 + math.max(82, textH) + 64
    local boxY = screenH - safe.bottom - BOX_MARGIN_BOTTOM - boxH
    Paper.card(vg, boxX, boxY, boxW, boxH)

    local portraitX = isFox and boxX + boxW - BOX_PADDING - portraitW or boxX + BOX_PADDING
    local imgHandle = isFox and foxImage_ or (npcImages_ and npcImages_[role])
    Paper.portrait(vg, imgHandle, portraitX, boxY + 30, portraitW, boxH - 54)

    local nameY = boxY + BOX_PADDING
    Paper.text(vg, fontName_, textAreaX, nameY, line.speaker, NAME_FONT_SIZE)
    -- 名字只用一笔角色色作识别，避免再叠一个标签框。
    nvgBeginPath(vg)
    nvgMoveTo(vg, textAreaX + 1, nameY + 28)
    nvgQuadTo(vg, textAreaX + 22, nameY + 29, textAreaX + 43, nameY + 27)
    nvgStrokeColor(vg, nvgRGBA(nameColor[1], nameColor[2], nameColor[3], 160))
    nvgStrokeWidth(vg, 4)
    nvgLineCap(vg, NVG_ROUND)
    nvgStroke(vg)
    Paper.text(vg, fontName_, textAreaX + textAreaW, nameY + 4,
        string.format("%d / %d", lineIdx_, #lines_), 12, C.muted, NVG_ALIGN_RIGHT)

    local textY = boxY + BOX_PADDING + 38
    local displayText = lineComplete_ and wrappedText_ or utf8Sub(wrappedText_, charCount_)
    Paper.paragraph(vg, fontName_, textAreaX, textY, displayText, TEXT_FONT_SIZE, TEXT_LINE_HEIGHT)

    local footerY = boxY + boxH - 48
    Paper.rule(vg, textAreaX, footerY, textAreaW)
    local hint = lineComplete_ and (lineIdx_ < #lines_ and "点击继续" or "点击关闭") or "轻点显示全部"
    Paper.text(vg, fontName_, textAreaX, footerY + 15, hint, HINT_FONT_SIZE, C.muted)
    if lineComplete_ then
        local arrowX, arrowY = textAreaX + textAreaW - 29, footerY + 9
        Pen.plaque(vg, arrowX, arrowY, 29, 28, C.orange, 1.8)
        nvgBeginPath(vg)
        nvgMoveTo(vg, arrowX + 11, arrowY + 8)
        nvgLineTo(vg, arrowX + 17, arrowY + 14)
        nvgLineTo(vg, arrowX + 11, arrowY + 20)
        nvgStrokeColor(vg, Pen.color(C.ink))
        nvgStrokeWidth(vg, 2.5)
        nvgStroke(vg)
    end
    nvgRestore(vg)
end

--- 强制停止对话（不触发回调）
function M.stop()
    resetWrap()
    active_ = false
    lines_ = nil
    onComplete_ = nil
    onTick_ = nil
    onAdvance_ = nil
    onDialogueComplete_ = nil
    onLineStart_ = nil
end

return M
