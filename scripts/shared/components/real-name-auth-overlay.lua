--- 实名认证 UI 覆盖层
--- 全屏模态弹窗，要求玩家输入身份证号进行实名认证
--- 当前阶段：本地模拟校验
--- 后续阶段：替换为真实 SDK 弹窗或跳转
local UI = require("urhox-libs/UI")
local PaperUI = require("shared.components.paper-ui")
local realNameAuth = require("shared.real-name-auth")
local Layout = require("shared.constants.layout")
local C = require("shared.constants.art").colors
local logger = require("shared.utils.logger")

local M = {}
local MODULE = "real-name-auth-overlay"

---@type any
local overlay_ = nil
---@type any
local errorLabel_ = nil
---@type any
local submitBtn_ = nil
---@type any
local inputField_ = nil
---@type any
local nameField_ = nil
local active_ = false
local onComplete_ = nil
local inputValue_ = ""
local nameValue_ = ""

-- ============================================================================
-- UI 构建
-- ============================================================================

--- 创建实名认证 UI
---@param onComplete fun(verified: boolean, isAdult: boolean) 认证完成回调
---@return any UI 节点
function M.create(onComplete)
    onComplete_ = onComplete
    active_ = true
    inputValue_ = ""
    nameValue_ = ""

    -- 错误提示标签
    errorLabel_ = UI.Label {
        id = "auth-error", text = "",
        fontSize = 13,
        fontColor = { 220, 60, 60, 255 },
        height = 18,
        marginTop = 4,
        textAlign = "center",
    }

    -- 姓名输入框
    nameField_ = PaperUI.field {
        id = "auth-name",
        value = "",
        placeholder = "请输入真实姓名",
        fontSize = 16,
        width = "100%",
        height = 46,
        borderRadius = Layout.RADIUS_PANEL,
        maxLength = 20,
        onChange = function(self, value)
            nameValue_ = value or ""
            if errorLabel_ then
                errorLabel_:SetStyle({ text = "" })
            end
        end,
        onSubmit = function(self, value)
            nameValue_ = value or ""
        end,
    }

    -- 身份证号输入框
    inputField_ = PaperUI.field {
        id = "auth-id-number",
        value = "",
        placeholder = "请输入18位身份证号码",
        fontSize = 16,
        width = "100%",
        height = 46,
        borderRadius = Layout.RADIUS_PANEL,
        maxLength = 18,
        onChange = function(self, value)
            inputValue_ = value or ""
            -- 清除错误提示
            if errorLabel_ then
                errorLabel_:SetStyle({ text = "" })
            end
        end,
        onSubmit = function(self, value)
            inputValue_ = value or ""
            M.submit()
        end,
    }

    -- 提交按钮
    submitBtn_ = PaperUI.button {
        id = "auth-submit",
        text = "确认提交",
        variant = "primary",
        width = "100%",
        height = 46,
        fontSize = Layout.FONT_SIZE_MEDIUM,
        borderRadius = Layout.RADIUS_LARGE,
        fontWeight = "bold",
        backgroundColor = C.orange,
        onClick = function()
            M.submit()
        end,
    }

    -- 全屏覆盖
    overlay_ = UI.Panel {
        position = "absolute",
        left = 0, top = 0,
        width = "100%", height = "100%",
        backgroundColor = { 63, 56, 36, 175 },
        justifyContent = "center",
        alignItems = "center",
        children = {
            -- 认证卡片
            UI.Panel {
                id = "auth-card", width = "90%", maxWidth = 420,
                height = "88%", maxHeight = 620,
                backgroundColor = C.paper,
                borderWidth = 2.5, borderColor = C.ink,
                borderRadius = 12,
                overflow = "hidden",
                flexDirection = "column",
                alignItems = "center",
                shadowBlur = 0,
                shadowColor = { 180, 120, 60, 80 },
                shadowOffsetY = 6,
                children = {
                    -- 标题栏（暖色渐变）
                    UI.Panel {
                        alignSelf = "stretch",
                        marginLeft = 2.5, marginRight = 2.5,
                        height = 80,
                        borderBottomWidth = 2, borderColor = C.track,
                        flexShrink = 0, paddingHorizontal = 12,
                        justifyContent = "center",
                        alignItems = "center",
                        flexDirection = "column",
                        children = {
                            UI.Label {
                                text = "模拟实名认证",
                                fontSize = Layout.FONT_SIZE_HEADER,
                                fontColor = C.ink,
                                fontWeight = "bold",
                                marginBottom = 4,
                            },
                            UI.Label {
                                text = "根据国家规定，需完成实名认证后进入游戏",
                                fontSize = 12,
                                fontColor = C.muted,
                            },
                        },
                    },

                    -- 表单区域：短屏可以滚到输入和提交操作。
                    UI.ScrollView {
                        id = "auth-scroll", flexGrow = 1, flexBasis = 0,
                        flexShrink = 1,
                        width = "100%",
                        padding = 24,
                        paddingTop = 20,
                        paddingBottom = 16,
                        flexDirection = "column",
                        children = {
                            -- 姓名说明
                            UI.Label {
                                text = "请输入您的真实姓名：",
                                fontSize = 14,
                                fontColor = { 80, 60, 40, 255 },
                                marginBottom = 12,
                            },

                            -- 姓名输入框
                            nameField_,

                            -- 间距
                            UI.Panel { height = 12 },

                            -- 身份证说明
                            UI.Label {
                                text = "请输入您的身份证号码：",
                                fontSize = 14,
                                fontColor = { 80, 60, 40, 255 },
                                marginBottom = 12,
                            },

                            -- 身份证输入框
                            inputField_,

                            -- 错误提示
                            errorLabel_,

                            -- 间距
                            UI.Panel { height = 16 },

                            -- 提交按钮
                            submitBtn_,

                            -- 隐私提示
                            UI.Panel {
                                marginTop = 16,
                                flexDirection = "column",
                                alignItems = "center",
                                children = {
                                    UI.Label {
                                        text = "您的信息仅用于实名认证，我们将严格保护",
                                        fontSize = 11,
                                        fontColor = C.muted,
                                        textAlign = "center",
                                    },
                                    UI.Label {
                                        text = "您的个人隐私安全",
                                        fontSize = 11,
                                        fontColor = C.muted,
                                        textAlign = "center",
                                        marginTop = 2,
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }

    logger.info(MODULE, "create", "overlay created")
    return overlay_
end

--- 提交认证
function M.submit()
    if not active_ then return end

    local name = nameValue_
    local idNumber = inputValue_

    -- 姓名空值检查
    if not name or #name == 0 then
        if errorLabel_ then
            errorLabel_:SetStyle({ text = "请输入真实姓名" })
        end
        return
    end

    -- 身份证号空值检查
    if not idNumber or #idNumber == 0 then
        if errorLabel_ then
            errorLabel_:SetStyle({ text = "请输入身份证号码" })
        end
        return
    end

    -- 调用认证模块
    realNameAuth.verify(name, idNumber, function(success, isAdult, errMsg)
        if not success then
            -- 显示错误
            if errorLabel_ then
                errorLabel_:SetStyle({ text = errMsg or "认证失败" })
            end
            return
        end

        -- 认证成功
        active_ = false
        logger.info(MODULE, "submit", "verified, isAdult=" .. tostring(isAdult))

        -- 隐藏覆盖层
        if overlay_ then
            overlay_:SetVisible(false)
        end

        -- 回调
        if onComplete_ then
            onComplete_(true, isAdult)
        end
    end)
end

--- 是否仍在显示中
---@return boolean
function M.isActive()
    return active_
end

return M
