--- 共享 UI 点击音效播放工具
--- 音量受 SoundManager 主音量控制

local SoundManager = require("shared.sound-manager")

---@type Scene|nil
local scene_ = nil
---@type Sound|nil
local sound_ = nil

local BASE_GAIN = 0.5

local M = {}

--- 播放 ui_tap 音效
function M.play()
    if not scene_ then
        scene_ = Scene()
        sound_ = cache:GetResource("Sound", "audio/sfx/ui_tap.ogg")
    end
    if scene_ and sound_ then
        local node = scene_:CreateChild("Tap")
        local src = node:CreateComponent("SoundSource")
        src.autoRemoveMode = REMOVE_NODE
        src.gain = BASE_GAIN * SoundManager.getMasterVolume()
        src:Play(sound_)
    end
end

return M
