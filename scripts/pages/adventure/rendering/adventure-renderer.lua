--- 主线选关页：扁平粗线条地图。背景不包含关卡、文字或交互状态。
local Storyline = require("modules.storyline.init")
local FoxMascot = require("shared.components.fox-mascot")
local bgManager = require("shared.background-manager")
local TabBar = require("shared.components.tab-bar")
local Art = require("shared.constants.art")
local Pen = require("shared.components.handdrawn")
local chapterDefs = require("pages.adventure.data.chapter-definitions")
local layout = require("pages.adventure.layout.adaptive-layout")
local M = {}
local C = Art.colors
local images_ = {}

function M.init(vg)
    images_ = {
        background = nvgCreateImage(vg, Art.adventureBackground, 0),
        logo = nvgCreateImage(vg, Art.titleLogo, 0),
    }
end

function M.cleanup()
    -- 图像随所属页面的 NanoVG 上下文一起销毁。
    images_ = {}
end

local function drawImage(vg, image, x, y, w, h)
    if not image or image <= 0 then return false end
    nvgBeginPath(vg)
    nvgRect(vg, x, y, w, h)
    nvgFillPaint(vg, nvgImagePattern(vg, x, y, w, h, 0, image, 1))
    nvgFill(vg)
    return true
end

local function renderBackground(vg, w, h)
    local img = images_.background
    if img and img > 0 then
        local iw, ih = nvgImageSize(vg, img)
        local scale = math.max(w / iw, h / ih)
        nvgSave(vg)
        nvgScissor(vg, 0, 0, w, h)
        drawImage(vg, img, (w - iw * scale) / 2, (h - ih * scale) / 2, iw * scale, ih * scale)
        nvgRestore(vg)
    else
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, w, h)
        nvgFillColor(vg, Pen.color(C.paper)); nvgFill(vg)
    end
    -- 装扮背景仍影响主线地图的色调，不修改选择、解锁或云存档。
    if bgManager.getCurrentId() ~= "default" then
        local base = bgManager.getCurrent().colors.base
        nvgBeginPath(vg); nvgRect(vg, 0, 0, w, h)
        nvgFillColor(vg, nvgRGBA(base[1], base[2], base[3], 100)); nvgFill(vg)
    end
end

local function drawLock(vg, cx, cy, size)
    local s = size * 0.5
    nvgBeginPath(vg)
    nvgArc(vg, cx, cy - s * 0.15, s * 0.42, math.pi, 0, NVG_CW)
    nvgStrokeWidth(vg, math.max(2.5, s * 0.2))
    nvgStrokeColor(vg, Pen.color(C.muted)); nvgStroke(vg)
    Pen.plaque(vg, cx - s * 0.65, cy - s * 0.1, s * 1.3, s, C.muted, 1, C.muted)
    nvgBeginPath(vg); nvgCircle(vg, cx, cy + s * 0.25, s * 0.12)
    nvgFillColor(vg, Pen.color(C.paper)); nvgFill(vg)
    nvgBeginPath(vg); nvgRect(vg, cx - s * 0.06, cy + s * 0.25, s * 0.12, s * 0.3)
    nvgFill(vg)
end

local function drawCheck(vg, x, y, r)
    Pen.circle(vg, x, y, r, C.green, 2, C.paper)
    nvgBeginPath(vg)
    nvgMoveTo(vg, x - r * 0.45, y)
    nvgLineTo(vg, x - r * 0.1, y + r * 0.34)
    nvgLineTo(vg, x + r * 0.48, y - r * 0.36)
    nvgLineCap(vg, NVG_ROUND); nvgLineJoin(vg, NVG_ROUND)
    nvgStrokeWidth(vg, 2.5); nvgStrokeColor(vg, Pen.color(C.paper)); nvgStroke(vg)
end

function M.renderHeader(vg, screenW, t, headerH)
    local w = math.min(screenW * 0.64, (headerH - 8) * 1331 / 477)
    local h = w * 477 / 1331
    local bob = math.sin((t or 0) * 2.2) * 1.5
    if not drawImage(vg, images_.logo, (screenW - w) / 2, (headerH - h) / 2 + bob, w, h) then
        Pen.plaque(vg, screenW / 2 - 110, 12 + bob, 220, headerH - 24, C.paper, 3)
        Pen.text(vg, screenW / 2, headerH / 2 + bob, "玩趣乐园", 30)
    end
