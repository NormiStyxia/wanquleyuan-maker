--- 自由模式页：布局读取编辑器文档，交互和动态状态保留在 Lua。
local UI = require("urhox-libs/UI")
local Router = require("app.router")
local gameRegistry = require("modules.game-registry.init")
local ScreenTransition = require("shared.components.screen-transition")
local SettingsPopup = require("shared.components.settings-popup")
local FoxMascot = require("shared.components.fox-mascot")
local OutfitManager = require("shared.outfit-manager")
local BackgroundManager = require("shared.background-manager")
local Storyline = require("modules.storyline.init")
local PlayTimeGuard = require("shared.utils.play-time-guard")
local AntiAddictionPopup = require("shared.components.anti-addiction-popup")
local uiTap = require("shared.utils.ui-tap")
local logger = require("shared.utils.logger")

local M = {}
local MODULE = "page-home"
local RESOURCE = "ui/home.ui.json"
local active_ = false
local animTime_ = 0.0
---@type any
local instance_
---@type Panel
local pageContainer_
---@type Panel
local document_
---@type Panel
local canvas_
---@type Node
local eventNode_
---@type LuaScriptObject
local receiver_
---@type table<string, any>
local widgets_ = {}
local designW_, designH_ = 403.2, 896.0
local viewportW_, viewportH_ = 0.0, 0.0
local lastSkin_, lastBackground_, lastUnlocked_ = "", "", nil
---@type any
local lastGameList_
local enteringGame_ = false
local settingsHelper_ = SettingsPopup.createPageHelper({
    extraButtons = SettingsPopup.makeDevButtons(),
})

local function find(id)
    if not widgets_[id] then widgets_[id] = instance_:Find(id) end
    return widgets_[id]
end

local function canInteract()
    return active_ and not enteringGame_ and not settingsHelper_.isOpen()
end

--- 沿用原卡片入口：防沉迷检查、点击音效、转场及游戏参数不变。
local function enterGame(gameId)
    if not canInteract() then return end
    local config = gameRegistry.getGameById(gameId)
    if not config then return end
    if PlayTimeGuard.isRestricted() then
        logger.info(MODULE, "click_game_tile", "blocked: restricted play time")
        local reason = PlayTimeGuard.getBlockReason()
        if reason == "curfew" then
            AntiAddictionPopup.showCurfew(pageContainer_, function() end)
        elseif reason == "time_limit" then
            AntiAddictionPopup.showForceExit(pageContainer_, function() end)
        end
        return
    end
    enteringGame_ = true
    uiTap.play()
    logger.info(MODULE, "click_game_tile", gameId)
    ScreenTransition.run(function()
        Router.push("game", { gameConfig = config })
    end)
end

local function navigate(pageId)
    if not canInteract() then return end
    uiTap.play()
    ScreenTransition.run(function() Router.replace(pageId) end)
end

--- 整体适配文档画布；不重排、覆盖文档中各元素的编辑器布局。
local function fitCanvas()
    local w, h = UI.GetViewportSize()
    if w <= 0 or h <= 0 or (w == viewportW_ and h == viewportH_) then return end
    viewportW_, viewportH_ = w, h
    local scale = math.min(w / designW_, h / designH_)
    canvas_:SetStyle({
        left = (w - designW_ * scale) / 2,
        top = (h - designH_ * scale) / 2,
        scale = scale,
    })
end

local function refreshGames()
    local games = gameRegistry.getGameList()
    if games == lastGameList_ then return end
    lastGameList_ = games
    ---@type table<string, any>
    local available = {}
    for _, config in ipairs(games) do available[config.gameId] = config end
    for _, button in ipairs(instance_:FindAll("Button")) do
        local id = button.props.id or ""
        if id:sub(1, 5) == "game-" then
            local gameId = id:sub(6)
            local config = available[gameId]
            button:SetVisible(config ~= nil)
            if config then
                local title = find(gameId .. "-title")
                local subtitle = find(gameId .. "-subtitle")
                if title then title:SetText(config.title) end
                if subtitle then subtitle:SetText(config.subtitle or "") end
            end
        end
    end
end

local function refreshState()
    local skin = OutfitManager.getTexturePath()
    if skin ~= lastSkin_ then
        lastSkin_ = skin
        local mascot = find("home-mascot")
        if mascot then mascot:SetBackgroundImage(skin) end
    end
    local bg = BackgroundManager.getCurrent()
    if bg.id ~= lastBackground_ then
        lastBackground_ = bg.id
        local background = find("home-background")
        if background then
            background:SetStyle({backgroundImage = bg.themeImage, backgroundColor = bg.colors.base})
        end
    end
    local unlocked = Storyline.getNodeState("story-4") == "done"
    if unlocked ~= lastUnlocked_ then
        lastUnlocked_ = unlocked
        local tab = find("tab-home")
        local lock = find("tab-home-lock")
        local plaque = find("tab-home-plaque")
        if tab then tab:SetDisabled(not unlocked) end
        if lock then lock:SetVisible(not unlocked) end
        if plaque then
            plaque:SetStyle({backgroundColor = unlocked and {238,156,67,255} or {224,220,197,255}})
        end
    end
    refreshGames()
end

