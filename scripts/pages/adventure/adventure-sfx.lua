--- 冒险页专用音效播放器
--- 轻量级独立 Scene，播放主线模式的 UI/对话/互动音效
--- 音量受 SoundManager 主音量控制

local SoundManager = require("shared.sound-manager")

local M = {}

---@type Scene|nil
local scene_ = nil

--- 音效注册表 { name = { path, gain, throttleMs, pitchRange } }
local SOUNDS = {
    -- 对话系统
    dialogue_tick     = { path = "audio/sfx/dialogue_tick.ogg",     gain = 0.25, throttleMs = 60,  pitchRange = 0.08 },
    dialogue_advance  = { path = "audio/sfx/dialogue_advance.ogg",  gain = 0.5,  throttleMs = 200, pitchRange = 0 },
    dialogue_complete = { path = "audio/sfx/dialogue_complete.ogg", gain = 0.5,  throttleMs = 0,   pitchRange = 0 },

    -- 角色语音（动物叫声，对话时间歇播放）
    chat_fox     = { path = "audio/sfx/chat_huohuo.ogg",   gain = 0.35, throttleMs = 400, pitchRange = 0.06 },
    chat_owl     = { path = "audio/sfx/chat_huihui.ogg",   gain = 0.35, throttleMs = 400, pitchRange = 0.06 },
    chat_cat     = { path = "audio/sfx/chat_paopao.ogg",   gain = 0.35, throttleMs = 400, pitchRange = 0.06 },
    chat_rabbit  = { path = "audio/sfx/chat_tangtang.ogg", gain = 0.35, throttleMs = 400, pitchRange = 0.06 },
    chat_raccoon = { path = "audio/sfx/chat_doudou.ogg",   gain = 0.35, throttleMs = 400, pitchRange = 0.06 },

    -- 冒险地图
    node_unlock         = { path = "audio/sfx/node_unlock.ogg",         gain = 0.55, throttleMs = 500, pitchRange = 0 },
    node_locked         = { path = "audio/sfx/node_locked.ogg",         gain = 0.4,  throttleMs = 300, pitchRange = 0 },
    page_whoosh         = { path = "audio/sfx/page_whoosh.ogg",         gain = 0.4,  throttleMs = 200, pitchRange = 0 },
    celebration_fanfare = { path = "audio/sfx/celebration_fanfare.ogg", gain = 0.6,  throttleMs = 0,   pitchRange = 0 },

    -- 趣味小知识卡片
    fun_fact_popup   = { path = "audio/sfx/fun_fact_popup.ogg",   gain = 0.45, throttleMs = 300, pitchRange = 0 },
    fun_fact_dismiss = { path = "audio/sfx/fun_fact_dismiss.ogg", gain = 0.4,  throttleMs = 200, pitchRange = 0 },

    -- 狐狸立绘气泡
    fox_praise_pop = { path = "audio/sfx/fox_praise_pop.ogg", gain = 0.45, throttleMs = 500, pitchRange = 0 },
    fox_chat_pop   = { path = "audio/sfx/fox_chat_pop.ogg",   gain = 0.4,  throttleMs = 300, pitchRange = 0 },
}

---@type table<string, Sound|false> 资源缓存
local cache_ = {}
---@type table<string, number> 上次播放时间
local lastPlay_ = {}

--- 播放音效
---@param name string 音效名
function M.play(name)
    local entry = SOUNDS[name]
    if not entry then return end

    -- 懒创建 Scene
    if not scene_ then
        scene_ = Scene()
    end

    -- 节流
    local now = time.elapsedTime
    if entry.throttleMs > 0 then
        local last = lastPlay_[name] or 0
        if (now - last) * 1000 < entry.throttleMs then return end
    end
    lastPlay_[name] = now

    -- 懒加载音效
    local snd = cache_[entry.path]
    if snd == false then return end
    if snd == nil then
        snd = cache:GetResource("Sound", entry.path)
        if not snd then
            cache_[entry.path] = false
            return
        end
        cache_[entry.path] = snd
    end

    -- 播放
    local node = scene_:CreateChild("SFX")
    local src = node:CreateComponent("SoundSource")
    src.autoRemoveMode = REMOVE_NODE
    src.gain = entry.gain * SoundManager.getMasterVolume()

    -- 音高随机
    if entry.pitchRange and entry.pitchRange > 0 then
        local pitch = 1.0 + (math.random() * 2 - 1) * entry.pitchRange
        src.frequency = snd.frequency * pitch
    end

    src:Play(snd)
end

--- 清理（页面销毁时调用）
function M.cleanup()
    if scene_ then
        scene_:Remove()
        scene_ = nil
    end
    cache_ = {}
    lastPlay_ = {}
end

return M
