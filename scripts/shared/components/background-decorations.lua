--- 公共背景装饰组件：浮动的卡通元素（circle/star/heart/diamond）
--- 提取自 home/adventure/profile 页面的重复装饰代码
local M = {}

-- ============================================================================
-- 预设装饰配置（各页面可直接引用或自定义）
-- ============================================================================

--- 首页装饰配置（暖色系，20 个元素）
M.PRESET_HOME = {
    { kind = "circle",  rx = 0.06, ry0 = 0.12, size = 66, color = { 255, 200, 100, 56 }, drift = 24, sway = 7,  phase = 0   },
    { kind = "star",    rx = 0.12, ry0 = 0.42, size = 60, color = { 255, 210, 80, 62 },  drift = 28, sway = 9,  phase = 0.5 },
    { kind = "heart",   rx = 0.10, ry0 = 0.68, size = 52, color = { 255, 160, 140, 50 }, drift = 22, sway = 6,  phase = 1.0 },
    { kind = "circle",  rx = 0.16, ry0 = 0.88, size = 58, color = { 180, 140, 255, 46 }, drift = 18, sway = 8,  phase = 3.1 },
    { kind = "diamond", rx = 0.04, ry0 = 0.55, size = 48, color = { 255, 200, 150, 44 }, drift = 26, sway = 5,  phase = 2.2 },
    { kind = "circle",  rx = 0.92, ry0 = 0.20, size = 56, color = { 255, 140, 170, 54 }, drift = 20, sway = 6,  phase = 1.2 },
    { kind = "star",    rx = 0.86, ry0 = 0.38, size = 54, color = { 255, 180, 100, 56 }, drift = 22, sway = 6,  phase = 2.0 },
    { kind = "heart",   rx = 0.90, ry0 = 0.60, size = 56, color = { 255, 130, 160, 56 }, drift = 20, sway = 8,  phase = 2.5 },
    { kind = "circle",  rx = 0.84, ry0 = 0.78, size = 72, color = { 100, 210, 180, 44 }, drift = 16, sway = 7,  phase = 1.8 },
    { kind = "diamond", rx = 0.96, ry0 = 0.45, size = 50, color = { 200, 170, 255, 46 }, drift = 24, sway = 5,  phase = 3.8 },
    { kind = "star",    rx = 0.30, ry0 = 0.18, size = 50, color = { 255, 170, 120, 54 }, drift = 26, sway = 5,  phase = 0.8 },
    { kind = "circle",  rx = 0.25, ry0 = 0.50, size = 62, color = { 130, 200, 255, 46 }, drift = 19, sway = 7,  phase = 4.0 },
    { kind = "diamond", rx = 0.35, ry0 = 0.80, size = 48, color = { 255, 220, 130, 44 }, drift = 23, sway = 4,  phase = 0.3 },
    { kind = "star",    rx = 0.70, ry0 = 0.15, size = 54, color = { 200, 180, 255, 54 }, drift = 25, sway = 6,  phase = 2.8 },
    { kind = "heart",   rx = 0.60, ry0 = 0.48, size = 50, color = { 255, 180, 180, 46 }, drift = 21, sway = 7,  phase = 1.5 },
    { kind = "circle",  rx = 0.75, ry0 = 0.85, size = 60, color = { 180, 220, 140, 44 }, drift = 17, sway = 6,  phase = 3.5 },
    { kind = "star",    rx = 0.48, ry0 = 0.30, size = 52, color = { 255, 190, 90, 50 },  drift = 27, sway = 5,  phase = 0.6 },
    { kind = "circle",  rx = 0.55, ry0 = 0.70, size = 64, color = { 140, 180, 255, 40 }, drift = 18, sway = 8,  phase = 3.3 },
    { kind = "heart",   rx = 0.42, ry0 = 0.92, size = 48, color = { 255, 150, 170, 46 }, drift = 22, sway = 6,  phase = 4.2 },
    { kind = "diamond", rx = 0.52, ry0 = 0.05, size = 54, color = { 220, 200, 130, 44 }, drift = 25, sway = 4,  phase = 1.6 },
}

