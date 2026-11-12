--- 健康游戏忠告组件
--- 游戏启动时显示健康忠告画面：
--- - 立即显示忠告文字 + 适龄提示（CADPA 8+ 图标）
--- - 5 秒后在忠告卡片上方出现"点击进入游戏"提示
--- - 点击任意位置关闭忠告，进入游戏
--- - 点击适龄提示区域展开详情弹窗（不会关闭忠告）
--- - 10 秒后自动关闭
--- - 关闭时带渐隐效果
local UI = require("urhox-libs/UI")
local ANIM = require("shared.constants.animations")
local Layout = require("shared.constants.layout")
local Art = require("shared.constants.art")
local kinsoku = require("shared.utils.kinsoku")
local Theme = UI.Theme

local M = {}

---@type any
local overlay_ = nil
---@type any
local hintLabel_ = nil
---@type any
local progressFill_ = nil
---@type any
local titleImage_ = nil
---@type any
local tagline_ = nil
---@type any
local characterGroup_ = nil
---@type any
local footer_ = nil
local bottomStack_ = nil
local preparePanel_ = nil
local healthBody_ = nil
---@type any
local progressTrack_ = nil
---@type any
local cadpaCard_ = nil
local characterNodes_ = {}
local lastWidth_, lastHeight_ = 0, 0
local lastBottomHeight_ = -1
local lastLayoutKey_ = ""
local progressWidth_ = 200
local elapsed_ = 0
local hintShown_ = false
local closing_ = false
local active_ = false
local onDismiss_ = nil

--- 适龄提示弹窗状态
local cadpaPopupOpen_ = false
---@type any
local cadpaOverlay_ = nil

local PROGRESS_DURATION = 5 -- 进度条填满时长（秒）
local AUTO_CLOSE_DELAY = 10 -- 自动关闭延迟（秒）
local FADE_DURATION = ANIM.DURATION_FADE   -- 渐隐时长（秒）
local PROGRESS_BAR_W = 200  -- 进度条宽度
local PROGRESS_BAR_H = 10   -- 进度条高度

local COLORS = Art.colors

--- 用 UI 自身的逻辑坐标布局，保持与全局 DPI 缩放一致。
local function getMetrics()
    local w, h = UI.GetViewportSize()
    local scale = math.min(math.min(w, 620) / Layout.DESIGN_WIDTH, h / Layout.DESIGN_HEIGHT)
    return w, h, scale
end

--- 文本用同一字号计算字宽与行盒，避免旧 Runtime 缩放字号后保留旧高度。
local function layoutLine(label, fontSize, maxWidth, lineHeight, stretch)
    local face = Theme.FontFace(label.props.fontFamily, label.props.fontWeight)
    local width = UI.MeasureTextWidth(label.props.text or "", Theme.FontSize(fontSize), face)
    if width > maxWidth and width > 0 then
        fontSize = fontSize * maxWidth / width
        width = maxWidth
    end
    local height = math.ceil(Theme.FontSize(fontSize) * lineHeight)
    label:SetStyle({ fontSize = fontSize, lineHeight = lineHeight,
        width = stretch and "100%" or math.ceil(width), height = height, minHeight = height,
        flexShrink = 0, whiteSpace = "nowrap" })
    return height, width
end

