--- 底部导航组件（激活指示器 + 视觉增强）
local UI = require("urhox-libs/UI")
local Colors = require("shared.constants.colors")
local Layout = require("shared.constants.layout")

local M = {}

--- 创建底部导航
---@param props table { tabs: {id:string, label:string, icon:string}[], activeTab: string, onTabChange: function }
---@return any UI 节点
function M.create(props)
    local tabs = props.tabs
    local activeTab = props.activeTab or tabs[1].id
    local onTabChange = props.onTabChange

    local navItems = {}
    for _, tab in ipairs(tabs) do
        local isActive = (tab.id == activeTab)
        local labelColor = isActive and Colors.navActive or Colors.navInactive
        local fontWeight = isActive and "bold" or "normal"
        local iconScale = isActive and 1.1 or 1.0

        -- 激活指示器（选中项顶部的小圆角条）
        local indicator = isActive and UI.Panel {
            position = "absolute",
            top = 0,
            width = 28,
            height = 3,
            borderRadius = { 0, 0, 2, 2 },
            backgroundGradient = {
                type = "linear",
                direction = "to-right",
                from = Colors.gradientStart,
                to   = Colors.gradientEnd,
            },
        } or nil

        -- 图标背景光晕（激活时）
        local iconBg = isActive and { 79, 109, 245, 15 } or nil

        table.insert(navItems, UI.Panel {
            flexGrow = 1,
            height = "100%",
            justifyContent = "center",
            alignItems = "center",
            flexDirection = "column",
            gap = 3,
            overflow = "hidden",
            onClick = function()
                if onTabChange then
                    onTabChange(tab.id)
                end
            end,
            children = {
                -- 激活指示条
                indicator,
                -- 图标区域（带背景光晕）
                UI.Panel {
                    width = 36,
                    height = 28,
                    borderRadius = 14,
                    backgroundColor = iconBg,
                    justifyContent = "center",
                    alignItems = "center",
                    children = {
                        UI.Label {
                            text = tab.icon or "",
                            fontSize = 20,
                            textAlign = "center",
                            pointerEvents = "none",
                            scale = iconScale,
                        },
                    },
                },
                -- 标签文字
                UI.Label {
                    text = tab.label,
                    fontSize = Layout.FONT_SIZE_SMALL,
                    fontColor = labelColor,
                    fontWeight = fontWeight,
                    textAlign = "center",
                    pointerEvents = "none",
                },
            },
        })
    end

    return UI.Panel {
        width = "100%",
        height = Layout.BOTTOM_NAV_HEIGHT,
        backgroundColor = Colors.navBg,
        flexDirection = "row",
        alignItems = "center",
        -- 顶部阴影（向上扩散）
        boxShadow = {
            { x = 0, y = -2, blur = 8, spread = 0, color = { 0, 0, 0, 12 } },
        },
        children = navItems,
    }
end

return M
