--- 游戏主菜单（NanoVG 渲染版，替代原 UI 库 + Emoji 方案）
--- 拥有独立 NanoVG 上下文，通过 active_ 控制渲染/输入
local UI = require("urhox-libs/UI")
local Colors = require("shared.constants.colors")
local Layout = require("shared.constants.layout")
local gameRegistry = require("modules.game-registry.init")
local GameCard = require("shared.components.game-card")
local Router = require("app.router")
local ScreenTransition = require("shared.components.screen-transition")
local SoundManager = require("shared.sound-manager")
local logger = require("shared.utils.logger")
local uiTap = require("shared.utils.ui-tap")
local SettingsPopup = require("shared.components.settings-popup")
local TabBar = require("shared.components.tab-bar")
local Storyline = require("modules.storyline.init")
local FoxMascot = require("shared.components.fox-mascot")
local Density = require("shared.utils.density")
local bgManager = require("shared.background-manager")
local PageHeader = require("shared.components.page-header")
local PlayTimeGuard = require("shared.utils.play-time-guard")
local AntiAddictionPopup = require("shared.components.anti-addiction-popup")

local M = {}
local MODULE = "page-home"

-- NanoVG 状态
---@type userdata|nil
local nvgCtx_ = nil
local fontHandle_ = -1
local active_ = false

-- 瓷砖点击区域缓存（复用表，避免每帧 GC）
local tileHitAreas_ = {}  -- { { x, y, w, h, config } }
local tileHitCount_ = 0   -- 当前帧有效的点击区域数量

-- 游戏数据缓存
local games_ = {}
local onlineCount_ = 0

-- 动画时间累计
local animTime_ = 0

-- 布局缓存（避免每帧重算 calcTileSize）
local tileSizeCache_ = {
    screenW = 0, screenH = 0,
    tileSize = 0, gridOffsetX = 0,
}

---@type any 首页返回的 UI 容器（用于挂载弹窗）
local pageContainer_ = nil
-- 设置弹窗管理器
local settingsHelper_ = SettingsPopup.createPageHelper({
    extraButtons = SettingsPopup.makeDevButtons(),
})
-- 页签栏点击区域
local tabBarHitAreas_ = nil

-- ============================================================================
-- NanoVG 渲染
-- ============================================================================

--- 绘制标题区域，返回绘制后的 curY（委托给公共组件）
---@param vg userdata
---@param screenW number
---@param curY number
---@param t number 动画时间（未使用，保持接口一致）
---@return number curY
local function renderTitle(vg, screenW, curY, t)
    return PageHeader.render(vg, screenW, PageHeader.PRESET_HOME, curY) or curY
end

--- 计算瓷砖尺寸（带最大值约束）
---@param screenW number
---@param screenH number
---@return number tileSize
---@return number gridOffsetX 网格左偏移（居中用）
local function calcTileSize(screenW, screenH)
    local padding = Layout.MENU_PADDING
    local gap = Layout.TILE_GAP
    local cols = Layout.TILE_COLUMNS
    local gridW = screenW - padding * 2
    local tileSize = (gridW - gap * (cols - 1)) / cols

    -- 限制卡片最大尺寸：不超过可用高度的 30%（避免高屏下卡片过大遮挡狐狸）
    local maxTile = screenH * 0.28
    if tileSize > maxTile then
        tileSize = maxTile
    end

    -- 计算居中偏移
    local actualGridW = tileSize * cols + gap * (cols - 1)
    local gridOffsetX = padding + (gridW - actualGridW) / 2

    return tileSize, gridOffsetX
end