--- 冒险地图装饰配置（稍大元素，12 个）
M.PRESET_ADVENTURE = {
    { kind = "circle",  rx = 0.08, ry0 = 0.15, size = 100, color = { 255, 200, 120, 50 }, drift = 20, sway = 6,  phase = 0   },
    { kind = "star",    rx = 0.14, ry0 = 0.45, size = 90,  color = { 255, 210, 90, 54 },  drift = 24, sway = 7,  phase = 0.5 },
    { kind = "heart",   rx = 0.10, ry0 = 0.75, size = 80,  color = { 255, 170, 150, 44 }, drift = 18, sway = 5,  phase = 1.0 },
    { kind = "diamond", rx = 0.06, ry0 = 0.55, size = 74,  color = { 255, 200, 160, 38 }, drift = 22, sway = 4,  phase = 2.2 },
    { kind = "circle",  rx = 0.90, ry0 = 0.22, size = 88,  color = { 255, 160, 180, 46 }, drift = 17, sway = 5,  phase = 1.2 },
    { kind = "star",    rx = 0.88, ry0 = 0.55, size = 84,  color = { 255, 190, 110, 50 }, drift = 20, sway = 5,  phase = 2.0 },
    { kind = "heart",   rx = 0.92, ry0 = 0.80, size = 86,  color = { 255, 140, 170, 46 }, drift = 16, sway = 6,  phase = 2.5 },
    { kind = "diamond", rx = 0.94, ry0 = 0.40, size = 76,  color = { 210, 180, 255, 40 }, drift = 21, sway = 4,  phase = 3.8 },
    { kind = "star",    rx = 0.45, ry0 = 0.28, size = 78,  color = { 255, 195, 100, 44 }, drift = 23, sway = 4,  phase = 0.6 },
    { kind = "circle",  rx = 0.55, ry0 = 0.65, size = 96,  color = { 150, 190, 255, 38 }, drift = 15, sway = 7,  phase = 3.3 },
    { kind = "heart",   rx = 0.35, ry0 = 0.90, size = 72,  color = { 255, 160, 180, 40 }, drift = 19, sway = 5,  phase = 4.2 },
    { kind = "diamond", rx = 0.65, ry0 = 0.10, size = 80,  color = { 230, 210, 140, 38 }, drift = 24, sway = 3,  phase = 1.6 },
}

--- 晴空蔚蓝装饰配置（蓝白系，圆形+云朵，12 个）
M.PRESET_SKY = {
    { kind = "cloud",   rx = 0.08, ry0 = 0.10, size = 80, color = { 200, 225, 255, 44 }, drift = 12, sway = 6,  phase = 0   },
    { kind = "circle",  rx = 0.15, ry0 = 0.35, size = 54, color = { 170, 210, 255, 40 }, drift = 18, sway = 7,  phase = 0.8 },
    { kind = "cloud",   rx = 0.06, ry0 = 0.60, size = 70, color = { 210, 235, 255, 38 }, drift = 14, sway = 5,  phase = 1.5 },
    { kind = "circle",  rx = 0.12, ry0 = 0.85, size = 48, color = { 180, 220, 255, 36 }, drift = 20, sway = 6,  phase = 2.3 },
    { kind = "cloud",   rx = 0.90, ry0 = 0.18, size = 74, color = { 190, 220, 255, 42 }, drift = 13, sway = 7,  phase = 0.5 },
    { kind = "circle",  rx = 0.88, ry0 = 0.45, size = 56, color = { 160, 200, 255, 38 }, drift = 16, sway = 5,  phase = 1.2 },
    { kind = "cloud",   rx = 0.92, ry0 = 0.70, size = 66, color = { 220, 240, 255, 36 }, drift = 15, sway = 6,  phase = 2.8 },
    { kind = "circle",  rx = 0.85, ry0 = 0.90, size = 50, color = { 175, 215, 255, 34 }, drift = 19, sway = 4,  phase = 3.5 },
    { kind = "cloud",   rx = 0.45, ry0 = 0.25, size = 60, color = { 200, 230, 255, 36 }, drift = 11, sway = 8,  phase = 1.0 },
    { kind = "circle",  rx = 0.55, ry0 = 0.55, size = 52, color = { 185, 215, 255, 40 }, drift = 17, sway = 5,  phase = 3.0 },
    { kind = "cloud",   rx = 0.35, ry0 = 0.78, size = 64, color = { 210, 230, 255, 34 }, drift = 13, sway = 6,  phase = 4.0 },
    { kind = "circle",  rx = 0.65, ry0 = 0.08, size = 46, color = { 195, 225, 255, 38 }, drift = 21, sway = 4,  phase = 0.3 },
}

