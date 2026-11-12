--- 主线关卡 1：慧慧的花园课堂（推箱子入门）
--- 格式与 p1-puzzle-land/data/levels.lua 单个关卡一致
--- 设计要点：5x5 棋盘，1 个箱子，无冰面，入门难度

return {
    id = "story-1",
    title = "慧慧的花园课堂",
    themeBackground = "Textures/LevelThemes/garden.png",
    difficulty = "easy",
    width = 5, height = 5,
    player = { 2, 3 },
    walls = {
        { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 }, { 4, 0 },
        { 0, 1 }, { 4, 1 },
        { 0, 2 }, { 4, 2 },
        { 0, 3 }, { 4, 3 },
        { 0, 4 }, { 1, 4 }, { 2, 4 }, { 3, 4 }, { 4, 4 },
    },
    boxes = { { 2, 2 } },
    targets = { { 2, 1 } },
    ice = {},
    recommendedSteps = 1,
    solution = "U",
}
