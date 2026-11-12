--- 主线关卡 30：泡泡的至尊记忆（记忆翻牌神话）
--- 设计要点：40 张卡片（20对），8×5 布局，280ms 翻回延迟，shapes_medium，冷却700ms

return {
    levelId = "story-30",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/kaleidoscope.png",
    cardCount = 40,
    layout = { rows = 8, cols = 5 },
    artPool = "shapes_medium",
    flipBackDelayMs = 280,
    flipCooldownMs = 700,
    rankTime = { s = 90, a = 120, b = 160 },
}
