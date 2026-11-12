--- 主线地图页（NanoVG 渲染，分页模式）
--- 拥有独立 NanoVG 上下文，通过 active_ 控制渲染/输入
local UI = require("urhox-libs/UI")
local Storyline = require("modules.storyline.init")
local gameRegistry = require("modules.game-registry.init")
local Router = require("app.router")
local ScreenTransition = require("shared.components.screen-transition")
local logger = require("shared.utils.logger")
local uiTap = require("shared.utils.ui-tap")
local SettingsPopup = require("shared.components.settings-popup")
local SoundManager = require("shared.sound-manager")
local TabBar = require("shared.components.tab-bar")
local Dialogue = require("modules.dialogue.init")
local FunFact = require("modules.dialogue.fun-fact")
local FoxMascot = require("shared.components.fox-mascot")
local Density = require("shared.utils.density")
local advSfx = require("pages.adventure.adventure-sfx")
local PageHeader = require("shared.components.page-header")
local PlayTimeGuard = require("shared.utils.play-time-guard")
local AntiAddictionPopup = require("shared.components.anti-addiction-popup")
local HealthAdvisory = require("shared.components.health-advisory")
local OutfitUnlockPopup = require("shared.components.outfit-unlock-popup")
local BgUnlockPopup = require("shared.components.bg-unlock-popup")
local BackgroundManager = require("shared.background-manager")

-- 提取的子模块
local advRenderer = require("pages.adventure.rendering.adventure-renderer")
local adventureLayout = require("pages.adventure.layout.adaptive-layout")
local chapterDefs = require("pages.adventure.data.chapter-definitions")
local dlgManager = require("pages.adventure.dialogue.dialogue-manager")

local M = {}
local MODULE = "page-adventure"

-- ============================================================================
-- NanoVG 状态
-- ============================================================================
---@type userdata|nil
local nvgCtx_ = nil
local fontHandle_ = -1
local active_ = false
local animTime_ = 0

-- 页面 UI 容器（用于挂载设置弹窗等）
---@type any
local pageContainer_ = nil

-- ============================================================================
-- NPC 头像纹理
-- ============================================================================
---@type table<string, number> role -> nvgImage handle
local npcImages_ = {}

local NPC_TEXTURES = {
    owl     = "Textures/character/owl.png",
    cat     = "Textures/character/cat.png",
    rabbit  = "Textures/character/bunny.png",
    raccoon = "Textures/character/raccoon.png",
}

local OutfitManager = require("shared.outfit-manager")
---@type number
local foxImage_ = -1
---@type boolean 云端皮肤到达后的脏标记
local foxSkinDirty_ = false

-- ============================================================================
-- 分页状态
-- ============================================================================
local currentPage_ = 1

-- ============================================================================
-- 点击区域（复用表，避免每帧 GC）
-- ============================================================================
---@type table[] { cx, cy, r, nodeIdx }
local nodeHitAreas_ = {}
local nodeHitCount_ = 0
local tabBarHitAreas_ = nil
---@type table|nil { x, y, w, h }
local prevPageBtn_ = nil
---@type table|nil { x, y, w, h }
local nextPageBtn_ = nil

-- ============================================================================
-- 布局缓存（避免每帧重算）
-- ============================================================================
local layoutCache_ = {
    screenW = 0, screenH = 0,
    headerH = 0, chapterH = 0, footerH = 0,
    nodeKey = "",
    nodeRadius = 0, rowSpacing = 0,
}

-- 章节标题动画状态（传给渲染器）
local chapterState_ = {
    fadeAlpha = 1.0,
    lastDisplayedPage = -1,
}

-- 设置弹窗管理器
local settingsHelper_ = SettingsPopup.createPageHelper({
    extraButtons = SettingsPopup.makeDevButtons(),
})

-- ============================================================================
-- 对话系统状态
-- ============================================================================
---@type string|nil 刚通关的节点 ID（用于触发 postDialogue）
local pendingPostNodeId_ = nil
---@type boolean 是否首次通关该节点
local pendingFirstClear_ = false
---@type string|nil 待展示的解锁皮肤 ID
local pendingUnlockSkin_ = nil
---@type string|nil 待展示的解锁背景 ID
local pendingUnlockBg_ = nil
---@type boolean 防止重复进入关卡（对话/过渡期间的点击穿透保护）
local enteringLevel_ = false

-- ============================================================================
-- 进入主线关卡
-- ============================================================================

