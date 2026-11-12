--- 主线关卡 22：泡泡的星光记忆（记忆翻牌宗师）
--- 设计要点：36 张卡片（18对），6×6 布局，320ms 翻回延迟，shapes_medium 图案池

return {
    levelId = "story-22",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/starlight.png",
    cardCount = 36,
    layout = { rows = 6, cols = 6 },
    artPool = "shapes_medium",
    flipBackDelayMs = 320,
    rankTime = { s = 75, a = 100, b = 135 },
}
