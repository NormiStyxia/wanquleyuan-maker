--- 主线关卡 7：泡泡的记忆迷宫（记忆翻牌进阶）
--- 格式与 p2-memory-flip/data/levels.lua 单个关卡一致
--- 设计要点：20 张卡片，4x5 布局，较紧时间

return {
    levelId = "story-7",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/maze.png",
    cardCount = 20,
    layout = { rows = 5, cols = 4 },
    artPool = "shapes_easy",
    flipBackDelayMs = 500,
    rankTime = { s = 35, a = 50, b = 70 },
}
