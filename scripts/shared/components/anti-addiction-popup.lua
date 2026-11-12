--- 防沉迷弹窗 UI 组件
--- 提供三种弹窗：30 分钟提醒、60 分钟强制退出、宵禁拦截
--- 使用 urhox-libs/UI 系统构建，统一暖色圆角风格
local UI = require("urhox-libs/UI")
local PaperUI = require("shared.components.paper-ui")
local Colors = require("shared.constants.colors")
local Layout = require("shared.constants.layout")
local C = require("shared.constants.art").colors
local uiTap = require("shared.utils.ui-tap")
local logger = require("shared.utils.logger")

local M = {}
local MODULE = "anti-addiction-popup"

---@type any 当前显示的弹窗节点
local currentOverlay_ = nil

-- ============================================================================
-- 自适应缩放
-- ============================================================================
local uiScale_ = 1.0

local function refreshUIScale()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local logW = physW / dpr
    local logH = physH / dpr
    local minDim = math.min(logW, logH)
    uiScale_ = math.min(2.0, math.max(1.0, minDim / 500))
end

local function s(v)
    return math.floor(v * uiScale_)
end

-- ============================================================================
-- 通用弹窗骨架
-- ============================================================================

---@param opts { icon: string, title: string, desc: string, buttons: table[] }
---@return any overlay
local function createPopup(opts)
    refreshUIScale()
    local viewportW, viewportH = UI.GetViewportSize()
    local cardW = math.min(viewportW * 0.9, s(420))
    local textW = math.max(100, cardW - s(40))
    local rows = 0
    local paragraphs = {}
    for line in (opts.desc .. "\n"):gmatch("(.-)\n") do
        rows = rows + math.max(1, math.ceil(utf8.len(line) * s(14) / textW))
        paragraphs[#paragraphs + 1] = line == "" and UI.Panel {height = s(10), flexShrink = 0} or UI.Label {
            id = "rest-paragraph-" .. (#paragraphs + 1),
            text = line, width = "100%", fontSize = s(14),
            fontColor = C.muted, textAlign = "center", lineHeight = 1.6,
            whiteSpace = "normal", verticalAlign = "top", flexShrink = 0,
        }
    end
    local naturalH = s(90 + 40 + #opts.buttons * 58) + rows * s(23)
    local cardH = math.min(viewportH * 0.88, naturalH)
    local buttonChildren = {}
    for i, btn in ipairs(opts.buttons) do
        buttonChildren[#buttonChildren + 1] = PaperUI.button {
            id = "rest-action-" .. i, text = btn.text,
            variant = btn.variant or "primary", width = "100%", height = s(46),
            fontSize = s(17), backgroundColor = btn.backgroundColor or C.orange,
            textColor = C.ink,
            onClick = function()
                uiTap.play()
                if btn.onClick then btn.onClick() end
            end,
        }
    end
    return UI.Panel {
        position = "absolute", width = "100%", height = "100%", left = 0, top = 0,
        backgroundColor = {63, 56, 36, 140},
        justifyContent = "center", alignItems = "center",
        onClick = function() end,
        children = {
            UI.Panel {
                id = "rest-card", width = cardW, height = cardH,
                backgroundColor = C.paper, borderWidth = 2.5, borderColor = C.ink,
                borderRadius = 12, overflow = "hidden", flexDirection = "column",
                children = {
                    UI.Panel {
                        width = "100%", height = s(80), flexShrink = 0,
                        borderBottomWidth = 1.5, borderColor = C.track,
                        justifyContent = "center", alignItems = "center", gap = s(4),
                        children = {
                            UI.Label {text = "玩趣乐园 · 温馨提示", fontSize = s(12), fontColor = C.muted},
                            UI.Label {text = opts.title, fontSize = s(20), fontColor = C.ink, fontWeight = "bold"},
                        },
                    },
                    UI.ScrollView {
                        id = "rest-scroll", width = "100%", flexGrow = 1, flexShrink = 1, flexBasis = 0,
                        children = {UI.Panel {
                            width = "100%", padding = s(20), flexShrink = 0,
                            flexDirection = "column", gap = s(2), children = paragraphs,
                        }},
                    },
                    UI.Panel {
                        id = "rest-footer", width = "100%", padding = s(16), paddingTop = s(8),
                        flexShrink = 0, flexDirection = "column", gap = s(10), children = buttonChildren,
                    },
                },
            },
        },
    }
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 30 分钟提醒弹窗
---@param parentContainer any 父容器节点
---@param onRest function 选择休息的回调
---@param onContinue function 选择继续的回调
function M.showReminder(parentContainer, onRest, onContinue)
    M.dismiss()

    local overlay = createPopup({
        icon = "\xE2\x8F\xB0", -- ⏰
        title = "休息一下吧！",
        desc = "你已经玩了 30 分钟啦，\n休息一下眼睛吧！",
        buttons = {
            {
                text = "好的，休息一会儿",
                variant = "primary",
                backgroundColor = Colors.primary,
                onClick = function()
                    M.dismiss()
                    if onRest then onRest() end
                end,
            },
            {
                text = "再玩一会儿",
                variant = "outline",
                backgroundColor = C.paper,
                fontColor = Colors.textSecondary,
                borderColor = Colors.primaryLight,
                onClick = function()
                    M.dismiss()
                    if onContinue then onContinue() end
                end,
            },
        },
    })

    currentOverlay_ = overlay
    parentContainer:AddChild(overlay)
    logger.info(MODULE, "showReminder", "30min reminder shown")
end

--- 60 分钟强制退出弹窗
---@param parentContainer any 父容器节点
---@param onConfirm function 确认的回调
function M.showForceExit(parentContainer, onConfirm)
    M.dismiss()

    local overlay = createPopup({
        icon = "\xF0\x9F\x98\xB4", -- 😴
        title = "今天玩够啦！",
        desc = "你已经玩了 60 分钟啦，\n今天要先休息了哦！",
        buttons = {
            {
                text = "好的",
                variant = "primary",
                backgroundColor = Colors.primary,
                onClick = function()
                    M.dismiss()
                    if onConfirm then onConfirm() end
                end,
            },
        },
    })

    currentOverlay_ = overlay
    parentContainer:AddChild(overlay)
    logger.info(MODULE, "showForceExit", "60min force exit shown")
end

--- 宵禁拦截弹窗
---@param parentContainer any 父容器节点
---@param onConfirm function 确认的回调
function M.showCurfew(parentContainer, onConfirm)
    M.dismiss()

    local overlay = createPopup({
        title = "现在不能玩哦！",
        icon = "",
        desc = "当前账号实名为未成年人。\n未成年人每日 20:00 至次日 08:00 不能进入游戏，请明天 8 点以后再来玩吧。",
        buttons = {
            {
                text = "好的",
                variant = "primary",
                backgroundColor = Colors.primary,
                onClick = function()
                    M.dismiss()
                    if onConfirm then onConfirm() end
                end,
            },
            {
                text = "退出游戏",
                variant = "outline",
                backgroundColor = C.paper,
                fontColor = Colors.textSecondary,
                borderColor = Colors.primaryLight,
                onClick = function()
                    logger.info(MODULE, "showCurfew", "exit game button clicked")
                    M.dismiss()
                    engine:Exit()
                end,
            },
        },
    })

    currentOverlay_ = overlay
    parentContainer:AddChild(overlay)
    logger.info(MODULE, "showCurfew", "curfew popup shown")
end

--- 未成年人实名认证成功后的防沉迷限制说明弹窗
---@param parentContainer any 父容器节点
---@param age number|nil 年龄
---@param onConfirm function|nil 确认的回调
function M.showMinorLimitNotice(parentContainer, age, onConfirm)
    M.dismiss()

    local ageText = age and (tostring(age) .. "周岁") or "未成年"
    local paymentText
    if age and age < 8 then
        paymentText = "未满8周岁的用户不能进行充值消费。"
    elseif age and age < 16 then
        paymentText = "8周岁以上未满16周岁的用户，单次充值金额不得超过50元人民币，每月充值金额累计不得超过200元人民币。"
    else
        paymentText = "16周岁以上未满18周岁的用户，单次充值金额不得超过100元人民币，每月充值金额累计不得超过400元人民币。"
    end

    local overlay = createPopup({
        icon = "",
        title = "未成年人保护提示",
        desc = "实名认证成功，当前身份为" .. ageText .. "。\n\n根据防沉迷规定，未成年人每日20:00至次日08:00不能进入游戏；单次游玩满30分钟会提醒休息，累计满60分钟后今天需先休息。\n\n" .. paymentText,
        buttons = {
            {
                text = "我知道了",
                variant = "primary",
                backgroundColor = Colors.primary,
                onClick = function()
                    M.dismiss()
                    if onConfirm then onConfirm() end
                end,
            },
        },
    })

    currentOverlay_ = overlay
    parentContainer:AddChild(overlay)
    logger.info(MODULE, "showMinorLimitNotice", "minor limit notice shown, age=" .. tostring(age))
end

--- 关闭当前弹窗
function M.dismiss()
    if currentOverlay_ then
        currentOverlay_:Remove()
        currentOverlay_ = nil
    end
end

--- 是否有弹窗正在显示
---@return boolean
function M.isShowing()
    return currentOverlay_ ~= nil
end

return M
