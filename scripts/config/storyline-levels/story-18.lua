--- 主线关卡 18：泡泡的万花筒（记忆翻牌大师）
--- 设计要点：32 张卡片（16对），8×4 布局，360ms 翻回延迟，shapes_medium 图案池

return {
    levelId = "story-18",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/kaleidoscope.png",
    cardCount = 32,
    layout = { rows = 8, cols = 4 },
    artPool = "shapes_medium",
    flipBackDelayMs = 360,
    rankTime = { s = 65, a = 90, b = 120 },
}
