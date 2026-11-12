--- 皮肤购买弹窗（NanoVG 渲染）
--- 两阶段流程：
---   阶段1: 确认购买弹窗（皮肤名 + 价格 + 确认/取消）
---   阶段2: 模拟支付页面（点击确认完成支付 / 取消返回）
--- 用法：
---   local popup = require("shared.components.purchase-popup")
---   popup.show(nvgCtx, skinId, { onPurchased = fn, fontName = "profile" })
---   popup.update(dt)
---   popup.render(vg, screenW, screenH)
---   popup.handleClick(mx, my)

local OutfitManager = require("shared.outfit-manager")
local logger = require("shared.utils.logger")
local realNameAuth = require("shared.real-name-auth")
local uiTap = require("shared.utils.ui-tap")

-- 延迟加载：anti-addiction 与本模块存在循环依赖
-- (purchase-popup → anti-addiction → settings-save → background-manager → purchase-popup)
---@type table|nil
local antiAddiction_ = nil
local function getAntiAddiction()
    if not antiAddiction_ then
        antiAddiction_ = require("shared.anti-addiction")
    end
    return antiAddiction_
end

-- 延迟加载：cloud-age → settings-save → background-manager → purchase-popup 存在循环依赖
---@type table|nil
local cloudAge_ = nil
local function getCloudAge()
    if not cloudAge_ then
        cloudAge_ = require("shared.cloud-age")
    end
    return cloudAge_
end

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local StoryPaper = require("shared.components.story-paper")
local C = Paper.colors
local M = {}
local MODULE = "purchase-popup"

-- ============================================================================
-- 状态
-- ============================================================================

---@type boolean
local active_ = false

---@type number 已经过时间
local elapsed_ = 0

---@type string 当前阶段 "confirm" | "payment"
local phase_ = "confirm"

---@type string|nil 当前皮肤 ID
local skinId_ = nil

---@type table|nil 皮肤配置
local skinData_ = nil

---@type number 皮肤图片句柄
local skinImage_ = -1

---@type userdata|nil NanoVG 上下文
local nvgCtx_ = nil

---@type string 字体名称
local fontName_ = "sans"

---@type function|nil 购买成功回调
local onPurchased_ = nil

---@type function|nil 关闭回调（不论结果）
local onDismiss_ = nil

---@type string|nil 消费限额拦截提示（非 nil 时显示在支付页面）
local spendingBlockMsg_ = nil

-- 按钮区域缓存
---@type table|nil { x, y, w, h }
local confirmBtn_ = nil
---@type table|nil { x, y, w, h }
local cancelBtn_ = nil
---@type table|nil { x, y, w, h } blocked 阶段"知道了"按钮
local knownBtn_ = nil
---@type boolean blocked 独立展示模式（无 skinData，供背景直购拦截复用）
local blockedOnly_ = false

-- ============================================================================
-- 动画常量
-- ============================================================================

local POPUP_W = 280
local POPUP_H = 344
local BLOCKED_POPUP_H = 190
local BTN_W = 110
local BTN_H = 44
local BTN_GAP = 16

-- ============================================================================
-- 未成年人消费限额（依据国家新闻出版署 2019 年第 44 号通知）
-- ============================================================================

--- 单次充值限额（元）
local SINGLE_LIMIT = {
    under8  = 0,    -- 不满 8 周岁：禁止充值
    age8to15 = 50,  -- 8-15 周岁：单次不超过 50 元
    age16to17 = 100, -- 16-17 周岁：单次不超过 100 元
}

--- 检查未成年人是否允许本次消费
---@param price number 本次消费金额（元）
---@return boolean allowed
---@return string|nil blockMsg 被拦截时的提示信息
local function checkMinorSpendingLimit(price)
    -- 成年人不受限制
    if getAntiAddiction().isAdult() then
        return true, nil
    end
    -- 未认证用户视为未成年人，允许消费但使用最低年龄档位限制
    local birthday = realNameAuth.getBirthday()
    if not birthday then
        -- 未认证：按 8-15 档限制
        if price > SINGLE_LIMIT.age8to15 then
            return false, "未完成实名认证，单次消费不能超过" .. SINGLE_LIMIT.age8to15 .. "元"
        end
        return true, nil
    end
    local age = realNameAuth.calculateAge(birthday)
    if age < 8 then
        return false, "8周岁以下用户不允许充值消费"
    elseif age < 16 then
        if price > SINGLE_LIMIT.age8to15 then
            return false, "未满16周岁用户单次消费不能超过" .. SINGLE_LIMIT.age8to15 .. "元"
        end
    elseif age < 18 then
        if price > SINGLE_LIMIT.age16to17 then
            return false, "未满18周岁用户单次消费不能超过" .. SINGLE_LIMIT.age16to17 .. "元"
        end
    end
    return true, nil
end

