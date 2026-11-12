--- 主线关卡 14：泡泡的终极考验（记忆翻牌专家）
--- 设计要点：28 张卡片，4×7 布局，适中翻回

return {
    levelId = "story-14",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/starlight.png",
    cardCount = 28,
    layout = { rows = 7, cols = 4 },
    artPool = "shapes_easy",
    flipBackDelayMs = 420,
    rankTime = { s = 60, a = 80, b = 110 },
}
