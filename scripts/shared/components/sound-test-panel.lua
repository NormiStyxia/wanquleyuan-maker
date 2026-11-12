--- 音效测试面板组件
--- 提供所有游戏音效的分组试听功能
--- 通过调试面板的"音效测试"按钮展开
--- 内部使用独立 Scene 播放，不干扰游戏中的 SoundManager

local UI = require("urhox-libs/UI")
local Colors = require("shared.constants.colors")
local Layout = require("shared.constants.layout")
local logger = require("shared.utils.logger")

local M = {}
local MODULE = "sound-test"

-- ============================================================================
-- 音效定义（按分类）
-- ============================================================================

local GROUPS = {
    {
        label = "共用",
        color = { 76, 175, 80, 255 },
        sounds = {
            { name = "button_click",  path = "Sounds/shared/button_click.ogg" },
            { name = "level_cleared", path = "Sounds/shared/level_cleared.ogg" },
            { name = "level_failed",  path = "Sounds/shared/level_failed.ogg" },
        },
    },

    {
        label = "儿童休闲",
        color = { 255, 152, 0, 255 },
        sounds = {
            { name = "bubble_pop_cute",   path = "audio/sfx/bubble_pop_cute.ogg" },
            { name = "bubble_float",      path = "audio/sfx/bubble_float.ogg" },
            { name = "button_tap_cute",   path = "audio/sfx/button_tap_cute.ogg" },
            { name = "correct_chime",     path = "audio/sfx/correct_chime.ogg" },
            { name = "wrong_buzzer_soft", path = "audio/sfx/wrong_buzzer_soft.ogg" },
            { name = "star_collect_cute", path = "audio/sfx/star_collect_cute.ogg" },
            { name = "bounce_boing",      path = "audio/sfx/bounce_boing.ogg" },
            { name = "slide_whoosh",      path = "audio/sfx/slide_whoosh.ogg" },
            { name = "success_fanfare",   path = "audio/sfx/success_fanfare.ogg" },
            { name = "hint_twinkle",      path = "audio/sfx/hint_twinkle.ogg" },
        },
    },
    {
        label = "气泡1",
        color = { 33, 150, 243, 255 },
        sounds = {
            { name = "pop_sparkle",   path = "audio/sfx/pop_sparkle.ogg" },
            { name = "ding_cheerful", path = "audio/sfx/ding_cheerful.ogg" },
            { name = "plop_soft",     path = "audio/sfx/plop_soft.ogg" },
            { name = "twinkle_match", path = "audio/sfx/twinkle_match.ogg" },
            { name = "whoosh_cute",   path = "audio/sfx/whoosh_cute.ogg" },
            { name = "bloop_bounce",  path = "audio/sfx/bloop_bounce.ogg" },
        },
    },
    {
        label = "背景音乐",
        color = { 156, 39, 176, 255 },
        isBgm = true,
        sounds = {
            { name = "欢乐益智", path = "audio/bgm/bgm_happy_puzzle.ogg" },
            { name = "温柔梦境", path = "audio/bgm/bgm_gentle_dream.ogg" },
            { name = "活力乐园", path = "audio/bgm/bgm_active_park.ogg" },
        },
    },
    {
        label = "未使用/预留",
        color = { 158, 158, 158, 255 },
        sounds = {
            { name = "correct_answer", path = "audio/sfx/correct_answer.ogg" },
            { name = "level_complete", path = "audio/sfx/level_complete.ogg" },
            { name = "ui_tap",         path = "audio/sfx/ui_tap.ogg" },
        },
    },
}

-- ============================================================================
-- 内部状态
-- ============================================================================

---@type Scene|nil 独立 Scene（仅用于测试播放）
local scene_ = nil
---@type any 根容器节点
local rootRef_ = nil
---@type any 浮层节点
local overlay_ = nil
---@type boolean
local visible_ = false

-- ============================================================================
-- 内部音频播放（独立于 SoundManager，不干扰游戏音效）
-- ============================================================================

local function playSound(path)
    if not scene_ then scene_ = Scene() end
    local snd = cache:GetResource("Sound", path)
    if not snd then
        logger.warn(MODULE, "play", "not found: " .. path)
        return
    end
    local node = scene_:CreateChild("TestSFX")
    local source = node:CreateComponent("SoundSource")
    source.autoRemoveMode = REMOVE_NODE
    source.gain = 0.8
    source:Play(snd)
end

---@type Node|nil 当前正在播放的 BGM 节点
local bgmNode_ = nil
---@type string|nil 当前播放的 BGM 路径
local bgmPath_ = nil

local function stopAll()
    if not scene_ then return end
    local n = scene_:GetNumChildren(false)
    for i = 0, n - 1 do
        local child = scene_:GetChild(i)
        if child then
            local src = child:GetComponent("SoundSource")
            if src then src:Stop() end
        end
    end
    bgmNode_ = nil
    bgmPath_ = nil
end

--- 播放 BGM（循环，同时只播一首）
local function playBgm(path)
    if not scene_ then scene_ = Scene() end
    -- 如果正在播同一首，停止
    if bgmPath_ == path and bgmNode_ then
        local src = bgmNode_:GetComponent("SoundSource")
        if src then src:Stop() end
        bgmNode_ = nil
        bgmPath_ = nil
        return
    end
    -- 停止上一首
    if bgmNode_ then
        local src = bgmNode_:GetComponent("SoundSource")
        if src then src:Stop() end
        bgmNode_:Remove()
        bgmNode_ = nil
    end
    local snd = cache:GetResource("Sound", path)
    if not snd then
        logger.warn(MODULE, "playBgm", "not found: " .. path)
        return
    end
    snd.looped = true
    local node = scene_:CreateChild("TestBGM")
    local source = node:CreateComponent("SoundSource")
    source.gain = 0.5
    source:Play(snd)
    bgmNode_ = node
    bgmPath_ = path
