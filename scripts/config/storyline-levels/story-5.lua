--- 主线关卡 5：慧慧的冰面谜题（推箱子进阶）
--- 格式与 p1-puzzle-land/data/levels.lua 单个关卡一致
--- 设计要点：7x6 棋盘，含冰面，2 个箱子

return {
    id = "story-5",
    title = "慧慧的冰面谜题",
    themeBackground = "Textures/LevelThemes/ice.png",
    difficulty = "normal",
    width = 7, height = 6,
    player = { 3, 4 },
    walls = {
        { 0, 0 }, { 1, 0 }, { 2, 0 }, { 3, 0 }, { 4, 0 }, { 5, 0 }, { 6, 0 },
        { 0, 1 }, { 6, 1 },
        { 0, 2 }, { 6, 2 },
        { 0, 3 }, { 6, 3 },
        { 0, 4 }, { 6, 4 },
        { 0, 5 }, { 1, 5 }, { 2, 5 }, { 3, 5 }, { 4, 5 }, { 5, 5 }, { 6, 5 },
    },
    boxes = { { 2, 3 }, { 4, 3 } },
    targets = { { 2, 1 }, { 4, 1 } },
    ice = { { 2, 2 }, { 3, 2 }, { 4, 2 } },
    recommendedSteps = 6,
    solution = "LLUURU",
}
