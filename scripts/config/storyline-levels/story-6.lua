--- 主线关卡 6：糖糖的糖果风暴（消消乐进阶）
--- 格式与 p3-match-3/data/levels.lua 单个关卡一致
--- 设计要点：8x8 棋盘，6 色，较高分数目标 2000，80 秒

return {
    levelId = "story-6",
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
    goal = { type = "score", targetScore = 650 },
    starScore = { two = 2600, three = 3200 },
    scoreRule = {
        basePerTile = 10,
        comboBonusRate = 0.3,
        comboCap = 2.5,
        bonusPerSecond = 50,
    },
    animTiming = {
        swapMs = 170,
        swapBackMs = 130,
        eliminateMs = 200,
        fallMs = 140,
    },
}
