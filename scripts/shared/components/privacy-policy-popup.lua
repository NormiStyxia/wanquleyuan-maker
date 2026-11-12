--- 隐私政策弹窗组件
--- 提供两种模式:
--- 1. 查看模式(view): 设置页面点击"隐私政策"时打开，仅展示内容
--- 2. 同意模式(consent): 首次启动时弹出，需用户同意后才能继续
local UI = require("urhox-libs/UI")
local PaperUI = require("shared.components.paper-ui")
local Colors = require("shared.constants.colors")
local Layout = require("shared.constants.layout")
local C = require("shared.constants.art").colors
local logger = require("shared.utils.logger")
local uiTap = require("shared.utils.ui-tap")

local M = {}
local MODULE = "privacy-policy"

local SAVE_PATH = "saves/privacy_accepted.json"

-- ============================================================================
-- 隐私政策正文
-- ============================================================================

local POLICY_TITLE = "隐私政策"
local POLICY_SECTIONS = {
    {
        title = "引言",
        body = "欢迎使用《玩趣乐园》（以下简称「本游戏」）。我们深知个人信息对您的重要性，并会尽全力保护您的个人信息安全。本隐私政策将帮助您了解我们收集、使用和保护您个人信息的情况。",
    },
    {
        title = "一、我们收集的信息",
        body = "1. 实名认证信息：姓名和身份证号码，用于未成年人防沉迷系统验证，该信息仅在本地设备存储，不会上传至服务器。\n\n2. 游戏存档数据：关卡进度、分数记录等游戏数据，用于保存您的游戏进度。\n\n3. 设备信息：屏幕分辨率等基本设备参数，用于优化游戏显示效果。\n\n4. 云端存储数据：当您使用云同步功能时，游戏进度会加密上传至云端服务器，以便跨设备同步。",
    },
    {
        title = "二、信息的使用目的",
        body = "我们收集的信息仅用于以下目的：\n\n1. 提供游戏核心功能（存档、排行榜）\n2. 落实国家防沉迷相关规定\n3. 优化游戏体验和性能\n4. 保障账号安全",
    },
    {
        title = "三、信息存储与保护",
        body = "1. 实名认证信息仅存储在您的本地设备中，我们不会上传或分享给任何第三方。\n\n2. 云端存档数据采用加密传输和存储，仅您本人可访问。\n\n3. 我们不会向任何第三方出售、出租或以其他方式提供您的个人信息。",
    },
    {
        title = "四、未成年人保护",
        body = "本游戏严格遵守《关于防止未成年人沉迷网络游戏的通知》等相关法规：\n\n1. 所有用户需完成实名认证\n2. 未成年人仅可在规定时间段内游戏\n3. 未成年人消费受到严格限额控制\n4. 我们鼓励家长参与和监督孩子的游戏行为",
    },
    {
        title = "五、您的权利",
        body = "您有权：\n\n1. 查看和修改您的个人信息\n2. 删除您的游戏数据（通过设置中的「清空存档」功能）\n3. 撤回同意（撤回后将无法继续使用本游戏）",
    },
    {
        title = "六、政策更新",
        body = "我们可能会适时更新本隐私政策。如有重大变更，我们将在游戏内通知您。继续使用本游戏即表示您同意更新后的隐私政策。",
    },
    {
        title = "七、联系我们",
        body = "如您对本隐私政策有任何疑问，可通过 TapTap 游戏页面的反馈渠道与我们联系。",
    },
}

-- ============================================================================
-- 持久化：是否已同意（本地缓存 + clientCloud 云端持久化）
-- WASM 环境下本地文件刷新即丢失，必须依赖云端持久化
-- ============================================================================

local CLOUD_KEY = "privacy_accepted"

--- 内存缓存（避免重复读文件/云端）
local accepted_ = false

--- 从本地文件加载同意状态
local function loadFromFile()
    if not fileSystem:FileExists(SAVE_PATH) then return false end
    local file = File(SAVE_PATH, FILE_READ)
    if not file:IsOpen() then return false end
    local jsonStr = file:ReadString()
    file:Close()
    local ok, data = pcall(cjson.decode, jsonStr)
    if not ok or type(data) ~= "table" then return false end
    return data.accepted == true
end

--- 写入本地文件缓存
local function saveToFile()
    fileSystem:CreateDir("saves")
    local file = File(SAVE_PATH, FILE_WRITE)
    if not file:IsOpen() then
        logger.error(MODULE, "saveToFile", "cannot write file")
        return
    end
    local jsonStr = cjson.encode({ accepted = true, acceptedAt = os.time() })
    file:WriteString(jsonStr)
    file:Close()
end

