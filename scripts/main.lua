-- 玩趣乐园 - 益智游戏合集（主入口）

local UI = require("urhox-libs/UI")
local Colors = require("shared.constants.colors")
local logger = require("shared.utils.logger")
local gameRegistry = require("modules.game-registry.init")
local gameContainer = require("modules.game-container.init")
local Router = require("app.router")
local ScreenTransition = require("shared.components.screen-transition")
local featureFlags = require("config.feature-flags")
local compliance = require("config.compliance")
local PrivacyPolicy = require("shared.components.privacy-policy-popup")
local SoundManager = require("shared.sound-manager")
local settingsSave = require("shared.settings-save")
local ANIM = require("shared.constants.animations")
local OutfitManager = require("shared.outfit-manager")
local HealthAdvisory = require("shared.components.health-advisory")
local realNameAuth = require("shared.real-name-auth")
local RealNameAuthOverlay = require("shared.components.real-name-auth-overlay")
local antiAddiction = require("shared.anti-addiction")
local cloudAge = require("shared.cloud-age")
local AntiAddictionPopup = require("shared.components.anti-addiction-popup")
local bgManager = require("shared.background-manager")

-- 全局变量
local MODULE = "main"
---@type any
local uiRoot_ = nil
---@type any
local pageContainer_ = nil
---@type any
local authOverlayNode_ = nil
---@type Scene|nil BGM 专用 Scene（独立于 SoundManager，不受游戏切换影响）
local bgmScene_ = nil
---@type any 防沉迷弹窗挂载容器
local antiAddictionContainer_ = nil
---@type integer F6 测试未成年人年龄段索引
local minorLimitTestIndex_ = 0
local MINOR_LIMIT_TEST_AGES = { 7, 12, 17 }

-- 生命周期

function Start()
    graphics.windowTitle = "玩趣乐园"

    -- 1. 初始化 UI 框架
    UI.Init({
        fonts = {
            { family = "sans", weights = {
                normal = "Fonts/LongZhuTi-Regular.ttf",
            } }
        },
        scale = UI.Scale.DEFAULT,
    })

    -- 设置暖色主题（橘红色 primary）
    local Theme = UI.Theme
    local warmTheme = Theme.ExtendTheme(Theme.defaultTheme, {
        colors = {
            primary        = Colors.primary,
            primaryHover   = Colors.primaryLight,
            primaryPressed = Colors.primaryDark,
            text           = Colors.textPrimary,
            textSecondary  = Colors.textSecondary,
            border         = Colors.tileBorder,
            borderFocus    = Colors.primary,
            surface        = Colors.cardBg,
        },
    })
    Theme.SetTheme(warmTheme)

    -- 2. 加载游戏配置
    gameRegistry.loadAll()

    -- 3. 初始化皮肤管理器（从存档加载）
    OutfitManager.init()

    -- 3.2 初始化背景管理器（从云端加载已选背景和已购买状态）
    bgManager.init()

    -- 3.5 初始化模拟实名认证（外部合规系统启用时关闭）
    if compliance.isEnabled() then
        realNameAuth.init()
    end

    -- 3.6 初始化模拟防沉迷模块（外部合规系统启用时关闭）
    antiAddiction.init()

    -- 3.7 初始化云存档测试年龄（本地缓存同步加载 + 云端异步拉取）
    cloudAge.init()
    cloudAge.syncFromCloud()

    -- 4. 注册页面
    local adventurePage = require("pages.adventure.init")
    local homePage = require("pages.home.init")
    local gamePage = require("pages.game.init")
    local profilePage = require("pages.profile.init")
    Router.register("adventure", adventurePage.create, adventurePage.destroy)
    Router.register("home", homePage.create, homePage.destroy)
    Router.register("game", gamePage.create, gamePage.destroy)
    Router.register("profile", profilePage.create, profilePage.destroy)

    -- 4. 设置游戏退出回调
    gameContainer.setOnExitCallback(function()
        ScreenTransition.run(function()
            Router.pop()
        end)
    end)

    -- 5. 构建全局 UI
    CreateUI()

    -- 6. 转场动画驱动
    SubscribeToEvent("PostUpdate", "Main_HandlePostUpdate")

    -- 7. 加载音量存档并应用
    local settings = settingsSave.load()
    SoundManager.setMasterVolume(settings.sfxVolume)

    -- 8. 启动全局 BGM（使用存档中的音量）
    StartBGM(settings.bgmVolume)

    -- 8. 导航到主线地图页（默认首页）
    Router.replace("adventure")

    logger.info(MODULE, "Start", "ok")
