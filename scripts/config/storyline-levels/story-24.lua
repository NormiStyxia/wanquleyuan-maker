--- 主线关卡 24：豆豆的锁链迷阵（连连看宗师）
--- 设计要点：12×10 棋盘（120方块），16 种图案，110 秒，锁定方块

return {
    levelId = "story-24",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/chain.png",
    board = { rows = 12, cols = 10 },
    patternCount = 16,
    artPool = "shapes_medium",
    timeLimit = 110,
    hints = 1,
    shuffles = 2,
    lockedBlocks = 5,
    rankTime = { s = 55, a = 75, b = 100 },
}