--- 薄荷清风装饰配置（绿色系，圆形+叶片，12 个）
M.PRESET_MINT = {
    { kind = "leaf",    rx = 0.07, ry0 = 0.12, size = 56, color = { 130, 210, 160, 44 }, drift = 20, sway = 8,  phase = 0   },
    { kind = "circle",  rx = 0.14, ry0 = 0.40, size = 50, color = { 150, 220, 180, 38 }, drift = 16, sway = 6,  phase = 0.7 },
    { kind = "leaf",    rx = 0.10, ry0 = 0.65, size = 52, color = { 120, 200, 150, 40 }, drift = 22, sway = 7,  phase = 1.4 },
    { kind = "circle",  rx = 0.05, ry0 = 0.88, size = 60, color = { 140, 215, 170, 36 }, drift = 14, sway = 5,  phase = 2.1 },
    { kind = "leaf",    rx = 0.91, ry0 = 0.20, size = 58, color = { 110, 195, 145, 42 }, drift = 18, sway = 6,  phase = 0.5 },
    { kind = "circle",  rx = 0.87, ry0 = 0.50, size = 46, color = { 160, 225, 190, 36 }, drift = 20, sway = 7,  phase = 1.8 },
    { kind = "leaf",    rx = 0.93, ry0 = 0.75, size = 54, color = { 125, 205, 155, 38 }, drift = 16, sway = 5,  phase = 2.6 },
    { kind = "circle",  rx = 0.84, ry0 = 0.92, size = 48, color = { 145, 220, 175, 34 }, drift = 22, sway = 4,  phase = 3.3 },
    { kind = "leaf",    rx = 0.40, ry0 = 0.18, size = 50, color = { 135, 210, 165, 40 }, drift = 19, sway = 8,  phase = 0.9 },
    { kind = "circle",  rx = 0.55, ry0 = 0.58, size = 54, color = { 155, 225, 185, 38 }, drift = 15, sway = 6,  phase = 3.0 },
    { kind = "leaf",    rx = 0.30, ry0 = 0.80, size = 48, color = { 115, 195, 140, 36 }, drift = 21, sway = 5,  phase = 3.8 },
    { kind = "circle",  rx = 0.68, ry0 = 0.05, size = 44, color = { 140, 210, 170, 34 }, drift = 23, sway = 4,  phase = 0.2 },
}

