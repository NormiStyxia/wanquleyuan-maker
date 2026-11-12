--- 主线关卡 3：糖糖的花园（消消乐入门）
--- 格式与 p3-match-3/data/levels.lua 单个关卡一致
--- 设计要点：8x8 棋盘，5 色，低分数目标 1200，90 秒

return {
    levelId = "story-3",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/garden.png",
    board = { rows = 8, cols = 8 },
    timeLimit = 90,
    tilePool = {
        { colorId = 1, weight = 20 },
        { colorId = 2, weight = 20 },
        { colorId = 3, weight = 20 },
        { colorId = 4, weight = 20 },
        { colorId = 5, weight = 20 },
    },
    goal = { type = "score", targetScore = 500 },
    starScore = { two = 1600, three = 2200 },
    scoreRule = {
        basePerTile = 10,
        comboBonusRate = 0.25,
        comboCap = 2.0,
        bonusPerSecond = 55,
    },
    animTiming = {
        swapMs = 180,
        swapBackMs = 140,
        eliminateMs = 220,
        fallMs = 150,
    },
}
