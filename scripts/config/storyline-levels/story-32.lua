--- 主线关卡 32：豆豆的迷雾秘境（连连看神话）
--- 设计要点：12×10 棋盘（120方块），18 种图案，135 秒，锁定+迷雾方块

return {
    levelId = "story-32",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/mist.png",
    board = { rows = 12, cols = 10 },
    patternCount = 18,
    artPool = "shapes_medium",
    timeLimit = 135,
    hints = 1,
    shuffles = 2,
    lockedBlocks = 7,
    fogBlocks = 4,
    rankTime = { s = 65, a = 90, b = 120 },
}