local function enterStoryLevel(nodeInfo)
    if enteringLevel_ then return end
    enteringLevel_ = true
    local node = nodeInfo.node
    local levelData = require("config.storyline-levels." .. node.levelFile)
    levelData.title = levelData.title or node.title
    local gameConfig = gameRegistry.getGameById(node.gameType)

    if not gameConfig then
        logger.error(MODULE, "enterStoryLevel", "game not found: " .. node.gameType)
        return
    end

    logger.info(MODULE, "enterStoryLevel", "entering " .. node.nodeId .. " (" .. node.gameType .. ")")

    local function doEnterGame()
        ScreenTransition.run(function()
            Router.push("game", {
                gameConfig = gameConfig,
                storylineOpts = {
                    levelData = levelData,
                    mode = "storyline",
                    onComplete = function()
                        pendingFirstClear_ = (Storyline.getNodeState(node.nodeId) ~= "done")

                        pendingUnlockSkin_ = nil
                        pendingUnlockBg_ = nil
                        if pendingFirstClear_ then
                            local allSkins = OutfitManager.getAllSkins()
                            for _, skin in ipairs(allSkins) do
                                if skin.unlock and skin.unlock.type == "story" and skin.unlock.nodeId == node.nodeId then
                                    pendingUnlockSkin_ = skin.id
                                    break
                                end
                            end

                            local allBgs = BackgroundManager.getAll()
                            for _, bg in ipairs(allBgs) do
                                if bg.unlock and bg.unlock.type == "story" and bg.unlock.nodeId == node.nodeId then
                                    pendingUnlockBg_ = bg.id
                                    break
                                end
                            end
                        end

                        Storyline.completeNode(node.nodeId)
                        pendingPostNodeId_ = node.nodeId
                    end,
                },
            })
            M.setActive(false)
        end)
    end

    if node.preDialogue and #node.preDialogue > 0 then
        local levelVars = dlgManager.extractLevelVars(node)
        Dialogue.start(node.preDialogue, dlgManager.getDialogueOpts(npcImages_, foxImage_, doEnterGame, levelVars))
    else
        doEnterGame()
    end
end

-- ============================================================================
-- 事件回调
-- ============================================================================

function Adv_HandleNanoVGRender(eventType, eventData)
    if not active_ or not nvgCtx_ then return end

    -- 云端皮肤到达后刷新狐狸贴图
    if foxSkinDirty_ then
        foxSkinDirty_ = false
        local newImg = nvgCreateImage(nvgCtx_, OutfitManager.getTexturePath(), 0)
        if newImg >= 0 then
            foxImage_ = newImg
        end
    end

    local dt = 1.0 / 60.0
    animTime_ = animTime_ + dt

    Dialogue.update(dt)
    FunFact.update(dt)
    FoxMascot.update(dt)
    OutfitUnlockPopup.update(dt)
    BgUnlockPopup.update(dt)

    local logW, logH = Density.beginFrame(nvgCtx_)

    -- 委托到渲染器
    nodeHitCount_, prevPageBtn_, nextPageBtn_, tabBarHitAreas_, currentPage_ =
        advRenderer.renderMap(nvgCtx_, logW, logH, animTime_, currentPage_, npcImages_, nodeHitAreas_, layoutCache_, chapterState_)

    -- 对话框和小知识卡片渲染在地图之上
    Dialogue.render(nvgCtx_, logW, logH)
    FunFact.render(nvgCtx_, logW, logH)
    OutfitUnlockPopup.render(nvgCtx_, logW, logH)
    BgUnlockPopup.render(nvgCtx_, logW, logH)
    PlayTimeGuard.renderOverlay(nvgCtx_, logW, logH, "adv", animTime_)
    Density.endFrame(nvgCtx_)
end