end

function Stop()
    if gameContainer.isRunning() then
        gameContainer.exit("app_background")
    end
    -- 停止 BGM
    if bgmScene_ then
        bgmScene_:Remove()
        bgmScene_ = nil
    end
    local uiVg = UI.GetNVGContext()
    if uiVg then bgManager.clearThemeCache(uiVg) end
    UI.Shutdown()
    logger.info(MODULE, "Stop", "ok")
end

-- 全局 BGM（独立于 SoundManager，不受游戏切换影响）

-- 场景 → BGM 映射
local BGM_TRACKS = {
    menu = "audio/bgm/bgm_gentle_dream.ogg",    -- 首页/冒险/个人页：轻松舒缓
    game = "audio/bgm/bgm_active_park.ogg",      -- 游戏中：节奏活跃
}

-- 页面 → BGM 场景类型映射
local PAGE_BGM = {
    home      = "menu",
    adventure = "menu",
    profile   = "menu",
    game      = "game",
}

---@type string|nil 当前正在播放的曲目路径
local currentBgmPath_ = nil
---@type number 用户设置的 BGM 音量
local bgmTargetVolume_ = 0.35
-- 淡入淡出状态
---@type string|nil "fade_out"|"fade_in"|nil
local bgmFadeState_ = nil
---@type string|nil 淡出完成后要切换的曲目路径
local bgmPendingPath_ = nil
local BGM_FADE_SPEED = ANIM.BGM_FADE_SPEED  -- 每秒淡变量（约 0.6 秒完成淡入淡出）

--- 启动 BGM 系统，播放指定或默认曲目
---@param volume number|nil BGM 音量 0~1，默认 0.35
---@param trackPath string|nil BGM 文件路径，默认 menu 曲目
function StartBGM(volume, trackPath)
    bgmTargetVolume_ = volume or 0.35
    local path = trackPath or BGM_TRACKS.menu
    local snd = cache:GetResource("Sound", path)
    if not snd then
        logger.warn(MODULE, "StartBGM", "BGM file not found: " .. path)
        return
    end
    snd.looped = true
    bgmScene_ = Scene()
    local node = bgmScene_:CreateChild("BGM")
    local source = node:CreateComponent("SoundSource")
    source.gain = bgmTargetVolume_
    source:Play(snd)
    currentBgmPath_ = path
    logger.info(MODULE, "StartBGM", "playing: " .. path .. ", vol=" .. source.gain)
end

--- 切换 BGM 曲目（带淡入淡出过渡）
---@param trackPath string 新曲目路径
local function switchBGM(trackPath)
    if trackPath == currentBgmPath_ then return end
    if not bgmScene_ then
        -- 尚未初始化，直接启动
        StartBGM(bgmTargetVolume_, trackPath)
        return
    end
    -- 开始淡出当前曲目
    bgmPendingPath_ = trackPath
    bgmFadeState_ = "fade_out"
end

--- 根据页面 ID 切换到对应场景的 BGM
---@param pageId string
local function switchBGMForPage(pageId)
    local sceneType = PAGE_BGM[pageId] or "menu"
    local trackPath = BGM_TRACKS[sceneType] or BGM_TRACKS.menu
    switchBGM(trackPath)
end