--- 下半区由内容自然撑高；卡片不设固定高度，所有文字行禁止被 Flex 压扁。
local function layoutBottom(w, scale, safe)
    local width = math.min(478 * scale, w - safe.left - safe.right - 32 * scale)
    bottomStack_:SetStyle({ left = safe.left + (w - safe.left - safe.right - width) / 2,
        bottom = safe.bottom + 32 * scale, width = width, gap = 14 * scale })
    local hintHeight = layoutLine(hintLabel_, 20 * scale, width, 1.35, true)
    preparePanel_:SetStyle({ width = "100%", height = hintHeight, minHeight = hintHeight })
    hintLabel_:SetStyle({ position = "absolute", left = 0, top = 0 })
    progressWidth_ = math.floor(290 * scale)
    progressTrack_:SetStyle({ width = progressWidth_, height = 8 * scale,
        minHeight = 8 * scale, borderRadius = 4 * scale, flexShrink = 0,
        position = "absolute", left = (width - progressWidth_) / 2,
        top = (hintHeight - 8 * scale) / 2 })
    progressFill_:SetStyle({ width = math.floor((progressWidth_ - 3)
        * math.min(elapsed_ / PROGRESS_DURATION, 1)) })

    local innerW = width - 32 * scale - 4
    footer_:SetStyle({ width = "100%", padding = 16 * scale,
        paddingBottom = 24 * scale, gap = 10 * scale, borderRadius = 20 * scale })
    local ageEntry = footer_:FindById("splash-age-entry")
    local ageIcon = footer_:FindById("splash-age-icon")
    local ageText = footer_:FindById("splash-age-text")
    local ageTextH, ageTextW = layoutLine(ageText, 17 * scale,
        innerW - (31 + 9 + 24) * scale - 3, 1.35, false)
    ageEntry:SetStyle({ width = math.min(innerW, ageTextW + (31 + 9 + 24) * scale + 3),
        height = math.max(39 * scale, ageTextH) + 10 * scale + 3,
        paddingTop = 5 * scale, paddingBottom = 5 * scale,
        paddingLeft = 12 * scale, paddingRight = 12 * scale })
    ageIcon:SetStyle({ width = 31 * scale, height = 39 * scale, marginRight = 9 * scale })
    layoutLine(footer_:FindById("splash-health-title"), 16 * scale, innerW, 1.35, true)
    healthBody_:SetStyle({ width = "100%", gap = 4 * scale })
    for i = 1, 4 do
        layoutLine(footer_:FindById("splash-health-line-" .. i), 16 * scale, innerW, 1.35, true)
    end
end

local function layoutHero(w, h, scale, safe, bottomHeight)
    local compact = h / w < 1.9
    local centerX = safe.left + (w - safe.left - safe.right) / 2
    local logoTop = math.max(safe.top + 16 * scale, h * (compact and 0.08 or 0.15))
    local logoW = 460 * scale
    local logoH = logoW * 477 / 1331
    titleImage_:SetStyle({ left = centerX - logoW / 2, top = logoTop, width = logoW, height = logoH })
    local taglineW = 286 * scale
    layoutLine(tagline_, 19 * scale, taglineW - 16 * scale, 1.35, false)
    tagline_:SetStyle({ left = centerX - taglineW / 2, top = logoTop + logoH + 12 * scale,
        width = taglineW, paddingTop = 4 * scale, paddingBottom = 4 * scale,
        height = math.ceil(Theme.FontSize(19 * scale) * 1.35) + 8 * scale })
    local bottomTop = h - safe.bottom - 32 * scale - math.max(bottomHeight, 334 * scale)
    local characterTop = logoTop + logoH + 78 * scale
    local characterScale = math.min(scale, math.max(0,
        (bottomTop - characterTop - 20 * scale) / 240))
    local groupW, groupH = 490 * characterScale, 240 * characterScale
    characterGroup_:SetStyle({ left = centerX - groupW / 2,
        top = math.max(characterTop, math.min(h * 0.39, bottomTop - groupH - 20 * scale)),
        width = groupW, height = groupH })
    local placements = {
        { "owl", 0, 108, 112 }, { "cat", 80, 84, 126 },
        { "bunny", 292, 84, 126 }, { "raccoon", 378, 108, 112 }, { "fox", 141, 0, 216 },
    }
    for _, p in ipairs(placements) do
        characterNodes_[p[1]]:SetStyle({ left = p[2] * characterScale, top = p[3] * characterScale,
            width = p[4] * characterScale, height = p[4] * characterScale })
    end
end

