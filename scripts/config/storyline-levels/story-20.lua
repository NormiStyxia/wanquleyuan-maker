--- 主线关卡 20：豆豆的传奇宝库（连连看大师）
--- 设计要点：12×8 棋盘（96方块），14 种图案，1 提示，100 秒时限

return {
    levelId = "story-20",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/eternal_garden.png",
    board = { rows = 12, cols = 8 },
    patternCount = 14,
    artPool = "shapes_medium",
    timeLimit = 100,
    hints = 1,
    shuffles = 1,
    rankTime = { s = 50, a = 70, b = 90 },
}
