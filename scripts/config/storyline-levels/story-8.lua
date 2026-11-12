--- 主线关卡 8：豆豆的收藏室（连连看进阶）
--- 格式与 p4-link-match/data/levels.lua 单个关卡一致
--- 设计要点：8x7 棋盘，8 种图案，100 秒

return {
    levelId = "story-8",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/garden.png",
    board = { rows = 8, cols = 7 },
    patternCount = 8,
    artPool = "shapes_easy",
    timeLimit = 100,
    hints = 2,
    shuffles = 1,
    rankTime = { s = 50, a = 70, b = 95 },
}
