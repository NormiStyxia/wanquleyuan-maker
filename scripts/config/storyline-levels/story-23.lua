--- 主线关卡 23：糖糖的糖果派对（消消乐宗师）
--- 设计要点：9×9 棋盘，6 色，目标 3800 分，70 秒时限

return {
    levelId = "story-23",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/candy.png",
    board = { rows = 9, cols = 9 },
    timeLimit = 70,
    tilePool = {
        { colorId = 1, weight = 17 },
        { colorId = 2, weight = 17 },
        { colorId = 3, weight = 17 },
        { colorId = 4, weight = 17 },
        { colorId = 5, weight = 16 },
        { colorId = 6, weight = 16 },
    },
    goal = { type = "score", targetScore = 1250 },
    starScore = { two = 4900, three = 6100 },
    scoreRule = {
        basePerTile = 10,
        comboBonusRate = 0.40,
        comboCap = 3.0,
        bonusPerSecond = 45,
    },
    animTiming = {
        swapMs = 150,
        swapBackMs = 110,
        eliminateMs = 180,
        fallMs = 120,
    },
}
