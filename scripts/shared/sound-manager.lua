--- 共享音效管理器
--- 职责：懒加载音效资源，播放控制（音量/音高/节流），自动回收节点
--- 两个游戏都是纯 NanoVG 无 Scene，此模块内部创建轻量 Scene 仅用于音频节点

local logger = require("shared.utils.logger")

local M = {}
local MODULE = "SoundManager"

-- ============================================================================
-- 内部状态
-- ============================================================================

---@type Scene|nil 内部轻量 Scene（仅用于音频节点）
local scene_ = nil
---@type table<string, table> 音效注册表 { name = { path, gain, throttleMs, pitchRange } }
local registry_ = {}
---@type table<string, Sound|false> 资源缓存（false = 加载失败，不重试）
local soundCache_ = {}
---@type table<string, number> 上次播放时间（秒）
local lastPlay_ = {}
---@type number 主音量 0~1
local masterVolume_ = 1.0
---@type boolean 静音开关
local muted_ = false

-- LRU 淘汰相关
local CACHE_MAX_SIZE = 32      -- 最大缓存条目数
---@type string[] LRU 队列（尾部 = 最近使用，头部 = 最久未用）
local lruOrder_ = {}
---@type table<string, number> path → 在 lruOrder_ 中的索引（加速查找）
local lruIndex_ = {}

--- 将指定 path 标记为最近使用（移到 LRU 队列尾部）
---@param path string
local function lruTouch(path)
    local idx = lruIndex_[path]
    if idx then
        -- 已在队列中，移到尾部
        table.remove(lruOrder_, idx)
        -- 重建移除位置之后的索引
        for i = idx, #lruOrder_ do
            lruIndex_[lruOrder_[i]] = i
        end
    end
    lruOrder_[#lruOrder_ + 1] = path
    lruIndex_[path] = #lruOrder_
end

--- 淘汰最久未使用的缓存条目，直到 count <= CACHE_MAX_SIZE
local function lruEvict()
    while #lruOrder_ > CACHE_MAX_SIZE do
        local evictPath = lruOrder_[1]
        table.remove(lruOrder_, 1)
        lruIndex_[evictPath] = nil
        -- 重建索引
        for i = 1, #lruOrder_ do
            lruIndex_[lruOrder_[i]] = i
        end
        soundCache_[evictPath] = nil
        logger.info(MODULE, "lruEvict", "evicted: " .. evictPath)
    end
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 初始化音效系统
---@param soundTable table 音效注册表
function M.init(soundTable)
    if scene_ then M.shutdown() end
    scene_ = Scene()
    registry_ = soundTable or {}
    soundCache_ = {}
    lastPlay_ = {}
    lruOrder_ = {}
    lruIndex_ = {}
    local count = 0
    for _ in pairs(registry_) do count = count + 1 end
    logger.info(MODULE, "init", "registered " .. count .. " sounds")
end

--- 关闭音效系统，停止所有播放 → 销毁 Scene → 清理缓存
function M.shutdown()
    if not scene_ then return end
    -- 1. 遍历所有活跃 SoundSource，调用 Stop()
    local numChildren = scene_:GetNumChildren(false)
    for i = 0, numChildren - 1 do
        local child = scene_:GetChild(i)
        if child then
            local source = child:GetComponent("SoundSource")
            if source then source:Stop() end
        end
    end
    -- 2. 删除音频 Scene
    scene_:Remove()
    scene_ = nil
    -- 3. 清空缓存和状态
    registry_ = {}
    soundCache_ = {}
    lastPlay_ = {}
    lruOrder_ = {}
    lruIndex_ = {}
    logger.info(MODULE, "shutdown", "cleanup done")
end

--- 播放音效
---@param name string 音效名（注册表中的 key）
---@param opts table|nil { pitch = number, volume = number }
function M.play(name, opts)
    if muted_ or not scene_ then return end

    local entry = registry_[name]
    if not entry then return end

    -- 节流判断（在 pitch/volume 处理之前，被节流直接跳过）
    local now = time.elapsedTime
    local throttle = entry.throttleMs or 0
    if throttle > 0 then
        local last = lastPlay_[name] or 0
        if (now - last) * 1000 < throttle then return end
    end
    lastPlay_[name] = now

    -- 懒加载 + 失败缓存 + LRU 淘汰
    local snd = soundCache_[entry.path]
    if snd == false then return end
    if snd == nil then
        snd = cache:GetResource("Sound", entry.path)
        if not snd then
            logger.warn(MODULE, "play", "failed to load: " .. entry.path .. " (won't retry)")
            soundCache_[entry.path] = false
            return
        end
        soundCache_[entry.path] = snd
        lruTouch(entry.path)
        lruEvict()
    else
        lruTouch(entry.path)
    end

    -- 创建节点 + SoundSource（autoRemoveMode 播放结束后引擎自动删除节点）
    local node = scene_:CreateChild("SFX")
    local source = node:CreateComponent("SoundSource")
    source.autoRemoveMode = REMOVE_NODE

    -- 音量：opts.volume 覆盖注册表 gain
    local gain = entry.gain or 1.0
    if opts and opts.volume then gain = opts.volume end
    source.gain = gain * masterVolume_

    -- 音高：opts.pitch 显式传入时直接使用，不叠加 pitchRange 随机
    local pitch = 1.0
    if opts and opts.pitch then
        pitch = opts.pitch
    elseif entry.pitchRange and entry.pitchRange > 0 then
        pitch = 1.0 + (math.random() * 2 - 1) * entry.pitchRange
    end
    if pitch ~= 1.0 then
        source.frequency = snd.frequency * pitch
    end

    source:Play(snd)
end

--- 获取主音量
---@return number 0~1
function M.getMasterVolume()
    return masterVolume_
end

--- 设置主音量
---@param v number 0~1
function M.setMasterVolume(v)
    masterVolume_ = math.max(0, math.min(1, v))
end

--- 设置静音开关
---@param mute boolean
function M.setMuted(mute)
    muted_ = mute
end

return M
