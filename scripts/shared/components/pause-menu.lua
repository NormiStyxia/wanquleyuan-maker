--- 暂停菜单组件（主容器统一提供，小游戏不需自行实现）
--- 暖色调风格：奶油白卡片 + 暖橙主按钮 + 深棕文字
local UI = require("urhox-libs/UI")
local PaperUI = require("shared.components.paper-ui")
local Colors = require("shared.constants.colors")
local Layout = require("shared.constants.layout")
local uiTap = require("shared.utils.ui-tap")

local M = {}

--- 创建暂停菜单覆盖层
---@param props { onResume: function, onBackToHall: function, gameTitle: string|nil }
---@return any UI 节点
function M.create(props)
    local onResume = props.onResume
    local onBackToHall = props.onBackToHall
    local gameTitle = props.gameTitle or "游戏"

    return UI.Panel {
        -- 全屏半透明遮罩（暖棕色调）
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = Colors.dialog.overlay,
        justifyContent = "center",
        alignItems = "center",
        children = {
            -- 菜单卡片（奶油白）
            UI.Panel {
                width = 280,
                backgroundColor = Colors.dialog.cardBg,
                borderRadius = Layout.RADIUS_BUTTON,
                borderWidth = 1.5,
                borderColor = Colors.dialog.cardBorder,
                padding = 24,
                flexDirection = "column",
                alignItems = "center",
                gap = Layout.GAP_XLARGE,
                -- 卡片阴影（暖棕色投影）
                shadowBlur = Layout.SHADOW_LG,
                shadowColor = Colors.dialog.cardShadow,
                children = {
                    -- 标题
                    UI.Label {
                        text = "游戏暂停",
                        fontSize = 20,
                        fontColor = Colors.dialog.titleColor,
                        fontWeight = "bold",
                        textAlign = "center",
                    },
                    -- 游戏名
                    UI.Label {
                        text = gameTitle,
                        fontSize = Layout.FONT_SIZE_BODY,
                        fontColor = { 180, 140, 100, 200 },
                        textAlign = "center",
                    },
                    -- 分割线（暖色）
                    UI.Panel {
                        width = "100%",
                        height = 1,
                        backgroundColor = { 235, 215, 190, 200 },
                    },
                    -- 继续游戏按钮（暖橙主色）
                    PaperUI.button {
                        text = "继续游戏",
                        variant = "primary",
                        width = "100%",
                        backgroundColor = Colors.primary,
                        borderRadius = Layout.RADIUS_CAPSULE,
                        onClick = function()
                            uiTap.play()
                            if onResume then onResume() end
                        end,
                    },
                    -- 返回大厅按钮（浅暖色）
                    PaperUI.button {
                        text = "返回大厅",
                        variant = "secondary",
                        width = "100%",
                        backgroundColor = Colors.dialog.btnExitBg,
                        fontColor = { 160, 110, 70, 230 },
                        borderColor = { 220, 185, 150, 160 },
                        borderRadius = Layout.RADIUS_CAPSULE,
                        onClick = function()
                            uiTap.play()
                            if onBackToHall then onBackToHall() end
                        end,
                    },
                },
            },
        },
    }
end

return M