--- 更新 BGM 淡入淡出（每帧调用）
---@param dt number
local function updateBGMFade(dt)
    if not bgmFadeState_ or not bgmScene_ then return end

    local node = bgmScene_:GetChild("BGM", false)
    if not node then
        bgmFadeState_ = nil
        return
    end
    local source = node:GetComponent("SoundSource")
    if not source then
        bgmFadeState_ = nil
        return
    end

    if bgmFadeState_ == "fade_out" then
        local newGain = source.gain - BGM_FADE_SPEED * dt
        if newGain <= 0.01 then
            -- 淡出完成，切换曲目
            source:Stop()
            if bgmPendingPath_ then
                local snd = cache:GetResource("Sound", bgmPendingPath_)
                if snd then
                    snd.looped = true
                    source.gain = 0.0
                    source:Play(snd)
                    currentBgmPath_ = bgmPendingPath_
                    bgmFadeState_ = "fade_in"
                    logger.info(MODULE, "switchBGM", "now playing: " .. bgmPendingPath_)
                else
                    logger.warn(MODULE, "switchBGM", "BGM not found: " .. bgmPendingPath_)
                    bgmFadeState_ = nil
                end
                bgmPendingPath_ = nil
            else
                bgmFadeState_ = nil
            end
        else
            source.gain = newGain
        end

    elseif bgmFadeState_ == "fade_in" then
        local newGain = source.gain + BGM_FADE_SPEED * dt
        if newGain >= bgmTargetVolume_ then
            source.gain = bgmTargetVolume_
            bgmFadeState_ = nil
        else
            source.gain = newGain
        end

    elseif bgmFadeState_ == "volume_adjust" then
        -- 用户拖动音量滑块时的平滑过渡（避免瞬间跳变爆音）
        local curGain = source.gain
        local diff = bgmTargetVolume_ - curGain
        if math.abs(diff) < 0.01 then
            source.gain = bgmTargetVolume_
            bgmFadeState_ = nil
        else
            -- 使用更快的渐变速度（滑块响应要及时）
            local step = BGM_FADE_SPEED * 2.0 * dt
            if diff > 0 then
                source.gain = math.min(bgmTargetVolume_, curGain + step)
            else
                source.gain = math.max(bgmTargetVolume_, curGain - step)
            end
        end
    end
end

--- 获取 BGM 音量（0.0 ~ 1.0）
---@return number
function GetBGMVolume()
    return bgmTargetVolume_
end

--- 设置 BGM 音量（0.0 ~ 1.0，平滑渐变避免爆音）
---@param v number
function SetBGMVolume(v)
    bgmTargetVolume_ = math.max(0.0, math.min(1.0, v))
    -- 非曲目切换淡变时，启动音量渐变到目标值
    if not bgmFadeState_ then
        bgmFadeState_ = "volume_adjust"
    end
end

-- UI 构建（无 TopBar / BottomNav，全屏游戏风格）

