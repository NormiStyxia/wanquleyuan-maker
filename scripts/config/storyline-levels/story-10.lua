--- 主线关卡 10：泡泡的星光翻牌（记忆翻牌高级）
--- 设计要点：24 张卡片，4×6 布局，中等翻回延迟

return {
    levelId = "story-10",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/starlight.png",
    cardCount = 24,
    layout = { rows = 6, cols = 4 },
    artPool = "shapes_easy",
    flipBackDelayMs = 450,
    rankTime = { s = 45, a = 65, b = 90 },
}
