--- 主线关卡 28：豆豆的锁链宝库（连连看传说）
--- 设计要点：12×10 棋盘（120方块），16 种图案，120 秒，锁定方块

return {
    levelId = "story-28",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/chain.png",
    board = { rows = 12, cols = 10 },
    patternCount = 16,
    artPool = "shapes_medium",
    timeLimit = 120,
    hints = 1,
    shuffles = 2,
    lockedBlocks = 6,
    rankTime = { s = 60, a = 80, b = 105 },
}