end

function M.renderChapterTitle(vg, screenW, pageStart, pageEnd, t, headerH, chapterH, currentPage, chapterState)
    if currentPage ~= chapterState.lastDisplayedPage then
        chapterState.pageDir = (chapterState.lastDisplayedPage and currentPage < chapterState.lastDisplayedPage) and -1 or 1
        chapterState.fadeAlpha = 0
        chapterState.lastDisplayedPage = currentPage
    end
    chapterState.fadeAlpha = math.min(1, chapterState.fadeAlpha + 3.2 / 60)
    local p = chapterState.fadeAlpha
    local c1 = 1.70158
    local tm1 = p - 1
    local spring = p >= 1 and 1 or (1 + (c1 + 1) * tm1 * tm1 * tm1 + c1 * tm1 * tm1)
    local slideX = (chapterState.pageDir or 1) * (1 - spring) * 16
    local scale = 0.92 + 0.08 * spring
    local text = chapterDefs.CHAPTERS[chapterDefs.getChapterForNode(pageStart)].name
    local w = math.min(screenW - 48, 254)
    local cx, cy = screenW / 2 + slideX, headerH + (chapterH - 4) / 2
    nvgSave(vg)
    nvgGlobalAlpha(vg, math.min(1, p * 1.4))
    nvgTranslate(vg, cx, cy)
    nvgScale(vg, scale, scale)
    nvgTranslate(vg, -cx, -cy)
    Pen.plaque(vg, cx - w / 2, headerH + 1, w, chapterH - 6, C.paper, 2.5)
    Pen.text(vg, cx, cy, text, 16)
    nvgRestore(vg)
end

function M.renderPagePaths(vg, nodes, pageStart, pageEnd, screenW, areaTop, areaH, pageNodeCount, nodeRadius, rowSpacing, t)
    for i = pageStart, pageEnd - 1 do
        local x1, y1 = layout.getPageNodePosition(i - pageStart + 1, screenW, areaTop, areaH, pageNodeCount, nodeRadius, rowSpacing)
        local x2, y2 = layout.getPageNodePosition(i - pageStart + 2, screenW, areaTop, areaH, pageNodeCount, nodeRadius, rowSpacing)
        for pass = 1, 2 do
            nvgBeginPath(vg); nvgMoveTo(vg, x1, y1)
            nvgBezierTo(vg, x1, y1 + rowSpacing * 0.65, x2, y2 - rowSpacing * 0.65, x2, y2)
            nvgLineCap(vg, NVG_ROUND)
            nvgStrokeWidth(vg, pass == 1 and 17 or 12)
            nvgStrokeColor(vg, Pen.color(pass == 1 and C.muted or C.track)); nvgStroke(vg)
        end
        if nodes[i].state == "done" then
            -- 已走过的小路加一枚带呼吸律动的草绿路标；保留路径本身的平涂质感。
            local pulse = 3.0 + math.sin((t or 0) * 3.5 + i) * 0.45
            Pen.circle(vg, (x1 + x2) / 2, (y1 + y2) / 2, pulse, C.green, 1, C.green)
        end
    end
end

