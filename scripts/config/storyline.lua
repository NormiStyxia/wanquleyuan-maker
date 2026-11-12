--- 主线系统 - 节点元数据配置
--- 定义 35 个主线关卡节点的元信息（NPC、标题、解锁条件、剧情对话等）

---@class DialogueLine
---@field speaker string   说话者名称（NPC名 或 "火火"）
---@field text    string   对话内容（<=30字）

---@class FunFact
---@field speaker string   说话者（NPC名）
---@field text    string   小知识内容（<=30字）

return {
    -- ================================================================
    -- 第一章：入门之旅（关卡 1~7）
    -- ================================================================

    -- 节点 1：慧慧的第一课（推箱子入门）
    {
        nodeId = "story-1",
        gameType = "p1-puzzle-land",
        npc = { name = "慧慧", emoji = "🦉", role = "owl" },
        title = "慧慧的花园课堂",
        subtitle = "在花园中学会推箱子",
        storyText = "欢迎来到智慧花园！我是慧慧，让我在这片花园里教你推箱子的基本技巧吧！",
        levelFile = "story-1",
        unlockAfter = nil,

        preDialogue = {
            { speaker = "慧慧", text = "欢迎来到智慧花园！我是慧慧。" },
            { speaker = "慧慧", text = "把箱子推到星星上就过关了，试试看！" },
            { speaker = "火火", text = "花园好漂亮！好的，交给我吧！" },
        },
        postDialogue = {
            { speaker = "慧慧", text = "太棒了！你学会推箱子啦！" },
            { speaker = "火火", text = "在花园里推箱子好有趣！下一关呢？" },
            { speaker = "慧慧", text = "泡泡在前面等你哦，快去看看吧！" },
        },
        funFact = {
            speaker = "慧慧",
            text = "猫头鹰的脖子可以转动270度哦！",
        },
    },

    -- 节点 2：泡泡的捉迷藏（记忆翻牌入门）
    {
        nodeId = "story-2",
        gameType = "p2-memory-flip",
        npc = { name = "泡泡", emoji = "🐱", role = "cat" },
        title = "泡泡的星光捉迷藏",
        subtitle = "在星光下翻开卡片找配对",
        storyText = "喵～我是泡泡！星光闪闪的夜晚，来和我玩捉迷藏吧！",
        levelFile = "story-2",
        unlockAfter = "story-1",

        preDialogue = {
            { speaker = "泡泡", text = "喵～ 你就是火火吧？我是泡泡！" },
            { speaker = "泡泡", text = "看这片星光，卡片在星光下闪烁呢！" },
            { speaker = "火火", text = "星光下捉迷藏？我试试看！" },
        },
        postDialogue = {
            { speaker = "泡泡", text = "哇，星光下你全记住了！记忆力真好！" },
            { speaker = "火火", text = "星光照着翻牌，还挺好玩的！" },
            { speaker = "泡泡", text = "糖糖也想认识你呢，往前走吧！" },
        },
        funFact = {
            speaker = "泡泡",
            text = "猫咪一天要睡16个小时呢，比你睡得多多了！",
        },
    },

    -- 节点 3：糖糖的花园（消消乐入门）
    {
        nodeId = "story-3",
        gameType = "p3-match-3",
        npc = { name = "糖糖", emoji = "🐰", role = "rabbit" },
        title = "糖糖的花园",
        subtitle = "消除方块装扮花园",
        storyText = "嘿嘿，我是糖糖！帮我把花园里的方块整理好吧，三个一样的就能消除哦！",
        levelFile = "story-3",
        unlockAfter = "story-2",

        preDialogue = {
            { speaker = "糖糖", text = "好棒好棒！你来啦！我是糖糖！" },
            { speaker = "糖糖", text = "帮我把花园里的方块整理好吧！" },
            { speaker = "火火", text = "三个一样的就能消除对吧？没问题！" },
        },
        postDialogue = {
            { speaker = "糖糖", text = "耶～ 花园变得好漂亮！谢谢你！" },
            { speaker = "火火", text = "不客气！这种消除好解压呀！" },
            { speaker = "糖糖", text = "豆豆也需要帮忙，快去找他吧！" },
        },
        funFact = {
            speaker = "糖糖",
            text = "兔子的牙齿一生都在长，所以要多啃东西磨牙！",
        },
    },

    -- 节点 4：豆豆的宝石配对（连连看入门）
    {
        nodeId = "story-4",
        gameType = "p4-link-match",
        npc = { name = "豆豆", emoji = "🦝", role = "raccoon" },
        title = "豆豆的花园配对",
        subtitle = "在花园中找到相同图案连起来",
        storyText = "我是豆豆！花园里藏着好多图案方块，帮我把一样的连起来吧！",
        levelFile = "story-4",
        unlockAfter = "story-3",

        preDialogue = {
            { speaker = "豆豆", text = "你好，我是豆豆。花园里有好多图案方块。" },
            { speaker = "豆豆", text = "帮我把花园里一样的图案连起来好吗？" },
            { speaker = "火火", text = "交给我吧！一定帮你整理好！" },
        },
        postDialogue = {
            { speaker = "豆豆", text = "一对一对，全部配好了！完美！" },
            { speaker = "豆豆", text = "你整理得比我还整齐呢。" },
            { speaker = "火火", text = "四位朋友都认识了！继续冒险！" },
        },
        funFact = {
            speaker = "豆豆",
            text = "浣熊的手非常灵活，能打开瓶盖和门把手！",
        },
    },

    -- 节点 5：慧慧的冰面谜题（推箱子进阶）
    {
        nodeId = "story-5",
        gameType = "p1-puzzle-land",
        npc = { name = "慧慧", emoji = "🦉", role = "owl" },
        title = "慧慧的冰面谜题",
        subtitle = "冰面上箱子会滑行",
        storyText = "做得好！现在来试试冰面关卡吧，箱子在冰面上会一直滑动，直到碰到障碍物！",
        levelFile = "story-5",
        unlockAfter = "story-4",

        preDialogue = {
            { speaker = "慧慧", text = "火火，你进步很快！准备好挑战了吗？" },
            { speaker = "慧慧", text = "这次地上有冰面，箱子会一直滑动哦。" },
            { speaker = "火火", text = "冰面？听起来更刺激了！" },
        },
        postDialogue = {
            { speaker = "慧慧", text = "了不起！冰面难题也难不倒你！" },
            { speaker = "火火", text = "多想一步就好，我学会了！" },
        },
        funFact = {
            speaker = "慧慧",
            text = "猫头鹰飞行时几乎没有声音，羽毛边缘像锯齿一样消音！",
        },
    },

    -- 节点 6：糖糖的糖果风暴（消消乐进阶）
    {
        nodeId = "story-6",
        gameType = "p3-match-3",
        npc = { name = "糖糖", emoji = "🐰", role = "rabbit" },
        title = "糖糖的糖果风暴",
        subtitle = "更多颜色更高目标",
        storyText = "花园变得更漂亮了！不过这次的方块颜色更多，你准备好了吗？",
        levelFile = "story-6",
        unlockAfter = "story-5",

        preDialogue = {
            { speaker = "糖糖", text = "火火火火！这次颜色更多了！" },
            { speaker = "糖糖", text = "分数目标也更高，加油加油！" },
            { speaker = "火火", text = "多连击就能拿高分，我明白了！" },
        },
        postDialogue = {
            { speaker = "糖糖", text = "好厉害好厉害！破纪录了！" },
            { speaker = "火火", text = "连击的感觉太爽啦！" },
        },
        funFact = {
            speaker = "糖糖",
            text = "兔子高兴的时候会原地跳起来转圈，叫做'快乐蹦'！",
        },
    },

    -- 节点 7：泡泡的记忆迷宫（记忆翻牌进阶）
    {
        nodeId = "story-7",
        gameType = "p2-memory-flip",
        npc = { name = "泡泡", emoji = "🐱", role = "cat" },
        title = "泡泡的记忆迷宫",
        subtitle = "更多卡片更短时间",
        storyText = "喵！这次的捉迷藏难度升级了，卡片更多、时间更紧，加油！",
        levelFile = "story-7",
        unlockAfter = "story-6",

        preDialogue = {
            { speaker = "泡泡", text = "喵～ 这次的捉迷藏升级了哦！" },
            { speaker = "泡泡", text = "卡片更多，翻回去的速度也更快了。" },
            { speaker = "火火", text = "我会集中注意力的！" },
        },
        postDialogue = {
            { speaker = "泡泡", text = "喵呜！你的记忆力越来越强了！" },
            { speaker = "火火", text = "秘诀是记位置而不是记图案！" },
        },
        funFact = {
            speaker = "泡泡",
            text = "猫咪的胡须和身体一样宽，能用来判断能不能钻过去！",
        },
    },

    -- ================================================================
    -- 第二章：进阶挑战（关卡 8~14）
    -- ================================================================

    -- 节点 8：豆豆的收藏室（连连看进阶）
    {
        nodeId = "story-8",
        gameType = "p4-link-match",
        npc = { name = "豆豆", emoji = "🦝", role = "raccoon" },
        title = "豆豆的花园收藏室",
        subtitle = "花园深处的更大棋盘",
        storyText = "花园深处有我的收藏室！这次的棋盘更大、图案更多，来挑战吧！",
        levelFile = "story-8",
        unlockAfter = "story-7",

        preDialogue = {
            { speaker = "豆豆", text = "花园深处有我的秘密收藏室！" },
            { speaker = "豆豆", text = "棋盘更大、图案更多，仔细看哦～" },
            { speaker = "火火", text = "我一定把它们全部配好！" },
        },
        postDialogue = {
            { speaker = "豆豆", text = "排列得整整齐齐，太舒服了！" },
            { speaker = "火火", text = "这种整理的感觉确实很棒！" },
        },
        funFact = {
            speaker = "豆豆",
            text = "浣熊喜欢用水洗东西，其实是在用手感受食物的形状！",
        },
    },

    -- 节点 9：慧慧的传送迷局（推箱子高级）
    {
        nodeId = "story-9",
        gameType = "p1-puzzle-land",
        npc = { name = "慧慧", emoji = "🦉", role = "owl" },
        title = "慧慧的星空传送门",
        subtitle = "星空下的传送门迷局",
        storyText = "星空闪烁，传送门在星光中若隐若现！箱子会被传送到另一端，仔细想想再推哦！",
        levelFile = "story-9",
        unlockAfter = "story-8",

        preDialogue = {
            { speaker = "慧慧", text = "看到星空中闪烁的传送门了吗？" },
            { speaker = "慧慧", text = "箱子推进去会从星空另一端出来。" },
            { speaker = "火火", text = "星空传送门！这也太酷了吧！" },
        },
        postDialogue = {
            { speaker = "慧慧", text = "星空传送门也难不倒你，真了不起！" },
            { speaker = "火火", text = "多试几次就找到规律了！" },
        },
        funFact = {
            speaker = "慧慧",
            text = "猫头鹰的眼睛不能转动，所以要转脖子来看周围。",
        },
    },

    -- 节点 10：泡泡的星光翻牌（记忆翻牌高级）
    {
        nodeId = "story-10",
        gameType = "p2-memory-flip",
        npc = { name = "泡泡", emoji = "🐱", role = "cat" },
        title = "泡泡的星光翻牌",
        subtitle = "24张卡片的记忆考验",
        storyText = "喵呜～星光下有24张卡片在闪烁呢！集中注意力，把它们全部配对吧！",
        levelFile = "story-10",
        unlockAfter = "story-9",

        preDialogue = {
            { speaker = "泡泡", text = "快看！星光下有24张卡片在闪烁！" },
            { speaker = "泡泡", text = "嘻嘻，看你能不能全记住～" },
            { speaker = "火火", text = "星光照着翻牌，挑战接受！" },
        },
        postDialogue = {
            { speaker = "泡泡", text = "24张全对！星光都为你闪耀！" },
            { speaker = "火火", text = "一开始觉得难，翻几张就有感觉了！" },
        },
        funFact = {
            speaker = "泡泡",
            text = "猫咪能发出超过100种不同的声音，狗狗只有10种左右！",
        },
    },

    -- 节点 11：糖糖的彩虹瀑布（消消乐高级）
    {
        nodeId = "story-11",
        gameType = "p3-match-3",
        npc = { name = "糖糖", emoji = "🐰", role = "rabbit" },
        title = "糖糖的彩虹瀑布",
        subtitle = "在彩虹中追逐高分",
        storyText = "哇，彩虹瀑布出现了！这次分数要求更高，多制造连击才能过关！",
        levelFile = "story-11",
        unlockAfter = "story-10",

        preDialogue = {
            { speaker = "糖糖", text = "哇，彩虹瀑布出现了！好漂亮！" },
            { speaker = "糖糖", text = "这次要更高的分数才能过关哦。" },
            { speaker = "火火", text = "多制造连击就行了，看我的！" },
        },
        postDialogue = {
            { speaker = "糖糖", text = "分数超高！你简直是消除大师！" },
            { speaker = "火火", text = "眼疾手快，越玩越顺！" },
        },
        funFact = {
            speaker = "糖糖",
            text = "兔子的耳朵不只是听声音，还能帮助散热降温哦！",
        },
    },

    -- 节点 12：豆豆的花园配对（连连看高级）
    {
        nodeId = "story-12",
        gameType = "p4-link-match",
        npc = { name = "豆豆", emoji = "🦝", role = "raccoon" },
        title = "豆豆的花园配对",
        subtitle = "花园中的图案连线",
        storyText = "花园里藏着10种不同的图案，你能全部配对吗？",
        levelFile = "story-12",
        unlockAfter = "story-11",

        preDialogue = {
            { speaker = "豆豆", text = "花园里藏着好多图案！" },
            { speaker = "豆豆", text = "10种不同的图案，你能全部配对吗？" },
            { speaker = "火火", text = "没问题，一对一对来！" },
        },
        postDialogue = {
            { speaker = "豆豆", text = "完美！花园里的图案全部配对了！" },
            { speaker = "火火", text = "这种成就感真让人开心！" },
        },
        funFact = {
            speaker = "豆豆",
            text = "浣熊的黑色'面具'花纹能减少阳光反射，方便夜间视力！",
        },
    },

    -- 节点 13：慧慧的迷雾试炼（推箱子专家）
    {
        nodeId = "story-13",
        gameType = "p1-puzzle-land",
        npc = { name = "慧慧", emoji = "🦉", role = "owl" },
        title = "慧慧的迷雾试炼",
        subtitle = "迷雾中的高难推箱子",
        storyText = "浓雾弥漫，这是我准备的精英谜题！4个箱子加上冰面和传送门，你准备好了吗？",
        levelFile = "story-13",
        unlockAfter = "story-12",

        preDialogue = {
            { speaker = "慧慧", text = "火火，迷雾深处是我准备的精英谜题。" },
            { speaker = "慧慧", text = "4个箱子加上冰面和传送门，全力以赴！" },
            { speaker = "火火", text = "迷雾中的试炼？那正好，我准备好了！" },
        },
        postDialogue = {
            { speaker = "慧慧", text = "你穿越了迷雾试炼！我为你骄傲！" },
            { speaker = "火火", text = "谢谢慧慧一路的教导！" },
        },
        funFact = {
            speaker = "慧慧",
            text = "有些猫头鹰的耳朵一高一低，这样能更准确地定位声音来源！",
        },
    },

    -- 节点 14：泡泡的精英考验（记忆翻牌专家）
    {
        nodeId = "story-14",
        gameType = "p2-memory-flip",
        npc = { name = "泡泡", emoji = "🐱", role = "cat" },
        title = "泡泡的星光考验",
        subtitle = "星光中28张卡片极速翻转",
        storyText = "喵！星光璀璨的精英捉迷藏！28张卡片在星光中闪烁，展示你的超强记忆力吧！",
        levelFile = "story-14",
        unlockAfter = "story-13",

        preDialogue = {
            { speaker = "泡泡", text = "喵！星光下的精英考验！28张卡片！" },
            { speaker = "泡泡", text = "星光闪烁，翻回速度超快，准备好了吗？" },
            { speaker = "火火", text = "28张！星光为伴……我可以的！" },
        },
        postDialogue = {
            { speaker = "泡泡", text = "28张全对！星光都为你闪耀！" },
            { speaker = "火火", text = "和泡泡一起玩变得越来越厉害了！" },
        },
        funFact = {
            speaker = "泡泡",
            text = "猫咪的鼻纹和人的指纹一样，每只猫都不同！",
        },
    },

    -- ================================================================
    -- 第三章：精英试炼（关卡 15~21）
    -- ================================================================

    -- 节点 15：糖糖的甜蜜决战（消消乐专家）
    {
        nodeId = "story-15",
        gameType = "p3-match-3",
        npc = { name = "糖糖", emoji = "🐰", role = "rabbit" },
        title = "糖糖的糖果决战",
        subtitle = "糖果世界的甜蜜精英挑战",
        storyText = "糖果世界的精英挑战！缤纷糖果中，时间更紧、目标更高，要拿出全部实力哦！",
        levelFile = "story-15",
        unlockAfter = "story-14",

        preDialogue = {
            { speaker = "糖糖", text = "这是糖果世界的精英挑战！" },
            { speaker = "糖糖", text = "满满的糖果，目标更高，拿出全部实力！" },
            { speaker = "火火", text = "全力以赴！一定能过！" },
        },
        postDialogue = {
            { speaker = "糖糖", text = "太厉害了！花园里最棒的冒险者！" },
            { speaker = "火火", text = "最后一关了！豆豆在等我！" },
        },
        funFact = {
            speaker = "糖糖",
            text = "兔子的视野接近360度，几乎能看到身后的东西！",
        },
    },

    -- 节点 16：豆豆的精英收藏（连连看专家）
    {
        nodeId = "story-16",
        gameType = "p4-link-match",
        npc = { name = "豆豆", emoji = "🦝", role = "raccoon" },
        title = "豆豆的彩虹收藏",
        subtitle = "彩虹中最大棋盘最多图案",
        storyText = "彩虹光芒中是我全部的收藏！超大棋盘、12种图案，完成就是真正的脑力大师！",
        levelFile = "story-16",
        unlockAfter = "story-15",

        preDialogue = {
            { speaker = "豆豆", text = "彩虹下是我全部的收藏，最后的挑战。" },
            { speaker = "豆豆", text = "超大棋盘、12种图案，如彩虹般绚丽！" },
            { speaker = "火火", text = "最后一关！我一定完成它！" },
        },
        postDialogue = {
            { speaker = "豆豆", text = "完美！全部收藏归位了！" },
            { speaker = "火火", text = "前四章全部通关！我变强了好多！" },
            { speaker = "豆豆", text = "别急，前方还有大师之路的考验！" },
        },
        funFact = {
            speaker = "豆豆",
            text = "浣熊的记忆力特别好，能记住三年前解决过的谜题！",
        },
    },

    -- 节点 17：慧慧的星空棋盘（推箱子大师）
    {
        nodeId = "story-17",
        gameType = "p1-puzzle-land",
        npc = { name = "慧慧", emoji = "🦉", role = "owl" },
        title = "慧慧的星空棋盘",
        subtitle = "双色传送门的大师谜题",
        storyText = "星空下的智慧殿堂，5个箱子和双色传送门等你来破解！",
        levelFile = "story-17",
        unlockAfter = "story-16",

        preDialogue = {
            { speaker = "慧慧", text = "火火，你已经超越了所有考验。" },
            { speaker = "慧慧", text = "这是星空殿堂的终极棋盘，两种传送门交织。" },
            { speaker = "火火", text = "双色传送门？我一定能解开的！" },
        },
        postDialogue = {
            { speaker = "慧慧", text = "我的弟子已经青出于蓝了！" },
            { speaker = "慧慧", text = "去吧，泡泡也为你准备了惊喜。" },
            { speaker = "火火", text = "谢谢慧慧！推箱子的每一步都值得思考！" },
        },
        funFact = {
            speaker = "慧慧",
            text = "世界上最小的猫头鹰是精灵猫头鹰，只有13厘米高！",
        },
    },

    -- 节点 18：泡泡的万花筒（记忆翻牌大师）
    {
        nodeId = "story-18",
        gameType = "p2-memory-flip",
        npc = { name = "泡泡", emoji = "🐱", role = "cat" },
        title = "泡泡的万花筒",
        subtitle = "32张卡片的万花筒挑战",
        storyText = "喵！万花筒里藏着32张卡片，图案形状都长得很像，考验真正的记忆力！",
        levelFile = "story-18",
        unlockAfter = "story-17",

        preDialogue = {
            { speaker = "泡泡", text = "看看这个万花筒！32张卡片哦！" },
            { speaker = "泡泡", text = "而且这次的图案长得好像，要看仔细！" },
            { speaker = "火火", text = "32张……集中精神！一定记得住！" },
        },
        postDialogue = {
            { speaker = "泡泡", text = "32张全对！你的大脑简直是超级电脑！" },
            { speaker = "火火", text = "一开始眼花缭乱，后来就越来越清晰了！" },
            { speaker = "泡泡", text = "糖糖的考验比我的还难，加油哦～" },
        },
        funFact = {
            speaker = "泡泡",
            text = "猫咪能记住长达16小时前发生的事，比很多动物都强！",
        },
    },

    -- 节点 19：糖糖的极光盛宴（消消乐大师）
    {
        nodeId = "story-19",
        gameType = "p3-match-3",
        npc = { name = "糖糖", emoji = "🐰", role = "rabbit" },
        title = "糖糖的极光盛宴",
        subtitle = "极光下的极限消除",
        storyText = "极光闪耀的夜晚，9×9的超大花园等你来消除！时间很紧，目标更高！",
        levelFile = "story-19",
        unlockAfter = "story-18",

        preDialogue = {
            { speaker = "糖糖", text = "快看！极光出现了！好美好美！" },
            { speaker = "糖糖", text = "在极光消失前完成消除挑战吧！" },
            { speaker = "火火", text = "9×9的大棋盘？让我来！" },
        },
        postDialogue = {
            { speaker = "糖糖", text = "在极光下达成{targetScore}分！你是消除之王！" },
            { speaker = "火火", text = "连击就是关键，停不下来！" },
            { speaker = "糖糖", text = "最后一关是豆豆的，这次一定超级难！" },
        },
        funFact = {
            speaker = "糖糖",
            text = "兔子奔跑时速可达72公里，比很多汽车在城市里开得还快！",
        },
    },

    -- 节点 20：豆豆的传奇宝库（连连看大师）
    {
        nodeId = "story-20",
        gameType = "p4-link-match",
        npc = { name = "豆豆", emoji = "🦝", role = "raccoon" },
        title = "豆豆的永恒收藏",
        subtitle = "永恒花园中仅1次提示的大师连线",
        storyText = "永恒花园深处是我的传奇收藏！96个方块、14种图案，只有1次提示，全靠你的眼力！",
        levelFile = "story-20",
        unlockAfter = "story-19",

        preDialogue = {
            { speaker = "豆豆", text = "永恒花园里有我最珍贵的收藏。" },
            { speaker = "豆豆", text = "96个方块，14种图案，而且……只有1次提示。" },
            { speaker = "火火", text = "只有1次提示？好！靠我自己的眼睛！" },
        },
        postDialogue = {
            { speaker = "豆豆", text = "不可思议……永恒花园的收藏被征服了！" },
            { speaker = "火火", text = "前五章都通关了！我是不是最强的？" },
            { speaker = "豆豆", text = "别急，前方还有更强的考验在等着你！" },
        },
        funFact = {
            speaker = "豆豆",
            text = "浣熊的智商在动物界排名很高，能解开复杂的锁和机关！",
        },
    },

    -- 节点 21：慧慧的迷雾单行道（推箱子宗师）
    {
        nodeId = "story-21",
        gameType = "p1-puzzle-land",
        npc = { name = "慧慧", emoji = "🦉", role = "owl" },
        title = "慧慧的迷雾单行道",
        subtitle = "迷雾中的单向传送通道",
        storyText = "迷雾中的传送门是单向的！推箱子前要在雾中辨清方向！",
        levelFile = "story-21",
        unlockAfter = "story-20",

        preDialogue = {
            { speaker = "慧慧", text = "火火，看到迷雾中若隐若现的单行道了吗？" },
            { speaker = "慧慧", text = "迷雾传送门是单向的，只能朝一个方向通过。" },
            { speaker = "火火", text = "迷雾单行道？那得更仔细规划路线了！" },
        },
        postDialogue = {
            { speaker = "慧慧", text = "迷雾单行道也挡不住你了！" },
            { speaker = "火火", text = "规划好路线，一步都不浪费！" },
        },
        funFact = {
            speaker = "慧慧",
            text = "猫头鹰的听觉极灵敏，能听到雪下面老鼠的动静！",
        },
    },

    -- ================================================================
    -- 第四章：奇迹觉醒（关卡 22~28）
    -- ================================================================

    -- 节点 22：泡泡的星光记忆（记忆翻牌宗师）
    {
        nodeId = "story-22",
        gameType = "p2-memory-flip",
        npc = { name = "泡泡", emoji = "🐱", role = "cat" },
        title = "泡泡的星光记忆",
        subtitle = "36张卡片的星光挑战",
        storyText = "喵！星光下有36张卡片在闪烁，翻回速度更快了，考验真正开始！",
        levelFile = "story-22",
        unlockAfter = "story-21",

        preDialogue = {
            { speaker = "泡泡", text = "喵～ 看到那些闪烁的星光了吗？" },
            { speaker = "泡泡", text = "36张卡片藏在里面，翻回更快了哦！" },
            { speaker = "火火", text = "36张！我的记忆力够用吗……" },
        },
        postDialogue = {
            { speaker = "泡泡", text = "36张全对！你简直是星光之子！" },
            { speaker = "火火", text = "集中注意力，一切都清晰了！" },
        },
        funFact = {
            speaker = "泡泡",
            text = "猫咪的瞳孔可以放大到眼睛的90%，夜视能力超强！",
        },
    },

    -- 节点 23：糖糖的糖果派对（消消乐宗师）
    {
        nodeId = "story-23",
        gameType = "p3-match-3",
        npc = { name = "糖糖", emoji = "🐰", role = "rabbit" },
        title = "糖糖的糖果派对",
        subtitle = "缤纷糖果的极限消除",
        storyText = "糖果派对开始啦！9×9的棋盘、1250分目标，连击是关键！",
        levelFile = "story-23",
        unlockAfter = "story-22",

        preDialogue = {
            { speaker = "糖糖", text = "糖果派对开始啦！好多颜色！" },
            { speaker = "糖糖", text = "{targetScore}分目标，{timeLimit}秒，连击是关键！" },
            { speaker = "火火", text = "这么多糖果，消起来一定很过瘾！" },
        },
        postDialogue = {
            { speaker = "糖糖", text = "糖果派对大成功！好厉害！" },
            { speaker = "火火", text = "连击越来越顺手了！" },
        },
        funFact = {
            speaker = "糖糖",
            text = "兔子能跳到自身身高的3倍高，弹跳力惊人！",
        },
    },

    -- 节点 24：豆豆的锁链迷阵（连连看宗师）
    {
        nodeId = "story-24",
        gameType = "p4-link-match",
        npc = { name = "豆豆", emoji = "🦝", role = "raccoon" },
        title = "豆豆的锁链迷阵",
        subtitle = "锁链封路，挑战解锁",
        storyText = "锁链封住了前进的道路！只有通过挑战才能打破锁链继续前进！",
        levelFile = "story-24",
        unlockAfter = "story-23",

        preDialogue = {
            { speaker = "豆豆", text = "前面的路被锁链封住了！" },
            { speaker = "豆豆", text = "只有通过挑战才能打破锁链，继续前进。" },
            { speaker = "火火", text = "锁链挡路？那就用实力打破它！" },
        },
        postDialogue = {
            { speaker = "豆豆", text = "锁链全部打破了！道路畅通无阻！" },
            { speaker = "火火", text = "没有什么锁链能挡住我们！" },
        },
        funFact = {
            speaker = "豆豆",
            text = "浣熊的爪子有5个灵活的脚趾，像人的手指一样！",
        },
    },

    -- 节点 25：慧慧的计步棋局（推箱子传说）
    {
        nodeId = "story-25",
        gameType = "p1-puzzle-land",
        npc = { name = "慧慧", emoji = "🦉", role = "owl" },
        title = "慧慧的星空棋局",
        subtitle = "星空下每一步都要精打细算",
        storyText = "星空下的棋盘更大了！11×10的棋盘，6个箱子，每一步都不能浪费！",
        levelFile = "story-25",
        unlockAfter = "story-24",

        preDialogue = {
            { speaker = "慧慧", text = "星空下的棋局需要精确计算。" },
            { speaker = "慧慧", text = "11×10的棋盘，6个箱子，步步为营。" },
            { speaker = "火火", text = "每一步都要想三步，我明白了！" },
        },
        postDialogue = {
            { speaker = "慧慧", text = "{recommendedSteps}步内完成，堪称完美！" },
            { speaker = "火火", text = "精打细算的感觉真好！" },
        },
        funFact = {
            speaker = "慧慧",
            text = "猫头鹰有三层眼皮，第三层用来保护和清洁眼睛！",
        },
    },

    -- 节点 26：泡泡的冷却挑战（记忆翻牌传说）
    {
        nodeId = "story-26",
        gameType = "p2-memory-flip",
        npc = { name = "泡泡", emoji = "🐱", role = "cat" },
        title = "泡泡的星光冷却",
        subtitle = "星光下翻牌需要等待冷却",
        storyText = "喵！星光下翻错了要等0.7秒才能再翻，36张卡片在星光中闪烁，要更加谨慎！",
        levelFile = "story-26",
        unlockAfter = "story-25",

        preDialogue = {
            { speaker = "泡泡", text = "喵～ 星光下有新规则哦！" },
            { speaker = "泡泡", text = "翻错了要等{flipCooldownSec}秒冷却，星光可不等人！" },
            { speaker = "火火", text = "星光冷却？那每次翻牌都要确定才行！" },
        },
        postDialogue = {
            { speaker = "泡泡", text = "零失误！星光一直为你闪耀！" },
            { speaker = "火火", text = "确定了再翻，反而更快了！" },
        },
        funFact = {
            speaker = "泡泡",
            text = "猫咪能在0.03秒内翻转身体，总是四脚着地！",
        },
    },

    -- 节点 27：糖糖的冰火花园（消消乐传说）
    {
        nodeId = "story-27",
        gameType = "p3-match-3",
        npc = { name = "糖糖", emoji = "🐰", role = "rabbit" },
        title = "糖糖的极光花园",
        subtitle = "极光下6色方块加冰冻格挑战",
        storyText = "极光下花园里出现了冰冻格！被冻住的方块要消除两次才能清除，在极光消失前追求1400分！",
        levelFile = "story-27",
        unlockAfter = "story-26",

        preDialogue = {
            { speaker = "糖糖", text = "哇，极光下花园里有方块被冻住了！" },
            { speaker = "糖糖", text = "冰冻格要消除两次，{targetScore}分目标，极光双重挑战！" },
            { speaker = "火火", text = "极光下冰冻格加高分？双重挑战！" },
        },
        postDialogue = {
            { speaker = "糖糖", text = "极光照耀下冰冻格全融化了！太厉害了！" },
            { speaker = "火火", text = "先处理冰冻格，再追分数！" },
        },
        funFact = {
            speaker = "糖糖",
            text = "兔子的门牙每年能长12厘米，不磨牙就会太长！",
        },
    },

    -- 节点 28：豆豆的锁链宝库（连连看传说）
    {
        nodeId = "story-28",
        gameType = "p4-link-match",
        npc = { name = "豆豆", emoji = "🦝", role = "raccoon" },
        title = "豆豆的锁链宝库",
        subtitle = "重重锁链中的连线挑战",
        storyText = "宝库被重重锁链封住了！12×10的超大棋盘和16种图案，打破锁链才能通关！",
        levelFile = "story-28",
        background = "cherry_blossom",
        unlockAfter = "story-27",

        preDialogue = {
            { speaker = "豆豆", text = "宝库被重重锁链封住了……" },
            { speaker = "豆豆", text = "12×10棋盘，16种图案，锁定方块更多了。" },
            { speaker = "火火", text = "越大越有挑战！打破锁链！" },
        },
        postDialogue = {
            { speaker = "豆豆", text = "所有锁链都被你打破了！" },
            { speaker = "火火", text = "大棋盘也不怕，一对一对来！" },
        },
        funFact = {
            speaker = "豆豆",
            text = "浣熊能从12米高的树上跳下来安全着地！",
        },
    },

    -- ================================================================
    -- 第五章：永恒之巅（关卡 29~35）
    -- ================================================================

    -- 节点 29：慧慧的三色迷宫（推箱子神话）
    {
        nodeId = "story-29",
        gameType = "p1-puzzle-land",
        npc = { name = "慧慧", emoji = "🦉", role = "owl" },
        title = "慧慧的万花筒迷宫",
        subtitle = "万花筒中三色传送门交织",
        storyText = "万花筒般绚丽的三色传送门交织在一起！12×10的棋盘，6个箱子，这是真正的智慧考验！",
        levelFile = "story-29",
        unlockAfter = "story-28",

        preDialogue = {
            { speaker = "慧慧", text = "火火，看这个万花筒般的迷宫！" },
            { speaker = "慧慧", text = "红蓝绿三色传送门如万花筒般交织。" },
            { speaker = "火火", text = "万花筒迷宫！要记清每个传送门的配对！" },
        },
        postDialogue = {
            { speaker = "慧慧", text = "万花筒迷宫也难不倒你，真了不起！" },
            { speaker = "火火", text = "颜色多了反而更有趣了！" },
        },
        funFact = {
            speaker = "慧慧",
            text = "长耳鸮的耳羽不是真的耳朵，真耳朵藏在脸盘羽毛下面！",
        },
    },

    -- 节点 30：泡泡的至尊记忆（记忆翻牌神话）
    {
        nodeId = "story-30",
        gameType = "p2-memory-flip",
        npc = { name = "泡泡", emoji = "🐱", role = "cat" },
        title = "泡泡的万花筒记忆",
        subtitle = "万花筒中40张卡片的终极考验",
        storyText = "喵！万花筒光芒中，40张卡片图案交错，冷却0.7秒！这是记忆的最高殿堂！",
        levelFile = "story-30",
        unlockAfter = "story-29",

        preDialogue = {
            { speaker = "泡泡", text = "万花筒里40张卡片！图案更难分辨了！" },
            { speaker = "泡泡", text = "万花筒的光芒让人眼花缭乱，要小心哦。" },
            { speaker = "火火", text = "万花筒中40张图案？我不会退缩的！" },
        },
        postDialogue = {
            { speaker = "泡泡", text = "万花筒中全对！你是记忆之神！" },
            { speaker = "火火", text = "越难的图案越要仔细观察细节！" },
        },
        funFact = {
            speaker = "泡泡",
            text = "猫咪跑步最快时速48公里，比博尔特还快！",
        },
    },

    -- 节点 31：糖糖的石之花园（消消乐神话）
    {
        nodeId = "story-31",
        gameType = "p3-match-3",
        npc = { name = "糖糖", emoji = "🐰", role = "rabbit" },
        title = "糖糖的永恒石之花园",
        subtitle = "永恒花园中石块障碍需要特殊消除",
        storyText = "永恒花园里出现了石块！石块是固定障碍不能交换，要消除石块相邻的方块才能让它们消失！",
        levelFile = "story-31",
        unlockAfter = "story-30",

        preDialogue = {
            { speaker = "糖糖", text = "永恒花园里出现了顽固的石块！" },
            { speaker = "糖糖", text = "9×9棋盘，石块是固定障碍，消除相邻方块才能让它们消失，{targetScore}分目标！" },
            { speaker = "火火", text = "石块挡路？那就绕着它们消除！" },
        },
        postDialogue = {
            { speaker = "糖糖", text = "永恒石之花园也被你征服了！太强了！" },
            { speaker = "火火", text = "绕过障碍找机会，越玩越有策略！" },
        },
        funFact = {
            speaker = "糖糖",
            text = "兔子的后腿力量是前腿的10倍，所以跳得又高又远！",
        },
    },

    -- 节点 32：豆豆的迷雾秘境（连连看神话）
    {
        nodeId = "story-32",
        gameType = "p4-link-match",
        npc = { name = "豆豆", emoji = "🦝", role = "raccoon" },
        title = "豆豆的迷雾秘境",
        subtitle = "迷雾方块需要消除才能看清",
        storyText = "有些方块被迷雾遮住了，看不清图案！通过挑战就能驱散周围的迷雾！12×10超大棋盘！",
        levelFile = "story-32",
        unlockAfter = "story-31",

        preDialogue = {
            { speaker = "豆豆", text = "有些方块被迷雾笼罩了……" },
            { speaker = "豆豆", text = "迷雾遮住了图案，看不清！通过挑战就能驱散周围迷雾。" },
            { speaker = "火火", text = "交给我吧！" },
        },
        postDialogue = {
            { speaker = "豆豆", text = "迷雾全部散开了！太完美了！" },
            { speaker = "豆豆", text = "你是我见过最厉害的冒险者。" },
            { speaker = "火火", text = "谢谢豆豆！每次连连看都很开心！" },
        },
        funFact = {
            speaker = "豆豆",
            text = "浣熊能在水中游泳好几个小时，是天生的游泳健将！",
        },
    },

    -- 节点 33：慧慧的永恒棋局（推箱子终极）
    {
        nodeId = "story-33",
        gameType = "p1-puzzle-land",
        npc = { name = "慧慧", emoji = "🦉", role = "owl" },
        title = "慧慧的永恒花园棋局",
        subtitle = "永恒花园中所有机制的终极融合",
        storyText = "永恒花园中我最难的谜题！12×11棋盘，7个箱子，三色传送门加单向通道，全部融合！",
        levelFile = "story-33",
        unlockAfter = "story-32",

        preDialogue = {
            { speaker = "慧慧", text = "火火……永恒花园中，这是我最后的谜题。" },
            { speaker = "慧慧", text = "所有机制融合在一起，{recommendedSteps}步内解开它。" },
            { speaker = "火火", text = "慧慧的最后一课，我不会让你失望！" },
        },
        postDialogue = {
            { speaker = "慧慧", text = "你已经超越了老师……我很欣慰。" },
            { speaker = "火火", text = "谢谢慧慧！没有你的教导就没有今天的我！" },
            { speaker = "慧慧", text = "去吧，永恒之巅在等你。" },
        },
        funFact = {
            speaker = "慧慧",
            text = "雪鸮的羽毛能在零下40度保暖，是极地的生存大师！",
        },
    },

    -- 节点 34：泡泡的终极万花筒（记忆翻牌终极）
    {
        nodeId = "story-34",
        gameType = "p2-memory-flip",
        npc = { name = "泡泡", emoji = "🐱", role = "cat" },
        title = "泡泡的终极万花筒",
        subtitle = "42张卡片最短延迟最长冷却",
        storyText = "喵！42张卡片，翻回延迟只有260毫秒，冷却要0.8秒！这是记忆的终极考验！",
        levelFile = "story-34",
        unlockAfter = "story-33",

        preDialogue = {
            { speaker = "泡泡", text = "这是我们最后一次捉迷藏了……" },
            { speaker = "泡泡", text = "42张卡片，{flipBackDelayMs}毫秒翻回，{flipCooldownSec}秒冷却！" },
            { speaker = "火火", text = "最后的记忆考验！泡泡，看好了！" },
        },
        postDialogue = {
            { speaker = "泡泡", text = "喵呜……我输了！你是真正的记忆王！" },
            { speaker = "火火", text = "泡泡，谢谢你教会我用心记忆！" },
            { speaker = "泡泡", text = "最后一关了，糖糖等你，加油哦～" },
        },
        funFact = {
            speaker = "泡泡",
            text = "猫咪用尾巴保持平衡，从高处落下也能稳稳着地！",
        },
    },

    -- 节点 35：糖糖的永恒花园（消消乐终极 -- 大结局）
    {
        nodeId = "story-35",
        gameType = "p3-match-3",
        npc = { name = "糖糖", emoji = "🐰", role = "rabbit" },
        title = "糖糖的永恒花园",
        subtitle = "大结局——1700分的终极挑战",
        storyText = "这是永恒花园的最终挑战！9×9棋盘，7色方块，冰冻格加石块，目标1700分！",
        levelFile = "story-35",
        unlockAfter = "story-34",

        preDialogue = {
            { speaker = "糖糖", text = "这是永恒花园……最后的挑战！" },
            { speaker = "糖糖", text = "{targetScore}分，{timeLimit}秒，冰冻格加石块，全部上！" },
            { speaker = "火火", text = "最后一关！我要用最好的表现收尾！" },
        },
        postDialogue = {
            { speaker = "糖糖", text = "{targetScore}分达成！你是永恒花园的王者！" },
            { speaker = "火火", text = "我做到了！35关全部通关！！" },
            { speaker = "豆豆", text = "所有人都为你骄傲！你是真正的脑力传奇！" },
        },
        funFact = {
            speaker = "糖糖",
            text = "兔子会吃自己的便便来吸收更多营养，这是生存智慧！",
        },
    },
}
