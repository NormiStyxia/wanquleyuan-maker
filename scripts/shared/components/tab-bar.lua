-- 底部页签栏（NanoVG 渲染，两个页面共用）
local TabBar = {}
local Art = require("shared.constants.art")
local Pen = require("shared.components.handdrawn")

TabBar.HEIGHT = 56

--- 页签配置
local TABS = {
    { id = "adventure", label = "主线模式" },
    { id = "home",      label = "自由模式" },
    { id = "profile",   label = "装扮" },
}

local GEAR_SIZE = 40        -- 齿轮按钮区域
local GEAR_MARGIN = 12      -- 右侧边距
local TAB_PILL_H = 36       -- 活跃页签药丸高度
local FONT_SIZE = 18
local LOCK_SIZE = 10        -- 锁图标大小

--- 绘制齿轮图标
local function drawGear(vg, cx, cy, t, ink, paper)
    nvgSave(vg)
    nvgTranslate(vg, cx, cy)
    nvgRotate(vg, t * 0.3)

    local outerR = 12
    local teeth = 8

    nvgBeginPath(vg)
    for i = 0, teeth * 2 - 1 do
        local angle = i * math.pi / teeth
        local r = (i % 2 == 0) and outerR or (outerR - 3)
        local x = r * math.cos(angle)
        local y = r * math.sin(angle)
        if i == 0 then nvgMoveTo(vg, x, y) else nvgLineTo(vg, x, y) end
    end
    nvgClosePath(vg)
    nvgFillColor(vg, ink and Pen.color(ink) or nvgRGBA(140, 130, 120, 200))
    nvgFill(vg)

    nvgBeginPath(vg)
    nvgCircle(vg, 0, 0, 4)
    nvgFillColor(vg, paper and Pen.color(paper) or nvgRGBA(255, 255, 255, 220))
    nvgFill(vg)

    nvgRestore(vg)
end

--- 绘制锁图标（锁体 + 锁环）
local function drawLock(vg, cx, cy, s)
    local bw = s          -- 锁体宽度
    local bh = s * 0.7    -- 锁体高度
    local bx = cx - bw / 2
    local by = cy - bh * 0.2

    -- 锁体（圆角矩形）
    nvgBeginPath(vg)
    nvgRoundedRect(vg, bx, by, bw, bh, 1.5)
    nvgFillColor(vg, nvgRGBA(160, 150, 140, 200))
    nvgFill(vg)

    -- 锁环（半圆弧）
    local arcR = bw * 0.32
    local arcCy = by
    nvgBeginPath(vg)
    nvgArc(vg, cx, arcCy, arcR, math.pi, 0, NVG_CW)
    nvgStrokeWidth(vg, 2.0)
    nvgStrokeColor(vg, nvgRGBA(160, 150, 140, 200))
    nvgStroke(vg)
end

--- 显式启用的手绘皮肤；点击区域和路由 ID 沿用原契约。
local function renderHanddrawn(vg, screenW, screenH, activeTab, fontFace, lockedTabs)
    local c = Art.colors
    local y = screenH - TabBar.HEIGHT
    nvgBeginPath(vg); nvgRect(vg, 0, y, screenW, TabBar.HEIGHT)
    nvgFillColor(vg, Pen.color(c.paper)); nvgFill(vg)
    nvgBeginPath(vg); nvgMoveTo(vg, 0, y); nvgLineTo(vg, screenW, y)
    nvgStrokeWidth(vg, 2.5); nvgStrokeColor(vg, Pen.color(c.ink)); nvgStroke(vg)
    local tabW = (screenW - GEAR_MARGIN * 2 - GEAR_SIZE - 8) / #TABS
    local hits = { tabs = {}, settings = {
        x = screenW - GEAR_MARGIN - GEAR_SIZE, y = y,
        w = GEAR_SIZE + GEAR_MARGIN, h = TabBar.HEIGHT,
    } }
    nvgFontFace(vg, fontFace)
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
    local size = math.min(17, (tabW - 18) / 4.6)
    for i, tab in ipairs(TABS) do
        local cx = (i - 0.5) * tabW
        local locked = lockedTabs and lockedTabs[tab.id] or false
        local fill = tab.id == activeTab and c.orange or c.paper
        Pen.plaque(vg, cx - tabW * 0.45, y + 8, tabW * 0.9, 40,
            locked and {224, 220, 197, 255} or fill, 2)
        nvgFontSize(vg, size)
        nvgFillColor(vg, Pen.color(locked and c.muted or c.ink))
        nvgText(vg, cx, y + (locked and 23 or 28), tab.label)
        if locked then drawLock(vg, cx, y + 39, 7) end
        hits.tabs[i] = { id = tab.id, locked = locked, x = (i - 1) * tabW,
            y = y, w = tabW, h = TabBar.HEIGHT }
    end
    local gearCx = screenW - GEAR_MARGIN - GEAR_SIZE / 2
    Pen.plaque(vg, gearCx - 22, y + 8, 44, 40, c.paper, 2)
    drawGear(vg, gearCx, y + 28, 0, c.ink, c.paper)
    return hits
end