end

-- ============================================================================
-- UI 构建
-- ============================================================================

--- 构建单条音效行
---@param sndDef { name: string, path: string }
---@param isBgm boolean|nil
---@return any UI 节点
local function buildSoundRow(sndDef, isBgm)
    return UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        height = 34,
        paddingLeft = 4,
        paddingRight = 4,
        children = {
            UI.Button {
                text = isBgm and "♫" or "▶",
                width = 30,
                height = 26,
                fontSize = 12,
                borderRadius = 6,
                variant = isBgm and "outlined" or "primary",
                onClick = function()
                    if isBgm then
                        playBgm(sndDef.path)
                    else
                        playSound(sndDef.path)
                    end
                end,
            },
            UI.Label {
                text = sndDef.name,
                fontSize = 12,
                fontColor = { 50, 50, 60, 255 },
                marginLeft = 8,
            },
        },
    }
end

--- 构建完整浮层
---@return any UI 节点
local function buildOverlay()
    -- 滚动区内容
    local contentChildren = {}
    for _, group in ipairs(GROUPS) do
        -- 分组标题
        contentChildren[#contentChildren + 1] = UI.Panel {
            width = "100%",
            height = 28,
            backgroundColor = group.color,
            borderRadius = 6,
            justifyContent = "center",
            paddingLeft = 8,
            marginTop = 6,
            marginBottom = 2,
            children = {
                UI.Label {
                    text = group.label .. "  (" .. #group.sounds .. ")",
                    fontSize = 12,
                    fontColor = { 255, 255, 255, 255 },
                    fontWeight = "bold",
                },
            },
        }
        -- 音效行
        for _, snd in ipairs(group.sounds) do
            contentChildren[#contentChildren + 1] = buildSoundRow(snd, group.isBgm)
        end
    end

    -- 标题栏
    local titleBar = UI.Panel {
        width = "100%",
        flexDirection = "row",
        alignItems = "center",
        justifyContent = "space-between",
        children = {
            UI.Label {
                text = "音效测试 (31)",
                fontSize = 15,
                fontColor = Colors.textPrimary,
                fontWeight = "bold",
            },
            UI.Button {
                text = "✕",
                width = 28,
                height = 28,
                fontSize = 14,
                borderRadius = 14,
                variant = "text",
                onClick = function()
                    M.hide()
                end,
            },
        },
    }

    -- 分割线
    local divider = UI.Panel {
        width = "100%",
        height = 1,
        backgroundColor = Colors.divider,
        marginTop = 6,
        marginBottom = 2,
    }

    -- 可滚动内容区
    local scrollPanel = UI.Panel {
        width = "100%",
        flexDirection = "column",
        flexShrink = 1,
        overflow = "scroll",
        children = contentChildren,
    }

    -- 底部"停止全部"按钮
    local stopBtn = UI.Button {
        text = "停止全部",
        width = "100%",
        height = 30,
        fontSize = 12,
        borderRadius = 8,
        variant = "outlined",
        marginTop = 8,
        onClick = function()
            stopAll()
        end,
    }

    -- 卡片
    local card = UI.Panel {
        width = 260,
        maxHeight = "80%",
        backgroundColor = { 255, 255, 255, 250 },
        borderRadius = Layout.RADIUS_BUTTON_SM,
        padding = 12,
        flexDirection = "column",
        shadowBlur = Layout.SHADOW_MD,
        shadowColor = { 0, 0, 0, 50 },
        shadowOffsetY = 4,
        children = {
            titleBar,
            divider,
            scrollPanel,
            stopBtn,
        },
    }

    -- 全屏遮罩
    return UI.Panel {
        position = "absolute",
        top = 0,
        left = 0,
        right = 0,
        bottom = 0,
        backgroundColor = { 0, 0, 0, 120 },
        justifyContent = "center",
        alignItems = "center",
        children = { card },
    }
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 创建音效测试面板（返回 UI 节点，需添加到根层级）
---@return any UI 节点
function M.create()
    -- 初始隐藏：宽高为 0，不拦截任何点击
    rootRef_ = UI.Panel {
        position = "absolute",
        width = 0,
        height = 0,
    }
    return rootRef_
end

--- 显示面板
function M.show()
    if visible_ then return end
    visible_ = true
    scene_ = Scene()
    overlay_ = buildOverlay()
    -- 展开为全屏
    rootRef_:SetStyle({
        top = 0, left = 0,
        width = "100%", height = "100%",
    })
    rootRef_:AddChild(overlay_)
    logger.info(MODULE, "show", "opened")
end

--- 隐藏面板
function M.hide()
    if not visible_ then return end
    visible_ = false
    stopAll()
    if overlay_ and rootRef_ then
        rootRef_:RemoveChild(overlay_)
        overlay_ = nil
    end
    if scene_ then
        scene_:Remove()
        scene_ = nil
    end
    -- 收回为 0 尺寸，不拦截点击
    rootRef_:SetStyle({
        width = 0, height = 0,
    })
    logger.info(MODULE, "hide", "closed")
end

--- 切换显示/隐藏
function M.toggle()
    if visible_ then M.hide() else M.show() end
end

--- 是否可见
---@return boolean
function M.isVisible()
    return visible_
end

--- 销毁
function M.destroy()
    M.hide()
    rootRef_ = nil
end

return M
