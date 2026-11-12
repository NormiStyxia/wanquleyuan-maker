--- 推箱子关卡编辑器
--- 职责：NanoVG 绘制编辑网格、工具栏、尺寸调节、导出关卡数据
local boardRenderer = require("games.p1-puzzle-land.view.board-renderer")
local gridMgr = require("games.p1-puzzle-land.editor.core.grid-manager")
local serializer = require("games.p1-puzzle-land.editor.core.level-serializer")
local panels = require("games.p1-puzzle-land.editor.ui.editor-panels")
local modalDialog = require("games.p1-puzzle-land.editor.ui.modal-dialog")
local logger = require("shared.utils.logger")

local M = {}
local MODULE = "level-editor"

local COLORS = boardRenderer.COLORS

-- ============================================================================
-- 共享编辑器状态（传递给子模块）
-- ============================================================================

--- 工具定义
local TOOLS = {
    { id = "wall",        label = "墙壁", icon = "W" },
    { id = "floor",       label = "地板", icon = "F" },
    { id = "ice",         label = "冰面", icon = "I" },
    { id = "box",         label = "箱子", icon = "B" },
    { id = "target",      label = "目标", icon = "T" },
    { id = "player",      label = "玩家", icon = "P" },
    { id = "portal_red",  label = "红门", icon = "R门" },
    { id = "portal_green",label = "绿门", icon = "G门" },
    { id = "portal_blue", label = "蓝门", icon = "B门" },
    { id = "ptarget_red",  label = "红标", icon = "R标" },
    { id = "ptarget_green",label = "绿标", icon = "G标" },
    { id = "ptarget_blue", label = "蓝标", icon = "B标" },
    { id = "eraser",      label = "橡皮", icon = "E" },
}

--- 工具 ID → 传送门颜色映射
local TOOL_PORTAL_COLOR = {
    portal_red = "red", portal_green = "green", portal_blue = "blue",
    ptarget_red = "red", ptarget_green = "green", ptarget_blue = "blue",
}

--- 共享状态表（子模块通过此表读写编辑器状态）
local state = {
    -- 网格尺寸
    gridW = 8,
    gridH = 6,
    MIN_SIZE = 4,
    MAX_SIZE = 16,
    -- 当前工具
    currentTool = "wall",
    -- 网格数据
    grid = {},
    -- 特殊元素
    playerPos = nil,
    boxPositions = {},
    targetPositions = {},
    portalPositions = {},
    portalTargetPositions = {},
    -- 导出提示
    exportMessage = nil,
    exportMessageTimer = 0,
    -- 常量引用
    TOOL_PORTAL_COLOR = TOOL_PORTAL_COLOR,
}

--- 拖动放置状态
local isDragging_ = false
---@type number[]|nil
local lastDragCell_ = nil

-- ============================================================================
-- 初始化 / 重置
-- ============================================================================

--- 进入编辑器
function M.enter()
    state.currentTool = "wall"
    gridMgr.initGrid(state)
    logger.info(MODULE, "enter", "editor opened, grid=" .. state.gridW .. "x" .. state.gridH)
end

--- 离开编辑器
function M.leave()
    modalDialog.dismiss()
    isDragging_ = false
    lastDragCell_ = nil
    logger.info(MODULE, "leave", "editor closed")
end

-- ============================================================================
-- 布局计算
-- ============================================================================

