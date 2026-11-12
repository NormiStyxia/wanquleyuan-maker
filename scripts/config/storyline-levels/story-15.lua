--- 主线关卡 15：糖糖的甜蜜决战（消消乐专家）
--- 设计要点：8×8 棋盘，6 色，目标 2400 分，80 秒

return {
    levelId = "story-15",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/candy.png",
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
    goal = { type = "score", targetScore = 950 },
    starScore = { two = 3100, three = 3800 },
    scoreRule = {
        basePerTile = 10,
        comboBonusRate = 0.35,
        comboCap = 2.8,
        bonusPerSecond = 40,
    },
    animTiming = {
        swapMs = 150,
        swapBackMs = 110,
        eliminateMs = 180,
        fallMs = 120,
    },
}
