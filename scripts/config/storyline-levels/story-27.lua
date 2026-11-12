--- 主线关卡 27：糖糖的冰火花园（消消乐传说）
--- 设计要点：9×9 棋盘，6 色，冰冻格，目标 4500 分，65 秒时限

return {
    levelId = "story-27",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/aurora.png",
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
    icePositions = {
        { 4, 4 }, { 2, 6 }, { 6, 6 },
        { 3, 2 }, { 7, 2 }, { 5, 8 },
    },
    goal = { type = "score", targetScore = 1400 },
    starScore = { two = 5800, three = 7200 },
    scoreRule = {
        basePerTile = 10,
        comboBonusRate = 0.42,
        comboCap = 3.2,
        bonusPerSecond = 50,
    },
    animTiming = {
        swapMs = 150,
        swapBackMs = 110,
        eliminateMs = 180,
        fallMs = 120,
    },
}