--- 从云端同步同意状态（异步，启动时调用）
---@param onDone fun(accepted: boolean)|nil
function M.syncFromCloud(onDone)
    -- 先读本地缓存
    accepted_ = loadFromFile()
    if accepted_ then
        logger.info(MODULE, "syncFromCloud", "local cache: accepted")
        if onDone then onDone(true) end
        return
    end

    -- 本地无记录，尝试从云端拉取
    if not clientCloud then
        logger.info(MODULE, "syncFromCloud", "clientCloud not available, skip")
        if onDone then onDone(false) end
        return
    end

    clientCloud:Get(CLOUD_KEY, {
        ok = function(values)
            local cloudData = values[CLOUD_KEY]
            if type(cloudData) == "table" and cloudData.accepted then
                accepted_ = true
                saveToFile()
                logger.info(MODULE, "syncFromCloud", "cloud: accepted")
            else
                logger.info(MODULE, "syncFromCloud", "cloud: not accepted")
            end
            if onDone then onDone(accepted_) end
        end,
        error = function(code, reason)
            logger.warn(MODULE, "syncFromCloud", "failed: " .. tostring(code) .. " " .. tostring(reason))
            if onDone then onDone(accepted_) end
        end,
        timeout = function()
            logger.warn(MODULE, "syncFromCloud", "timeout")
            if onDone then onDone(accepted_) end
        end,
    })
end

--- 检查用户是否已同意隐私政策（内存缓存）
---@return boolean
function M.hasAccepted()
    return accepted_
end

--- 保存同意状态（本地 + 云端）
local function saveAccepted()
    accepted_ = true
    saveToFile()

    -- 同步到云端
    if clientCloud then
        clientCloud:Set(CLOUD_KEY, { accepted = true, acceptedAt = os.time() }, {
            ok = function()
                logger.info(MODULE, "saveAccepted", "cloud synced")
            end,
            error = function(code, reason)
                logger.warn(MODULE, "saveAccepted", "cloud sync failed: " .. tostring(code) .. " " .. tostring(reason))
            end,
        })
    end

    logger.info(MODULE, "saveAccepted", "privacy policy accepted")
end

-- ============================================================================
-- 自适应缩放
-- ============================================================================
local uiScale_ = 1.0

local function refreshUIScale()
    local physW = graphics:GetWidth()
    local physH = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local logW = physW / dpr
    local logH = physH / dpr
    local minDim = math.min(logW, logH)
    uiScale_ = math.min(2.0, math.max(1.0, minDim / 500))
end

local function s(v)
    return math.floor(v * uiScale_)
end

-- ============================================================================
-- 构建隐私政策正文 UI 列表
-- ============================================================================

local function buildPolicySections()
    local children = {}
    for index, section in ipairs(POLICY_SECTIONS) do
        children[#children + 1] = UI.Label {
            text = section.title,
            fontSize = s(15),
            fontColor = Colors.textPrimary,
            fontWeight = "bold",
            marginTop = #children > 0 and s(14) or 0,
            marginBottom = s(4),
        }
        children[#children + 1] = UI.Label {
            id = "privacy-body-" .. index,
            text = section.body,
            width = "100%", whiteSpace = "normal", flexShrink = 0,
            verticalAlign = "top",
            fontSize = s(13),
            fontColor = { 100, 80, 60, 255 },
            lineHeight = 1.6,
        }
    end
    return children
end

-- ============================================================================
-- 查看模式弹窗（设置页入口，仅展示内容）
-- ============================================================================

