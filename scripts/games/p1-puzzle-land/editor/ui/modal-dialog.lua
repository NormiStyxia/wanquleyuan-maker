--- 导入模态框模块
--- 职责：drawImportModal 渲染 + 文本输入/按键/点击交互
--- 内部持有模态框状态（文本、光标、滚动），通过 state 读写导出消息

local serializer = require("games.p1-puzzle-land.editor.core.level-serializer")

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local M = {}

-- ============================================================================
-- 模态框内部状态
-- ============================================================================

local showImportModal_ = false
local importText_ = ""
local importCursorPos_ = 0
local importCursorTimer_ = 0
---@type table|nil
local importModalHits_ = nil
local importTextScrollX_ = 0

-- ============================================================================
-- 内部辅助
-- ============================================================================

--- 关闭导入模态框（统一清理）
local function closeImportModal()
    showImportModal_ = false
    input:SetScreenKeyboardVisible(false)
end

-- ============================================================================
-- 绘制
-- ============================================================================

--- 绘制导入模态框
---@param ctx userdata
---@param screenW number
---@param screenH number
function M.draw(ctx, screenW, screenH)
    if not showImportModal_ then return end

    nvgBeginPath(ctx);nvgRect(ctx,0,0,screenW,screenH)
    nvgFillColor(ctx,nvgRGBA(63,56,36,120));nvgFill(ctx)
    local modalW,modalH=math.min(screenW-32,400),244
    local mx,my=(screenW-modalW)/2,(screenH-modalH)/2
    Paper.panel(ctx,mx,my,modalW,modalH)
    Paper.text(ctx,screenW/2,my+28,"导入关卡",22)
    local inputX,inputY,inputW,inputH=mx+16,my+56,modalW-32,48
    Pen.plaque(ctx,inputX,inputY,inputW,inputH,{255,251,238,255},1.8)
    -- 裁剪区域绘制文本
    nvgSave(ctx)
    nvgScissor(ctx, inputX + 4, inputY, inputW - 8, inputH)

    nvgFontFace(ctx, "sans")
    nvgFontSize(ctx, 12)
    nvgTextAlign(ctx, NVG_ALIGN_LEFT + NVG_ALIGN_MIDDLE)

    if #importText_ == 0 then
        nvgFillColor(ctx, nvgRGBA(170, 155, 135, 150))
        nvgText(ctx, inputX + 6, inputY + inputH / 2, "粘贴或输入关卡数据……", nil)
    else
        local textBeforeCursor = importText_:sub(1, importCursorPos_)
        local advance, bounds = nvgTextBounds(ctx, 0, 0, textBeforeCursor)
        local cursorXInText = advance or 0

        local visibleW = inputW - 12
        if cursorXInText - importTextScrollX_ > visibleW then
            importTextScrollX_ = cursorXInText - visibleW + 20
        elseif cursorXInText - importTextScrollX_ < 0 then
            importTextScrollX_ = math.max(0, cursorXInText - 20)
        end

        local drawX = inputX + 6 - importTextScrollX_
        nvgFillColor(ctx, nvgRGBA(50, 35, 20, 255))
        nvgText(ctx, drawX, inputY + inputH / 2, importText_, nil)

        if math.floor(importCursorTimer_ * 2) % 2 == 0 then
            local cursorDrawX = drawX + cursorXInText
            nvgBeginPath(ctx)
            nvgRect(ctx, cursorDrawX, inputY + 6, 1.5, inputH - 12)
            nvgFillColor(ctx, nvgRGBA(80, 55, 30, 220))
            nvgFill(ctx)
        end
    end

    nvgRestore(ctx)

    Paper.text(ctx,inputX,inputY+inputH+22,"粘贴已导出的关卡数据",13,Paper.colors.muted,NVG_ALIGN_LEFT)
    Paper.text(ctx,inputX,inputY+inputH+44,"确认后会替换当前编辑内容",12,Paper.colors.muted,NVG_ALIGN_LEFT)
    local btnY,btnH,btnGap=my+modalH-62,44,8
    local btnW=(modalW-32-btnGap*3)/4
    importModalHits_={}
    for i,def in ipairs({{"pasteBtn","粘贴"},{"clearBtn","清空"},{"confirmBtn","确认"},{"cancelBtn","取消"}}) do
        local x=inputX+(i-1)*(btnW+btnGap)
        Paper.button(ctx,x,btnY,btnW,btnH,def[2],i==3)
        importModalHits_[def[1]]={x=x,y=btnY,w=btnW,h=btnH}
    end
    return {card={x=mx,y=my,w=modalW,h=modalH},
        input={x=inputX,y=inputY,w=inputW,h=inputH},buttons=importModalHits_}

end

-- ============================================================================
-- 公共接口
-- ============================================================================

--- 打开导入模态框
function M.open()
    showImportModal_ = true
    importText_ = ""
    importCursorPos_ = 0
    importTextScrollX_ = 0
    importCursorTimer_ = 0
    importModalHits_ = nil
    input:SetScreenKeyboardVisible(true)
end

--- 模态框是否正在显示
---@return boolean
function M.dismiss()
    if showImportModal_ then closeImportModal() end
    importModalHits_=nil
end

function M.isShowing()
    return showImportModal_
end

--- 每帧更新光标闪烁计时器
---@param dt number
function M.update(dt)
    if showImportModal_ then
        importCursorTimer_ = importCursorTimer_ + dt
    end
