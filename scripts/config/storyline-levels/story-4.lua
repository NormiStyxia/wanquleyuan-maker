--- 主线关卡 4：豆豆的图案配对（连连看入门）
--- 格式与 p4-link-match/data/levels.lua 单个关卡一致
--- 设计要点：6x5 棋盘，5 种图案，120 秒

return {
    levelId = "story-4",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/garden.png",
    board = { rows = 6, cols = 5 },
    patternCount = 5,
    artPool = "shapes_easy",
    timeLimit = 120,
    hints = 3,
    shuffles = 2,
    rankTime = { s = 45, a = 65, b = 95 },
}
