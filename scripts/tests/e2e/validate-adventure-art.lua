--- 使用真实 main.lua。只读取进度，测试不完成关卡、不写入存档。
---@diagnostic disable: undefined-global
local Trace = require("devtools.adventure-art-trace")
local Renderer = require("pages.adventure.rendering.adventure-renderer")
local Layout = require("pages.adventure.layout.adaptive-layout")
local TabBar = require("shared.components.tab-bar")
local Storyline = require("modules.storyline.init")
local Router = require("app.router")
local Fox = require("shared.components.fox-mascot")
local Density = require("shared.utils.density")
local Health = require("shared.components.health-advisory")
local last_, renders_, pages_ = nil, 0, {}
local testDone_, doneRendered_ = false, false
local originalRender = Renderer.renderMap
Renderer.renderMap = function(vg, w, h, t, page, images, hits, cache, state)
    Trace.begin()
    local count, prev, nextBtn, tabs, current = originalRender(vg, w, h, t, page, images, hits, cache, state)
    Trace.finish(w, h)
    if testDone_ then
        testDone_ = false
        local first = Storyline.getNodeList()[1]
        local isolatedHits = {}
        local n = Renderer.renderNode(vg, {state = "done", node = first.node}, 1, 1, w,
            cache.headerH + cache.chapterH, h - cache.headerH - cache.chapterH - cache.footerH,
            7, t, cache.nodeRadius, cache.rowSpacing, images, isolatedHits, 0)
        doneRendered_ = n == 1 and isolatedHits[1].nodeIdx == 1
    end
    renders_ = renders_ + 1
    last_ = { w = w, h = h, count = count, prev = prev, nextBtn = nextBtn, tabs = tabs,
        current = current, hits = hits, cache = cache }
    pages_[current] = true
    return count, prev, nextBtn, tabs, current
end

local function key(code)
    Adv_HandleKeyDown(nil, { Key = { GetInt = function() return code end } })
end

local function checkPage(expected)
    V.assert(last_ ~= nil, "真实主线渲染器已经执行")
    if not last_ then return end
    V.assert(last_.current == expected, "翻到第" .. expected .. "章")
    V.assert(last_.count == 7, "一章仍显示七关")
    V.assert((last_.prev ~= nil) == (expected > 1), "上一章按钮边界正确")
    V.assert((last_.nextBtn ~= nil) == (expected < 5), "下一章按钮边界正确")
    local boundsOK, sameColumnOK, hitOK = true, true, true
    local r = last_.cache.nodeRadius
    for i = 1, 7 do
        local hit = last_.hits[i]
        boundsOK = boundsOK and hit.cx - r > 0 and hit.cx + r < last_.w
            and hit.cy - r >= last_.cache.headerH + last_.cache.chapterH
            and hit.cy + r + Layout.CARD_ATTACH <= last_.h - last_.cache.footerH
        hitOK = hitOK and hit.nodeIdx == (expected - 1) * 7 + i and hit.r >= 22
        if i > 2 then sameColumnOK = sameColumnOK and
            last_.hits[i - 2].cy + r + Layout.CARD_ATTACH + 4 < hit.cy - r end
    end
    V.assert(boundsOK, "节点和标题标签都在地图区域内")
    V.assert(sameColumnOK, "同列关卡卡片不重叠")
    V.assert(hitOK, "关卡命中索引与最小触摸区保持正确")
    local fx = Layout.getFoxOptions(last_.h)
    V.assert(not Fox.hitTest(last_.hits[7].cx, last_.hits[7].cy, last_.w, last_.h, TabBar.HEIGHT, fx),
        "最后一关不被狐狸点击区拦截")
    for _, btn in pairs({ last_.prev or false, last_.nextBtn or false }) do
        if btn then
            V.assert(btn.w >= 44 and btn.h >= 44 and btn.x >= 0 and btn.x + btn.w <= last_.w,
                "翻页按钮在视口内且达到44像素")
            V.assert(not Fox.hitTest(btn.x + btn.w / 2, btn.y + btn.h / 2, last_.w, last_.h, TabBar.HEIGHT, fx),
                "狐狸不拦截翻页按钮")
        end
    end
end

V.atFrame(25, function()
    Health.update(6)
    local root = require("urhox-libs/UI").GetRoot()
    local splash = root:FindById("splash-screen")
    if splash then splash.props.onClick() end
    Fox.reset()
    Trace.request()
    V.assert(Router.getCurrent() == "adventure", "真实主入口仍导航到选关页")
    print("[AdventureArtRenderCount] " .. renders_)
end)
V.atFrame(35, function() checkPage(1); key(KEY_LEFT) end)
V.atFrame(40, function() V.assert(last_ and last_.current == 1, "不能翻到第一章之前"); key(KEY_RIGHT) end)
V.atFrame(50, function() checkPage(2); key(KEY_RIGHT) end)
V.atFrame(60, function() checkPage(3); key(KEY_RIGHT) end)
V.atFrame(70, function() checkPage(4); key(KEY_RIGHT) end)
V.atFrame(80, function() checkPage(5); key(KEY_RIGHT) end)
V.atFrame(85, function() testDone_ = true end)
V.atFrame(90, function()
    V.assert(doneRendered_, "已完成状态徽章可由真实渲染器绘制")
    V.assert(last_ and last_.current == 5, "不能翻到第五章之后")
    if last_ then
        local s = last_.tabs.settings
        V.assert(TabBar.handleClick(s.x + s.w / 2, s.y + s.h / 2, last_.tabs).type == "settings", "设置入口保留")
        local locked = { tabs = { { id = "home", x = 0, y = 0, w = 44, h = 44, locked = true } } }
        V.assert(TabBar.handleClick(22, 22, locked) == nil, "锁定自由模式仍不可点击")
        local profiles = last_.tabs.tabs[3]
        V.assert(TabBar.handleClick(profiles.x + profiles.w / 2, profiles.y + profiles.h / 2, last_.tabs).id == "profile", "装扮入口保留")
        print("[AdventureArtLayout] " .. cjson.encode({w = last_.w, h = last_.h, hits = last_.hits, cache = last_.cache}))
    end
    V.assert(Storyline.getNodeList()[1].node.title == "慧慧的花园课堂", "关卡数据未被改写")
    V.finish()
end)
