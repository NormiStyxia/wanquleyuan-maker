--- 背景管理器（全局单例）
--- 管理游戏背景配置、当前选中状态、解锁/购买、渲染

local Storyline = require("modules.storyline.init")
local PurchasePopup = require("shared.components.purchase-popup")
local logger = require("shared.utils.logger")

local M = {}
local MODULE = "bg-manager"

-- ============================================================================
-- 背景配置表
-- ============================================================================

---@type table[]
local BACKGROUNDS = {
    -- 免费背景
    {
        id = "default",
        name = "暖阳奶油",
        colors = { base = { 255, 248, 238, 255 } },
        themeImage = "image/handdrawn/backgrounds/default.png",
        previewImage = "image/handdrawn/backgrounds/previews/default.png",
        thumbnail = {
            primary = { 255, 248, 238, 255 },
            accent = { 255, 200, 150, 255 },
        },
        unlock = nil,
    },
    {
        id = "sky_blue",
        name = "晴空蔚蓝",
        colors = { base = { 230, 242, 255, 255 } },
        themeImage = "image/handdrawn/backgrounds/sky_blue.png",
        previewImage = "image/handdrawn/backgrounds/previews/sky_blue.png",
        thumbnail = {
            primary = { 230, 242, 255, 255 },
            accent = { 150, 200, 255, 255 },
        },
        unlock = nil,
    },
    {
        id = "mint_green",
        name = "薄荷清风",
        colors = { base = { 235, 250, 240, 255 } },
        themeImage = "image/handdrawn/backgrounds/mint_green.png",
        previewImage = "image/handdrawn/backgrounds/previews/mint_green.png",
        thumbnail = {
            primary = { 235, 250, 240, 255 },
            accent = { 130, 220, 170, 255 },
        },
        unlock = nil,
    },
    -- 主线解锁背景
    {
        id = "sunset_glow",
        name = "夕阳余晖",
        colors = { base = { 255, 235, 220, 255 } },
        themeImage = "image/handdrawn/backgrounds/sunset_glow.png",
        previewImage = "image/handdrawn/backgrounds/previews/sunset_glow.png",
        thumbnail = {
            primary = { 255, 235, 220, 255 },
            accent = { 255, 180, 130, 255 },
        },
        unlock = { type = "story", nodeId = "story-7", label = "通关第7关" },
    },
    {
        id = "lavender",
        name = "薰衣紫梦",
        colors = { base = { 240, 235, 255, 255 } },
        themeImage = "image/handdrawn/backgrounds/lavender.png",
        previewImage = "image/handdrawn/backgrounds/previews/lavender.png",
        thumbnail = {
            primary = { 240, 235, 255, 255 },
            accent = { 180, 160, 255, 255 },
        },
        unlock = { type = "story", nodeId = "story-14", label = "通关第14关" },
    },
    {
        id = "cherry_blossom",
        name = "樱花漫舞",
        colors = { base = { 255, 235, 240, 255 } },
        themeImage = "image/handdrawn/backgrounds/cherry_blossom.png",
        previewImage = "image/handdrawn/backgrounds/previews/cherry_blossom.png",
        thumbnail = {
            primary = { 255, 235, 240, 255 },
            accent = { 255, 160, 180, 255 },
        },
        unlock = { type = "story", nodeId = "story-21", label = "通关第21关" },
    },
    {
        id = "golden_autumn",
        name = "金秋丰收",
        colors = { base = { 255, 242, 215, 255 } },
        themeImage = "image/handdrawn/backgrounds/golden_autumn.png",
        previewImage = "image/handdrawn/backgrounds/previews/golden_autumn.png",
        thumbnail = {
            primary = { 255, 242, 215, 255 },
            accent = { 220, 180, 80, 255 },
        },
        unlock = { type = "story", nodeId = "story-28", label = "通关第28关" },
    },
}

-- ============================================================================
-- 主题背景图缓存
-- ============================================================================

--- 每个上下文单独持有图片；切页或同时绘制弹层不重新解码其他上下文的图片。
local themeImageCache_ = {}

--- 获取或创建主题背景图片句柄（带缓存）
--- 按上下文缓存，离开页面时通过 clearThemeCache(vg) 释放。
---@param vg userdata
---@param path string 资源路径
---@return integer handle  (0 = 加载失败)
local function getThemeImage(vg, path)
    local images = themeImageCache_[vg]
    if not images then
        images = {}
        themeImageCache_[vg] = images
    end
    local cached = images[path]
    if cached then return cached end
    local handle = nvgCreateImage(vg, path, 0)
    if handle and handle > 0 then
        images[path] = handle
    else
        handle = 0
        -- 注意：加载失败不缓存，下一帧会重试（DWP 资源可能尚未下载完成）
    end
    return handle
end

-- ============================================================================
-- 内部状态
-- ============================================================================

--- id -> 配置的快速索引
---@type table<string, table>
local bgById_ = {}
for _, bg in ipairs(BACKGROUNDS) do
    bgById_[bg.id] = bg
