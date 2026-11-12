--- 共享设置弹窗组件
--- 奶油纸卡与受约束滚动区，保留音量、账号与合规操作。
local UI = require("urhox-libs/UI")
local PaperUI = require("shared.components.paper-ui")
local Colors = require("shared.constants.colors")
local Art = require("shared.constants.art")
local settingsSave = require("shared.settings-save")
local SoundManager = require("shared.sound-manager")
local uiTap = require("shared.utils.ui-tap")
local compliance = require("config.compliance")
local antiAddiction = require("shared.anti-addiction")
local cloudAge = require("shared.cloud-age")
local PrivacyPolicy = require("shared.components.privacy-policy-popup")
local logger = require("shared.utils.logger")

local M = {}

-- ============================================================================
-- 自适应缩放（手机/PC 适配）
-- ============================================================================
local uiScale_ = 1.0

--- 根据屏幕逻辑短边计算缩放因子
--- 手机 (~360px) → 1.0，PC (~1080px) → 2.0
local function refreshUIScale()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local logW = physW / dpr
    local logH = physH / dpr
    local minDim = math.min(logW, logH)
    uiScale_ = math.min(2.0, math.max(1.0, minDim / 500))
end

--- 按当前缩放因子缩放像素值
local function s(v)
    return math.floor(v * uiScale_)
end

-- ============================================================================
-- 确认对话框
-- ============================================================================