--- 绘制游戏瓷砖网格，返回绘制后的 curY
---@param vg userdata
---@param screenW number
---@param screenH number
---@param curY number
---@return number curY
local function renderGrid(vg, screenW, screenH, curY)
    local gap = Layout.TILE_GAP
    local cols = Layout.TILE_COLUMNS

    -- 使用缓存的 tileSize（屏幕尺寸不变时跳过计算）
    if screenW ~= tileSizeCache_.screenW or screenH ~= tileSizeCache_.screenH then
        tileSizeCache_.screenW = screenW
        tileSizeCache_.screenH = screenH
        tileSizeCache_.tileSize, tileSizeCache_.gridOffsetX = calcTileSize(screenW, screenH)
    end
    local tileSize = tileSizeCache_.tileSize
    local gridOffsetX = tileSizeCache_.gridOffsetX
    local rows = math.ceil(#games_ / cols)

    -- 重置点击区域计数（复用已有表条目）
    tileHitCount_ = 0

    if #games_ == 0 then
        nvgFontFace(vg, "menu")
        nvgFontSize(vg, Layout.FONT_SIZE_BODY)
        nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
        local hc = Colors.textHint
        nvgFillColor(vg, nvgRGBA(hc[1], hc[2], hc[3], 255))
        nvgText(vg, screenW / 2, curY + 60, "暂无游戏")
        return curY + 120
    end

    for i, config in ipairs(games_) do
        local row = math.ceil(i / cols) - 1
        local col = (i - 1) % cols
        local tx = gridOffsetX + col * (tileSize + gap)
        local ty = curY + row * (tileSize + gap)

        GameCard.drawTile(vg, tx, ty, tileSize, config, i)

        -- 复用已有 table 条目，减少 GC
        tileHitCount_ = tileHitCount_ + 1
        local hitArea = tileHitAreas_[tileHitCount_]
        if not hitArea then
            hitArea = { x = 0, y = 0, w = 0, h = 0, config = nil }
            tileHitAreas_[tileHitCount_] = hitArea
        end
        hitArea.x = tx
        hitArea.y = ty
        hitArea.w = tileSize
        hitArea.h = tileSize
        hitArea.config = config
    end

    local gridH = rows * tileSize + math.max(0, rows - 1) * gap
    return curY + gridH
end

--- 主渲染函数
local function renderAll(vg, screenW, screenH, t)
    local gap = Layout.TILE_GAP
    local cols = Layout.TILE_COLUMNS

    -- 预算总内容高度
    local tileSize = calcTileSize(screenW, screenH)
    local rows = math.ceil(math.max(1, #games_) / cols)
    local gridH = rows * tileSize + math.max(0, rows - 1) * gap

    -- 绘制标题 + 网格
    local curY = Layout.MENU_START_Y + Layout.MENU_TITLE_GAP
    curY = renderTitle(vg, screenW, curY, t)
    curY = curY + Layout.MENU_GRID_GAP
    renderGrid(vg, screenW, screenH, curY)

    -- 狐狸立绘（在页签栏下方）
    FoxMascot.render(vg, screenW, screenH, TabBar.HEIGHT, { handdrawn=true, size=screenH<720 and 100 or 128, bubbleBottomInset=72 })

    -- 底部页签栏
    local lockedTabs = Storyline.getNodeState("story-4") ~= "done" and { home = true } or nil
    tabBarHitAreas_ = TabBar.render(vg, screenW, screenH, "home", t, "menu", lockedTabs, { handdrawn = true })


end

-- ============================================================================
-- 事件回调（全局函数名，UrhoX 要求）
-- ============================================================================

--- NanoVG 渲染回调
---@param eventType string
---@param eventData table
function Home_HandleNanoVGRender(eventType, eventData)
    if not active_ or not nvgCtx_ then return end

    -- 累计动画时间
    local dt = 1.0 / 60.0
    animTime_ = animTime_ + dt
    FoxMascot.update(dt)

    local logW, logH = Density.beginFrame(nvgCtx_)

    -- 背景（跟随装扮页面选择）
    bgManager.renderBackground(nvgCtx_, logW, logH, animTime_, nil)

    renderAll(nvgCtx_, logW, logH, animTime_)

    -- 非可游玩时间遮罩
    PlayTimeGuard.renderOverlay(nvgCtx_, logW, logH, "menu", animTime_)

    Density.endFrame(nvgCtx_)
end

--- 处理点击/触摸
local function handleClickAt(screenX, screenY)
    if not active_ then return end
    -- 设置弹窗打开时，不处理 NanoVG 层点击（UI 层会拦截弹窗内的点击）
    if settingsHelper_.isOpen() then return end

    local lx, ly = Density.toGameCoords(screenX, screenY)

    -- 狐狸立绘点击 → 触发聊天气泡
    local logW, logH = Density.getGameSize()
    if FoxMascot.hitTest(lx, ly, logW, logH, TabBar.HEIGHT) then
        FoxMascot.notifyChat()
        return
    end

    -- 检测页签栏点击
    local tabAction = TabBar.handleClick(lx, ly, tabBarHitAreas_)
    if tabAction then
        if tabAction.type == "tab" and tabAction.id ~= "home" then
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

    for i = 1, tileHitCount_ do
        local area = tileHitAreas_[i]
        if lx >= area.x and lx <= area.x + area.w and
           ly >= area.y and ly <= area.y + area.h then
            -- 非可游玩时间禁止进入游戏
            if PlayTimeGuard.isRestricted() then
                logger.info(MODULE, "click_game_tile", "blocked: restricted play time")
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
            logger.info(MODULE, "click_game_tile", area.config.gameId)
            ScreenTransition.run(function()
                Router.push("game", { gameConfig = area.config })
            end)
            return
        end
    end
end

--- 鼠标点击回调
---@param eventType string
---@param eventData table
function Home_HandleMouseDown(eventType, eventData)
    if not active_ then return end
    local button = eventData["Button"]:GetInt()
    if button ~= MOUSEB_LEFT then return end
    local x = eventData["X"]:GetInt()
    local y = eventData["Y"]:GetInt()
    handleClickAt(x, y)
end

--- 触摸回调
---@param eventType string
---@param eventData table
function Home_HandleTouchBegin(eventType, eventData)
    if not active_ then return end
    local x = eventData["X"]:GetInt()
    local y = eventData["Y"]:GetInt()
    handleClickAt(x, y)
end

-- ============================================================================
-- 页面生命周期
-- ============================================================================

--- 设置页面活跃状态（由 main.lua 通过 Router.onNavigate 调用）
--- 显示自由模式进入问候
local function showHomeGreeting()
    local homeGreetings = {
        "自由模式！想玩哪个就玩哪个~",
        "欢迎回来！今天想挑战哪个游戏？",
        "自由选择，随心畅玩！",
        "嘿嘿，选一个你最拿手的游戏吧！",
        "自由模式真棒，每个游戏都很有趣哦~",
    }
    FoxMascot.showMessage(homeGreetings[math.random(1, #homeGreetings)])
end

function M.setActive(a)
    active_ = a
    if a then
        -- 从游戏返回时需要重新订阅输入事件（游戏可能覆盖了全局订阅）
        SubscribeToEvent("MouseButtonDown", "Home_HandleMouseDown")
        SubscribeToEvent("TouchBegin", "Home_HandleTouchBegin")
        -- 从游戏返回时重新初始化狐狸立绘（游戏 onExit 会 cleanup）
        if nvgCtx_ then
            FoxMascot.init(nvgCtx_)
        end
        showHomeGreeting()
    end
end

--- 创建首页
---@param params table|nil
---@return any UI 节点（透明占位面板，实际渲染由 NanoVG 完成）
function M.create(params)
    -- 加载游戏数据
    games_ = gameRegistry.getGameList()
    onlineCount_ = 0
    for _, g in ipairs(games_) do
        if g.status == "online" then
            onlineCount_ = onlineCount_ + 1
        end
    end

    -- 创建 NanoVG 上下文（如果不存在）
    if not nvgCtx_ then
        nvgCtx_ = nvgCreate(1)
        if nvgCtx_ then
            fontHandle_ = nvgCreateFont(nvgCtx_, "menu", "Fonts/LongZhuTi-Regular.ttf")
            if fontHandle_ < 0 then
                logger.warn(MODULE, "create", "font load failed")
            end
            -- NanoVGRender 订阅在 nvgCtx_ 对象上，不与游戏冲突
            SubscribeToEvent(nvgCtx_, "NanoVGRender", "Home_HandleNanoVGRender")
            FoxMascot.init(nvgCtx_)
            showHomeGreeting()
        else
            logger.error(MODULE, "create", "failed to create NanoVG context")
        end
    end

    active_ = true
    tileHitCount_ = 0
    tileSizeCache_.screenW = 0  -- 强制重算布局

    -- 订阅输入事件
    SubscribeToEvent("MouseButtonDown", "Home_HandleMouseDown")
    SubscribeToEvent("TouchBegin", "Home_HandleTouchBegin")

    logger.info(MODULE, "create", "games=" .. #games_)

    -- 返回透明占位面板，供 Router 管理节点树
    -- 使用相对定位容器以便挂载 absolute 弹窗
    pageContainer_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
    }
    return pageContainer_
end

--- 销毁首页
function M.destroy()
    active_ = false
    tileHitCount_ = 0
    settingsBtnArea_ = nil
    adventureBtnArea_ = nil

    -- 关闭设置弹窗
    settingsHelper_.close()
    pageContainer_ = nil

    FoxMascot.cleanup()

    if nvgCtx_ then
        bgManager.clearThemeCache(nvgCtx_)
        PlayTimeGuard.cleanup(nvgCtx_)
        nvgDelete(nvgCtx_)
        nvgCtx_ = nil
    end

    -- 全局输入事件由各页共享；销毁时由 active_ 门控，保留具名回调供再次进入。
    -- 不调用全局退订，否则会移除 UI 系统和其他页面的同名事件。


    logger.info(MODULE, "destroy", "ok")
end

return M