--- 夕阳余晖装饰配置（橙红系，圆形+星星，12 个）
M.PRESET_SUNSET = {
    { kind = "circle",  rx = 0.08, ry0 = 0.14, size = 62, color = { 255, 180, 120, 50 }, drift = 18, sway = 6,  phase = 0   },
    { kind = "star",    rx = 0.13, ry0 = 0.42, size = 54, color = { 255, 160, 100, 46 }, drift = 22, sway = 7,  phase = 0.6 },
    { kind = "circle",  rx = 0.06, ry0 = 0.68, size = 58, color = { 255, 190, 130, 44 }, drift = 16, sway = 5,  phase = 1.2 },
    { kind = "star",    rx = 0.11, ry0 = 0.90, size = 50, color = { 255, 150, 90, 42 },  drift = 24, sway = 6,  phase = 2.0 },
    { kind = "circle",  rx = 0.92, ry0 = 0.20, size = 56, color = { 255, 170, 110, 48 }, drift = 15, sway = 5,  phase = 0.4 },
    { kind = "star",    rx = 0.88, ry0 = 0.50, size = 52, color = { 255, 145, 85, 44 },  drift = 20, sway = 6,  phase = 1.5 },
    { kind = "circle",  rx = 0.90, ry0 = 0.76, size = 60, color = { 255, 185, 125, 42 }, drift = 17, sway = 7,  phase = 2.5 },
    { kind = "star",    rx = 0.86, ry0 = 0.38, size = 48, color = { 255, 155, 95, 40 },  drift = 23, sway = 4,  phase = 3.2 },
    { kind = "circle",  rx = 0.45, ry0 = 0.28, size = 54, color = { 255, 175, 115, 46 }, drift = 19, sway = 8,  phase = 0.8 },
    { kind = "star",    rx = 0.55, ry0 = 0.62, size = 50, color = { 255, 165, 105, 42 }, drift = 21, sway = 5,  phase = 3.0 },
    { kind = "circle",  rx = 0.35, ry0 = 0.85, size = 46, color = { 255, 195, 140, 38 }, drift = 14, sway = 6,  phase = 3.8 },
    { kind = "star",    rx = 0.65, ry0 = 0.10, size = 56, color = { 255, 140, 80, 44 },  drift = 25, sway = 4,  phase = 0.2 },
}

--- 薰衣紫梦装饰配置（紫色系，心形+钻石，12 个）
M.PRESET_LAVENDER = {
    { kind = "heart",   rx = 0.09, ry0 = 0.15, size = 54, color = { 200, 170, 255, 44 }, drift = 18, sway = 7,  phase = 0   },
    { kind = "diamond", rx = 0.14, ry0 = 0.40, size = 48, color = { 180, 150, 240, 40 }, drift = 22, sway = 5,  phase = 0.8 },
    { kind = "heart",   rx = 0.06, ry0 = 0.65, size = 50, color = { 210, 180, 255, 38 }, drift = 16, sway = 6,  phase = 1.5 },
    { kind = "diamond", rx = 0.12, ry0 = 0.88, size = 46, color = { 190, 160, 245, 36 }, drift = 20, sway = 4,  phase = 2.2 },
    { kind = "heart",   rx = 0.91, ry0 = 0.22, size = 52, color = { 195, 165, 250, 42 }, drift = 17, sway = 6,  phase = 0.5 },
    { kind = "diamond", rx = 0.88, ry0 = 0.48, size = 44, color = { 175, 145, 235, 38 }, drift = 23, sway = 5,  phase = 1.3 },
    { kind = "heart",   rx = 0.93, ry0 = 0.72, size = 56, color = { 215, 185, 255, 36 }, drift = 15, sway = 7,  phase = 2.8 },
    { kind = "diamond", rx = 0.85, ry0 = 0.35, size = 42, color = { 185, 155, 240, 34 }, drift = 21, sway = 4,  phase = 3.5 },
    { kind = "heart",   rx = 0.45, ry0 = 0.18, size = 48, color = { 205, 175, 255, 40 }, drift = 19, sway = 8,  phase = 0.3 },
    { kind = "diamond", rx = 0.55, ry0 = 0.58, size = 50, color = { 170, 140, 230, 36 }, drift = 24, sway = 5,  phase = 3.0 },
    { kind = "heart",   rx = 0.35, ry0 = 0.82, size = 46, color = { 220, 190, 255, 34 }, drift = 14, sway = 6,  phase = 4.0 },
    { kind = "diamond", rx = 0.65, ry0 = 0.08, size = 52, color = { 195, 165, 245, 38 }, drift = 25, sway = 3,  phase = 0.6 },
}

