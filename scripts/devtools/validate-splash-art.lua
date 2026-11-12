--- 与 main.lua 一起运行，验证启动页排版与适龄弹窗/进入门禁。
---@diagnostic disable: undefined-global
local UI = require("urhox-libs/UI")
local Health = require("shared.components.health-advisory")
local splash
local loadingFooter, loadingSlot

V.atFrame(25, function()
    splash = UI.GetRoot():FindById("splash-screen")
    V.assert(splash ~= nil, "启动页已挂载到真实游戏根节点")
    if not splash then return end
    local w, h = UI.GetViewportSize()
    for _, id in ipairs({ "splash-title", "splash-age-entry", "splash-enter-hint", "splash-health-line-4" }) do
        local node = splash:FindById(id)
        V.assert(node ~= nil, id .. " 存在")
        if node then
            local box = node:GetAbsoluteLayout()
            V.assert(box.w > 0 and box.h > 0, id .. " 非零尺寸")
            V.assert(box.x >= 0 and box.y >= 0 and box.x + box.w <= w + 1 and box.y + box.h <= h + 1,
                id .. " 在视口范围内")
        end
    end
    local title = splash:FindById("splash-title"):GetAbsoluteLayout()
    local characters = splash:FindById("splash-characters"):GetAbsoluteLayout()
    local footer = splash:FindById("splash-footer"):GetAbsoluteLayout()
    V.assert(characters.h > 80, "角色区保持可见尺寸")
    V.assert(title.y + title.h < characters.y, "标题不遮挡角色")
    V.assert(characters.y + characters.h <= footer.y, "角色不遮挡底部健康忠告")
    local hint = splash:FindById("splash-enter-hint"):GetAbsoluteLayout()
    local progress = splash:FindById("splash-progress-track"):GetAbsoluteLayout()
    local safe = UI.GetSafeAreaInsets()
    V.assert(math.abs(hint.y + hint.h / 2 - progress.y - progress.h / 2) <= 2,
        "进度条和进入提示使用同一中心槽位")
    V.assert(splash:FindById("splash-progress-track"):IsVisible(), "准备阶段显示加载条")
    V.assert(splash:FindById("splash-enter-hint").props.opacity == 0, "准备阶段隐藏进入提示")
    loadingFooter = footer
    loadingSlot = splash:FindById("splash-prepare"):GetAbsoluteLayout()
    splash.props.onClick()
    V.assert(Health.isActive(), "准备完成前点击不会进入游戏")
    V.assert(progress.y + progress.h < footer.y, "进入提示与进度条均在卡片外上方")
    V.assert(characters.y + characters.h < hint.y, "角色不遮挡进入提示")
    V.assert(footer.y + footer.h <= h - safe.bottom - 8, "卡片与底部安全区保留间距")
    local previousBottom = 0
    for _, id in ipairs({"splash-age-entry", "splash-health-title", "splash-health-line-1",
        "splash-health-line-2", "splash-health-line-3", "splash-health-line-4"}) do
        local node = splash:FindById(id)
        local box = node:GetAbsoluteLayout()
        V.assert(box.x >= footer.x + 2 and box.x + box.w <= footer.x + footer.w - 2,
            id .. " 横向位于卡片边框内")
        V.assert(box.y >= previousBottom and box.y + box.h <= footer.y + footer.h - 8,
            id .. " 无垂直重叠且不溢出底框")
        previousBottom = box.y + box.h
    end
    splash:FindById("splash-age-entry").props.onClick()
end)

V.atFrame(55, function()
    if not splash then return end
    V.assert(splash:FindById("splash-age-overlay") ~= nil, "适龄详情可打开")
    Health.update(20)
    V.assert(Health.isActive(), "适龄详情打开时暂停自动进入倒计时")
    splash:FindById("splash-age-close").props.onClick()
    V.assert(splash:FindById("splash-age-overlay") == nil, "适龄详情可关闭")
    Health.update(5.1)
end)

V.atFrame(85, function()
    if not splash then return end
    V.assert(splash:FindById("splash-enter-hint").props.opacity > 0, "准备完成后显示进入提示")
    V.assert(not splash:FindById("splash-progress-track"):IsVisible(), "准备完成后加载条消失")
    local footer = splash:FindById("splash-footer"):GetAbsoluteLayout()
    local slot = splash:FindById("splash-prepare"):GetAbsoluteLayout()
    V.assert(math.abs(footer.y - loadingFooter.y) < 1 and math.abs(footer.h - loadingFooter.h) < 1,
        "加载完成前后忠告卡片不跳动")
    V.assert(math.abs(slot.y - loadingSlot.y) < 1 and math.abs(slot.h - loadingSlot.h) < 1,
        "同槽位替换提示不改变占位高度")
    local Theme = require("urhox-libs/UI/Core/Theme")
    print(string.format("[SplashArtViewport] %.4f", UI.GetScale()))
    local ids = { "splash-title", "splash-tagline", "splash-characters", "splash-footer",
        "splash-bottom-stack", "splash-progress-track", "splash-age-entry", "splash-age-icon", "splash-age-text", "splash-enter-hint", "splash-health-title" }
    for i = 1, 4 do ids[#ids + 1] = "splash-health-line-" .. i end
    for _, id in ipairs(ids) do
        local node = splash:FindById(id)
        local box = node:GetAbsoluteLayout()
        print(string.format("[SplashArtLayout] %s %.3f %.3f %.3f %.3f %.3f", id,
            box.x, box.y, box.w, box.h, Theme.FontSize(node.props.fontSize or 0)))
    end
end)

V.atFrame(125, function()
    if splash then splash.props.onClick() end
end)

V.atFrame(145, function()
    Health.update(1)
    V.assert(not Health.isActive(), "准备完成后点击可关闭启动页")
    V.finish()
end)