end

--- 处理文本输入（从 TextInput 事件转发）
---@param text string 输入的字符
function M.handleTextInput(text)
    if not showImportModal_ then return end
    local before = importText_:sub(1, importCursorPos_)
    local after = importText_:sub(importCursorPos_ + 1)
    importText_ = before .. text .. after
    importCursorPos_ = importCursorPos_ + #text
    importCursorTimer_ = 0
end

--- 处理模态框的按键事件
---@param key number 按键码
---@param qualifiers number 修饰键
---@param state table 共享编辑器状态（用于写 exportMessage）
---@return boolean handled 是否消费了该按键
function M.handleKey(key, qualifiers, state)
    if not showImportModal_ then return false end

    local hasCtrl = (qualifiers & QUAL_CTRL) ~= 0

    if key == KEY_BACKSPACE then
        if importCursorPos_ > 0 then
            local before = importText_:sub(1, importCursorPos_ - 1)
            local after = importText_:sub(importCursorPos_ + 1)
            importText_ = before .. after
            importCursorPos_ = importCursorPos_ - 1
            importCursorTimer_ = 0
        end
        return true
    elseif key == KEY_DELETE then
        if importCursorPos_ < #importText_ then
            local before = importText_:sub(1, importCursorPos_)
            local after = importText_:sub(importCursorPos_ + 2)
            importText_ = before .. after
            importCursorTimer_ = 0
        end
        return true
    elseif key == KEY_LEFT then
        if importCursorPos_ > 0 then
            importCursorPos_ = importCursorPos_ - 1
            importCursorTimer_ = 0
        end
        return true
    elseif key == KEY_RIGHT then
        if importCursorPos_ < #importText_ then
            importCursorPos_ = importCursorPos_ + 1
            importCursorTimer_ = 0
        end
        return true
    elseif key == KEY_HOME then
        importCursorPos_ = 0
        importCursorTimer_ = 0
        return true
    elseif key == KEY_END then
        importCursorPos_ = #importText_
        importCursorTimer_ = 0
        return true
    elseif key == KEY_RETURN or key == KEY_KP_ENTER then
        if #importText_ > 0 then
            local success, errMsg = serializer.import(state, importText_)
            if success then
                state.exportMessage = "导入成功!"
                state.exportMessageTimer = 2.0
                closeImportModal()
            else
                state.exportMessage = errMsg or "导入失败"
                state.exportMessageTimer = 2.5
            end
        end
        return true
    elseif key == KEY_ESCAPE then
        closeImportModal()
        return true
    elseif hasCtrl and key == KEY_V then
        local clipText = ui:GetClipboardText() or ""
        if #clipText > 0 then
            local before = importText_:sub(1, importCursorPos_)
            local after = importText_:sub(importCursorPos_ + 1)
            importText_ = before .. clipText .. after
            importCursorPos_ = importCursorPos_ + #clipText
            importCursorTimer_ = 0
        end
        return true
    elseif hasCtrl and key == KEY_A then
        importCursorPos_ = #importText_
        importCursorTimer_ = 0
        return true
    end

    return true -- 模态框打开时消费所有按键
end

--- 处理模态框内的点击事件
---@param mx number
---@param my number
---@param state table 共享编辑器状态（用于写 exportMessage）
---@return boolean handled 是否消费了点击
function M.handleClick(mx, my, state)
    if not showImportModal_ then return false end
    if not importModalHits_ then return true end

    -- 粘贴按钮
    local pb = importModalHits_.pasteBtn
    if pb and mx >= pb.x and mx <= pb.x + pb.w and my >= pb.y and my <= pb.y + pb.h then
        local clipText = ui:GetClipboardText() or ""
        if #clipText > 0 then
            importText_ = clipText
            importCursorPos_ = #importText_
            importTextScrollX_ = 0
            importCursorTimer_ = 0
        else
            state.exportMessage = "剪贴板为空!"
            state.exportMessageTimer = 2.0
        end
        return true
    end

    -- 清空按钮
    local cb = importModalHits_.clearBtn
    if cb and mx >= cb.x and mx <= cb.x + cb.w and my >= cb.y and my <= cb.y + cb.h then
        importText_ = ""
        importCursorPos_ = 0
        importTextScrollX_ = 0
        importCursorTimer_ = 0
        return true
    end

    -- 确认按钮
    local cfb = importModalHits_.confirmBtn
    if cfb and mx >= cfb.x and mx <= cfb.x + cfb.w and my >= cfb.y and my <= cfb.y + cfb.h then
        if #importText_ > 0 then
            local success, errMsg = serializer.import(state, importText_)
            if success then
                state.exportMessage = "导入成功!"
                state.exportMessageTimer = 2.0
                closeImportModal()
            else
                state.exportMessage = errMsg or "导入失败"
                state.exportMessageTimer = 2.5
            end
        else
            state.exportMessage = "请输入关卡数据!"
            state.exportMessageTimer = 2.0
        end
        return true
    end

    -- 取消按钮
    local cab = importModalHits_.cancelBtn
    if cab and mx >= cab.x and mx <= cab.x + cab.w and my >= cab.y and my <= cab.y + cab.h then
        closeImportModal()
        return true
    end

    return true -- 模态框区域内的任何点击都拦截
end

return M
