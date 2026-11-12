--- 主线关卡 34：泡泡的终极万花筒（记忆翻牌终极）
--- 设计要点：42 张卡片（21对），7×6 布局，260ms 翻回延迟，shapes_medium，冷却800ms

return {
    levelId = "story-34",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/kaleidoscope.png",
    cardCount = 42,
    layout = { rows = 7, cols = 6 },
    artPool = "shapes_medium",
    flipBackDelayMs = 260,
    flipCooldownMs = 800,
    rankTime = { s = 95, a = 130, b = 170 },
}