-- ============================================================================
-- 弹性缓动
-- ============================================================================

local function elasticOut(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    local p = 0.35
    return (2 ^ (-10 * t)) * math.sin((t - p / 4) * (2 * math.pi) / p) + 1
end

-- ============================================================================
-- 公共 API
-- ============================================================================

function M.isActive()
    return active_
end

--- 显示购买弹窗
---@param nvgCtx userdata NanoVG 上下文
---@param skinId string 要购买的皮肤 ID
---@param opts table|nil { fontName, onPurchased, onDismiss, skinImage }
function M.show(nvgCtx, skinId, opts)
    opts = opts or {}
    skinData_ = OutfitManager.getSkinById(skinId)
    if not skinData_ then
        logger.warn(MODULE, "show", "unknown skin: " .. tostring(skinId))
        return
    end

    nvgCtx_ = nvgCtx
    skinId_ = skinId
    elapsed_ = 0
    -- 云存档年龄拦截：开关开启且云存档有数据、档位为未实名/未满8 时，
    -- 不进入确认购买流程，直接显示"禁止游戏付费服务"弹窗
    if getCloudAge().isPurchaseBlocked() then
        phase_ = "blocked"
        logger.info(MODULE, "show", "purchase blocked by cloud age")
    else
        phase_ = "confirm"
    end
    active_ = true
    confirmBtn_ = nil
    cancelBtn_ = nil
    knownBtn_ = nil
    spendingBlockMsg_ = nil
    fontName_ = opts.fontName or "sans"
    onPurchased_ = opts.onPurchased
    onDismiss_ = opts.onDismiss

    -- 复用外部传入的图片句柄（避免与页面缩略图冲突）
    skinImage_ = opts.skinImage or -1
    if skinImage_ < 0 then
        logger.warn(MODULE, "show", "no skin image handle provided")
    end

    logger.info(MODULE, "show", "purchase popup for: " .. skinData_.name)
end

--- 仅展示"禁止游戏付费服务"弹窗（用于背景等无购买弹窗流程直接拦截）
---@param nvgCtx userdata NanoVG 上下文
---@param opts table|nil { fontName, onDismiss }
function M.showBlocked(nvgCtx, opts)
    opts = opts or {}
    if active_ then return end
    nvgCtx_ = nvgCtx
    skinId_ = nil
    skinData_ = nil
    elapsed_ = 0
    phase_ = "blocked"
    active_ = true
    blockedOnly_ = true
    confirmBtn_ = nil
    cancelBtn_ = nil
    knownBtn_ = nil
    spendingBlockMsg_ = nil
    fontName_ = opts.fontName or "sans"
    onPurchased_ = nil
    onDismiss_ = opts.onDismiss
    logger.info(MODULE, "showBlocked", "blocked popup shown (standalone)")
end

function M.update(dt)
    if not active_ then return end
    elapsed_ = elapsed_ + dt
end

function M.handleClick(mx, my)
    if not active_ then return end

    -- blocked 阶段：只有"知道了"按钮，点击关闭弹窗
    if phase_ == "blocked" then
        local b = knownBtn_
        if b and mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
            uiTap.play()
            M.dismiss()
        end
        return
    end

    -- 确认按钮
    if confirmBtn_ then
        local b = confirmBtn_
        if mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
            uiTap.play()
            if phase_ == "confirm" then
                -- 消费限额检查
                local price = OutfitManager.getPrice(skinId_) or 3
                local allowed, blockMsg = checkMinorSpendingLimit(price)
                if not allowed then
                    spendingBlockMsg_ = blockMsg
                    logger.info(MODULE, "handleClick", "spending blocked: " .. tostring(blockMsg))
                    -- 不进入支付阶段，停留在确认页面（提示会显示在渲染中）
                    return
                end
                spendingBlockMsg_ = nil
                -- 进入模拟支付阶段
                phase_ = "payment"
                elapsed_ = 0
                confirmBtn_ = nil
                cancelBtn_ = nil
                logger.info(MODULE, "handleClick", "entering payment phase")
            elseif phase_ == "payment" then
                -- 模拟支付成功，执行购买
                local purchasedId = skinId_
                OutfitManager.purchaseSkin(purchasedId, function(success, msg)
                    logger.info(MODULE, "handleClick", "purchase result: " .. tostring(success) .. " " .. msg)
                end)
                local cb = onPurchased_
                M.dismiss()
                if cb then cb(purchasedId) end
            end
            return
        end
    end

    -- 取消按钮
    if cancelBtn_ then
        local b = cancelBtn_
        if mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
            uiTap.play()
            if phase_ == "payment" then
                -- 从支付页面返回确认页面
                phase_ = "confirm"
                elapsed_ = 0
                confirmBtn_ = nil
                cancelBtn_ = nil
                logger.info(MODULE, "handleClick", "back to confirm phase")
            else
                M.dismiss()
            end
            return
        end
    end
end

function M.dismiss()
    if not active_ then return end
    active_ = false

    -- 图片句柄由外部管理，不在此释放
    skinImage_ = -1

    skinId_ = nil
    skinData_ = nil
    confirmBtn_ = nil
    cancelBtn_ = nil
    knownBtn_ = nil
    blockedOnly_ = false

    if onDismiss_ then
        local cb = onDismiss_
        onDismiss_ = nil
        cb()
    end
end

-- ============================================================================
-- 绘制通用按钮
-- ============================================================================

---@param vg userdata
---@param x number
---@param y number
---@param w number
---@param h number
---@param label string
---@param isPrimary boolean
---@param alpha number 0 到 1
---@return table { x, y, w, h }
local function drawButton(vg,x,y,w,h,label,isPrimary,alpha)
    Paper.button(vg,x,y,w,h,label,isPrimary,true,fontName_,alpha)
    return {x=x,y=y,w=w,h=h}
end



-- ============================================================================
-- 渲染：确认购买阶段
-- ============================================================================

local function renderConfirmPhase(vg, cx, cy, popX, popY, popW, popH, contentAlpha)
    local a = math.floor(contentAlpha * 255)

    -- 标题
    nvgFontFace(vg, fontName_)
    nvgFontSize(vg, 22)
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(80, 55, 35, a))
    nvgText(vg, cx, popY + 32, "确认购买")

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, popX + 24, popY + 54)
    nvgLineTo(vg, popX + popW - 24, popY + 54)
    nvgStrokeWidth(vg, 1)
    nvgStrokeColor(vg, nvgRGBA(230, 220, 210, math.floor(a * 0.6)))
    nvgStroke(vg)

    -- 皮肤图片
    local imgSize = 100
    local imgY = popY + 70
    if skinImage_ >= 0 then
        nvgSave(vg); nvgGlobalAlpha(vg,contentAlpha)
        StoryPaper.portrait(vg,skinImage_,cx-imgSize/2,imgY,imgSize,imgSize)
        nvgRestore(vg)
    end

    -- 皮肤名称
    local nameY = imgY + imgSize + 16
    nvgFontSize(vg, 18)
    nvgFillColor(vg, nvgRGBA(100, 75, 50, a))
    nvgText(vg, cx, nameY, skinData_.name)

    -- 价格
    local price = OutfitManager.getPrice(skinId_) or 3
    local priceY = nameY + 28
    nvgFontSize(vg, 20)
    nvgFillColor(vg, nvgRGBA(230, 100, 40, a))
    nvgText(vg, cx, priceY, "售价：" .. price .. " 元")

    -- 消费限额拦截提示
    if spendingBlockMsg_ then
        local warnY = priceY + 24
        nvgFontSize(vg, 13)
        nvgFillColor(vg, nvgRGBA(220, 60, 40, a))
        nvgText(vg, cx, warnY, spendingBlockMsg_)
    end

    -- 按钮区域
    local btnY = popY + popH - BTN_H - 24
    local totalBtnW = BTN_W * 2 + BTN_GAP
    local btnStartX = cx - totalBtnW / 2

    cancelBtn_ = drawButton(vg, btnStartX, btnY, BTN_W, BTN_H, "取消", false, contentAlpha)
    confirmBtn_ = drawButton(vg, btnStartX + BTN_W + BTN_GAP, btnY, BTN_W, BTN_H, "确认购买", true, contentAlpha)