--- 计算编辑器布局
---@param screenW number
---@param screenH number
---@return table layout
local function calcEditorLayout(screenW, screenH)
    local availW = screenW - panels.SIDE_PAD * 2
    local availH = screenH - panels.TOP_BAR_H - panels.toolbarHeight(screenW, #TOOLS) - panels.BOTTOM_BAR_H - 16

    local cellW = math.floor(availW / state.gridW)
    local cellH = math.floor(availH / state.gridH)
    local cellSize = math.max(1, math.min(cellW, cellH, 64))

    local boardW = cellSize * state.gridW
    local boardH = cellSize * state.gridH

    local offsetX = math.floor((screenW - boardW) / 2)
    local offsetY = panels.TOP_BAR_H + panels.toolbarHeight(screenW, #TOOLS) + 8 + math.floor((availH - boardH) / 2)

    return {
        cellSize = cellSize,
        offsetX = offsetX,
        offsetY = offsetY,
        boardW = boardW,
        boardH = boardH,
    }
end



--- 构建可玩的关卡数据（委托到 serializer）
---@return table|nil level 成功返回关卡数据，失败返回 nil
---@return string|nil errMsg 失败原因
function M.buildPlayableLevel()
    return serializer.buildPlayableLevel(state)
end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 逻辑更新
---@param dt number
function M.update(dt)
    if state.exportMessageTimer > 0 then
        state.exportMessageTimer = state.exportMessageTimer - dt
    end
    modalDialog.update(dt)
end

--- 渲染编辑器
---@param ctx userdata NanoVG 上下文
---@param screenW number
---@param screenH number
---@return table allHitAreas
function M.render(ctx, screenW, screenH)
    -- 背景
    nvgBeginPath(ctx)
    nvgRect(ctx, 0, 0, screenW, screenH)
    nvgFillColor(ctx, nvgRGBA(COLORS.background[1], COLORS.background[2], COLORS.background[3], 255))
    nvgFill(ctx)

    local layout = calcEditorLayout(screenW, screenH)

    -- 绘制各部分（委托到 panels 模块）
    local topHits = panels.drawTopBar(ctx, screenW, state)
    local toolHits = panels.drawToolbar(ctx, screenW, state, TOOLS)
    panels.drawGrid(ctx, layout, state)
    local bottomHits = panels.drawBottomBar(ctx, screenW, screenH, state)

    -- 导出提示
    panels.drawExportMessage(ctx, screenW, screenH, state)

    -- 导入模态框（最顶层）
    local modalHits = modalDialog.draw(ctx, screenW, screenH)

    return {
        topHits = topHits,
        toolHits = toolHits,
        bottomHits = bottomHits,
        layout = layout,
        modal = modalHits,
    }
end

--- 将逻辑像素坐标转换为网格坐标（1-based），超界返回 nil
---@param mx number
---@param my number
---@param hitAreas table
---@return number|nil gx, number|nil gy
local function screenToGrid(mx, my, hitAreas)
    local layout = hitAreas and hitAreas.layout
    if not layout then return nil, nil end
    local gx = math.floor((mx - layout.offsetX) / layout.cellSize) + 1
    local gy = math.floor((my - layout.offsetY) / layout.cellSize) + 1
    if gx >= 1 and gx <= state.gridW and gy >= 1 and gy <= state.gridH then
        return gx, gy
    end
    return nil, nil
end

--- 开始拖动（鼠标/触摸按下时调用）
--- 如果按下位置在网格内，开始拖动并放置第一个方块
---@param mx number
---@param my number
---@param hitAreas table
---@return boolean started 是否开始了网格拖动
function M.beginDrag(mx, my, hitAreas)
    local gx, gy = screenToGrid(mx, my, hitAreas)
    if gx then
        isDragging_ = true
        lastDragCell_ = { gx, gy }
        gridMgr.placeAt(state, gx, gy)
        return true
    end
    isDragging_ = false
    lastDragCell_ = nil
    return false
end

--- 拖动移动（鼠标/触摸移动时调用）
---@param mx number
---@param my number
---@param hitAreas table
function M.moveDrag(mx, my, hitAreas)
    if not isDragging_ then return end
    local gx, gy = screenToGrid(mx, my, hitAreas)
    if gx then
        -- 只在进入新格子时放置，避免重复操作
        if not lastDragCell_ or lastDragCell_[1] ~= gx or lastDragCell_[2] ~= gy then
            lastDragCell_ = { gx, gy }
            gridMgr.placeAt(state, gx, gy)
        end
    end
end

--- 结束拖动
---@return boolean wasDragging 是否处于拖动状态
function M.endDrag()
    local was = isDragging_
    isDragging_ = false
    lastDragCell_ = nil
    return was
end

--- 处理点击
---@param mx number 逻辑像素 x
---@param my number 逻辑像素 y
---@param hitAreas table render() 返回的点击区域
---@return string|nil action "back" | "export" | nil
function M.handleClick(mx, my, hitAreas)
    if not hitAreas then return nil end

    -- 顶栏按钮
    local top = hitAreas.topHits
    if top then
        local bb = top.backBtn
        if bb and mx >= bb.x and mx <= bb.x + bb.w and my >= bb.y and my <= bb.y + bb.h then
            return "back"
        end

        -- 尺寸调节
        local wm = top.widthMinus
        if wm and mx >= wm.x and mx <= wm.x + wm.w and my >= wm.y and my <= wm.y + wm.h then
            gridMgr.adjustWidth(state, -1)
            return nil
        end
        local wp = top.widthPlus
        if wp and mx >= wp.x and mx <= wp.x + wp.w and my >= wp.y and my <= wp.y + wp.h then
            gridMgr.adjustWidth(state, 1)
            return nil
        end
        local hm = top.heightMinus
        if hm and mx >= hm.x and mx <= hm.x + hm.w and my >= hm.y and my <= hm.y + hm.h then
            gridMgr.adjustHeight(state, -1)
            return nil
        end
        local hp = top.heightPlus
        if hp and mx >= hp.x and mx <= hp.x + hp.w and my >= hp.y and my <= hp.y + hp.h then
            gridMgr.adjustHeight(state, 1)
            return nil
        end
    end

    -- 工具栏
    local tools = hitAreas.toolHits
    if tools then
        for _, btn in ipairs(tools) do
            if mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h then
                state.currentTool = btn.toolId
                return nil
            end
        end
    end

    -- 底部栏
    local bottom = hitAreas.bottomHits
    if bottom then
        local cb = bottom.clearBtn
        if cb and mx >= cb.x and mx <= cb.x + cb.w and my >= cb.y and my <= cb.y + cb.h then
            gridMgr.initGrid(state)
            return nil
        end

        local pb = bottom.playBtn
        if pb and mx >= pb.x and mx <= pb.x + pb.w and my >= pb.y and my <= pb.y + pb.h then
            -- 校验是否可以试玩
            if not state.playerPos then
                state.exportMessage = "请先放置玩家!"
                state.exportMessageTimer = 2.0
                return nil
            end
            if #state.boxPositions == 0 then
                state.exportMessage = "请先放置箱子!"
                state.exportMessageTimer = 2.0
                return nil
            end
            if #state.boxPositions ~= #state.targetPositions then
                state.exportMessage = "箱子和目标数量不一致!"
                state.exportMessageTimer = 2.5
                return nil
            end
            return "test_play"
        end

        local ib = bottom.importBtn
        if ib and mx >= ib.x and mx <= ib.x + ib.w and my >= ib.y and my <= ib.y + ib.h then
            modalDialog.open()
            return nil
        end

        local eb = bottom.exportBtn
        if eb and mx >= eb.x and mx <= eb.x + eb.w and my >= eb.y and my <= eb.y + eb.h then
            -- 校验
            if not state.playerPos then
                state.exportMessage = "请先放置玩家!"
                state.exportMessageTimer = 2.0
                return nil
            end
            if #state.boxPositions == 0 then
                state.exportMessage = "请先放置箱子!"
                state.exportMessageTimer = 2.0
                return nil
            end
            if #state.boxPositions ~= #state.targetPositions then
                state.exportMessage = "箱子和目标数量不一致!"
                state.exportMessageTimer = 2.5
                return nil
            end

            local output = serializer.export(state)
            print("========== 关卡数据 ==========")
            print(output)
            print("==============================")
            state.exportMessage = "已输出到控制台!"
            state.exportMessageTimer = 2.5
            logger.info(MODULE, "export", "level exported to console")
            return "export"
        end
    end

    -- 网格区域点击
    local layout = hitAreas.layout
    if layout then
        local gx = math.floor((mx - layout.offsetX) / layout.cellSize) + 1
        local gy = math.floor((my - layout.offsetY) / layout.cellSize) + 1

        if gx >= 1 and gx <= state.gridW and gy >= 1 and gy <= state.gridH then
            gridMgr.placeAt(state, gx, gy)
        end
    end

    return nil
end

-- ============================================================================
-- 导入模态框交互（委托到 modal-dialog 模块）
-- ============================================================================

--- 模态框是否正在显示
---@return boolean
function M.isModalShowing()
    return modalDialog.isShowing()
end

--- 处理文本输入（从 TextInput 事件转发）
---@param text string 输入的字符
function M.handleTextInput(text)
    modalDialog.handleTextInput(text)
end

--- 处理模态框的按键事件
---@param key number 按键码
---@param qualifiers number 修饰键
---@return boolean handled 是否消费了该按键
function M.handleKeyForModal(key, qualifiers)
    return modalDialog.handleKey(key, qualifiers, state)
end

--- 处理模态框内的点击事件
---@param mx number
---@param my number
---@return boolean handled 是否消费了点击
function M.handleModalClick(mx, my)
    return modalDialog.handleClick(mx, my, state)
end

return M