function M.renderNode(vg, node, globalIdx, localIdx, screenW, areaTop, areaH, pageNodeCount, t, r, rowSpacing, npcImages, nodeHitAreas, nodeHitCount, chapterAlpha)
    local cx, cy = layout.getPageNodePosition(localIdx, screenW, areaTop, areaH, pageNodeCount, r, rowSpacing)
    local state, data = node.state, node.node
    local locked = state == "locked"
    local ink = locked and C.muted or C.ink
    local fill = locked and {225, 221, 191, 255} or (state == "current" and {255, 222, 152, 255} or C.paper)

    -- 章节切换时节点错峰弹簧浮现
    local nodeScale = 1.0
    if chapterAlpha and chapterAlpha < 1.0 then
        local delay = (localIdx - 1) * 0.06
        local np = math.max(0, math.min(1, (chapterAlpha - delay) / (1.0 - delay * 0.7)))
        local c1 = 1.70158
        local tm1 = np - 1
        local nSpring = np >= 1 and 1 or (1 + (c1 + 1) * tm1 * tm1 * tm1 + c1 * tm1 * tm1)
        nodeScale = 0.86 + 0.14 * nSpring
    elseif state == "current" then
        nodeScale = 1.0 + math.sin((t or 0) * 3.4) * 0.025
    end

    nvgSave(vg)
    if math.abs(nodeScale - 1.0) > 0.001 then
        nvgTranslate(vg, cx, cy)
        nvgScale(vg, nodeScale, nodeScale)
        nvgTranslate(vg, -cx, -cy)
    end

    if state == "current" then
        Pen.circle(vg, cx, cy, r + 5 + math.sin(t * 3.2) * 1.4, nil, 2.2, C.orange)
    end
    Pen.circle(vg, cx, cy, r, fill, 2.8, ink)
    if locked then
        drawLock(vg, cx, cy, r * 1.2)
    else
        local image = npcImages[data.npc.role]
        -- 圆框先画，透明角色后画；头顶稍微探出，脚底仍停在框内，带轻柔呼吸浮动。
        local px,py,size=layout.getPortraitBox(cx,cy,r)
        local portraitBob = math.sin((t or 0) * 2.6 + localIdx * 0.9) * 1.2
        if not drawImage(vg,image,px,py+portraitBob,size,size) then
            Pen.text(vg, cx, cy, tostring(globalIdx), r * 0.8)
        end
    end
    local badgeR = math.max(9, math.min(12, r * 0.32))
    if state == "done" then
        drawCheck(vg, cx + r * 0.94, cy - r * 0.66, badgeR)
    else
        Pen.circle(vg, cx - r * 0.94, cy - r * 0.66, badgeR, locked and C.paper or C.orange, 1.8, ink)
        Pen.text(vg, cx - r * 0.94, cy - r * 0.66, tostring(globalIdx), 11, ink)
    end

    -- 标题牌与玩法说明固定保留 44px 附属高度，字号还受真实字宽约束。
    local titleSize = math.max(12, math.min(16, r * 0.45))
    nvgFontFace(vg, "adv"); nvgFontSize(vg, titleSize)
    local tw = nvgTextBounds(vg, 0, 0, data.title) or 0
    local maxW = screenW * 0.46 - 8
    if tw > maxW - 12 then titleSize = titleSize * (maxW - 12) / tw end
    nvgFontSize(vg, titleSize)
    tw = nvgTextBounds(vg, 0, 0, data.title) or 0
    local titleW = math.min(maxW, math.max(r * 2 + 8, tw + 12))
    Pen.plaque(vg, cx - titleW / 2, cy + r - 1, titleW, 23, fill, 2, ink)
    Pen.text(vg, cx, cy + r + 10, data.title, titleSize, ink)

    local typeName = chapterDefs.GAME_TYPE_NAMES[data.gameType] or "益智关卡"
    local tagSize = math.min(12, titleSize - 2)
    -- 玩法只作为次级说明；文字顶部与标题牌底部保留约 8px 空隙。
    Pen.text(vg, cx, cy + r + 36, typeName, tagSize, C.ink)

    nvgRestore(vg)

    nodeHitCount = nodeHitCount + 1
    local hit = nodeHitAreas[nodeHitCount] or {}
    nodeHitAreas[nodeHitCount] = hit
    hit.cx, hit.cy, hit.r, hit.nodeIdx = cx, cy, math.max(r * (1 + layout.PORTRAIT_OVERHANG) + 2, 22), globalIdx
    return nodeHitCount
end

