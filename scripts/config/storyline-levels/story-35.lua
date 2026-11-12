--- 主线关卡 35：糖糖的永恒花园（消消乐终极 — 大结局）
--- 设计要点：9×9 棋盘，7 色，4冰冻格+4石块，目标 7000 分，60 秒时限

return {
    levelId = "story-35",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/eternal_garden.png",
    board = { rows = 9, cols = 9 },
    timeLimit = 60,
    tilePool = {
        { colorId = 1, weight = 15 },
        { colorId = 2, weight = 15 },
        { colorId = 3, weight = 15 },
        { colorId = 4, weight = 14 },
        { colorId = 5, weight = 14 },
        { colorId = 6, weight = 14 },
        { colorId = 7, weight = 13 },
    },
    icePositions = {
        { 2, 2 }, { 7, 2 }, { 4, 4 }, { 5, 7 },
    },
    stonePositions = {
        { 3, 3 }, { 6, 3 }, { 1, 5 }, { 8, 5 },
    },
    goal = { type = "score", targetScore = 1700 },
    starScore = { two = 8800, three = 10800 },
    scoreRule = {
        basePerTile = 10,
        comboBonusRate = 0.50,
        comboCap = 4.0,
        bonusPerSecond = 60,
    },
    animTiming = {
        swapMs = 140,
        swapBackMs = 100,
        eliminateMs = 170,
        fallMs = 110,
    },
}