end

-- ============================================================================
-- 渲染：模拟支付阶段
-- ============================================================================

local function renderPaymentPhase(vg, cx, cy, popX, popY, popW, popH, contentAlpha)
    local a = math.floor(contentAlpha * 255)

    -- 与确认页共用纸色标题，支付流程和拦截逻辑保持原样。
    nvgBeginPath(vg); nvgMoveTo(vg,popX+20,popY+50)
    nvgLineTo(vg,popX+popW-20,popY+50)
    nvgStrokeColor(vg,nvgRGBA(91,76,47,a)); nvgStrokeWidth(vg,2); nvgStroke(vg)

    nvgFontFace(vg, fontName_)
    nvgFontSize(vg, 20)
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(91, 76, 47, a))
    nvgText(vg, cx, popY + 26, "支付页面")

    -- 支付信息区域
    local infoY = popY + 70

    -- 商品名称
    nvgFontSize(vg, 15)
    nvgFillColor(vg, nvgRGBA(120, 120, 130, a))
    nvgText(vg, cx, infoY, "商品")

    nvgFontSize(vg, 18)
    nvgFillColor(vg, nvgRGBA(60, 50, 40, a))
    nvgText(vg, cx, infoY + 24, skinData_.name .. " 皮肤")

    -- 分隔线
    nvgBeginPath(vg)
    nvgMoveTo(vg, popX + 30, infoY + 48)
    nvgLineTo(vg, popX + popW - 30, infoY + 48)
    nvgStrokeWidth(vg, 1)
    nvgStrokeColor(vg, nvgRGBA(230, 230, 235, a))
    nvgStroke(vg)

    -- 金额
    local price = OutfitManager.getPrice(skinId_) or 3
    local amountY = infoY + 72

    nvgFontSize(vg, 15)
    nvgFillColor(vg, nvgRGBA(120, 120, 130, a))
    nvgText(vg, cx, amountY, "支付金额")

    nvgFontSize(vg, 32)
    nvgFillColor(vg, nvgRGBA(230, 80, 30, a))
    nvgText(vg, cx, amountY + 36, "¥ " .. price .. ".00")

    -- 按钮区域
    local btnY = popY + popH - BTN_H - 24
    local totalBtnW = BTN_W * 2 + BTN_GAP
    local btnStartX = cx - totalBtnW / 2

    cancelBtn_ = drawButton(vg, btnStartX, btnY, BTN_W, BTN_H, "取消", false, contentAlpha)
    confirmBtn_ = drawButton(vg, btnStartX + BTN_W + BTN_GAP, btnY, BTN_W, BTN_H, "确认支付", true, contentAlpha)