--- 樱花漫舞装饰配置（粉色系，心形+花瓣，12 个）
M.PRESET_CHERRY = {
    { kind = "heart",   rx = 0.08, ry0 = 0.12, size = 52, color = { 255, 180, 200, 46 }, drift = 20, sway = 7,  phase = 0   },
    { kind = "petal",   rx = 0.14, ry0 = 0.38, size = 48, color = { 255, 170, 190, 42 }, drift = 24, sway = 8,  phase = 0.7 },
    { kind = "heart",   rx = 0.06, ry0 = 0.62, size = 50, color = { 255, 190, 210, 40 }, drift = 16, sway = 6,  phase = 1.4 },
    { kind = "petal",   rx = 0.11, ry0 = 0.85, size = 44, color = { 255, 160, 185, 38 }, drift = 22, sway = 5,  phase = 2.1 },
    { kind = "heart",   rx = 0.92, ry0 = 0.20, size = 54, color = { 255, 185, 205, 44 }, drift = 18, sway = 6,  phase = 0.4 },
    { kind = "petal",   rx = 0.87, ry0 = 0.48, size = 46, color = { 255, 165, 188, 40 }, drift = 20, sway = 7,  phase = 1.2 },
    { kind = "heart",   rx = 0.90, ry0 = 0.74, size = 56, color = { 255, 195, 215, 38 }, drift = 15, sway = 5,  phase = 2.5 },
    { kind = "petal",   rx = 0.85, ry0 = 0.92, size = 42, color = { 255, 155, 180, 36 }, drift = 23, sway = 6,  phase = 3.2 },
    { kind = "heart",   rx = 0.42, ry0 = 0.25, size = 48, color = { 255, 175, 198, 42 }, drift = 19, sway = 8,  phase = 0.9 },
    { kind = "petal",   rx = 0.58, ry0 = 0.55, size = 50, color = { 255, 168, 192, 38 }, drift = 21, sway = 5,  phase = 2.8 },
    { kind = "heart",   rx = 0.32, ry0 = 0.80, size = 46, color = { 255, 200, 218, 36 }, drift = 14, sway = 6,  phase = 3.8 },
    { kind = "petal",   rx = 0.68, ry0 = 0.08, size = 44, color = { 255, 162, 186, 40 }, drift = 25, sway = 4,  phase = 0.2 },
}

--- 星空夜语装饰配置（白色半透明，星星为主，12 个）
M.PRESET_STARRY = {
    { kind = "star",    rx = 0.08, ry0 = 0.10, size = 40, color = { 255, 255, 255, 50 }, drift = 10, sway = 4,  phase = 0   },
    { kind = "star",    rx = 0.16, ry0 = 0.35, size = 56, color = { 255, 255, 240, 42 }, drift = 14, sway = 5,  phase = 0.8 },
    { kind = "circle",  rx = 0.04, ry0 = 0.58, size = 30, color = { 255, 255, 255, 36 }, drift = 8,  sway = 3,  phase = 1.5 },
    { kind = "star",    rx = 0.12, ry0 = 0.80, size = 48, color = { 240, 240, 255, 44 }, drift = 12, sway = 6,  phase = 2.2 },
    { kind = "star",    rx = 0.92, ry0 = 0.15, size = 52, color = { 255, 255, 230, 46 }, drift = 11, sway = 5,  phase = 0.5 },
    { kind = "circle",  rx = 0.88, ry0 = 0.42, size = 28, color = { 255, 255, 255, 34 }, drift = 9,  sway = 3,  phase = 1.3 },
    { kind = "star",    rx = 0.94, ry0 = 0.68, size = 44, color = { 245, 245, 255, 40 }, drift = 13, sway = 4,  phase = 2.8 },
    { kind = "star",    rx = 0.85, ry0 = 0.90, size = 36, color = { 255, 255, 245, 38 }, drift = 15, sway = 5,  phase = 3.5 },
    { kind = "star",    rx = 0.45, ry0 = 0.22, size = 60, color = { 255, 255, 255, 48 }, drift = 10, sway = 6,  phase = 0.3 },
    { kind = "circle",  rx = 0.55, ry0 = 0.50, size = 26, color = { 255, 255, 255, 32 }, drift = 7,  sway = 3,  phase = 3.0 },
    { kind = "star",    rx = 0.35, ry0 = 0.75, size = 46, color = { 250, 250, 255, 42 }, drift = 12, sway = 5,  phase = 4.0 },
    { kind = "star",    rx = 0.65, ry0 = 0.05, size = 38, color = { 255, 255, 235, 36 }, drift = 16, sway = 4,  phase = 0.6 },
}

