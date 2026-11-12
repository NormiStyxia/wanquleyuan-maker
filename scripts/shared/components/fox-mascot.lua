--- 狐狸立绘 + 夸奖气泡组件
--- 在大厅和游戏内左下角显示狐狸立绘，操作成功时概率弹出夸奖气泡
local logger = require("shared.utils.logger")
local OutfitManager = require("shared.outfit-manager")
local kinsoku = require("shared.utils.kinsoku")
local ANIM = require("shared.constants.animations")

local Art = require("shared.constants.art")
local Pen = require("shared.components.handdrawn")

local M = {}
local MODULE = "fox-mascot"

-- ============================================================================
-- 配置
-- ============================================================================
local TRIGGER_CHANCE  = 0.25   -- 触发概率
local COOLDOWN_SEC    = 8.0    -- 冷却时间（秒）
local POP_IN_DUR      = 0.15   -- 弹出动画时长
local SHOW_DUR        = 2.5    -- 气泡显示时长（夸奖）
local CHAT_SHOW_DUR   = 4.0    -- 气泡显示时长（聊天，文字更长）
local FADE_OUT_DUR    = 0.4    -- 淡出动画时长
local CHAT_COOLDOWN   = 2.0    -- 聊天冷却时间（秒，比夸奖短）
local FLOAT_AMP       = 2.0    -- 狐狸浮动幅度（像素）
local FLOAT_SPEED     = ANIM.FOX_FLOAT_SPEED    -- 浮动速度

local FOX_SIZE        = 160    -- 狐狸立绘逻辑尺寸
local FOX_MARGIN_L    = -21    -- 左边距
local FOX_MARGIN_B    = 4      -- 底边距
local CHAT_MAX_WIDTH  = 180    -- 聊天文字最大宽度（像素）
local CHAT_FONT_SIZE  = 14     -- 聊天字体大小（比夸奖稍小以容纳更多文字）
local TEXT_OFFSET_X   = 6      -- 文字相对狐狸右侧的 X 偏移
local TEXT_MARGIN_B   = 4      -- 文字底部距狐狸脚底的边距
local TEXT_BG_PAD_H   = 8      -- 文字背景水平内边距
local TEXT_BG_PAD_V   = 5      -- 文字背景垂直内边距
local TEXT_BG_RADIUS  = 6      -- 文字背景圆角

-- 夸奖文本由 OutfitManager.getPraises() 动态提供（根据当前皮肤身份）

-- ============================================================================
-- 内部状态
-- ============================================================================
---@type number NanoVG 图片句柄（-1 = 未加载）
local foxImg_ = -1
---@type userdata|nil 创建 foxImg_ 时使用的 NanoVG 上下文（防止跨上下文误删）
local vgCtx_ = nil
---@type number 字体句柄
local fontHandle_ = -1
---@type string 状态机 "idle"|"pop_in"|"show"|"fade_out"
local state_ = "idle"
---@type number 状态计时器
local stateTimer_ = 0
---@type number 冷却计时器（从上次气泡消失后计时）
local cooldownTimer_ = COOLDOWN_SEC  -- 初始就绪
---@type number 全局动画时间
local animTime_ = 0
---@type string 当前夸奖文本
local currentText_ = ""
---@type number 上次使用的文本索引（避免连续重复）
local lastTextIdx_ = 0
---@type boolean 是否已初始化
local inited_ = false
---@type boolean 本轮游戏首次触发（必定夸奖）
local firstTrigger_ = true
---@type boolean 皮肤变更脏标记（云端数据到达后置 true，渲染时刷新贴图）
local skinDirty_ = false
---@type boolean 当前气泡是否为聊天模式（影响显示时长和排版）
local isChatBubble_ = false
-- 音效回调（由调用方通过 setSfxCallbacks 设置）
---@type function|nil 夸奖气泡弹出时触发
local onPraisePop_ = nil
---@type function|nil 聊天气泡弹出时触发
local onChatPop_ = nil
---@type number 上次使用的聊天文本索引
local lastChatIdx_ = 0
---@type number 缓存的 screenW/screenH/bottomOffset（用于 hitTest）
local cachedScreenW_ = 0
local cachedScreenH_ = 0
local cachedBotOff_ = 0

