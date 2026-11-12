--- 调试面板组件
--- 提供功能开关的总开关和各子开关 UI 控制
--- 通过右上角悬浮按钮展开/收起
local UI = require("urhox-libs/UI")
local Colors = require("shared.constants.colors")
local Layout = require("shared.constants.layout")
local featureFlags = require("config.feature-flags")
local logger = require("shared.utils.logger")
local SoundTestPanel = require("shared.components.sound-test-panel")

local M = {}
local MODULE = "debug-panel"

-- ============================================================================
-- 内部状态
-- ============================================================================
local visible_ = false

---@type any
local rootNode_ = nil      -- 最外层容器（始终存在）
---@type any
local fabBtn_ = nil         -- 悬浮按钮
---@type any
local panelNode_ = nil      -- 展开的面板
---@type any
local masterToggle_ = nil   -- 总开关 Toggle
---@type table<string, any>
local toggleWidgets_ = {}   -- key -> Toggle widget

-- 前置声明（实现在后面）
local hidePanel

-- ============================================================================
-- 面板构建
-- ============================================================================

--- 创建单行开关
---@param def { key: string, label: string, default: boolean }
---@return any UI 节点
local function createToggleRow(def)
    local isOn = featureFlags.isEnabled(def.key)

    local toggle = UI.Toggle {
        value = isOn,
        trackWidth = 40,
        trackHeight = 22,
        thumbSize = 18,
        onChange = function(self, value)
            featureFlags.setEnabled(def.key, value)
        end,
    }
    toggleWidgets_[def.key] = toggle

    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "space-between",
        paddingLeft = 4,
        paddingRight = 4,
        height = 32,
        children = {
            UI.Label {
                text = def.label,
                fontSize = 13,
                fontColor = { 60, 60, 70, 255 },
            },
            toggle,
        },
    }
end

--- 构建展开面板的内容
---@return any UI 节点
local function buildPanel()
    -- 总开关行
    local masterOn = featureFlags.isMasterEnabled()
    masterToggle_ = UI.Toggle {
        value = masterOn,
        trackWidth = 40,
        trackHeight = 22,
        thumbSize = 18,
        onChange = function(self, value)
            featureFlags.setMasterEnabled(value)
            -- 总开关关闭时，视觉上禁用所有子开关
            for _, def in ipairs(featureFlags.definitions) do
                local w = toggleWidgets_[def.key]
                if w then
                    w:SetDisabled(not value)
                end
            end
        end,
    }

    local masterRow = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "space-between",
        paddingLeft = 4,
        paddingRight = 4,
        height = 36,
        children = {
            UI.Label {
                text = "总开关",
                fontSize = 14,
                fontColor = Colors.textPrimary,
                fontWeight = "bold",
            },
            masterToggle_,
        },
    }

    -- 分割线
    local divider = UI.Panel {
        width = "100%",
        height = 1,
        backgroundColor = Colors.divider,
        marginTop = 4,
        marginBottom = 4,
    }

    -- 子开关列表
    local toggleRows = {}
    for _, def in ipairs(featureFlags.definitions) do
        local row = createToggleRow(def)
        table.insert(toggleRows, row)
    end

    -- 如果总开关关闭，禁用子开关
    if not masterOn then
        for _, def in ipairs(featureFlags.definitions) do
            local w = toggleWidgets_[def.key]
            if w then w:SetDisabled(true) end
        end
    end

    -- 组装面板
    ---@type any[]
    local children = { masterRow, divider }
    for _, row in ipairs(toggleRows) do
        children[#children + 1] = row
    end

    -- 音效测试区域
    local testDivider = UI.Panel {
        width = "100%",
        height = 1,
        backgroundColor = Colors.divider,
        marginTop = 6,
        marginBottom = 6,
    }
    children[#children + 1] = testDivider

    children[#children + 1] = UI.Button {
        text = "🔊 音效测试",
        width = "100%",
        height = 34,
        fontSize = 13,
        borderRadius = 8,
        variant = "outline",
        onClick = function()
            hidePanel()
            SoundTestPanel.toggle()
        end,
    }

    return UI.Panel {
        width = 200,
        backgroundColor = { 255, 255, 255, 245 },
        borderRadius = Layout.RADIUS_CARD,
        padding = 12,
        flexDirection = "column",
        gap = 2,
        -- 阴影
        shadowBlur = Layout.SHADOW_SM,
        shadowColor = { 0, 0, 0, 40 },
        shadowOffsetY = 2,
        children = children,
    }
end

-- ============================================================================
-- 显示 / 隐藏
-- ============================================================================

local function showPanel()
    if visible_ then return end
    visible_ = true

    toggleWidgets_ = {}
    panelNode_ = buildPanel()

    rootNode_:AddChild(panelNode_)
    fabBtn_:SetStyle({ backgroundColor = Colors.primaryDark })

    logger.info(MODULE, "show", "ok")
end

hidePanel = function()
    if not visible_ then return end
    visible_ = false

    if panelNode_ then
        rootNode_:RemoveChild(panelNode_)
        panelNode_ = nil
    end
    toggleWidgets_ = {}
    masterToggle_ = nil

    fabBtn_:SetStyle({ backgroundColor = Colors.primary })

    logger.info(MODULE, "hide", "ok")
end

local function togglePanel()
    if visible_ then
        hidePanel()
    else
        showPanel()
    end
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 创建调试面板（返回绝对定位的 UI 节点，需添加到根层级）
---@return any UI 节点
function M.create()
    -- 悬浮按钮（右上角齿轮图标）
    fabBtn_ = UI.Button {
        text = "D",
        width = 32,
        height = 32,
        fontSize = 14,
        borderRadius = 16,
        variant = "primary",
        onClick = function()
            togglePanel()
        end,
    }

    -- 根容器（绝对定位右上角）
    rootNode_ = UI.Panel {
        position = "absolute",
        top = 8,
        right = 8,
        alignItems = "flex-end",
        flexDirection = "column",
        gap = 6,
        children = {
            fabBtn_,
        },
    }

    -- 总开关关闭时隐藏调试按钮
    if not featureFlags.isMasterEnabled() then
        rootNode_:SetVisible(false)
    end

    return rootNode_
end

--- 销毁
function M.destroy()
    hidePanel()
    rootNode_ = nil
    fabBtn_ = nil
end

--- 是否面板展开
---@return boolean
function M.isVisible()
    return visible_
end

return M