end

---@type string 当前选中的背景 ID
local currentId_ = "default"

---@type table<string, boolean> 已购买的背景 ID 集合
local purchasedBgs_ = {}

---@type boolean 云端数据是否已加载
local loaded_ = false

---@type userdata|nil NanoVG context (购买弹窗用)
local vg_ = nil

-- ============================================================================
-- 内部辅助
-- ============================================================================

--- 通过 ID 查找背景配置
---@param bgId string
---@return table|nil
local function findById(bgId)
    return bgById_[bgId]
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 初始化背景管理器
---@param onReady fun()|nil 加载完成回调
function M.init(onReady)
    currentId_ = "default"
    purchasedBgs_ = {}
    loaded_ = false

    if not clientCloud then
        loaded_ = true
        if onReady then onReady() end
        return
    end

    -- 异步加载云端数据
    local pending = 2
    local function checkDone()
        pending = pending - 1
        if pending == 0 then
            loaded_ = true
            logger.info(MODULE, "init", "loaded, current=" .. currentId_)
            if onReady then onReady() end
        end
    end

    clientCloud:Get("bg_selected", {
        ok = function(values)
            local data = values and values["bg_selected"]
            if data and type(data) == "table" and data.bgId and findById(data.bgId) then
                currentId_ = data.bgId
            end
            checkDone()
        end,
        error = function() checkDone() end,
    })

    clientCloud:Get("bg_purchased", {
        ok = function(values)
            local data = values and values["bg_purchased"]
            if data and type(data) == "table" then
                for k, v in pairs(data) do
                    if v == true and findById(k) then
                        purchasedBgs_[k] = true
                    end
                end
            end
            checkDone()
        end,
        error = function() checkDone() end,
    })
end

--- 设置 NanoVG context（购买弹窗需要）
---@param vg userdata
function M.setNvgContext(vg)
    vg_ = vg
end

--- 获取全部背景定义列表
---@return table[]
function M.getAll()
    return BACKGROUNDS
end

--- 获取当前选中的背景配置对象
---@return any
function M.getCurrent()
    return findById(currentId_) or findById("default") or BACKGROUNDS[1]
end

--- 获取当前选中的背景 ID
---@return string
function M.getCurrentId()
    return currentId_
end

--- 选中某个背景，持久化到云端
---@param bgId string
---@return boolean
function M.select(bgId)
    if not findById(bgId) then
        logger.warn(MODULE, "select", "unknown bg id: " .. tostring(bgId))
        return false
    end
    if not M.isUnlocked(bgId) then
        logger.warn(MODULE, "select", "bg '" .. bgId .. "' is locked")
        return false
    end
    if bgId == currentId_ then
        return true
    end
    currentId_ = bgId

    if clientCloud then
        clientCloud:Set("bg_selected", { bgId = bgId }, {
            ok = function()
                logger.info(MODULE, "select", "cloud saved: " .. bgId)
            end,
            error = function(code, reason)
                logger.warn(MODULE, "select", "cloud save failed: " .. tostring(code) .. " " .. tostring(reason))
            end,
        })
    end

    logger.info(MODULE, "select", "changed to: " .. bgId)
    return true
end

--- 判断背景是否已解锁
---@param bgId string
---@return boolean
function M.isUnlocked(bgId)
    local bg = findById(bgId)
    if not bg then return false end

    -- 无解锁条件 = 免费可用
    if not bg.unlock then return true end

    if bg.unlock.type == "story" then
        return Storyline.getNodeState(bg.unlock.nodeId) == "done"
    elseif bg.unlock.type == "purchase" then
        return purchasedBgs_[bgId] == true
    end

    return false
end

--- 是否为购买类型
---@param bgId string
---@return boolean
function M.isPurchaseType(bgId)
    local bg = findById(bgId)
    return bg and bg.unlock and bg.unlock.type == "purchase" or false
end

--- 获取价格，非购买类返回 nil
---@param bgId string
---@return number|nil
function M.getPrice(bgId)
    local bg = findById(bgId)
    if bg and bg.unlock and bg.unlock.type == "purchase" then
        return bg.unlock.price
    end
    return nil
end

--- 获取解锁条件的显示文本
---@param bgId string
---@return string|nil
function M.getUnlockLabel(bgId)
    local bg = findById(bgId)
    if bg and bg.unlock then
        return bg.unlock.label
    end
    return nil
end