function CreateUI()
    -- 页面容器（全屏，由 Router 管理内容；背景透明，NanoVG 负责绘制）
    pageContainer_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
    }

    -- 初始化路由
    Router.init(pageContainer_)

    -- 路由变化回调
    -- 所有页面均使用 NanoVG 渲染，UI 层保持透明
    local adventurePage = require("pages.adventure.init")
    local homePage = require("pages.home.init")
    local profilePage = require("pages.profile.init")
    Router.onNavigate(function(pageId)
        uiRoot_:SetStyle({ backgroundColor = false })
        pageContainer_:SetStyle({ backgroundColor = false })
        -- 通知各 NanoVG 页面切换活跃状态
        adventurePage.setActive(pageId == "adventure")
        homePage.setActive(pageId == "home")
        profilePage.setActive(pageId == "profile")
        -- 根据页面切换 BGM
        switchBGMForPage(pageId)
    end)

    -- 内容根节点（全屏，无顶栏底栏）
    uiRoot_ = UI.Panel {
        width = "100%",
        height = "100%",
        flexDirection = "column",
        children = {
            pageContainer_,
        },
    }

    -- 转场遮罩
    local transitionOverlay = ScreenTransition.create()

    -- 调试面板（仅 feature-flag 总开关开启时加载）
    local debugPanel = nil
    local soundTestOverlay = nil
    if featureFlags.isMasterEnabled() then
        local DebugPanel = require("shared.components.debug-panel")
        local SoundTestPanel = require("shared.components.sound-test-panel")
        debugPanel = DebugPanel.create()
        soundTestOverlay = SoundTestPanel.create()
    end

    -- 实名认证覆盖层（初始隐藏，健康忠告关闭后按需显示）
    authOverlayNode_ = UI.Panel {
        position = "absolute",
        left = 0, top = 0,
        width = "100%", height = "100%",
    }
    authOverlayNode_:SetVisible(false)

    --- 认证完成后执行防沉迷检查
    local function checkAntiAddictionAfterAuth()
        if not compliance.isEnabled() then return end
        if antiAddiction.isAdult() then return end
        -- 未成年人：立即检查宵禁
        if antiAddiction.isCurfew() then
            if antiAddictionContainer_ then
                antiAddictionContainer_:SetVisible(true)
            end
            AntiAddictionPopup.showCurfew(antiAddictionContainer_, function()
                -- 宵禁弹窗关闭，留在大厅（NanoVG 遮罩层会持续显示）
                if antiAddictionContainer_ then
                    antiAddictionContainer_:SetVisible(false)
                end
                logger.info(MODULE, "antiAddiction", "curfew popup dismissed")
            end)
        end
    end

    --- 认证成功绑定未成年身份证后显示年龄段防沉迷限制提示
    local function showMinorLimitNoticeAfterAuth(onDone)
        if not compliance.isEnabled() then
            if onDone then onDone() end
            return
        end
        if not antiAddictionContainer_ then
            if onDone then onDone() end
            return
        end
        antiAddictionContainer_:SetVisible(true)
        AntiAddictionPopup.showMinorLimitNotice(antiAddictionContainer_, realNameAuth.getAge(), function()
            if antiAddictionContainer_ then
                antiAddictionContainer_:SetVisible(false)
            end
            if onDone then onDone() end
        end)
    end

    --- 显示实名认证弹窗的辅助函数
    local function showAuthOverlay()
        local authUI = RealNameAuthOverlay.create(function(verified, isAdult)
            logger.info(MODULE, "realNameAuth", "verified=" .. tostring(verified) .. ", isAdult=" .. tostring(isAdult))
            -- 隐藏认证覆盖层，释放点击拦截
            authOverlayNode_:SetVisible(false)
            -- 新绑定的未成年身份证先提示年龄段防沉迷限制，再继续现有防沉迷检查
            if verified and not isAdult then
                showMinorLimitNoticeAfterAuth(checkAntiAddictionAfterAuth)
            else
                checkAntiAddictionAfterAuth()
            end
        end)
        authOverlayNode_:RemoveAllChildren()
        authOverlayNode_:AddChild(authUI)
        authOverlayNode_:SetVisible(true)
    end

    -- 实名认证检查（隐私政策同意后调用）
    local function proceedToAuthCheck()
        if not compliance.isEnabled() then return end
        realNameAuth.syncFromCloud(function(verified)
            if not verified then
                showAuthOverlay()
            else
                -- 已认证用户也需检查防沉迷（可能是未成年人重新进入）
                checkAntiAddictionAfterAuth()
            end
        end)
    end

    -- 隐私政策同意容器（首次启动时使用）
    ---@type any
    local privacyContainer_ = UI.Panel {
        position = "absolute",
        left = 0, top = 0,
        width = "100%", height = "100%",
    }
    privacyContainer_:SetVisible(false)

    -- 健康游戏忠告关闭后，外部合规系统接管时跳过游戏内模拟认证流程
    local healthAdvisoryOverlay = HealthAdvisory.create(function()
        if not compliance.isEnabled() then
            return
        end
        -- 忠告关闭后，先从云端同步隐私政策接受状态（WASM 本地文件刷新后丢失）
        PrivacyPolicy.syncFromCloud(function(accepted)
            if not accepted then
                privacyContainer_:SetVisible(true)
                PrivacyPolicy.showConsent(privacyContainer_, function()
                    -- 同意后隐藏容器，继续实名认证流程
                    privacyContainer_:SetVisible(false)
                    proceedToAuthCheck()
                end)
            else
                -- 已同意隐私政策，直接进入认证检查
                proceedToAuthCheck()
            end
        end)
    end)

    -- 防沉迷弹窗容器（位于认证覆盖层之上，默认隐藏避免遮挡下层 UI）
    antiAddictionContainer_ = UI.Panel {
        position = "absolute",
        left = 0, top = 0,
        width = "100%", height = "100%",
    }
    antiAddictionContainer_:SetVisible(false)

    --- 显示防沉迷容器
    local function showAntiAddictionContainer()
        if antiAddictionContainer_ then
            antiAddictionContainer_:SetVisible(true)
        end
    end

    --- 隐藏防沉迷容器
    local function hideAntiAddictionContainer()
        if antiAddictionContainer_ then
            antiAddictionContainer_:SetVisible(false)
        end
    end

    -- 注册防沉迷弹窗回调
    antiAddiction.setOnPopupRequest(function(popupType)
        if not antiAddictionContainer_ then return end
        showAntiAddictionContainer()
        if popupType == "remind_30" then
            AntiAddictionPopup.showReminder(antiAddictionContainer_,
                function() -- onRest: 退出游戏回到大厅
                    hideAntiAddictionContainer()
                    if gameContainer.isRunning() then
                        gameContainer.exit("anti_addiction_rest")
                    end
                end,
                function() -- onContinue: 关闭弹窗继续游戏
                    hideAntiAddictionContainer()
                    logger.info(MODULE, "antiAddiction", "user chose to continue")
                end
            )
        elseif popupType == "force_60" then
            AntiAddictionPopup.showForceExit(antiAddictionContainer_, function()
                hideAntiAddictionContainer()
                -- 已在 onForceExit 回调中退出游戏，此处仅关闭弹窗
                logger.info(MODULE, "antiAddiction", "60min force exit confirmed")
            end)
        elseif popupType == "curfew_exit" then
            AntiAddictionPopup.showCurfew(antiAddictionContainer_, function()
                hideAntiAddictionContainer()
                logger.info(MODULE, "antiAddiction", "curfew exit confirmed")
            end)
        end
    end)

    -- 注册防沉迷强制退出回调
    antiAddiction.setOnForceExit(function(reason)
        if gameContainer.isRunning() then
            gameContainer.exit("anti_addiction_" .. reason)
        end
    end)

    -- 应用根节点（debug 面板按 feature-flag 条件加载）
    local appChildren = {
        uiRoot_,
        transitionOverlay,
    }
    if debugPanel then
        appChildren[#appChildren + 1] = debugPanel
    end
    if soundTestOverlay then
        appChildren[#appChildren + 1] = soundTestOverlay
    end
    appChildren[#appChildren + 1] = healthAdvisoryOverlay
    appChildren[#appChildren + 1] = privacyContainer_
    appChildren[#appChildren + 1] = authOverlayNode_
    appChildren[#appChildren + 1] = antiAddictionContainer_

    local appRoot = UI.Panel {
        width = "100%",
        height = "100%",
        children = appChildren,
    }

    UI.SetRoot(appRoot)
end

--- 显示 F6 测试用未成年人年龄段限制弹窗
local function showNextMinorLimitTestPopup()
    if not compliance.isEnabled() or not antiAddictionContainer_ then return end
    minorLimitTestIndex_ = minorLimitTestIndex_ % #MINOR_LIMIT_TEST_AGES + 1
    local age = MINOR_LIMIT_TEST_AGES[minorLimitTestIndex_]
    antiAddictionContainer_:SetVisible(true)
    AntiAddictionPopup.showMinorLimitNotice(antiAddictionContainer_, age, function()
        if antiAddictionContainer_ then
            antiAddictionContainer_:SetVisible(false)
        end
    end)
    logger.info(MODULE, "minorLimitTest", "F6 popup shown, age=" .. tostring(age))
end

--- 显示 P 键测试用宵禁拦截弹窗
local function showCurfewTestPopup()
    if not compliance.isEnabled() or not antiAddictionContainer_ or not gameContainer.isRunning() then return end
    antiAddictionContainer_:SetVisible(true)
    AntiAddictionPopup.showCurfew(antiAddictionContainer_, function()
        if antiAddictionContainer_ then
            antiAddictionContainer_:SetVisible(false)
        end
        logger.info(MODULE, "curfewTest", "F7 popup dismissed")
    end)
    logger.info(MODULE, "curfewTest", "F7 popup shown")
end

-- 转场动画驱动

---@param eventType string
---@param eventData PostUpdateEventData
function Main_HandlePostUpdate(eventType, eventData)
    local dt = eventData["TimeStep"]:GetFloat()
    if input:GetKeyPress(KEY_F4) then
        antiAddiction.triggerTestForceLockout()
    end
    if input:GetKeyPress(KEY_F6) or input:GetKeyPress(KEY_6) then
        showNextMinorLimitTestPopup()
    end
    if input:GetKeyPress(KEY_P) then
        showCurfewTestPopup()
    end
    ScreenTransition.update(dt)
    updateBGMFade(dt)
    HealthAdvisory.update(dt)
    antiAddiction.update(dt)
end
