--- 主线关卡 12：豆豆的花园配对（连连看高级）
--- 设计要点：8×8 棋盘，10 种图案，90 秒

return {
    levelId = "story-12",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/garden.png",
    board = { rows = 8, cols = 8 },
    patternCount = 10,
    artPool = "shapes_easy",
    timeLimit = 90,
    hints = 2,
    shuffles = 1,
    rankTime = { s = 45, a = 65, b = 85 },
}