--- 金秋丰收装饰配置（金色系，星星+叶片，12 个）
M.PRESET_AUTUMN = {
    { kind = "star",    rx = 0.07, ry0 = 0.14, size = 54, color = { 240, 190, 80, 48 },  drift = 20, sway = 7,  phase = 0   },
    { kind = "leaf",    rx = 0.14, ry0 = 0.40, size = 50, color = { 220, 160, 60, 44 },  drift = 24, sway = 8,  phase = 0.7 },
    { kind = "star",    rx = 0.06, ry0 = 0.65, size = 48, color = { 250, 200, 90, 42 },  drift = 16, sway = 5,  phase = 1.3 },
    { kind = "leaf",    rx = 0.12, ry0 = 0.88, size = 52, color = { 210, 150, 50, 40 },  drift = 22, sway = 6,  phase = 2.0 },
    { kind = "star",    rx = 0.91, ry0 = 0.20, size = 56, color = { 245, 195, 85, 46 },  drift = 18, sway = 6,  phase = 0.5 },
    { kind = "leaf",    rx = 0.88, ry0 = 0.50, size = 46, color = { 215, 155, 55, 42 },  drift = 20, sway = 7,  phase = 1.5 },
    { kind = "star",    rx = 0.93, ry0 = 0.75, size = 50, color = { 235, 185, 75, 40 },  drift = 15, sway = 5,  phase = 2.6 },
    { kind = "leaf",    rx = 0.85, ry0 = 0.92, size = 48, color = { 225, 165, 65, 38 },  drift = 23, sway = 4,  phase = 3.3 },
    { kind = "star",    rx = 0.42, ry0 = 0.28, size = 52, color = { 248, 198, 88, 44 },  drift = 19, sway = 8,  phase = 0.9 },
    { kind = "leaf",    rx = 0.58, ry0 = 0.58, size = 54, color = { 230, 170, 70, 40 },  drift = 21, sway = 5,  phase = 3.0 },
    { kind = "star",    rx = 0.32, ry0 = 0.82, size = 46, color = { 242, 192, 82, 38 },  drift = 14, sway = 6,  phase = 3.8 },
    { kind = "leaf",    rx = 0.68, ry0 = 0.08, size = 50, color = { 218, 158, 58, 42 },  drift = 25, sway = 4,  phase = 0.2 },
}

