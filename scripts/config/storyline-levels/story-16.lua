--- 主线关卡 16：豆豆的终极收藏（连连看专家）
--- 设计要点：10×8 棋盘，12 种图案，90 秒

return {
    levelId = "story-16",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/rainbow.png",
    board = { rows = 10, cols = 8 },
    patternCount = 12,
    artPool = "shapes_easy",
    timeLimit = 90,
    hints = 2,
    shuffles = 2,
    rankTime = { s = 45, a = 60, b = 80 },
}
