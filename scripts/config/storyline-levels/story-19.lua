--- 主线关卡 19：糖糖的极光盛宴（消消乐大师）
--- 设计要点：9×9 棋盘，6 色，目标 3500 分，70 秒时限

return {
    levelId = "story-19",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/aurora.png",
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
    goal = { type = "score", targetScore = 1100 },
    starScore = { two = 4500, three = 5500 },
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