end

-- ============================================================================
-- 渲染：云存档年龄禁止付费阶段
-- ============================================================================

local function renderBlockedPhase(vg, cx, popX, popY, popW, popH, contentAlpha)
    local a = math.floor(contentAlpha * 255)

    -- 警告图标
    local iconCY = popY + 44
    nvgBeginPath(vg)
    nvgCircle(vg, cx, iconCY, 18)
    nvgFillColor(vg, nvgRGBA(255, 230, 228, a))
    nvgFill(vg)
    nvgBeginPath(vg)
    nvgCircle(vg, cx, iconCY, 18)
    nvgStrokeWidth(vg, 1.5)
    nvgStrokeColor(vg, nvgRGBA(230, 120, 110, math.floor(a * 0.7)))
    nvgStroke(vg)
    nvgFontFace(vg, fontName_)
    nvgFontSize(vg, 24)
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
    nvgFillColor(vg, nvgRGBA(220, 80, 60, a))
    nvgText(vg, cx, iconCY + 1, "!")

    -- 标题
    nvgFontSize(vg, 21)
    nvgFillColor(vg, nvgRGBA(130, 45, 40, a))
    nvgText(vg, cx, popY + 88, "禁止游戏付费服务")

    -- 说明文字
    nvgFontSize(vg, 13)
    nvgFillColor(vg, nvgRGBA(150, 140, 130, a))
    nvgText(vg, cx, popY + 116, "根据账号年龄限制，当前无法使用付费服务")

    -- 知道了按钮（居中单按钮）
    local btnY = popY + popH - BTN_H - 22
    knownBtn_ = drawButton(vg, cx - 70, btnY, 140, BTN_H, "知道了", true, contentAlpha)
end

-- ============================================================================
-- 主渲染
-- ============================================================================

function M.render(vg, screenW, screenH)
    if not active_ then return end
    if not skinData_ and not blockedOnly_ then return end

    local cx = screenW / 2
    local cy = screenH / 2

    -- 半透明遮罩
    local overlayAlpha = math.min(1, elapsed_ / 0.15)
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, screenW, screenH)
    nvgFillColor(vg, nvgRGBA(0, 0, 0, math.floor(150 * overlayAlpha)))
    nvgFill(vg)

    -- 弹窗弹性缩放
    local popT = math.max(0, (elapsed_ - 0.03) / 0.35)
    local popScale = elasticOut(math.min(1, popT))
    if popScale < 0.01 then return end

    local popW = math.min(POPUP_W, screenW - 40)
    local popH = phase_ == "blocked" and BLOCKED_POPUP_H or POPUP_H
    local popX = (screenW - popW) / 2
    local popY = (screenH - popH) / 2

    nvgSave(vg)
    nvgTranslate(vg, cx, cy)
    nvgScale(vg, 1, 1)
    nvgTranslate(vg, -cx, -cy)

    Paper.panel(vg,popX,popY,popW,popH)


    -- 内容淡入
    local contentAlpha = math.min(1, math.max(0, (elapsed_ - 0.1) / 0.2))

    if phase_ == "confirm" then
        renderConfirmPhase(vg, cx, cy, popX, popY, popW, popH, contentAlpha)
    elseif phase_ == "payment" then
        renderPaymentPhase(vg, cx, cy, popX, popY, popW, popH, contentAlpha)
    elseif phase_ == "blocked" then
        renderBlockedPhase(vg, cx, popX, popY, popW, popH, contentAlpha)
    end

    nvgRestore(vg)
end

return M
