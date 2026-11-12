--- 主线关卡 31：糖糖的石之花园（消消乐神话）
--- 设计要点：9×9 棋盘，6 色，5 石块障碍，目标 6000 分，65 秒时限

return {
    levelId = "story-31",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/eternal_garden.png",
    board = { rows = 9, cols = 9 },
    timeLimit = 65,
    tilePool = {
        { colorId = 1, weight = 17 },
        { colorId = 2, weight = 17 },
        { colorId = 3, weight = 17 },
        { colorId = 4, weight = 17 },
        { colorId = 5, weight = 16 },
        { colorId = 6, weight = 16 },
    },
    stonePositions = {
        { 2, 2 }, { 7, 2 }, { 4, 5 }, { 2, 7 }, { 7, 7 },
    },
    goal = { type = "score", targetScore = 1550 },
    starScore = { two = 7500, three = 9500 },
    scoreRule = {
        basePerTile = 10,
        comboBonusRate = 0.45,
        comboCap = 3.5,
        bonusPerSecond = 55,
    },
    animTiming = {
        swapMs = 150,
        swapBackMs = 110,
        eliminateMs = 180,
        fallMs = 120,
    },
}