--- 处理点击
local function handleClickAt(lx, ly)
    if not active_ then return end

    if HealthAdvisory.isActive() then return end

    if BgUnlockPopup.isActive() then
        BgUnlockPopup.handleClick(lx, ly)
        return
    end

    if OutfitUnlockPopup.isActive() then
        OutfitUnlockPopup.handleClick(lx, ly)
        return
    end

    if FunFact.isActive() then
        FunFact.handleClick(lx, ly)
        return
    end
    if Dialogue.isActive() then
        Dialogue.handleClick()
        return
    end

    if settingsHelper_.isOpen() then return end

    -- 页签栏
    local tabAction = TabBar.handleClick(lx, ly, tabBarHitAreas_)
    if tabAction then
        if tabAction.type == "tab" and tabAction.id ~= "adventure" then
            uiTap.play()
            ScreenTransition.run(function()
                Router.replace(tabAction.id)
            end)
        elseif tabAction.type == "settings" then
            uiTap.play()
            settingsHelper_.open(pageContainer_)
        end
        return
    end

    -- 上一页
    if prevPageBtn_ then
        local a = prevPageBtn_
        if lx >= a.x and lx <= a.x + a.w and ly >= a.y and ly <= a.y + a.h then
            advSfx.play("page_whoosh")
            currentPage_ = math.max(1, currentPage_ - 1)
            return
        end
    end

    -- 下一页
    if nextPageBtn_ then
        local a = nextPageBtn_
        if lx >= a.x and lx <= a.x + a.w and ly >= a.y and ly <= a.y + a.h then
            advSfx.play("page_whoosh")
            currentPage_ = currentPage_ + 1
            return
        end
    end

    -- 狐狸立绘
    local foxW, foxH = Density.getGameSize()
    if FoxMascot.hitTest(lx, ly, foxW, foxH, TabBar.HEIGHT, adventureLayout.getFoxOptions(foxH)) then
        advSfx.play("fox_chat_pop")
        FoxMascot.notifyChat()
        return
    end

    -- 节点点击
    for i = 1, nodeHitCount_ do
        local area = nodeHitAreas_[i]
        local dx = lx - area.cx
        local dy = ly - area.cy
        if dx * dx + dy * dy <= area.r * area.r then
            if PlayTimeGuard.isRestricted() then
                logger.info(MODULE, "click", "blocked: restricted play time")
                -- 弹出防沉迷提示告知用户原因
                if pageContainer_ then
                    local reason = PlayTimeGuard.getBlockReason()
                    if reason == "curfew" then
                        AntiAddictionPopup.showCurfew(pageContainer_, function() end)
                    elseif reason == "time_limit" then
                        AntiAddictionPopup.showForceExit(pageContainer_, function() end)
                    end
                end
                return
            end
            uiTap.play()
            local nodes = Storyline.getNodeList()
            local nodeInfo = nodes[area.nodeIdx]
            if nodeInfo then
                if nodeInfo.state == "current" or nodeInfo.state == "done" then
                    enterStoryLevel(nodeInfo)
                else
                    advSfx.play("node_locked")
                    logger.info(MODULE, "click", "node locked: " .. nodeInfo.node.nodeId)
                end
            end
            return
        end
    end
end

function Adv_HandleMouseDown(eventType, eventData)
    if not active_ then return end
    local button = eventData["Button"]:GetInt()
    if button ~= MOUSEB_LEFT then return end
    local mx = eventData["X"]:GetInt()
    local my = eventData["Y"]:GetInt()
    local gx, gy = Density.toGameCoords(mx, my)
    handleClickAt(gx, gy)
end

function Adv_HandleTouchEnd(eventType, eventData)
    if not active_ then return end
    local tx = eventData["X"]:GetInt()
    local ty = eventData["Y"]:GetInt()
    local gx, gy = Density.toGameCoords(tx, ty)
    handleClickAt(gx, gy)
end

function Adv_HandleKeyDown(eventType, eventData)
    if not active_ then return end
    if Dialogue.isActive() or FunFact.isActive() then return end
    local key = eventData["Key"]:GetInt()
    if key == KEY_LEFT then
        currentPage_ = math.max(1, currentPage_ - 1)
    elseif key == KEY_RIGHT then
        -- 按章节分页：总页数 = 章节数
        local totalPages = chapterDefs.getChapterCount()
        currentPage_ = math.min(totalPages, currentPage_ + 1)
    end
end

-- ============================================================================
-- 页面生命周期
-- ============================================================================

