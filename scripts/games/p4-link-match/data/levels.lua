--- 连连看 - 关卡数据 L1-L27
--- 棋盘坐标约定：rows=行数(y方向), cols=列数(x方向)
--- 方块总数 = rows * cols，必须为偶数
--- 竖屏适配：rows > cols，纵向多横向少

return {
    type = "link_match",
    version = 1,
    -- timeLimit 规则：初始 40 秒，每关 +5 秒，最高 90 秒
    levels = {
        -- 新手 L1-L5: 5列x6行, 30块
        {
            levelId = "L1", chapter = "newbie",
            board = { rows = 6, cols = 5 }, patternCount = 5,
            artPool = "shapes_easy", timeLimit = 40,
            hints = 3, shuffles = 2,
            rankTime = { s = 15, a = 25, b = 35 },
        },
        {
            levelId = "L2", chapter = "newbie",
            board = { rows = 6, cols = 5 }, patternCount = 5,
            artPool = "shapes_easy", timeLimit = 45,
            hints = 3, shuffles = 2,
            rankTime = { s = 16, a = 28, b = 38 },
        },
        {
            levelId = "L3", chapter = "newbie",
            board = { rows = 6, cols = 5 }, patternCount = 5,
            artPool = "shapes_easy", timeLimit = 50,
            hints = 3, shuffles = 2,
            rankTime = { s = 18, a = 30, b = 42 },
        },
        {
            levelId = "L4", chapter = "newbie",
            board = { rows = 6, cols = 5 }, patternCount = 7,
            artPool = "shapes_easy", timeLimit = 55,
            hints = 3, shuffles = 2,
            rankTime = { s = 20, a = 32, b = 46 },
        },
        {
            levelId = "L5", chapter = "newbie",
            board = { rows = 6, cols = 5 }, patternCount = 7,
            artPool = "shapes_easy", timeLimit = 60,
            hints = 3, shuffles = 2,
            rankTime = { s = 22, a = 35, b = 50 },
        },
        -- 进阶 L6-L10: 5列x8行, 40块
        {
            levelId = "L6", chapter = "advanced",
            board = { rows = 8, cols = 5 }, patternCount = 9,
            artPool = "shapes_medium", timeLimit = 65,
            hints = 3, shuffles = 2,
            rankTime = { s = 25, a = 38, b = 55 },
        },
        {
            levelId = "L7", chapter = "advanced",
            board = { rows = 8, cols = 5 }, patternCount = 9,
            artPool = "shapes_medium", timeLimit = 70,
            hints = 3, shuffles = 2,
            rankTime = { s = 28, a = 42, b = 58 },
        },
        {
            levelId = "L8", chapter = "advanced",
            board = { rows = 8, cols = 5 }, patternCount = 9,
            artPool = "shapes_medium", timeLimit = 75,
            hints = 3, shuffles = 2,
            rankTime = { s = 30, a = 45, b = 62 },
        },
        {
            levelId = "L9", chapter = "advanced",
            board = { rows = 8, cols = 5 }, patternCount = 9,
            artPool = "shapes_medium", timeLimit = 80,
            hints = 3, shuffles = 2,
            rankTime = { s = 32, a = 48, b = 66 },
        },
        {
            levelId = "L10", chapter = "advanced",
            board = { rows = 8, cols = 5 }, patternCount = 9,
            artPool = "shapes_medium", timeLimit = 85,
            hints = 3, shuffles = 2,
            rankTime = { s = 35, a = 52, b = 70 },
        },
        -- 挑战 L11-L15: 6列x8行, 48块（从 L11 开始达到 90 秒上限）
        {
            levelId = "L11", chapter = "challenge",
            board = { rows = 8, cols = 6 }, patternCount = 10,
            artPool = "shapes_medium", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 35, a = 52, b = 72 },
        },
        {
            levelId = "L12", chapter = "challenge",
            board = { rows = 8, cols = 6 }, patternCount = 10,
            artPool = "shapes_medium", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 33, a = 50, b = 70 },
        },
        {
            levelId = "L13", chapter = "challenge",
            board = { rows = 8, cols = 6 }, patternCount = 10,
            artPool = "shapes_medium", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 35, a = 52, b = 72 },
        },
        {
            levelId = "L14", chapter = "challenge",
            board = { rows = 8, cols = 6 }, patternCount = 10,
            artPool = "shapes_medium", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 36, a = 54, b = 74 },
        },
        {
            levelId = "L15", chapter = "challenge",
            board = { rows = 8, cols = 6 }, patternCount = 10,
            artPool = "shapes_medium", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 38, a = 56, b = 76 },
        },
        -- 专家 L16-L20: 6列x10行, 60块
        {
            levelId = "L16", chapter = "expert",
            board = { rows = 10, cols = 6 }, patternCount = 13,
            artPool = "shapes_hard", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 38, a = 55, b = 75 },
        },
        {
            levelId = "L17", chapter = "expert",
            board = { rows = 10, cols = 6 }, patternCount = 13,
            artPool = "shapes_hard", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 36, a = 52, b = 72 },
        },
        {
            levelId = "L18", chapter = "expert",
            board = { rows = 10, cols = 6 }, patternCount = 13,
            artPool = "shapes_hard", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 34, a = 50, b = 70 },
        },
        {
            levelId = "L19", chapter = "expert",
            board = { rows = 10, cols = 6 }, patternCount = 13,
            artPool = "shapes_hard", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 36, a = 52, b = 72 },
        },
        {
            levelId = "L20", chapter = "expert",
            board = { rows = 10, cols = 6 }, patternCount = 13,
            artPool = "shapes_hard", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 38, a = 55, b = 75 },
        },
        -- 大师 L21-L25: 8列x10行, 80块
        {
            levelId = "L21", chapter = "master",
            board = { rows = 10, cols = 8 }, patternCount = 17,
            artPool = "shapes_hard", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 40, a = 56, b = 76 },
        },
        {
            levelId = "L22", chapter = "master",
            board = { rows = 10, cols = 8 }, patternCount = 17,
            artPool = "shapes_hard", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 38, a = 54, b = 74 },
        },
        {
            levelId = "L23", chapter = "master",
            board = { rows = 10, cols = 8 }, patternCount = 17,
            artPool = "shapes_hard", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 36, a = 52, b = 72 },
        },
        {
            levelId = "L24", chapter = "master",
            board = { rows = 10, cols = 8 }, patternCount = 17,
            artPool = "shapes_hard", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 34, a = 50, b = 70 },
        },
        {
            levelId = "L25", chapter = "master",
            board = { rows = 10, cols = 8 }, patternCount = 17,
            artPool = "shapes_hard", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 32, a = 48, b = 68 },
        },
        -- 大师+ L26-L27: 更大棋盘
        {
            levelId = "L26", chapter = "master",
            board = { rows = 11, cols = 8 }, patternCount = 19,
            artPool = "shapes_hard", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 36, a = 54, b = 74 },
        },
        {
            levelId = "L27", chapter = "master",
            board = { rows = 12, cols = 8 }, patternCount = 20,
            artPool = "shapes_hard", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 40, a = 58, b = 78 },
        },
        -- 极限 L28-L30: 8列x13~15行
        {
            levelId = "L28", chapter = "master",
            board = { rows = 13, cols = 8 }, patternCount = 22,
            artPool = "shapes_hard", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 42, a = 60, b = 80 },
        },
        {
            levelId = "L29", chapter = "master",
            board = { rows = 14, cols = 8 }, patternCount = 24,
            artPool = "shapes_hard", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 44, a = 62, b = 82 },
        },
        {
            levelId = "L30", chapter = "master",
            board = { rows = 15, cols = 8 }, patternCount = 26,
            artPool = "shapes_hard", timeLimit = 90,
            hints = 3, shuffles = 2,
            rankTime = { s = 46, a = 64, b = 84 },
        },
    },
}
