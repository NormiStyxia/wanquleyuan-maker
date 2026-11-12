--- 主线关卡 26：泡泡的冷却挑战（记忆翻牌传说）
--- 设计要点：36 张卡片（18对），6×6 布局，300ms 翻回延迟，翻牌冷却700ms

return {
    levelId = "story-26",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/starlight.png",
    cardCount = 36,
    layout = { rows = 6, cols = 6 },
    artPool = "shapes_medium",
    flipBackDelayMs = 300,
    flipCooldownMs = 700,
    rankTime = { s = 80, a = 110, b = 145 },
}
