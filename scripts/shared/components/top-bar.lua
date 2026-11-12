--- 顶部栏组件（渐变背景 + 装饰元素）
local UI = require("urhox-libs/UI")
local Colors = require("shared.constants.colors")
local Layout = require("shared.constants.layout")

local M = {}

--- 创建顶部栏
---@param props { title: string }
---@return any UI 节点
function M.create(props)
    local title = props and props.title or "玩趣乐园"

    return UI.Panel {
        width = "100%",
        height = Layout.TOP_BAR_HEIGHT,
        backgroundGradient = {
            type = "linear",
            direction = "to-right",
            from = Colors.gradientStart,
            to   = Colors.gradientEnd,
        },
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "center",
        paddingHorizontal = Layout.PAGE_PADDING,
        overflow = "hidden",
        -- 底部阴影
        boxShadow = {
            { x = 0, y = 3, blur = 10, spread = 0, color = { 80, 100, 240, 50 } },
        },
        children = {
            -- 左侧装饰圆点
            UI.Panel {
                position = "absolute",
                left = -10,
                top = -10,
                width = 40,
                height = 40,
                borderRadius = 20,
                backgroundColor = { 255, 255, 255, 20 },
            },
            -- 右上角装饰圆环
            UI.Panel {
                position = "absolute",
                right = 20,
                top = -15,
                width = 50,
                height = 50,
                borderRadius = 25,
                borderWidth = 3,
                borderColor = { 255, 255, 255, 15 },
            },
            -- 右侧小装饰圆点
            UI.Panel {
                position = "absolute",
                right = 80,
                bottom = 8,
                width = 8,
                height = 8,
                borderRadius = 4,
                backgroundColor = { 255, 255, 255, 25 },
            },
            -- 标题区域
            UI.Panel {
                flexDirection = "row",
                alignItems = "center",
                gap = 8,
                children = {
                    -- 拼图图标装饰
                    UI.Panel {
                        width = 28,
                        height = 28,
                        borderRadius = 8,
                        backgroundColor = { 255, 255, 255, 20 },
                        justifyContent = "center",
                        alignItems = "center",
                        children = {
                            UI.Label {
                                text = "P",
                                fontSize = 16,
                                textAlign = "center",
                            },
                        },
                    },
                    UI.Label {
                        text = title,
                        fontSize = Layout.FONT_SIZE_TITLE + 1,
                        fontColor = Colors.textWhite,
                        fontWeight = "bold",
                        textAlign = "center",
                        letterSpacing = 1,
                    },
                },
            },
        },
    }
end

return M