function M.renderPagination(vg, screenW, screenH, totalPages, currentPage, t, footerH)
    local cx, cy = layout.getPaginationCenter(screenW, screenH)
    local buttons = {}
    for _, dir in ipairs({-1, 1}) do
        local enabled = dir == -1 and currentPage > 1 or dir == 1 and currentPage < totalPages
        local x = cx + dir * layout.ARROW_SPREAD - 22
        nvgSave(vg)
        if not enabled then nvgGlobalAlpha(vg, 0.45) end
        Pen.texturedPlaque(vg, x, cy - 22, 44, 44, C.paper, 2.5)
        nvgBeginPath(vg)
        nvgMoveTo(vg, x + 22 - dir * 4, cy - 7)
        nvgLineTo(vg, x + 22 + dir * 4, cy)
        nvgLineTo(vg, x + 22 - dir * 4, cy + 7)
        nvgLineCap(vg, NVG_ROUND); nvgLineJoin(vg, NVG_ROUND)
        nvgStrokeWidth(vg, 3); nvgStrokeColor(vg, Pen.color(C.ink)); nvgStroke(vg)
        nvgRestore(vg)
        if enabled then
            -- Density 最低缩放为 0.85；52 个游戏单位仍保留约 44 个逻辑像素的触摸区。
            buttons[dir] = { x = x - 4, y = cy - 26, w = 52, h = 52 }
        end
    end
    for p = 1, totalPages do
        Pen.circle(vg, cx + (p - (totalPages + 1) / 2) * layout.DOT_GAP, cy, layout.DOT_RADIUS,
            p == currentPage and C.orange or C.paper, 1.5, C.muted)
    end
    return buttons[-1], buttons[1]
end

function M.renderAllCompleted(vg, screenW, areaTop, areaH, t)
    if not Storyline.isAllCompleted() then return end
    -- 放在章节牌下方，避免压住最后一关或狐狸。
    Pen.text(vg, screenW / 2, areaTop + 4, "全园通关啦！", 13, C.ink)
end

function M.renderMap(vg, screenW, screenH, t, currentPage, npcImages, nodeHitAreas, layoutCache, chapterState)
    renderBackground(vg, screenW, screenH)
    local nodes = Storyline.getNodeList()
    if #nodes == 0 then return 0, nil, nil, nil, currentPage end
    local totalPages = chapterDefs.getChapterCount()
    currentPage = math.max(1, math.min(currentPage, totalPages))
    local pageStart, pageEnd = chapterDefs.getPageNodeRange(currentPage, #nodes)
    local count = pageEnd - pageStart + 1
    if screenW ~= layoutCache.screenW or screenH ~= layoutCache.screenH then
        layoutCache.screenW, layoutCache.screenH = screenW, screenH
        layoutCache.headerH, layoutCache.chapterH, layoutCache.footerH = layout.calcAdaptiveRegions(screenH)
        layoutCache.nodeKey = ""
    end
    local top = layoutCache.headerH + layoutCache.chapterH
    local areaH = screenH - top - layoutCache.footerH
    local key = areaH .. ":" .. count
    if key ~= layoutCache.nodeKey then
        layoutCache.nodeKey = key
        layoutCache.nodeRadius, layoutCache.rowSpacing = layout.calcAdaptiveLayout(areaH, count)
    end
    local r, spacing = layoutCache.nodeRadius, layoutCache.rowSpacing
    M.renderHeader(vg, screenW, t, layoutCache.headerH)
    M.renderChapterTitle(vg, screenW, pageStart, pageEnd, t, layoutCache.headerH, layoutCache.chapterH, currentPage, chapterState)
    M.renderPagePaths(vg, nodes, pageStart, pageEnd, screenW, top, areaH, count, r, spacing, t)
    local hitCount = 0
    for i = pageStart, pageEnd do
        hitCount = M.renderNode(vg, nodes[i], i, i - pageStart + 1, screenW, top, areaH, count, t, r, spacing, npcImages, nodeHitAreas, hitCount, chapterState.fadeAlpha)
    end
    if currentPage == totalPages then M.renderAllCompleted(vg, screenW, top, areaH, t) end
    FoxMascot.render(vg, screenW, screenH, TabBar.HEIGHT, layout.getFoxOptions(screenH))
    local prev, nextBtn = M.renderPagination(vg, screenW, screenH, totalPages, currentPage, t, layoutCache.footerH)
    local lockedTabs = Storyline.getNodeState("story-4") ~= "done" and { home = true } or nil
    local tabs = TabBar.render(vg, screenW, screenH, "adventure", t, "adv", lockedTabs, "handdrawn")
    if Storyline.isSyncing() then
        -- 独立提示，不覆盖章节名称。
        Pen.text(vg, screenW - 48, layoutCache.headerH - 6, "同步中…", 11, C.muted)
    end
    return hitCount, prev, nextBtn, tabs, currentPage
end

return M