local function showHomeGreeting()
    local greetings = {
        "自由模式！想玩哪个就玩哪个~",
        "欢迎回来！今天想挑战哪个游戏？",
        "自由选择，随心畅玩！",
        "嘿嘿，选一个你最拿手的游戏吧！",
        "自由模式真棒，每个游戏都很有趣哦~",
    }
    FoxMascot.showMessage(greetings[math.random(1, #greetings)])
end

--- 动态绘制处于 JSON 背景之上、设置等弹窗之下，不再绘制旧首页。
---@class HomeDynamicLayer : Panel
local HomeDynamicLayer = UI.Panel:Extend("HomeDynamicLayer")
function HomeDynamicLayer:Render(vg)
    if not active_ then return end
    local mascot = find("home-mascot")
    if mascot then
        local rect = mascot:GetAbsoluteLayout()
        local root = document_:GetAbsoluteLayout()
        FoxMascot.render(vg, root.x + designW_, root.y + designH_, 56, {
            handdrawn = true, size = rect.w, x = rect.x, y = rect.y,
            drawPortrait = false, bubbleBottomInset = 72,
        })
    end
    local rect = document_:GetAbsoluteLayout()
    nvgSave(vg)
    nvgTranslate(vg, rect.x, rect.y)
    PlayTimeGuard.renderOverlay(vg, designW_, designH_, "sans", animTime_)
    nvgRestore(vg)
end

function M.setActive(active)
    active_ = active
    if not active or not instance_ then return end
    enteringGame_ = false
    FoxMascot.init(UI.GetNVGContext())
    refreshState()
    fitCanvas()
    showHomeGreeting()
end

function M.create(params)
    local err
    instance_, err = UI.LoadJSON(RESOURCE)
    if not instance_ then error("无法加载首页 UI：" .. tostring(err)) end
    document_ = instance_:GetRoot() --[[@as Panel]]
    assert(document_, "首页 UI 缺少根节点")
    designW_ = tonumber(document_.props.width) or 403.2
    designH_ = tonumber(document_.props.height) or 896
    widgets_ = {}
    lastSkin_, lastBackground_, lastUnlocked_, lastGameList_ = "", "", nil, nil
    viewportW_, viewportH_, animTime_ = 0.0, 0.0, 0.0
    enteringGame_ = false

    canvas_ = UI.Panel {
        id = "home-document-canvas", position = "absolute",
        width = designW_, height = designH_, transformOrigin = "top-left",
        pointerEvents = "box-none", children = {document_},
    }
    canvas_:AddChild(HomeDynamicLayer {
        id = "home-dynamic-layer", position = "absolute",
        left = 0, top = 0, width = "100%", height = "100%", pointerEvents = "none",
    })
    pageContainer_ = UI.Panel {
        id = "home-page-container", width = "100%", height = "100%",
        flexGrow = 1, flexBasis = 0, pointerEvents = "box-none",
        backgroundColor = {0,0,0,255}, children = {canvas_},
    }

    -- 编辑器允许可见溢出的分组；让命中范围跟随子网格，避免分组边界截掉下排按钮。
    local grid = find("home-game-grid")
    if grid and grid.parent and grid.parent.props.overflow ~= "hidden" then
        local group = grid.parent
        local originalHitTest = group.HitTest
        group:SetStyle({pointerEvents = "box-none"})
        group.HitTest = function(self, x, y)
            return originalHitTest(self, x, y) or grid:HitTest(x, y)
        end
    end

    for _, button in ipairs(instance_:FindAll("Button")) do
        local id = button.props.id or ""
        if id:sub(1, 5) == "game-" then
            local gameId = id:sub(6)
            button:OnEvent("click", function() enterGame(gameId) end)
        end
    end
    local adventure = find("tab-adventure")
    local profile = find("tab-profile")
    local settings = find("tab-settings")
    if adventure then adventure:OnEvent("click", function() navigate("adventure") end) end
    if profile then profile:OnEvent("click", function() navigate("profile") end) end
    if settings then
        settings:OnEvent("click", function()
            if not canInteract() then return end
            uiTap.play()
            settingsHelper_.open(pageContainer_)
        end)
    end
    local mascot = find("home-mascot")
    if mascot then
        mascot:SetStyle({pointerEvents = "auto"})
        mascot:OnEvent("click", function()
            if canInteract() then FoxMascot.notifyChat() end
        end)
    end

    -- 独立接收者不替换 UI 或其他页面的全局 Update/Input 订阅。
    eventNode_ = Node()
    receiver_ = eventNode_:CreateScriptObject("LuaScriptObject") --[[@as LuaScriptObject]]
    receiver_:SubscribeToEvent("Update", function(self, eventType, eventData)
        if not active_ then return end
        local dt = eventData["TimeStep"]:GetFloat()
        animTime_ = animTime_ + dt
        FoxMascot.update(dt)
        fitCanvas()
        refreshState()
    end)
    M.setActive(true)
    logger.info(MODULE, "create", "loaded " .. RESOURCE .. "; games=" .. #gameRegistry.getGameList())
    return pageContainer_
end

function M.destroy()
    active_ = false
    settingsHelper_.close()
    if receiver_ then receiver_:UnsubscribeFromAllEvents() end
    receiver_, eventNode_ = nil, nil
    -- 只释放首页的独立树，不替换 main 的全局 UI 根或其他覆盖层。
    -- JSON 图标由 UI.ImageCache 绑定全局 UI 上下文；切页不销毁共享上下文或释放共享句柄。
    -- GameCard.release 仅用于旧手绘卡片自有上下文销毁前，不能套用到这里。
    if canvas_ then canvas_:Destroy() end
    instance_, document_, canvas_, pageContainer_ = nil, nil, nil, nil
    widgets_ = {}
    lastGameList_ = nil
    FoxMascot.cleanup()
    logger.info(MODULE, "destroy", "ok")
end

return M