--- 缓存包含安全区与字体缩放；布局变化只更新样式，不重建节点或重置倒计时。
local function updateLayout()
    if not overlay_ then return end
    local w, h, scale = getMetrics()
    local safe = UI.GetSafeAreaInsets()
    scale = math.min(scale, (w - safe.left - safe.right) / Layout.DESIGN_WIDTH,
        (h - safe.top - safe.bottom) / Layout.DESIGN_HEIGHT)
    local key = table.concat({ w, h, safe.left, safe.top, safe.right, safe.bottom, Theme.FontSize(1) }, ":")
    local measuredBottomH = bottomStack_:GetAbsoluteLayout().h
    if key == lastLayoutKey_ and measuredBottomH == lastBottomHeight_ then return end
    lastWidth_, lastHeight_, lastLayoutKey_ = w, h, key
    lastBottomHeight_ = measuredBottomH
    layoutBottom(w, scale, safe)
    layoutHero(w, h, scale, safe, measuredBottomH)
    if cadpaCard_ then
        cadpaCard_:SetStyle({ width = math.min(440 * scale, w - 32),
            height = math.min(620 * scale, h - 48) })
    end
end

--- 将禁则换行拆成单行控件，避免不同运行端的多行 Label 测量差异。
local function makeParagraph(text, fontSize, maxWidth)
    local children = {}
    for line in kinsoku.wrap(text, maxWidth, fontSize):gmatch("[^\n]+") do
        children[#children + 1] = UI.Label {
            text = line, fontSize = fontSize, fontColor = COLORS.ink,
            lineHeight = 1.4,
        }
    end
    return UI.Panel {
        width = "100%", flexDirection = "column", gap = 3, marginBottom = 12,
        children = children,
    }
end

--- 显示适龄提示详情弹窗
local function showCadpaPopup()
    if cadpaPopupOpen_ or not overlay_ then return end
    cadpaPopupOpen_ = true

    local w, h, scale = getMetrics()
    local textWidth = math.min(440 * scale, w - 32) - 48
    cadpaCard_ = UI.Panel {
        width = math.min(440 * scale, w - 32),
        height = math.min(620 * scale, h - 48),
        backgroundColor = COLORS.paper,
        borderColor = COLORS.ink, borderWidth = 2,
        borderRadius = 18,
        overflow = "hidden",
        flexDirection = "column", alignItems = "center",
        children = {
            UI.Panel {
                width = "100%", height = 76,
                backgroundColor = COLORS.green,
                borderRadius = { 18, 18, 0, 0 },
                borderWidth = 2, borderColor = COLORS.ink,
                justifyContent = "center", alignItems = "center",
                flexDirection = "column",
                children = {
                    UI.Label { text = "玩趣乐园", fontSize = Layout.FONT_SIZE_NORMAL,
                        fontColor = COLORS.paper, marginBottom = 4 },
                    UI.Label { text = "适龄提示", fontSize = Layout.FONT_SIZE_HEADER,
                        fontColor = COLORS.paper, fontWeight = "bold" },
                },
            },
            UI.ScrollView {
                width = "100%", flexGrow = 1, flexShrink = 1, flexBasis = 0,
                padding = 20, paddingTop = 16, paddingBottom = 8,
                children = {
                    makeParagraph("1、本游戏是适用于年满8周岁及以上的用户，建议未成年人在家长监护下使用游戏产品。", 14, textWidth),
                    makeParagraph("2、本游戏中有用户实名认证系统，认证为未成年人的用户将接受以下管理：", 14, textWidth),
                    makeParagraph("游戏中有部分的付费道具。未满8周岁的用户不能付费；8周岁以上未满16周岁的未成年人用户，单次充值金额不得超过50元人民币，每月充值金额累计不得超过200元人民币；16周岁以上的未成年人用户，单次充值金额不得超过100元人民币，每月充值金额累计不得超过400元人民币。", 13, textWidth),
                    makeParagraph("所有用户需完成实名认证后方可进入游戏，未实名认证的用户不得进入游戏。认证为未成年人的用户每次游玩不超过1小时，且每日20时至次日8时不能进入游戏。", 13, textWidth),
                },
            },
            UI.Panel {
                width = "100%", padding = 16, paddingTop = 8,
                children = {
                    UI.Button {
                        id = "splash-age-close", text = "我知道了", variant = "primary",
                        width = "100%", height = 46, fontSize = Layout.FONT_SIZE_MEDIUM,
                        borderRadius = 12, fontWeight = "bold",
                        backgroundColor = COLORS.orange, fontColor = COLORS.ink,
                        borderColor = COLORS.ink, borderWidth = 2,
                        onClick = function()
                            if cadpaOverlay_ then cadpaOverlay_:Remove() end
                            cadpaOverlay_, cadpaCard_ = nil, nil
                            cadpaPopupOpen_ = false
                        end,
                    },
                },
            },
        },
    }
    cadpaOverlay_ = UI.Panel {
        id = "splash-age-overlay",
        position = "absolute", top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 46, 42, 29, 150 },
        justifyContent = "center", alignItems = "center",
        onClick = function() end,
        children = { cadpaCard_ },
    }
    overlay_:AddChild(cadpaOverlay_)