--- 购买背景
---@param bgId string
---@param onResult fun(ok: boolean, msg: string)
function M.purchase(bgId, onResult)
    local bg = findById(bgId)
    if not bg or not bg.unlock or bg.unlock.type ~= "purchase" then
        if onResult then onResult(false, "invalid bg") end
        return
    end

    if purchasedBgs_[bgId] then
        if onResult then onResult(false, "already purchased") end
        return
    end

    -- 标记为已购买
    purchasedBgs_[bgId] = true
    currentId_ = bgId

    -- 云端原子写入
    if clientCloud then
        local batch = clientCloud:BatchSet()
        batch:Set("bg_purchased", purchasedBgs_)
        batch:Set("bg_selected", { bgId = bgId })
        batch:Save("bg_purchase_" .. bgId, {
            ok = function()
                logger.info(MODULE, "purchase", bgId .. " saved to cloud")
                if onResult then onResult(true, "ok") end
            end,
            error = function(code, reason)
                logger.warn(MODULE, "purchase", "cloud save failed: " .. tostring(code))
                if onResult then onResult(true, "saved locally") end
            end,
        })
    else
        if onResult then onResult(true, "ok") end
    end
end

--- 按优先级获取背景配置
---@param levelData table|nil 关卡数据（可能包含 background / themeBackground 字段）
---@return table 背景配置对象
function M.getBackgroundForLevel(levelData)
    if levelData then
        -- 优先级 1：关卡主题背景图（themeBackground 图片路径）
        -- 返回一个合成的配置对象，renderBackground 会识别 themeImage 字段
        if levelData.themeBackground then
            local fallback = nil
            if levelData.background then
                fallback = findById(levelData.background)
            end
            fallback = fallback or M.getCurrent()
            return {
                themeImage = levelData.themeBackground,
                -- 保留色值用于图片加载失败时的回退
                colors = fallback.colors,
                decorations = nil, -- 主题背景图不叠加装饰粒子
            }
        end
        -- 优先级 2：关卡指定的装饰背景
        if levelData.background then
            local bg = findById(levelData.background)
            if bg then return bg end
        end
    end
    -- 优先级 3：玩家选择（getCurrent 内部已兜底默认值）
    return M.getCurrent()
end

--- 渲染手绘背景图，未就绪时回退到配置底色。
---@param vg userdata NanoVG context
---@param w number 屏幕宽度
---@param h number 屏幕高度
---@param t number 动画时间
---@param bgConfig table 背景配置对象
function M.renderBackground(vg, w, h, t, bgConfig)
    bgConfig = bgConfig or M.getCurrent()

    -- ====== 主题背景图模式 ======
    if bgConfig.themeImage then
        -- 小预览不解码整张1920高背景；画面内容和实际应用保持一致。
        local path = bgConfig.themeImage
        if bgConfig.previewImage and w <= 216 and h <= 480 then
            path = bgConfig.previewImage
        end
        local handle = getThemeImage(vg, path)
        if handle > 0 then
            -- Cover 模式：保持图片比例铺满屏幕（居中裁剪）
            local imgW, imgH = nvgImageSize(vg, handle)
            local scaleX = w / imgW
            local scaleY = h / imgH
            local scale = math.max(scaleX, scaleY)
            local drawW = imgW * scale
            local drawH = imgH * scale
            local ox = (w - drawW) * 0.5
            local oy = (h - drawH) * 0.5

            local paint = nvgImagePattern(vg, ox, oy, drawW, drawH, 0, handle, 1.0)
            nvgBeginPath(vg)
            nvgRect(vg, 0, 0, w, h)
            nvgFillPaint(vg, paint)
            nvgFill(vg)
            return -- 主题背景图不叠加装饰粒子
        end
        -- 图片加载失败，降级到色值渲染
    end

    -- ====== 默认模式：基底色/渐变 + 装饰粒子 ======

    -- 1. 基底色/渐变
    nvgBeginPath(vg)
    nvgRect(vg, 0, 0, w, h)

    if bgConfig.colors.gradient then
        local bc = bgConfig.colors.base
        local gc = bgConfig.colors.gradient
        local paint = nvgLinearGradient(vg, 0, 0, 0, h,
            nvgRGBA(bc[1], bc[2], bc[3], bc[4]),
            nvgRGBA(gc[1], gc[2], gc[3], gc[4])
        )
        nvgFillPaint(vg, paint)
    else
        local c = bgConfig.colors.base
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], c[4]))
    end
    nvgFill(vg)

    -- 图片尚未就绪时保留纯色底，不把旧几何装饰混回手绘场景。
end

--- 在所属上下文销毁前释放；省略 vg 时释放所有仍有效的上下文缓存。
function M.clearThemeCache(vg)
    local function release(context)
        for _, handle in pairs(themeImageCache_[context] or {}) do
            nvgDeleteImage(context, handle)
        end
        themeImageCache_[context] = nil
    end
    if vg then
        release(vg)
    else
        for context in pairs(themeImageCache_) do release(context) end
    end
end

--- 重置内存中的购买状态和当前选中（清空存档时调用）
--- 此函数只重置内存状态，不发起云端请求
--- 云端 key 由 settings-save.clearAllProgress() 的 cloudKeys 统一删除
function M.resetPurchases()
    purchasedBgs_ = {}
    currentId_ = "default"
    logger.info(MODULE, "resetPurchases", "memory state reset to default")
end

return M