--- 打开隐私政策查看弹窗
---@param parentContainer any 挂载容器
---@return any overlay
function M.showView(parentContainer)
    refreshUIScale()

    local overlay
    overlay = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 63, 56, 36, 140 },
        justifyContent = "center", alignItems = "center",
        children = {
            UI.Panel {
                id = "privacy-card",
                width = "90%", maxWidth = 520, height = "86%",
                backgroundColor = C.paper,
                borderWidth = 2.5, borderColor = C.ink,
                borderRadius = 12,
                overflow = "hidden",
                flexDirection = "column",
                shadowBlur = 0,
                children = {
                    -- 标题栏（暖色渐变）
                    UI.Panel {
                        width = "100%", height = s(64),
                        backgroundColor = C.paper,
                        borderBottomWidth = 2, borderColor = C.track,
                        flexShrink = 0,
                        justifyContent = "center", alignItems = "center",
                        children = {
                            UI.Label {
                                text = POLICY_TITLE,
                                fontSize = s(22),
                                fontColor = C.ink,
                                fontWeight = "bold",
                            },
                        },
                    },
                    -- 内容滚动区
                    UI.ScrollView {
                        id = "privacy-scroll",
                        width = "100%",
                        flexGrow = 1, flexShrink = 1, flexBasis = 0,
                        padding = s(20), paddingTop = s(16), paddingBottom = s(8),
                        children = buildPolicySections(),
                    },
                    -- 关闭按钮
                    UI.Panel {
                        id = "privacy-footer", flexShrink = 0,
                        width = "100%", padding = s(16), paddingTop = s(8),
                        children = {
                            PaperUI.button {
                                id = "privacy-close", text = "我知道了",
                                variant = "primary",
                                width = "100%", height = s(46),
                                fontSize = s(17), borderRadius = s(24),
                                fontWeight = "bold",
                                backgroundColor = Colors.primary,
                                onClick = function()
                                    uiTap.play()
                                    if overlay then
                                        overlay:Remove()
                                        overlay = nil
                                    end
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    parentContainer:AddChild(overlay)
    return overlay
end

-- ============================================================================
-- 同意模式弹窗（首次启动，必须同意才能继续）
-- ============================================================================

--- 打开隐私政策同意弹窗
---@param parentContainer any 挂载容器
---@param onAccept function 用户点击"同意"后的回调
---@return any overlay
function M.showConsent(parentContainer, onAccept)
    refreshUIScale()

    local overlay
    overlay = UI.Panel {
        position = "absolute",
        top = 0, left = 0, right = 0, bottom = 0,
        backgroundColor = { 63, 56, 36, 150 },
        justifyContent = "center", alignItems = "center",
        children = {
            UI.Panel {
                id = "privacy-card",
                width = "90%", maxWidth = 520, height = "86%",
                backgroundColor = C.paper,
                borderWidth = 2.5, borderColor = C.ink,
                borderRadius = 12,
                overflow = "hidden",
                flexDirection = "column",
                shadowBlur = 0,
                children = {
                    -- 标题栏
                    UI.Panel {
                        width = "100%", height = s(64),
                        backgroundColor = C.paper,
                        borderBottomWidth = 2, borderColor = C.track,
                        flexShrink = 0,
                        justifyContent = "center", alignItems = "center",
                        flexDirection = "column",
                        children = {
                            UI.Label {
                                text = "用户协议与隐私政策",
                                fontSize = s(20),
                                fontColor = C.ink,
                                fontWeight = "bold",
                            },
                        },
                    },
                    -- 提示文字
                    UI.Panel {
                        width = "100%", padding = s(16), paddingBottom = 0,
                        children = {
                            UI.Label {
                                text = "请您仔细阅读以下隐私政策，了解我们如何收集、使用和保护您的个人信息。点击「同意并继续」即表示您已阅读并同意本隐私政策。",
                                width = "100%", whiteSpace = "normal", flexShrink = 0,
                                fontSize = s(13),
                                fontColor = Colors.textSecondary,
                                lineHeight = 1.5,
                            },
                        },
                    },
                    -- 内容滚动区
                    UI.ScrollView {
                        id = "privacy-scroll",
                        width = "100%",
                        flexGrow = 1, flexShrink = 1, flexBasis = 0,
                        padding = s(20), paddingTop = s(12), paddingBottom = s(8),
                        children = buildPolicySections(),
                    },
                    -- 按钮区
                    UI.Panel {
                        id = "privacy-footer", flexShrink = 0,
                        width = "100%", padding = s(16), paddingTop = s(8),
                        flexDirection = "row", gap = s(12),
                        children = {
                            PaperUI.button {
                                id = "privacy-decline", text = "不同意",
                                variant = "outline",
                                flexGrow = 1, flexBasis = 0,
                                height = s(46),
                                fontSize = s(16), borderRadius = s(24),
                                fontWeight = "bold",
                                borderColor = Colors.primaryLight,
                                fontColor = Colors.textSecondary,
                                onClick = function()
                                    uiTap.play()
                                    -- 不同意则无法继续，保持弹窗显示
                                    logger.info(MODULE, "consent", "user declined - staying on popup")
                                end,
                            },
                            PaperUI.button {
                                id = "privacy-accept", text = "同意并继续",
                                variant = "primary",
                                flexGrow = 1, flexBasis = 0,
                                height = s(46),
                                fontSize = s(16), borderRadius = s(24),
                                fontWeight = "bold",
                                backgroundColor = Colors.primary,
                                onClick = function()
                                    uiTap.play()
                                    saveAccepted()
                                    if overlay then
                                        overlay:Remove()
                                        overlay = nil
                                    end
                                    if onAccept then onAccept() end
                                end,
                            },
                        },
                    },
                },
            },
        },
    }

    parentContainer:AddChild(overlay)
    return overlay
end

return M
