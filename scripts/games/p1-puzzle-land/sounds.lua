--- 推箱子 - 音效注册表
--- 共用音效 + 游戏专属音效合并导出，init 传入即完整可用

-- 共用音效（两个游戏共享）
local SHARED = {
    button_click = {
        path = "Sounds/shared/button_click.ogg",
        gain = 0.5,
        throttleMs = 100,
    },
    level_cleared = {
        path = "Sounds/shared/level_cleared.ogg",
        gain = 0.8,
    },
    level_failed = {
        path = "Sounds/shared/level_failed.ogg",
        gain = 0.7,
    },
}

-- 推箱子专属音效
local GAME = {
    wrong_buzzer_soft = {
        path = "audio/sfx/wrong_buzzer_soft.ogg",
        gain = 0.5,
        throttleMs = 150,
    },
    success_fanfare = {
        path = "audio/sfx/success_fanfare.ogg",
        gain = 0.7,
    },
    bubble_pop_cute = {
        path = "audio/sfx/bubble_pop_cute.ogg",
        gain = 0.6,
    },
    level_complete = {
        path = "audio/sfx/level_complete.ogg",
        gain = 0.7,
    },
    bloop_bounce = {
        path = "audio/sfx/bloop_bounce.ogg",
        gain = 0.5,
        throttleMs = 80,
    },
    undo = {
        path = "audio/sfx/bloop_bounce.ogg",
        gain = 0.4,
        throttleMs = 100,
    },
    reset = {
        path = "audio/sfx/bloop_bounce.ogg",
        gain = 0.5,
        throttleMs = 200,
    },
}

-- 合并导出：游戏专属覆盖同名共用
local merged = {}
for k, v in pairs(SHARED) do merged[k] = v end
for k, v in pairs(GAME) do merged[k] = v end
return merged