---@param opts { title: string, desc: string, confirmText: string, confirmColor: table|nil, onConfirm: function, parent: any }
local function showConfirm(opts)
    local overlay
    overlay = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        left = 0, top = 0,
        backgroundColor = { 0, 0, 0, 160 },
        justifyContent = "center", alignItems = "center",
        children = {
            UI.Panel {
                id="settings-confirm-card", width="90%", maxWidth=s(360), padding=s(20),
                backgroundColor = Art.colors.paper,
                borderRadius=s(12), borderWidth=2.5, borderColor=Art.colors.ink,
                flexDirection = "column",
                alignItems = "center", gap = s(12),
                boxShadow=false,
                children = {
                    -- 警告图标
                    UI.Panel {
                        width = s(48), height = s(48), borderRadius = s(10),
                        backgroundColor = { 255, 240, 220, 255 },
                        justifyContent = "center", alignItems = "center",
                        marginBottom = s(4),
                        children = {
                            UI.Label { text = "!", fontSize = s(26), fontColor = Colors.primary, fontWeight = "bold" },
                        },
                    },
                    UI.Label {
                        text=opts.title, width="100%", whiteSpace="normal",
                        fontSize = s(19),
                        fontColor = Colors.textPrimary,
                        fontWeight = "bold",
                        textAlign = "center",
                    },
                    UI.Label {
                        id="settings-confirm-desc", text=opts.desc, width="100%", whiteSpace="normal",
                        fontSize = s(14),
                        fontColor = Colors.textSecondary,
                        textAlign = "center",
                        marginBottom = s(4),
                    },
                    UI.Panel {
                        width = "100%",
                        flexDirection = "row",
                        gap = s(12),
                        marginTop = s(4),
                        children = {
                            PaperUI.button {
                                id="settings-confirm-cancel", text = "取消",
                                variant = "outline",
                                flexGrow = 1, flexBasis = 0,
                                height = s(46), fontSize = s(17),
                                borderRadius = s(10), fontWeight = "bold",
                                borderColor = Colors.primaryLight,
                                fontColor = Colors.textSecondary,
                                onClick = function()
                                    uiTap.play()
                                    overlay:Remove()
                                end,
                            },
                            PaperUI.button {
                                id="settings-confirm-submit", text = opts.confirmText,
                                variant = "primary",
                                flexGrow = 1, flexBasis = 0,
                                height = s(46), fontSize = s(17),
                                borderRadius = s(10), fontWeight = "bold",
                                backgroundColor = opts.confirmColor or Colors.primary,
                                onClick = function()
                                    uiTap.play()
                                    overlay:Remove()
                                    if opts.onConfirm then opts.onConfirm() end
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
    opts.parent:AddChild(overlay)
end

-- ============================================================================
-- 年龄选择弹窗（测试账号年龄：5 个档位单选）
-- ============================================================================

---@param parentOverlay any 挂载容器（设置弹窗 overlay）
---@param onSelected fun(band: string) 选择后回调（用于刷新外层状态卡片）
local function showAgePicker(parentOverlay, onSelected)
    local overlay
    local currentBand = cloudAge.getAgeBand()

    -- 选项列表：5 个档位按钮，当前选中项高亮
    ---@type any[]
    local optionButtons = {}
    for _, bandDef in ipairs(cloudAge.BANDS) do
        local isSelected = bandDef.id == currentBand
        optionButtons[#optionButtons + 1] = PaperUI.button {
            id="settings-age-option-"..bandDef.id, text = bandDef.label .. (isSelected and "  ✓" or ""),
            variant = isSelected and "primary" or "outline",
            width = "100%", height = s(46), fontSize = s(16),
            borderRadius = s(12), fontWeight = "bold",
            fontColor = isSelected and { 255, 255, 255, 255 } or Colors.textPrimary,
            backgroundColor = isSelected and Colors.primary or nil,
            borderColor = Colors.primaryLight,
            onClick = function()
                uiTap.play()
                cloudAge.setAgeBand(bandDef.id)
                overlay:Remove()
                overlay = nil
                if onSelected then onSelected(bandDef.id) end
            end,
        }
    end

    overlay = UI.Panel {
        position = "absolute",
        width = "100%", height = "100%",
        left = 0, top = 0,
        backgroundColor = { 0, 0, 0, 180 },
        justifyContent = "center", alignItems = "center",
        children = {
            UI.Panel {
                id="settings-age-card", width="90%", maxWidth=s(360), height="88%", maxHeight=s(460), padding=s(20),
                backgroundColor = Art.colors.paper,
                borderRadius=s(12), borderWidth=2.5, borderColor=Art.colors.ink,
                flexDirection = "column", alignItems = "center", gap = s(8),
                boxShadow=false,
                children = {
                    UI.Label {
                        text = "设置账号年龄", width="100%", whiteSpace="normal", textAlign="center", fontSize = s(19),
                        fontColor = Colors.textPrimary, fontWeight = "bold",
                        marginBottom = s(6),
                    },
                    UI.Label {
                        text = "选择后将保存到云存档，用于测试付费限制", width="100%", whiteSpace="normal", fontSize = s(12),
                        fontColor = Colors.textSecondary, textAlign = "center",
                        marginBottom = s(6),
                    },
                    UI.ScrollView {
                        id="settings-age-scroll", width="100%", flexGrow=1, flexBasis=0,
                        scrollY=true, scrollX=false, showScrollbar=true,
                        children={ UI.Panel {
                            width="100%", padding=2, flexDirection="column", gap=s(6),
                            flexShrink=0, children=optionButtons,
                        } },
                    },
                    PaperUI.button {
                        id="settings-age-cancel", text = "取消", variant = "outline",
                        width = "100%", height = s(46), fontSize = s(16),
                        borderRadius = s(12), fontWeight = "bold",
                        fontColor = Colors.textSecondary,
                        borderColor = Colors.primaryLight,
                        onClick = function()
                            uiTap.play()
                            overlay:Remove()
                            overlay = nil
                        end,
                    },
                },
            },
        },
    }
    parentOverlay:AddChild(overlay)
end

-- ============================================================================
-- 音量控制卡片（带图标和背景色的卡片式布局）
-- ============================================================================

---@param label string 标签
---@param valueLabel any 值 Label 引用
---@param pct number 当前百分比
---@param bgColor table 卡片背景色
---@param onChangeFn function 滑块变化回调
---@param onChangeEndFn? function 滑块结束回调
local function makeVolumeCard(label, valueLabel, pct, bgColor, onChangeFn, onChangeEndFn)
    return UI.Panel {
        width = "100%",
        backgroundColor=bgColor, borderWidth=1.5, borderColor=Art.colors.ink,
        borderRadius=s(10),
        padding = s(16), paddingTop = s(14), paddingBottom = s(14),
        flexDirection = "column", gap = s(10),
        children = {
            UI.Panel {
                width = "100%", flexDirection = "row",
                justifyContent = "space-between", alignItems = "center",
                children = {
                    UI.Label {
                        text = label, fontSize = s(17),
                        fontColor = Colors.textPrimary, fontWeight = "bold",
                    },
                    -- 数值
                    valueLabel,
                },
            },
            UI.Slider {
                value=pct, min=0, max=100, width="100%", height=s(44),
                trackBgColor=Art.colors.track, trackFillColor=Art.colors.green,
                thumbColor=Art.colors.paper, thumbBorderColor=Art.colors.ink, thumbBorderWidth=2,
                borderColor=Art.colors.ink, borderWidth=1.5, thumbBoxShadow=false,
                trackFillGradient=false, thumbBorderGradient=false,
                trackHeight = s(8), thumbSize = s(24),
                onChange = onChangeFn,
                onChangeEnd = onChangeEndFn,
            },
        },
    }
end

-- ============================================================================
-- 主弹窗
-- ============================================================================

---@param parentContainer any
---@param opts? { extraButtons?: table[], onClose?: function }
---@return any settingsOverlay, function doClose
function M.open(parentContainer, opts)
    opts = opts or {}
    refreshUIScale()

    local bgmPct = math.floor(GetBGMVolume() * 100 + 0.5)
    local sfxPct = math.floor(SoundManager.getMasterVolume() * 100 + 0.5)

    local bgmValueLabel = UI.Label {
        text = tostring(bgmPct) .. "%",
        fontSize = s(17), fontColor = Colors.primary, fontWeight = "bold",
    }
    local sfxValueLabel = UI.Label {
        text = tostring(sfxPct) .. "%",
        fontSize = s(17), fontColor = Colors.primary, fontWeight = "bold",
    }

    local overlay

    local function doClose()
        if not overlay then return end
        settingsSave.save({
            bgmVolume = GetBGMVolume(),
            sfxVolume = SoundManager.getMasterVolume(),
        })
        overlay:Remove()
        overlay = nil
        if opts.onClose then opts.onClose() end
    end

    -- 构造内容区子元素列表
    ---@type any[]
    local contentChildren = {
        -- BGM 音量卡片
        makeVolumeCard(
            "背景音乐", bgmValueLabel, bgmPct,
            { 255, 245, 230, 255 },
            function(_, v)
                local vol = math.floor(v + 0.5)
                SetBGMVolume(vol / 100)
                bgmValueLabel:SetText(tostring(vol) .. "%")
            end
        ),
        -- 音效音量卡片
        makeVolumeCard(
            "游戏音效", sfxValueLabel, sfxPct,
            { 237, 241, 216, 255 },
            function(_, v)
                local vol = math.floor(v + 0.5)
                SoundManager.setMasterVolume(vol / 100)
                sfxValueLabel:SetText(tostring(vol) .. "%")
            end,
            function() uiTap.play() end
        ),
    }

    -- 防沉迷状态卡片
    local complianceEnabled = compliance.isEnabled()
    local isAdult = antiAddiction.isAdult()
    local statusText = not complianceEnabled and "外部正式系统接管" or (isAdult and "当前身份：成年人（无限制）" or "当前身份：未成年人（已启用）")
    local statusColor = not complianceEnabled and Colors.success or (isAdult and Colors.success or Colors.warning)
    local statusBg = not complianceEnabled and { 230, 248, 238, 255 } or (isAdult and { 230, 248, 238, 255 } or { 255, 245, 230, 255 })
    contentChildren[#contentChildren + 1] = UI.Panel {
        width = "100%",
        backgroundColor=statusBg, borderWidth=1.5, borderColor=Art.colors.ink,
        borderRadius = s(14),
        padding = s(16), paddingTop = s(14), paddingBottom = s(14),
        flexDirection = "row",
        alignItems = "center", gap = s(12),
        children = {
            -- 状态指示圆点
            UI.Panel {
                width = s(10), height = s(10), borderRadius = s(5),
                backgroundColor = statusColor,
            },
            UI.Panel {
                flexGrow=1, flexBasis=0, flexShrink=1,
                flexDirection = "column", gap = s(2),
                children = {
                    UI.Label {
                        text = "防沉迷保护",
                        fontSize = s(17),
                        fontColor = Colors.textPrimary,
                        fontWeight = "bold",
                    },
                    UI.Label {
                        id="settings-protection-desc", text=statusText, width="100%", whiteSpace="normal",
                        fontSize = s(13),
                        fontColor = Colors.textSecondary,
                    },
                },
            },
        },
    }

    -- 云存档年龄区块（测试功能）：状态卡片 + 使用开关 + 测试按钮
    local ageSettings = settingsSave.load()
    local ageStatusLabel = UI.Label {
        text = "当前档位：" .. cloudAge.bandLabel(cloudAge.getAgeBand()), width="100%", whiteSpace="normal",
        fontSize = s(13), fontColor = Colors.textSecondary,
    }
    contentChildren[#contentChildren + 1] = UI.Panel {
        width = "100%",
        backgroundColor=Art.colors.track, borderWidth=1.5, borderColor=Art.colors.ink,
        borderRadius = s(14),
        padding = s(16), paddingTop = s(14), paddingBottom = s(14),
        flexDirection = "column", gap = s(10),
        children = {
            UI.Panel {
                width="100%", flexDirection="column", gap=s(4),
                children = {
                    UI.Label {
                        width="100%", whiteSpace="normal", text = "云存档年龄（测试）",
                        fontSize = s(17), fontColor = Colors.textPrimary, fontWeight = "bold",
                    },
                    ageStatusLabel,
                },
            },
            -- 使用云存档年龄开关
            UI.Panel {
                width = "100%", flexDirection = "row",
                justifyContent="space-between", alignItems="center", gap=s(12),
                children = {
                    UI.Panel {
                        flexGrow=1, flexBasis=0, flexShrink=1, flexDirection="column", gap=s(2),
                        children = {
                            UI.Label {
                                text = "使用云存档年龄",
                                fontSize = s(15), fontColor = Colors.textPrimary,
                            },
                            UI.Label {
                                id="settings-age-desc", text = "开启后，未实名/未满8 将禁止装扮购买", width="100%", whiteSpace="normal",
                                fontSize = s(12), fontColor = Colors.textSecondary,
                            },
                        },
                    },
                    UI.Toggle {
                        value = ageSettings.useCloudAge == true,
                        height=s(44), flexShrink=0, trackWidth=s(44), trackHeight=s(24), thumbSize=s(20),
                        trackCheckedBgColor=Art.colors.green, trackBg=Art.colors.track, thumbColor=Art.colors.paper,
                        onChange = function(self, value)
                            local s2 = settingsSave.load()
                            s2.useCloudAge = value
                            settingsSave.save(s2)
                            logger.info("settings-popup", "useCloudAge", tostring(value))
                        end,
                    },
                },
            },
            -- 测试账号年龄按钮
            PaperUI.button {
                id="settings-age-open", text = "测试账号年龄",
                variant = "outline",
                width = "100%", height = s(46), fontSize = s(15),
                borderRadius = s(21), fontWeight = "bold",
                fontColor = Colors.primary,
                borderColor = Colors.primaryLight,
                onClick = function()
                    uiTap.play()
                    if not overlay then return end
                    showAgePicker(overlay, function()
                        ageStatusLabel:SetText("当前档位：" .. cloudAge.bandLabel(cloudAge.getAgeBand()))
                    end)
                end,
            },
        },
    }

    -- 隐私政策入口
    contentChildren[#contentChildren + 1] = PaperUI.button {
        text = "隐私政策",
        variant = "outline",
        width = "100%", height = s(48), fontSize = s(17),
        borderRadius = s(10), fontWeight = "bold",
        fontColor = Colors.textSecondary,
        borderColor = Colors.primaryLight,
        onClick = function()
            uiTap.play()
            if overlay then
                PrivacyPolicy.showView(overlay)
            end
        end,
    }

    -- 退出登录：调用 sdk:Logout()（登出后由 SDK 侧处理跳转登录页）
    contentChildren[#contentChildren + 1] = PaperUI.button {
        text = "退出登录",
        variant = "outline",
        width = "100%", height = s(48), fontSize = s(17),
        borderRadius = s(10), fontWeight = "bold",
        fontColor = Colors.error,
        borderColor = Colors.error,
        onClick = function()
            uiTap.play()
            -- Logout 未包含在当前 SDK 类型定义中，使用 any 收窄避免静态检查误报
            local sdkAny = sdk --[[@as any]]
            local ok, err = pcall(function() sdkAny:Logout() end)
            if ok then
                print("[SettingsPopup] 已调用 sdk:Logout()，退出登录")
                doClose()
            else
                print("[SettingsPopup] 退出登录失败: " .. tostring(err))
            end
        end,
    }

    -- 插入扩展按钮
    if opts.extraButtons then
        for _, btn in ipairs(opts.extraButtons) do
            contentChildren[#contentChildren + 1] = PaperUI.button {
                id="settings-extra-"..tostring(#contentChildren+1), text = btn.text,
                variant = btn.variant or "outline",
                width = "100%", height = s(48), fontSize = s(17),
                borderRadius = s(10), fontWeight = "bold",
                fontColor = btn.fontColor,
                borderColor = btn.borderColor or Colors.primaryLight,
                backgroundColor = btn.backgroundColor,
                onClick = function()
                    uiTap.play()
                    if btn.onClick then
                        btn.onClick(overlay, doClose, showConfirm)
                    end
                end,
            }
        end
    end

    -- 关闭按钮
    contentChildren[#contentChildren + 1] = PaperUI.button {
        id="settings-close", text = "关闭", variant = "primary", width = "100%", height = s(50),
        fontSize = s(19), borderRadius = s(10), fontWeight = "bold",
        backgroundColor = Colors.primary, fontColor=Art.colors.ink, borderWidth=s(2), borderColor=Art.colors.ink,
        onClick = function()
            uiTap.play()
            doClose()
        end,
    }

    overlay = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 0, 0, 0, 160 },
        justifyContent = "center", alignItems = "center",
        children = {
            UI.Panel {
                id="settings-card", width = "92%", maxWidth=s(420), height="88%",
                backgroundColor = Art.colors.paper,
                borderRadius = s(12), borderWidth=s(2.5), borderColor=Art.colors.ink, overflow = "hidden",
                flexDirection = "column", alignItems = "center",
                shadowBlur = s(0), shadowColor = { 180, 120, 60, 90 },
                shadowOffsetY = s(6),
                children = {
                    -- 平整纸色标题，留出清楚的内容层级。
                    UI.Panel {
                        width="100%", height=s(64), flexShrink=0,
                        backgroundColor=Art.colors.track, borderBottomWidth=2, borderColor=Art.colors.ink,
                        justifyContent="center", alignItems="center",
                        children={ UI.Label {
                            text="设置", fontSize=s(26), fontColor=Art.colors.ink, fontWeight="bold",
                        } },
                    },
                    -- 受约束的滚动区域，短屏也能到达音量与关闭操作。
                    UI.ScrollView {
                        id="settings-scroll", width="100%", flexGrow=1, flexBasis=0,
                        scrollY=true, scrollX=false, showScrollbar=true,
                        children={ UI.Panel {
                            width="100%", padding=s(20), flexShrink=0,
                            flexDirection="column", alignItems="center", gap=s(16),
                            children=contentChildren,
                        } },
                    },
                },
            },
        },
    }

    parentContainer:AddChild(overlay)
    return overlay, doClose
end

-- ============================================================================
-- 标准扩展按钮：解锁所有关卡 + 清空存档
-- ============================================================================

--- 创建"解锁所有关卡 + 清空存档"标准按钮配置
--- home 和 adventure 页面共用，避免重复定义
---@param callbacks? { onAfterUnlock?: function, onAfterClear?: function }
---@return table[] extraButtons
function M.makeDevButtons(callbacks)
    callbacks = callbacks or {}
    local Storyline = require("modules.storyline.init")

    return {
        {
            text = "解锁所有关卡",
            variant = "primary",
            backgroundColor = Colors.primaryLight,
            fontColor = { 255, 255, 255, 255 },
            onClick = function(overlayRef, doClose, showConfirmFn)
                showConfirmFn({
                    title = "确认解锁所有关卡？",
                    desc = "将完成所有主线关卡，并将自由模式所有关卡记为1星通关。",
                    confirmText = "确认解锁",
                    onConfirm = function()
                        settingsSave.unlockAllLevels()
                        Storyline.load()
                        doClose()
                        if callbacks.onAfterUnlock then callbacks.onAfterUnlock() end
                    end,
                    parent = overlayRef,
                })
            end,
        },
        {
            text = "清空存档（重新开始）",
            variant = "primary",
            backgroundColor = { 250, 140, 140, 255 },
            fontColor = { 255, 255, 255, 255 },
            onClick = function(overlayRef, doClose, showConfirmFn)
                showConfirmFn({
                    title = "确认清空存档？",
                    desc = "所有主线和自由模式的游戏进度将被清空，此操作不可撤销。",
                    confirmText = "确认清空",
                    confirmColor = Colors.error,
                    onConfirm = function()
                        settingsSave.clearAllProgress()
                        Storyline.load()
                        doClose()
                        if callbacks.onAfterClear then callbacks.onAfterClear() end
                    end,
                    parent = overlayRef,
                })
            end,
        },
    }
end

-- ============================================================================
-- 页面级生命周期管理器
-- ============================================================================

--- 创建页面级设置弹窗管理器，封装 overlay 状态管理
--- 各页面不再需要手动维护 settingsOverlay_ 变量和 open/close 函数
---@param opts? { extraButtons?: table[] }
---@return table helper { open(container), close(), isOpen() }
function M.createPageHelper(opts)
    opts = opts or {}

    ---@type any
    local overlay_ = nil

    local helper = {}

    function helper.open(pageContainer)
        if overlay_ then return end
        if not pageContainer then return end

        local o = M.open(pageContainer, {
            extraButtons = opts.extraButtons,
            onClose = function()
                overlay_ = nil
            end,
        })
        overlay_ = o
    end

    function helper.close()
        if overlay_ then
            overlay_:Remove()
            overlay_ = nil
        end
    end

    function helper.isOpen()
        return overlay_ ~= nil
    end

    return helper
end

return M