local function showAdventureGreeting()
    local adventureGreetings = {
        "欢迎来到主线冒险！准备好挑战了吗？",
        "冒险模式开启！一起闯关吧~",
        "勇敢的冒险家，新的关卡在等你！",
        "主线故事继续啦，加油哦！",
        "嗨！我们继续冒险旅程吧~",
    }
    FoxMascot.showMessage(adventureGreetings[math.random(1, #adventureGreetings)])
end

function M.setActive(a)
    active_ = a
    enteringLevel_ = false
    if a then
        SubscribeToEvent("MouseButtonDown", "Adv_HandleMouseDown")
        SubscribeToEvent("TouchEnd", "Adv_HandleTouchEnd")
        SubscribeToEvent("KeyDown", "Adv_HandleKeyDown")

        if nvgCtx_ then
            FoxMascot.init(nvgCtx_)
            local newImg = nvgCreateImage(nvgCtx_, OutfitManager.getTexturePath(), 0)
            if newImg >= 0 then
                foxImage_ = newImg
            end
        end

        if pendingPostNodeId_ then
            local nodeId = pendingPostNodeId_
            pendingPostNodeId_ = nil
            if pendingFirstClear_ then
                advSfx.play("node_unlock")
            end

            -- 链式弹窗：皮肤解锁 → 背景解锁 → 剧情对话
            local unlockSkinId = pendingUnlockSkin_
            local unlockBgId = pendingUnlockBg_
            pendingUnlockSkin_ = nil
            pendingUnlockBg_ = nil

            local function showPostDialogue()
                dlgManager.showPostDialogueForNode(nodeId, pendingFirstClear_, npcImages_, foxImage_)
            end

            local function showBgUnlockOrNext()
                if unlockBgId and nvgCtx_ then
                    BgUnlockPopup.show(nvgCtx_, unlockBgId, {
                        fontName = "adv",
                        onDismiss = showPostDialogue,
                    })
                else
                    showPostDialogue()
                end
            end

            if unlockSkinId and nvgCtx_ then
                OutfitUnlockPopup.show(nvgCtx_, unlockSkinId, {
                    fontName = "adv",
                    onDismiss = showBgUnlockOrNext,
                })
            else
                showBgUnlockOrNext()
            end
        else
            showAdventureGreeting()
        end
    end
end

---@param params table|nil
---@return any UI 节点
function M.create(params)
    Storyline.load(function()
        logger.info(MODULE, "create", "storyline progress loaded")
    end)

    if not nvgCtx_ then
        nvgCtx_ = nvgCreate(1)
        if nvgCtx_ then
            fontHandle_ = nvgCreateFont(nvgCtx_, "adv", "Fonts/LongZhuTi-Regular.ttf")
            advRenderer.init(nvgCtx_)
            if fontHandle_ < 0 then
                logger.warn(MODULE, "create", "font load failed")
            end

            for role, path in pairs(NPC_TEXTURES) do
                local handle = nvgCreateImage(nvgCtx_, path, 0)
                if handle >= 0 then
                    npcImages_[role] = handle
                else
                    logger.warn(MODULE, "create", "failed to load NPC image: " .. path)
                end
            end

            foxImage_ = nvgCreateImage(nvgCtx_, OutfitManager.getTexturePath(), 0)
            if foxImage_ < 0 then
                logger.warn(MODULE, "create", "failed to load fox image")
            end

            SubscribeToEvent(nvgCtx_, "NanoVGRender", "Adv_HandleNanoVGRender")
            FoxMascot.init(nvgCtx_)
            FoxMascot.setSfxCallbacks({
                onPraisePop = function() advSfx.play("fox_praise_pop") end,
                onChatPop   = function() advSfx.play("fox_chat_pop") end,
            })
            showAdventureGreeting()
        else
            logger.error(MODULE, "create", "failed to create NanoVG context")
        end
    end

    active_ = true
    currentPage_ = 1
    animTime_ = 0
    nodeHitCount_ = 0
    layoutCache_.screenW = 0
    chapterState_.lastDisplayedPage = -1
    chapterState_.fadeAlpha = 0.0

    SubscribeToEvent("MouseButtonDown", "Adv_HandleMouseDown")
    SubscribeToEvent("TouchEnd", "Adv_HandleTouchEnd")
    SubscribeToEvent("KeyDown", "Adv_HandleKeyDown")

    logger.info(MODULE, "create", "adventure map ready")

    pageContainer_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
    }
    return pageContainer_
end

function M.destroy()
    active_ = false
    nodeHitCount_ = 0
    tabBarHitAreas_ = nil
    prevPageBtn_ = nil
    nextPageBtn_ = nil

    Dialogue.stop()
    FunFact.stop()
    OutfitUnlockPopup.dismiss()
    BgUnlockPopup.dismiss()
    pendingPostNodeId_ = nil
    pendingFirstClear_ = false
    pendingUnlockSkin_ = nil
    pendingUnlockBg_ = nil

    settingsHelper_.close()
    pageContainer_ = nil

    FoxMascot.cleanup()
    advSfx.cleanup()

    if nvgCtx_ then
        advRenderer.cleanup()
        BackgroundManager.clearThemeCache(nvgCtx_)
        PlayTimeGuard.cleanup(nvgCtx_)
        nvgDelete(nvgCtx_)
        nvgCtx_ = nil
    end

    npcImages_ = {}
    foxImage_ = -1

    -- 全局输入事件由各页共享；销毁时由 active_ 门控，保留具名回调供再次进入。
    -- 不调用全局退订，否则会移除 UI 系统和其他页面的同名事件。


    logger.info(MODULE, "destroy", "ok")
end

-- 注册云端皮肤变更回调
OutfitManager.onChange(function()
    foxSkinDirty_ = true
end)

return M