end

local function makeCharacters()
    characterNodes_ = {}
    local children = {}
    -- 主角最后绘制，在伙伴之间略靠前。
    for _, role in ipairs({ "owl", "cat", "bunny", "raccoon", "fox" }) do
        local node = UI.Panel {
            position = "absolute", pointerEvents = "none",
            backgroundImage = Art.characters[role], backgroundFit = "contain",
        }
        characterNodes_[role] = node
        children[#children + 1] = node
    end
    return UI.Panel { id = "splash-characters", position = "absolute",
        pointerEvents = "none", children = children }
end

local function makeAgeEntry()
    return UI.Panel {
        id = "splash-age-entry",
        flexDirection = "row", alignItems = "center", justifyContent = "center",
        borderRadius = 12, borderWidth = 1.5, borderColor = COLORS.ink, flexShrink = 0,
        backgroundColor = COLORS.paper,
        onClick = function() showCadpaPopup() end,
        children = {
            UI.Panel {
                id = "splash-age-icon", backgroundImage = "image/cadpa-8plus.jpg",
                backgroundFit = "contain", width = 31, height = 39, marginRight = 9,
                pointerEvents = "none",
            },
            UI.Label { id = "splash-age-text", text = "适龄提示 8+  >",
                fontSize = 17, fontColor = COLORS.ink },
        },
    }
end

local function makeFooter()
    local lines = {
        "抵制不良游戏，拒绝盗版游戏。",
        "注意自我保护，谨防受骗上当。",
        "适度游戏益脑，沉迷游戏伤身。",
        "合理安排时间，享受健康生活。",
    }
    local children = {}
    for i, line in ipairs(lines) do
        children[#children + 1] = UI.Label {
            id = "splash-health-line-" .. i, text = line, fontSize = 16,
            fontColor = COLORS.muted, lineHeight = 1.35, textAlign = "center", flexShrink = 0,
        }
    end
    healthBody_ = UI.Panel {
        id = "splash-health-body", width = "100%", flexDirection = "column",
        alignItems = "center", flexShrink = 0, gap = 4, children = children,
    }
    return UI.Panel {
        id = "splash-footer", width = "100%", flexDirection = "column", alignItems = "center",
        flexShrink = 0, padding = 16, paddingBottom = 24, gap = 10, backgroundColor = COLORS.panel,
        borderWidth = 2, borderColor = COLORS.ink, borderRadius = 20,
        pointerEvents = "box-none", children = {
            makeAgeEntry(),
            UI.Label { id = "splash-health-title", text = "健康游戏忠告",
                fontSize = 16, fontColor = COLORS.ink, fontWeight = "bold", textAlign = "center", flexShrink = 0 },
            healthBody_,
        },
    }
end

--- 创建启动页，5 秒后可点击进入，原有合规回调保持不变。
---@param onDismiss function 关闭后的回调
---@return any
function M.create(onDismiss)
    onDismiss_ = onDismiss
    elapsed_, lastWidth_, lastHeight_ = 0, 0, 0
    lastBottomHeight_, lastLayoutKey_ = -1, ""
    hintShown_, closing_, active_, cadpaPopupOpen_ = false, false, true, false
    cadpaOverlay_, cadpaCard_ = nil, nil
    progressFill_ = UI.Panel {
        width = 0, height = "100%", backgroundColor = COLORS.green,
        borderRadius = 3, transition = "width 0.1s linear", pointerEvents = "none",
    }
    progressTrack_ = UI.Panel {
        id = "splash-progress-track", width = PROGRESS_BAR_W, height = PROGRESS_BAR_H,
        backgroundColor = COLORS.track, borderColor = COLORS.ink,
        borderWidth = 1.5, borderRadius = 5, overflow = "hidden",
        pointerEvents = "none", children = { progressFill_ },
    }
    hintLabel_ = UI.Label {
        id = "splash-enter-hint", text = "点击屏幕进入游戏", fontSize = 21,
        fontColor = COLORS.ink, opacity = 0, transition = "opacity 0.5s easeOut",
        textAlign = "center", verticalAlign = "middle", flexShrink = 0,
    }
    titleImage_ = UI.Panel {
        id = "splash-title", position = "absolute", pointerEvents = "none",
        backgroundImage = Art.titleLogo, backgroundFit = "contain",
    }
    tagline_ = UI.Label {
        id = "splash-tagline", position = "absolute", text = "动动脑筋，快乐出发",
        fontSize = 19, fontColor = COLORS.ink, textAlign = "center",
        backgroundColor = COLORS.paper, borderColor = COLORS.ink,
        borderWidth = 1.5, borderRadius = 12,
    }
    characterGroup_ = makeCharacters()
    footer_ = makeFooter()
    preparePanel_ = UI.Panel {
        id = "splash-prepare", width = "100%", flexDirection = "column",
        alignItems = "center", flexShrink = 0, gap = 4,
        pointerEvents = "none", children = { hintLabel_, progressTrack_ },
    }
    bottomStack_ = UI.Panel {
        id = "splash-bottom-stack", position = "absolute", flexDirection = "column",
        alignItems = "center", flexShrink = 0, gap = 14,
        pointerEvents = "box-none", children = { preparePanel_, footer_ },
    }
    overlay_ = UI.Panel {
        id = "splash-screen", position = "absolute", left = 0, top = 0,
        width = "100%", height = "100%",
        backgroundImage = Art.splashBackground, backgroundFit = "cover",
        backgroundColor = COLORS.paper,
        transition = "opacity " .. FADE_DURATION .. "s easeOut", opacity = 1,
        onClick = function()
            if active_ and not closing_ and hintShown_ and not cadpaPopupOpen_ then M.dismiss() end
        end,
        children = { titleImage_, tagline_, characterGroup_, bottomStack_ },
    }
    updateLayout()
    return overlay_
end

--- 触发关闭（渐隐）
local fadeElapsed_ = 0
function M.dismiss()
    if closing_ or not active_ then return end
    closing_ = true
    fadeElapsed_ = 0
    overlay_:SetStyle({ opacity = 0 })
end

--- 每帧更新（由外部调用）
---@param dt number 帧间隔
function M.update(dt)
    if not active_ then return end
    updateLayout()

    -- 渐隐中：等待动画完成后隐藏并回调
    if closing_ then
        fadeElapsed_ = fadeElapsed_ + dt
        if fadeElapsed_ >= FADE_DURATION + 0.05 then
            active_ = false
            if overlay_ then
                overlay_:SetVisible(false)
            end
            if onDismiss_ then
                onDismiss_()
            end
        end
        return
    end

    -- 适龄弹窗打开时暂停计时
    if cadpaPopupOpen_ then return end

    elapsed_ = elapsed_ + dt

    -- 更新进度条
    if not hintShown_ then
        local progress = math.min(elapsed_ / PROGRESS_DURATION, 1.0)
        local fillW = math.floor((progressWidth_ - 3) * progress)
        progressFill_:SetStyle({ width = fillW })

        -- 同一固定槽位切换内容，不同时显示进度条和提示，也不改变卡片位置。
        if progress >= 1.0 then
            hintShown_ = true
            progressTrack_:SetVisible(false)
            hintLabel_:SetStyle({ opacity = 1.0 })
        end
    end

    -- 10 秒后自动关闭
    if elapsed_ >= AUTO_CLOSE_DELAY then
        M.dismiss()
    end
end

--- 是否仍在显示中
---@return boolean
function M.isActive()
    return active_
end

return M