--- 换装页装饰配置（暖粉/紫色系，10 个）
M.PRESET_PROFILE = {
    { kind = "circle",  rx = 0.08, ry0 = 0.15, size = 70,  color = { 255, 180, 200, 28 }, drift = 20, sway = 6,  phase = 0.2 },
    { kind = "star",    rx = 0.14, ry0 = 0.50, size = 60,  color = { 255, 200, 140, 32 }, drift = 24, sway = 8,  phase = 1.0 },
    { kind = "heart",   rx = 0.06, ry0 = 0.75, size = 56,  color = { 255, 150, 170, 26 }, drift = 18, sway = 5,  phase = 2.0 },
    { kind = "diamond", rx = 0.12, ry0 = 0.38, size = 50,  color = { 220, 180, 255, 24 }, drift = 22, sway = 4,  phase = 3.0 },
    { kind = "circle",  rx = 0.90, ry0 = 0.20, size = 62,  color = { 255, 160, 190, 28 }, drift = 19, sway = 5,  phase = 0.8 },
    { kind = "star",    rx = 0.88, ry0 = 0.55, size = 56,  color = { 255, 190, 120, 30 }, drift = 22, sway = 6,  phase = 1.8 },
    { kind = "heart",   rx = 0.92, ry0 = 0.72, size = 60,  color = { 255, 140, 180, 24 }, drift = 16, sway = 7,  phase = 2.8 },
    { kind = "diamond", rx = 0.85, ry0 = 0.35, size = 52,  color = { 200, 160, 255, 22 }, drift = 23, sway = 4,  phase = 3.5 },
    { kind = "circle",  rx = 0.50, ry0 = 0.10, size = 80,  color = { 255, 200, 170, 20 }, drift = 15, sway = 7,  phase = 0.5 },
    { kind = "star",    rx = 0.40, ry0 = 0.85, size = 54,  color = { 255, 170, 140, 26 }, drift = 21, sway = 5,  phase = 4.0 },
}

-- ============================================================================
-- 预设名 → table 映射（背景系统通过字符串查找预设）
-- ============================================================================

M.PRESETS = {
    -- 已有预设
    HOME      = M.PRESET_HOME,
    ADVENTURE = M.PRESET_ADVENTURE,
    PROFILE   = M.PRESET_PROFILE,
    -- 新增预设
    SKY       = M.PRESET_SKY,
    MINT      = M.PRESET_MINT,
    SUNSET    = M.PRESET_SUNSET,
    LAVENDER  = M.PRESET_LAVENDER,
    CHERRY    = M.PRESET_CHERRY,
    STARRY    = M.PRESET_STARRY,
    AUTUMN    = M.PRESET_AUTUMN,
}

--- 通过名称获取预设
---@param name string 预设名（如 "HOME"、"SKY"）
---@return table|nil
function M.getPreset(name)
    return M.PRESETS[name]
end

-- ============================================================================
-- 形状路径绘制
-- ============================================================================

--- 绘制五角星路径
---@param vg userdata
---@param cx number
---@param cy number
---@param r number
function M.starPath(vg, cx, cy, r)
    nvgBeginPath(vg)
    for i = 0, 9 do
        local rad = (i % 2 == 0) and r or (r * 0.42)
        local angle = -math.pi / 2 + i * math.pi / 5
        local x = cx + rad * math.cos(angle)
        local y = cy + rad * math.sin(angle)
        if i == 0 then nvgMoveTo(vg, x, y) else nvgLineTo(vg, x, y) end
    end
    nvgClosePath(vg)
end

--- 绘制爱心路径
---@param vg userdata
---@param cx number
---@param cy number
---@param size number
function M.heartPath(vg, cx, cy, size)
    local s = size * 0.5
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy + s * 0.8)
    nvgBezierTo(vg, cx - s * 1.2, cy - s * 0.2, cx - s * 0.6, cy - s * 1.0, cx, cy - s * 0.4)
    nvgBezierTo(vg, cx + s * 0.6, cy - s * 1.0, cx + s * 1.2, cy - s * 0.2, cx, cy + s * 0.8)
    nvgClosePath(vg)
end

--- 绘制云朵路径（三个重叠圆弧组成的卡通云）
---@param vg userdata
---@param cx number
---@param cy number
---@param size number
function M.cloudPath(vg, cx, cy, size)
    local s = size * 0.3
    nvgBeginPath(vg)
    nvgCircle(vg, cx - s * 0.8, cy + s * 0.2, s * 0.7)
    nvgCircle(vg, cx, cy - s * 0.3, s * 1.0)
    nvgCircle(vg, cx + s * 0.8, cy + s * 0.2, s * 0.7)
    -- 底部连接矩形
    nvgRect(vg, cx - s * 1.3, cy + s * 0.2, s * 2.6, s * 0.5)
