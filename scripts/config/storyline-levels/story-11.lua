--- 主线关卡 11：糖糖的彩虹瀑布（消消乐高级）
--- 设计要点：8×8 棋盘，6 色，目标 2200 分，80 秒

return {
    levelId = "story-11",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/rainbow.png",
    board = { rows = 8, cols = 8 },
    timeLimit = 80,
    tilePool = {
        { colorId = 1, weight = 17 },
        { colorId = 2, weight = 17 },
        { colorId = 3, weight = 17 },
        { colorId = 4, weight = 17 },
        { colorId = 5, weight = 16 },
        { colorId = 6, weight = 16 },
    },
    goal = { type = "score", targetScore = 800 },
    starScore = { two = 2800, three = 3500 },
    scoreRule = {
        basePerTile = 10,
        comboBonusRate = 0.3,
        comboCap = 2.5,
        bonusPerSecond = 45,
    },
    animTiming = {
        swapMs = 160,
        swapBackMs = 120,
        eliminateMs = 190,
        fallMs = 130,
    },
}