--- 渲染页签栏
---@param vg userdata NanoVG context
---@param screenW number 逻辑宽度
---@param screenH number 逻辑高度
---@param activeTab string "home" | "adventure"
---@param t number 动画时间
---@param fontFace string 页面字体名
---@param lockedTabs table|nil 锁定的页签 ID 集合，如 { home = true }
---@return table hitAreas 点击区域
function TabBar.render(vg, screenW, screenH, activeTab, t, fontFace, lockedTabs, style)
    if style == "handdrawn" or (type(style) == "table" and style.handdrawn) then
        return renderHanddrawn(vg, screenW, screenH, activeTab, fontFace, lockedTabs)
    end
    local barH = TabBar.HEIGHT
    local barY = screenH - barH

    -- 背景
    nvgBeginPath(vg)
    nvgRect(vg, 0, barY, screenW, barH)
    nvgFillColor(vg, nvgRGBA(255, 255, 255, 220))
    nvgFill(vg)

    -- 顶部细线
    nvgBeginPath(vg)
    nvgMoveTo(vg, 0, barY)
    nvgLineTo(vg, screenW, barY)
    nvgStrokeWidth(vg, 1)
    nvgStrokeColor(vg, nvgRGBA(220, 210, 200, 120))
    nvgStroke(vg)

    -- 齿轮区域（右侧）
    local gearCx = screenW - GEAR_MARGIN - GEAR_SIZE / 2
    local gearCy = barY + barH / 2
    drawGear(vg, gearCx, gearCy, t)

    -- 页签区域（左侧到齿轮左边）
    local tabAreaW = screenW - GEAR_MARGIN * 2 - GEAR_SIZE - 8
    local tabW = tabAreaW / #TABS
    local tabCy = barY + barH / 2

    local hitAreas = { tabs = {}, settings = nil }

    -- 设置齿轮点击区域
    hitAreas.settings = {
        x = screenW - GEAR_MARGIN - GEAR_SIZE,
        y = barY,
        w = GEAR_SIZE + GEAR_MARGIN,
        h = barH,
    }

    -- 绘制页签
    nvgFontFace(vg, fontFace)
    nvgFontSize(vg, FONT_SIZE)
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)

    for i, tab in ipairs(TABS) do
        local tx = (i - 1) * tabW + tabW / 2
        local isActive = (tab.id == activeTab)
        local isLocked = lockedTabs and lockedTabs[tab.id] or false

        local pillW = tabW * 0.88
        local pillX = tx - pillW / 2
        local pillY = tabCy - TAB_PILL_H / 2
        local pillR = TAB_PILL_H / 2

        if isLocked then
            -- 锁定页签：灰色背景 + 灰色文字
            nvgBeginPath(vg)
            nvgRoundedRect(vg, pillX, pillY, pillW, TAB_PILL_H, pillR)
            nvgFillColor(vg, nvgRGBA(210, 210, 210, 160))
            nvgFill(vg)

            nvgFillColor(vg, nvgRGBA(170, 170, 170, 180))
            nvgText(vg, tx - LOCK_SIZE * 0.6, tabCy, tab.label)

            -- 锁图标（文字右侧）
            local textW = nvgTextBounds(vg, 0, 0, tab.label) or 0
            local lockX = tx - LOCK_SIZE * 0.6 + textW / 2 + LOCK_SIZE * 0.7
            drawLock(vg, lockX, tabCy - 1, LOCK_SIZE)
        elseif isActive then
            -- 活跃页签：渐变药丸背景
            local paint = nvgLinearGradient(vg, pillX, pillY, pillX + pillW, pillY + TAB_PILL_H,
                nvgRGBA(255, 150, 80, 255), nvgRGBA(255, 100, 130, 255))
            nvgBeginPath(vg)
            nvgRoundedRect(vg, pillX, pillY, pillW, TAB_PILL_H, pillR)
            nvgFillPaint(vg, paint)
            nvgFill(vg)

            nvgFillColor(vg, nvgRGBA(255, 255, 255, 255))
            nvgText(vg, tx, tabCy, tab.label)
        else
            -- 非活跃页签：带颜色的淡渐变背景，与锁定状态明显区分
            local inactivePaint = nvgLinearGradient(vg, pillX, pillY, pillX + pillW, pillY + TAB_PILL_H,
                nvgRGBA(255, 190, 140, 100), nvgRGBA(255, 150, 170, 100))
            nvgBeginPath(vg)
            nvgRoundedRect(vg, pillX, pillY, pillW, TAB_PILL_H, pillR)
            nvgFillPaint(vg, inactivePaint)
            nvgFill(vg)
            nvgStrokeWidth(vg, 1.5)
            nvgStrokeColor(vg, nvgRGBA(255, 150, 120, 160))
            nvgStroke(vg)

            nvgFillColor(vg, nvgRGBA(200, 90, 60, 230))
            nvgText(vg, tx, tabCy, tab.label)
        end

        -- 点击区域（锁定的页签标记 locked）
        hitAreas.tabs[i] = {
            id = tab.id,
            locked = isLocked,
            x = (i - 1) * tabW,
            y = barY,
            w = tabW,
            h = barH,
        }
    end

    return hitAreas
end

--- 检测页签栏点击
---@param lx number 逻辑 x
---@param ly number 逻辑 y
---@param hitAreas table render 返回的点击区域
---@return table|nil action {type="tab", id=...} 或 {type="settings"} 或 nil
function TabBar.handleClick(lx, ly, hitAreas)
    if not hitAreas then return nil end

    -- 检测设置按钮
    local s = hitAreas.settings
    if s and lx >= s.x and lx <= s.x + s.w and ly >= s.y and ly <= s.y + s.h then
        return { type = "settings" }
    end

    -- 检测页签（锁定的页签不响应点击）
    for _, tab in ipairs(hitAreas.tabs) do
        if lx >= tab.x and lx <= tab.x + tab.w and ly >= tab.y and ly <= tab.y + tab.h then
            if tab.locked then return nil end
            return { type = "tab", id = tab.id }
        end
    end

    return nil
end

return TabBar
