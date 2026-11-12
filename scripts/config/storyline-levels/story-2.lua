--- 主线关卡 2：泡泡的捉迷藏（记忆翻牌入门）
--- 格式与 p2-memory-flip/data/levels.lua 单个关卡一致
--- 设计要点：8 张卡片，2x4 布局，宽裕时间

return {
    levelId = "story-2",
    chapter = "storyline",
    themeBackground = "Textures/LevelThemes/starlight.png",
    cardCount = 8,
    layout = { rows = 4, cols = 2 },
    artPool = "shapes_easy",
    flipBackDelayMs = 700,
    rankTime = { s = 18, a = 25, b = 35 },
}
