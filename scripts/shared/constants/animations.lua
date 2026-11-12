-- 动画时长与速度常量（单位：秒）
local M = {}

-- 通用动画时长
M.DURATION_INSTANT    = 0.1     -- 极快（移动、滑动）
M.DURATION_FAST       = 0.2     -- 快（翻转、切换）
M.DURATION_TRANSITION = 0.25    -- 页面过渡
M.DURATION_HOVER      = 0.3     -- 悬停反馈
M.DURATION_NORMAL     = 0.35    -- 标准（出生、弹跳）
M.DURATION_FADE       = 0.6     -- 淡入淡出
M.DURATION_EFFECT     = 0.75    -- 特效持续
M.DURATION_LONG       = 1.2     -- 长特效
M.DURATION_CELEBRATE  = 3.5     -- 庆祝动画

-- 速度
M.DIALOGUE_CHAR_SPEED = 0.04    -- 对话逐字速度（秒/字）
M.BGM_FADE_SPEED      = 1.5     -- BGM 淡入淡出速度
M.FOX_FLOAT_SPEED     = 2.0     -- 狐狸浮动速度

return M