end

--- 绘制叶片路径（椭圆叶 + 叶脉）
---@param vg userdata
---@param cx number
---@param cy number
---@param size number
function M.leafPath(vg, cx, cy, size)
    local s = size * 0.5
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s)
    nvgBezierTo(vg, cx + s * 0.8, cy - s * 0.5, cx + s * 0.8, cy + s * 0.5, cx, cy + s)
    nvgBezierTo(vg, cx - s * 0.8, cy + s * 0.5, cx - s * 0.8, cy - s * 0.5, cx, cy - s)
    nvgClosePath(vg)
end

--- 绘制花瓣路径（水滴形花瓣）
---@param vg userdata
---@param cx number
---@param cy number
---@param size number
function M.petalPath(vg, cx, cy, size)
    local s = size * 0.45
    nvgBeginPath(vg)
    nvgMoveTo(vg, cx, cy - s)
    nvgBezierTo(vg, cx + s * 0.6, cy - s * 0.3, cx + s * 0.5, cy + s * 0.6, cx, cy + s * 0.8)
    nvgBezierTo(vg, cx - s * 0.5, cy + s * 0.6, cx - s * 0.6, cy - s * 0.3, cx, cy - s)
    nvgClosePath(vg)
end

-- ============================================================================
-- 渲染函数
-- ============================================================================

--- 绘制背景装饰层（缓慢向上飘动，循环回绕）
---@param vg userdata NanoVG 上下文
---@param screenW number 屏幕宽度
---@param screenH number 屏幕高度
---@param t number 动画时间
---@param items table 装饰元素配置数组（使用 PRESET_* 或自定义）
---@param margin number|nil 上下边距（默认 60）
function M.render(vg, screenW, screenH, t, items, margin)
    margin = margin or 60
    local totalH = screenH + margin * 2

    for _, d in ipairs(items) do
        local baseY = d.ry0 * screenH + margin
        local py = baseY - t * d.drift
        py = py % totalH - margin

        local px = d.rx * screenW + math.sin(t * 0.5 + d.phase) * d.sway

        local c = d.color
        local slowRot = t * 0.3 + d.phase

        nvgSave(vg)
        nvgTranslate(vg, px, py)
        nvgRotate(vg, slowRot)
        nvgFillColor(vg, nvgRGBA(c[1], c[2], c[3], c[4]))

        if d.kind == "circle" then
            nvgBeginPath(vg)
            nvgCircle(vg, 0, 0, d.size / 2)
            nvgFill(vg)
        elseif d.kind == "star" then
            M.starPath(vg, 0, 0, d.size / 2)
            nvgFill(vg)
        elseif d.kind == "heart" then
            M.heartPath(vg, 0, 0, d.size)
            nvgFill(vg)
        elseif d.kind == "diamond" then
            nvgBeginPath(vg)
            local sz = d.size
            nvgMoveTo(vg, 0, -sz)
            nvgLineTo(vg, sz * 0.6, 0)
            nvgLineTo(vg, 0, sz)
            nvgLineTo(vg, -sz * 0.6, 0)
            nvgClosePath(vg)
            nvgFill(vg)
        elseif d.kind == "cloud" then
            M.cloudPath(vg, 0, 0, d.size)
            nvgFill(vg)
        elseif d.kind == "leaf" then
            M.leafPath(vg, 0, 0, d.size)
            nvgFill(vg)
        elseif d.kind == "petal" then
            M.petalPath(vg, 0, 0, d.size)
            nvgFill(vg)
        end

        nvgRestore(vg)
    end
end

return M