-- 文本测量缓存（避免每帧调用 nvgTextBoxBounds / nvgTextBounds）
---@type any
local textMeasureCache_ = {
    text = "",           -- 上次测量的文本
    isChat = false,      -- 上次测量时的模式
    textW = 0,           -- 缓存的文本宽度
    textH = 0,           -- 缓存的文本高度
    dirty = true,        -- 需要重新测量
}

-- ============================================================================
-- 内部函数
-- ============================================================================

--- 随机选一条不重复的夸奖（从当前皮肤专属台词表中选取）
local function pickPraise()
    local praises = OutfitManager.getPraises()
    local idx
    repeat
        idx = math.random(1, #praises)
    until idx ~= lastTextIdx_ or #praises <= 1
    lastTextIdx_ = idx
    return praises[idx]
end

--- 随机选一条不重复的聊天文本（从当前皮肤专属台词表中选取）
local function pickChat()
    local chats = OutfitManager.getChats()
    local idx
    repeat
        idx = math.random(1, #chats)
    until idx ~= lastChatIdx_ or #chats <= 1
    lastChatIdx_ = idx
    return chats[idx]
end

--- 设置当前气泡文本（同时标记测量缓存为脏）
local function setCurrentText(text, isChat)
    currentText_ = text
    isChatBubble_ = isChat
    textMeasureCache_.dirty = true
end

--- 弹簧缩放曲线：0→1.1→1.0
---@param t number 0~1
---@return number
local function springScale(t)
    if t < 0.7 then
        return (t / 0.7) * 1.1
    else
        return 1.1 - 0.1 * ((t - 0.7) / 0.3)
    end
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 初始化（加载 NanoVG 图片和字体，每次页面/游戏激活时调用）
---@param vg userdata NanoVG 上下文
function M.init(vg)
    if not vg then return end

    -- 同一上下文且图片已有效，跳过重复初始化（避免 create→delete→create 损坏纹理）
    if inited_ and vgCtx_ == vg and foxImg_ >= 0 then
        return
    end

    -- 创建新图片（不删除旧句柄，旧句柄随上下文销毁时自动回收）
    local newImg = nvgCreateImage(vg, OutfitManager.getTexturePath(), 0)
    if newImg >= 0 then
        foxImg_ = newImg
        vgCtx_ = vg
    else
        -- 切换上下文后旧句柄无效，必须重置
        if vgCtx_ ~= vg then
            foxImg_ = -1
            vgCtx_ = vg
        end
        logger.warn(MODULE, "init", "failed to load fox image: " .. OutfitManager.getTexturePath())
    end

    -- 尝试复用已有字体，失败则创建
    fontHandle_ = nvgCreateFont(vg, "fox-mascot", "Fonts/LongZhuTi-Regular.ttf")

    inited_ = true
    firstTrigger_ = true
    -- 重置状态机，防止页面切换时卡在非 idle 状态
    state_ = "idle"
    stateTimer_ = 0
    cooldownTimer_ = COOLDOWN_SEC  -- 立即就绪
    currentText_ = ""
    isChatBubble_ = false
    logger.info(MODULE, "init", "fox mascot initialized")
end

--- 清理资源（页面/游戏销毁前调用）
function M.cleanup()
    foxImg_ = -1
    vgCtx_ = nil
    fontHandle_ = -1
    inited_ = false
    state_ = "idle"
    stateTimer_ = 0
    onPraisePop_ = nil
    onChatPop_ = nil
end

--- 刷新皮肤贴图（换装后调用，需要传入当前 NanoVG 上下文）
--- 不删除旧句柄，避免因共享纹理导致新句柄被损坏（旧句柄随上下文销毁时自动回收）
---@param vg userdata NanoVG 上下文
function M.refreshSkin(vg)
    if not vg or not inited_ then return end
    local newImg = nvgCreateImage(vg, OutfitManager.getTexturePath(), 0)
    if newImg >= 0 then
        foxImg_ = newImg
        vgCtx_ = vg
        logger.info(MODULE, "refreshSkin", "skin updated to: " .. OutfitManager.getCurrent())
    else
        logger.warn(MODULE, "refreshSkin", "failed to load new skin image, keeping old")
    end
end

--- 重置气泡状态（切换页面/游戏时调用，保留 CD 计时）
function M.reset()
    state_ = "idle"
    stateTimer_ = 0
    currentText_ = ""
    textMeasureCache_.dirty = true
end

--- 每帧更新
---@param dt number
function M.update(dt)
    if not inited_ then return end

    animTime_ = animTime_ + dt

    -- 冷却计时
    if state_ == "idle" then
        cooldownTimer_ = cooldownTimer_ + dt
    end

    -- 状态机推进
    if state_ == "pop_in" then
        stateTimer_ = stateTimer_ + dt
        if stateTimer_ >= POP_IN_DUR then
            state_ = "show"
            stateTimer_ = 0
        end
    elseif state_ == "show" then
        stateTimer_ = stateTimer_ + dt
        local showDur = isChatBubble_ and CHAT_SHOW_DUR or SHOW_DUR
        if stateTimer_ >= showDur then
            state_ = "fade_out"
            stateTimer_ = 0
        end
    elseif state_ == "fade_out" then
        stateTimer_ = stateTimer_ + dt
        if stateTimer_ >= FADE_OUT_DUR then
            state_ = "idle"
            stateTimer_ = 0
            cooldownTimer_ = 0  -- 重新开始冷却
        end
    end
end

--- 设置音效回调（由调用方注入）
---@param callbacks table { onPraisePop, onChatPop }
function M.setSfxCallbacks(callbacks)
    if callbacks then
        onPraisePop_ = callbacks.onPraisePop
        onChatPop_ = callbacks.onChatPop
    end
end

--- 通知操作成功（内部判断概率和 CD）
function M.notifySuccess()
    if not inited_ then return end
    if state_ ~= "idle" then return end
    if cooldownTimer_ < COOLDOWN_SEC then return end

    -- 首次必定触发，之后按概率
    if firstTrigger_ then
        firstTrigger_ = false
    else
        if math.random() > TRIGGER_CHANCE then return end
    end

    -- 触发气泡
    setCurrentText(pickPraise(), false)
    state_ = "pop_in"
    stateTimer_ = 0
    if onPraisePop_ then onPraisePop_() end
    logger.info(MODULE, "notifySuccess", "praise: " .. currentText_)
end

--- 触发聊天气泡（点击立绘时调用，无概率判断）
--- 气泡显示中再次点击：立即切换到新的聊天内容
function M.notifyChat()
    if not inited_ then return end

    -- 气泡正在显示时，直接换一条新内容并重置显示计时
    if state_ == "show" and isChatBubble_ then
        setCurrentText(pickChat(), true)
        stateTimer_ = 0
        logger.info(MODULE, "notifyChat", "refresh chat: " .. currentText_)
        return
    end

    -- 弹出/淡出动画中，忽略点击
    if state_ == "pop_in" or state_ == "fade_out" then return end

    -- idle 状态，检查冷却
    if cooldownTimer_ < CHAT_COOLDOWN then return end

    setCurrentText(pickChat(), true)
    state_ = "pop_in"
    stateTimer_ = 0
    logger.info(MODULE, "notifyChat", "chat: " .. currentText_)
end

--- 显示指定文本的聊天气泡（用于场景切换时的主动问候）
--- 跳过冷却检查，但不会打断正在播放的气泡
---@param text string 要显示的文本
function M.showMessage(text)
    if not inited_ then return end
    if not text or text == "" then return end

    -- 正在播放动画时不打断
    if state_ == "pop_in" or state_ == "fade_out" then return end
    -- 正在显示时也不打断（避免连续切换覆盖）
    if state_ == "show" then return end

    setCurrentText(text, true)
    state_ = "pop_in"
    stateTimer_ = 0
    if onChatPop_ then onChatPop_() end
    logger.info(MODULE, "showMessage", "message: " .. text)
end

--- 点击检测：判断坐标是否落在狐狸立绘区域内
---@param lx number 逻辑坐标 X
---@param ly number 逻辑坐标 Y
---@param screenW number 逻辑屏幕宽度
---@param screenH number 逻辑屏幕高度
---@param bottomOffset number|nil 底部预留空间（页签栏高度）
---@return boolean
function M.hitTest(lx, ly, screenW, screenH, bottomOffset, options)
    if not inited_ then return false end
    options = options or {}
    local foxSize = options.size or FOX_SIZE
    local botOff = bottomOffset or 0
    local foxX = options.marginLeft or FOX_MARGIN_L
    local foxY = screenH - botOff - FOX_MARGIN_B - foxSize
    -- 点击区域适当放大，方便触摸
    local padding = 10
    return lx >= (foxX - padding) and lx <= (foxX + foxSize + padding)
       and ly >= (foxY - padding) and ly <= (foxY + foxSize + padding)
end

--- 每帧渲染（在 nvgBeginFrame/nvgEndFrame 之间调用，在其他内容之后）
---@param vg userdata NanoVG 上下文
---@param screenW number 逻辑屏幕宽度
---@param screenH number 逻辑屏幕高度
---@param bottomOffset number|nil 底部预留空间（如页签栏高度），默认 0
function M.render(vg, screenW, screenH, bottomOffset, options)
    if not inited_ then return end

    -- 防御性检查：渲染上下文与创建图片的上下文不一致时，重新加载图片
    if foxImg_ < 0 or vgCtx_ ~= vg then
        local newImg = nvgCreateImage(vg, OutfitManager.getTexturePath(), 0)
        if newImg >= 0 then
            foxImg_ = newImg
            vgCtx_ = vg
        else
            return  -- 加载失败，跳过本帧渲染
        end
    end

    -- 云端皮肤到达后自动刷新贴图
    if skinDirty_ then
        skinDirty_ = false
        M.refreshSkin(vg)
    end

    options = options or {}
    local foxSize = options.size or FOX_SIZE
    local botOff = bottomOffset or 0

    -- 狐狸位置（左下角，底部预留 bottomOffset）
    local foxX = options.x or options.marginLeft or FOX_MARGIN_L
    local foxY = options.y or (screenH - botOff - FOX_MARGIN_B - foxSize)

    -- JSON 页面保留自己的立绘位置；默认调用仍沿用原浮动动画。
    local floatY = options.y and 0 or math.sin(animTime_ * FLOAT_SPEED) * FLOAT_AMP
    foxY = foxY + floatY

    if options.drawPortrait ~= false then
        local imgPaint = nvgImagePattern(vg,
            foxX, foxY, foxSize, foxSize,
            0, foxImg_, 1.0)
        nvgBeginPath(vg)
        nvgRect(vg, foxX, foxY, foxSize, foxSize)
        nvgFillPaint(vg, imgPaint)
        nvgFill(vg)
    end

    -- 气泡渲染
    if state_ == "idle" then return end

    local bubbleAlpha = 1.0
    local bubbleScale = 1.0

    if state_ == "pop_in" then
        local t = math.min(stateTimer_ / POP_IN_DUR, 1.0)
        bubbleScale = springScale(t)
        bubbleAlpha = t
    elseif state_ == "show" then
        bubbleScale = 1.0
        bubbleAlpha = 1.0
    elseif state_ == "fade_out" then
        local t = math.min(stateTimer_ / FADE_OUT_DUR, 1.0)
        bubbleAlpha = 1.0 - t
        bubbleScale = 1.0
    end

    if bubbleAlpha <= 0.01 then return end

    -- 选关页将气泡抬到角色右上方，为翻页区留出空间；其他页面沿用脚底对齐。
    local textX = foxX + foxSize + TEXT_OFFSET_X
    local foxBottom = foxY + foxSize  -- 狐狸脚底 Y 坐标
    local textBottom = foxBottom - TEXT_MARGIN_B - (options.bubbleBottomInset or 0)

    local bubbleMaxW = math.max(60, math.min(CHAT_MAX_WIDTH, screenW - textX - 16))
    if textMeasureCache_.maxW ~= bubbleMaxW then
        textMeasureCache_.maxW = bubbleMaxW
        textMeasureCache_.dirty = true
    end

    -- 测量文本尺寸（使用缓存，仅文本变化时重新测量）
    local fontSize = isChatBubble_ and CHAT_FONT_SIZE or 16
    nvgFontFace(vg, "fox-mascot")
    nvgFontSize(vg, fontSize)
    nvgTextAlign(vg, NVG_ALIGN_LEFT | NVG_ALIGN_TOP)

    if textMeasureCache_.dirty then
        textMeasureCache_.dirty = false
        textMeasureCache_.isChat = isChatBubble_

        if isChatBubble_ then
            -- 聊天模式：避头尾换行预处理
            local maxW = bubbleMaxW
            currentText_ = kinsoku.wrapNvg(vg, currentText_, maxW)
        end
        textMeasureCache_.text = currentText_

        if isChatBubble_ then
            -- 聊天模式：限宽换行
            local maxW = bubbleMaxW
            local bounds = nvgTextBoxBounds(vg, 0, 0, maxW, currentText_)
            local bxmin = bounds[1] or 0
            local bymin = bounds[2] or 0
            local bxmax = bounds[3] or maxW
            local bymax = bounds[4] or fontSize
            local measuredW = bxmax - bxmin
            local measuredH = bymax - bymin
            textMeasureCache_.textW = math.min(measuredW > 0 and measuredW or maxW, maxW)
            local lineH = fontSize * 1.35
            if measuredH > lineH then
                textMeasureCache_.textH = measuredH + fontSize * 0.3
            else
                textMeasureCache_.textH = lineH
            end
        else
            -- 夸奖模式：单行
            local w = nvgTextBounds(vg, 0, 0, currentText_) or 0
            if w < 1 then w = #currentText_ * fontSize * 0.5 end
            textMeasureCache_.textW = w
            textMeasureCache_.textH = fontSize * 1.2
        end
    end

    local textW = textMeasureCache_.textW
    local textH = textMeasureCache_.textH

    local textDrawY = textBottom - textH

    nvgSave(vg)
    nvgGlobalAlpha(vg, bubbleAlpha)

    -- 半透明背景
    local bgX = textX - TEXT_BG_PAD_H
    local bgY = textDrawY - TEXT_BG_PAD_V
    local bgW = textW + TEXT_BG_PAD_H * 2
    local bgH = textH + TEXT_BG_PAD_V * 2
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bgX, bgY, bgW, bgH, TEXT_BG_RADIUS)
    nvgFillColor(vg, options.handdrawn and Pen.color(Art.colors.paper) or nvgRGBA(0, 0, 0, math.floor(90 * bubbleAlpha)))
    nvgFill(vg)

    if options.handdrawn then
        nvgStrokeColor(vg, Pen.color(Art.colors.ink)); nvgStrokeWidth(vg, 2); nvgStroke(vg)
    end

    -- 文本渲染
    nvgFontFace(vg, "fox-mascot")
    nvgFontSize(vg, fontSize)

    -- 文字投影（提升可读性）
    nvgFillColor(vg, nvgRGBA(0, 0, 0, options.handdrawn and 0 or math.floor(80 * bubbleAlpha)))
    if isChatBubble_ then
        nvgTextAlign(vg, NVG_ALIGN_LEFT | NVG_ALIGN_TOP)
        nvgTextBox(vg, textX + 1, textDrawY + 1, bubbleMaxW, currentText_)
    else
        nvgTextAlign(vg, NVG_ALIGN_LEFT | NVG_ALIGN_BOTTOM)
        nvgText(vg, textX + 1, textBottom + 1, currentText_)
    end

    -- 正文（白色文字配合深色背景）
    nvgFillColor(vg, options.handdrawn and Pen.color(Art.colors.ink) or nvgRGBA(255, 255, 255, math.floor(245 * bubbleAlpha)))
    if isChatBubble_ then
        nvgTextAlign(vg, NVG_ALIGN_LEFT | NVG_ALIGN_TOP)
        nvgTextBox(vg, textX, textDrawY, bubbleMaxW, currentText_)
    else
        nvgTextAlign(vg, NVG_ALIGN_LEFT | NVG_ALIGN_BOTTOM)
        nvgText(vg, textX, textBottom, currentText_)
    end

    nvgRestore(vg)
end

-- 注册云端皮肤变更回调
OutfitManager.onChange(function()
    skinDirty_ = true
end)

return M
