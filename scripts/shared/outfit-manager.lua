--- 皮肤管理器（全局单例）
--- 管理角色皮肤配置、当前选中状态、存档读写

local logger = require("shared.utils.logger")

local M = {}
local MODULE = "outfit-manager"

-- ============================================================================
-- 皮肤配置表
-- ============================================================================
local SKINS = {
    { id = "default",   name = "默认",   texture = "Textures/character/fox.png", thumbnail = "image/handdrawn/character-previews/default.png" },
    { id = "sport",     name = "运动装", texture = "Textures/character/skins/fox_sport.png", thumbnail = "image/handdrawn/character-previews/sport.png",
      unlock = { type = "story", nodeId = "story-7", label = "完成7关" } },
    { id = "chef",      name = "厨师装", texture = "Textures/character/skins/fox_chef.png", thumbnail = "image/handdrawn/character-previews/chef.png",
      unlock = { type = "story", nodeId = "story-14", label = "完成14关" } },
    { id = "suit",      name = "西装",   texture = "Textures/character/skins/fox_suit.png", thumbnail = "image/handdrawn/character-previews/suit.png",
      unlock = { type = "purchase", label = "点击购买", price = 3 } },
    { id = "astronaut", name = "宇航员", texture = "Textures/character/skins/fox_astronaut.png", thumbnail = "image/handdrawn/character-previews/astronaut.png",
      unlock = { type = "purchase", label = "点击购买", price = 3 } },
    { id = "worker",    name = "工程师", texture = "Textures/character/skins/fox_worker.png", thumbnail = "image/handdrawn/character-previews/worker.png",
      unlock = { type = "purchase", label = "点击购买", price = 3 } },
    { id = "pirate",    name = "船长",   texture = "Textures/character/skins/fox_pirate.png", thumbnail = "image/handdrawn/character-previews/pirate.png",
      unlock = { type = "purchase", label = "点击购买", price = 3 } },
    { id = "detective", name = "侦探",   texture = "Textures/character/skins/fox_detective.png", thumbnail = "image/handdrawn/character-previews/detective.png",
      unlock = { type = "purchase", label = "点击购买", price = 3 } },
    { id = "artist",    name = "画家",   texture = "Textures/character/skins/fox_artist.png", thumbnail = "image/handdrawn/character-previews/artist.png",
      unlock = { type = "purchase", label = "点击购买", price = 3 } },
    { id = "ninja",     name = "忍者",   texture = "Textures/character/skins/fox_ninja.png", thumbnail = "image/handdrawn/character-previews/ninja.png",
      unlock = { type = "purchase", label = "点击购买", price = 3 } },
    { id = "doctor",    name = "医生",   texture = "Textures/character/skins/fox_doctor.png", thumbnail = "image/handdrawn/character-previews/doctor.png",
      unlock = { type = "purchase", label = "点击购买", price = 3 } },
}

-- ============================================================================
-- 各皮肤专属夸奖台词（根据身份调整用语风格）
-- ============================================================================
---@type table<string, string[]>
local SKIN_PRAISES = {
    default = {
        "太棒了！", "好厉害！", "聪明！", "完美！",
        "真不错！", "厉害呀！", "太强了！", "漂亮！",
        "好样的！", "真聪明！", "太赞了！", "了不起！",
        "妙啊！", "绝了！", "优秀！", "超棒！",
        "天才！", "真厉害！", "好极了！", "没问题！",
        "轻松搞定！", "就是这样！", "继续加油！", "很有天赋！",
        "真行！", "太酷了！", "稳稳的！", "不错嘛！",
        "干得好！", "精彩！",
    },
    sport = {
        "漂亮进攻！", "冲冲冲！", "全力以赴！", "破纪录了！",
        "MVP就是你！", "稳住节奏！", "体力满格！", "超强爆发！",
        "跑得漂亮！", "绝杀！", "拿下比赛！", "太燃了！",
        "势不可挡！", "极速冲刺！", "赢麻了！", "运动健将！",
        "完美配合！", "强势逆转！", "实力碾压！", "金牌选手！",
    },
    chef = {
        "火候刚好！", "色香味俱全！", "大厨出品！", "完美调味！",
        "米其林水准！", "太香了！", "出锅咯！", "好手艺！",
        "锅气十足！", "摆盘漂亮！", "今日主厨！", "秘方在手！",
        "食材新鲜！", "刀工了得！", "美味满分！", "开饭啦！",
        "招牌菜！", "回味无穷！", "好吃到飞！", "厨神驾到！",
    },
    suit = {
        "谈判成功！", "气场全开！", "运筹帷幄！", "决策英明！",
        "签约达成！", "高瞻远瞩！", "出手不凡！", "格局打开！",
        "精英范儿！", "稳操胜券！", "步步为营！", "成竹在胸！",
        "商业嗅觉！", "眼光精准！", "大局已定！", "举止优雅！",
        "谈吐不凡！", "胜券在握！", "专业！", "从容不迫！",
    },
    astronaut = {
        "升空成功！", "星际穿越！", "太空漫步！", "任务完成！",
        "发现新星！", "轨道精准！", "宇宙无限！", "着陆完美！",
        "星河璀璨！", "探索未知！", "飞向宇宙！", "无重力操作！",
        "信号良好！", "航线正确！", "银河系最强！", "太空英雄！",
        "突破大气层！", "星际导航！", "月球漫步！", "火箭发射！",
    },
    worker = {
        "工程完美！", "结构稳固！", "蓝图实现！", "精密计算！",
        "安全达标！", "设计精妙！", "质量过关！", "按时交付！",
        "测量精准！", "图纸完成！", "技术过硬！", "焊接漂亮！",
        "地基牢固！", "进度超前！", "验收通过！", "匠心独运！",
        "硬核实力！", "零误差！", "建造完成！", "工程师之魂！",
    },
    pirate = {
        "宝藏到手！", "扬帆起航！", "满载而归！", "海上霸主！",
        "船长威武！", "风浪无惧！", "夺宝成功！", "航路畅通！",
        "宝箱开启！", "金币闪闪！", "海战大捷！", "冒险精神！",
        "水手好样的！", "锚定胜利！", "探索新大陆！", "无敌舰队！",
        "征服大海！", "宝图在手！", "船长之王！", "乘风破浪！",
    },
    detective = {
        "案件侦破！", "真相大白！", "线索找到！", "推理正确！",
        "证据确凿！", "观察入微！", "蛛丝马迹！", "逻辑清晰！",
        "破案神速！", "洞察敏锐！", "水落石出！", "侦探之眼！",
        "完美推理！", "抽丝剥茧！", "一针见血！", "明察秋毫！",
        "谜题已解！", "头脑风暴！", "福尔摩斯！", "真相只有一个！",
    },
    artist = {
        "色彩绝妙！", "灵感迸发！", "妙笔生花！", "画龙点睛！",
        "栩栩如生！", "构图完美！", "艺术天才！", "笔触细腻！",
        "创意无限！", "大师手笔！", "光影绝伦！", "美感十足！",
        "杰作诞生！", "调色精准！", "想象力爆棚！", "画风独特！",
        "艺术之魂！", "灵动笔触！", "浑然天成！", "视觉盛宴！",
    },
    ninja = {
        "影分身术！", "一击必中！", "隐身成功！", "忍术高超！",
        "飞檐走壁！", "身手敏捷！", "暗器精准！", "风一样快！",
        "完美潜行！", "出其不意！", "忍者之道！", "无声无息！",
        "手里剑命中！", "瞬间移动！", "忍法奥义！", "速度惊人！",
        "影遁术！", "任务完成！", "忍者大师！", "疾风迅雷！",
    },
    doctor = {
        "诊断正确！", "药到病除！", "妙手回春！", "手术成功！",
        "健康满分！", "医术高明！", "对症下药！", "精确诊疗！",
        "治愈成功！", "恢复健康！", "白衣天使！", "悬壶济世！",
        "生命守护者！", "病历完美！", "处方精准！", "医者仁心！",
        "救死扶伤！", "体检通过！", "康复出院！", "元气满满！",
    },
}

-- ============================================================================
-- 各皮肤专属聊天台词（点击立绘触发，小知识 + 日常闲聊）
-- ============================================================================
---@type table<string, string[]>
local SKIN_CHATS = {
    default = {
        -- 小知识
        "你知道吗？狐狸的耳朵能独立转动，像雷达一样捕捉声音！",
        "北极狐的毛冬天是白色的，夏天会变成棕灰色哦~",
        "狐狸是犬科动物里唯一会爬树的！厉害吧？",
        "狐狸的尾巴冬天可以当被子盖，又暖和又蓬松~",
        "全世界大约有12种不同的狐狸，分布在各大洲！",
        "狐狸能听到地下老鼠的脚步声，听力超级灵敏！",
        "大脑每天消耗身体20%的能量，多动脑很费卡路里的~",
        "人的大脑有860亿个神经元，比银河系的星星还多！",
        "睡眠时大脑会整理白天学到的知识，所以要好好睡觉哦~",
        "多喝水能让大脑运转更快，记得补充水分！",
        -- 日常闲聊
        "今天天气真好，适合动动脑子！",
        "嗯~让我想想今天吃什么好呢……",
        "最近有没有发现自己变聪明了？",
        "休息一下吧，劳逸结合才是真道理~",
        "你每天都来陪我，我好开心！",
        "打个哈欠~不是因为无聊，是因为大脑需要氧气！",
        "来来来，我们再挑战一关吧！",
        "我刚才在想一个很难的谜题……算了不想了~",
        "你的脑力越来越强了，我很骄傲！",
        "嘿嘿，被你发现我在偷懒了~",
    },
    sport = {
        -- 小知识
        "人体最强壮的肌肉其实是舌头！没想到吧？",
        "奥运会最早只有一个项目——跑步！",
        "人类跑步时脚会承受体重3倍的冲击力！",
        "游泳能锻炼全身95%的肌肉群，是最全面的运动~",
        "打篮球平均每场要跑5公里，难怪那么累！",
        "科学证明，运动后大脑会分泌多巴胺，让人快乐！",
        "羽毛球是球速最快的球类运动，最快能到493公里/小时！",
        "人在运动时心跳可以加速到每分钟200次！",
        -- 日常闲聊
        "今天做了热身运动吗？先活动活动再开始！",
        "来，跟我一起做拉伸~一二三四……",
        "运动完要记得补充水分，咕咚咕咚~",
        "感觉浑身充满力量！冲冲冲！",
        "我刚做了50个俯卧撑！……好吧其实是5个",
        "休息也是训练的一部分，别太拼啦~",
        "保持运动的习惯，身体和大脑都会感谢你！",
        "教练说今天加练……等等我没有教练",
    },
    chef = {
        -- 小知识
        "辣椒素不溶于水，被辣到要喝牛奶才管用！",
        "世界上最贵的香料是藏红花，比黄金还贵！",
        "西红柿最初被认为有毒，没人敢吃！",
        "巧克力对狗有毒，千万不能给狗狗吃哦！",
        "蜂蜜永远不会变质，几千年前的蜂蜜现在还能吃！",
        "胡萝卜最早是紫色的，橙色是后来培育的品种~",
        "爆米花已有5000年历史，古人就爱吃零食！",
        "一个柠檬含有的维C比你一天需要的还多！",
        -- 日常闲聊
        "嗯~空气中飘来一阵香味，谁在做好吃的？",
        "今天想吃什么？我推荐红烧肉！",
        "做菜最重要的是火候，其次才是调料~",
        "我的拿手菜是煎蛋……别笑！煎蛋很考验技术的！",
        "吃饱了才有力气思考，这是科学道理！",
        "你吃早餐了吗？不吃早餐大脑会罢工的~",
        "想学一道新菜，等我研究研究菜谱……",
        "厨房是创造幸福的地方，和游戏一样！",
    },
    suit = {
        -- 小知识
        "世界上第一台计算机重达30吨，占整整一间房！",
        "全球每天产生的数据量超过2.5艾字节！",
        "领带最初是克罗地亚士兵的军服饰品~",
        "世界500强企业的CEO平均身高比普通人高6厘米！",
        "人在做决策时，大脑每秒处理约1100万条信息！",
        "最成功的谈判策略是先倾听，后发言~",
        "人的注意力平均只有8秒，比金鱼还短1秒！",
        "成功人士平均每年阅读50本以上的书！",
        -- 日常闲聊
        "今天的行程安排得很紧凑，不过一切尽在掌控~",
        "西装笔挺，精神百倍！今天状态不错。",
        "刚看了一份市场分析报告，收获很大~",
        "高效率的秘诀？先做最重要的事！",
        "偶尔放松也是一种投资，投资健康嘛~",
        "我觉得你很有潜力，继续保持！",
        "成功不是终点，而是一种态度~",
        "今天的会议……哦不对，今天是游戏时间！",
    },
    astronaut = {
        -- 小知识
        "在太空中宇航员会长高2到5厘米，因为脊柱没有重力压缩！",
        "国际空间站每天能看到16次日出和日落！",
        "一光年大约是9.46万亿公里，超级远！",
        "月球上的脚印能保存数百万年，因为没有风！",
        "太空闻起来像烧焦的牛排和金属味！",
        "太阳的体积可以装下130万个地球！",
        "火星上的一天比地球长37分钟~",
        "宇宙中的星星比地球上的沙粒还要多！",
        -- 日常闲聊
        "我在数星星……一颗、两颗……太多了数不过来！",
        "如果能去太空旅行，你最想去哪个星球？",
        "今天的星空一定很美，可惜白天看不到~",
        "我的梦想是在月球上建一座基地！",
        "太空服虽然酷，但穿起来其实超级热……",
        "收到来自远方的信号……原来是肚子饿了",
        "地球真的好美，从太空看一定更美！",
        "宇宙那么大，一定还有其他聪明的生命~",
    },
    worker = {
        -- 小知识
        "世界上最高的建筑是哈利法塔，828米！",
        "混凝土是人类使用量第二大的物质，仅次于水！",
        "古埃及金字塔的石块缝隙连刀片都插不进去！",
        "螺丝钉有超过3000种不同的规格型号！",
        "最长的跨海大桥是港珠澳大桥，全长55公里！",
        "一个标准足球场大约需要用掉9000平方米的草皮！",
        "电路板上的铜线比头发丝还细！",
        "3D打印技术已经能打印出房子了！",
        -- 日常闲聊
        "今天的工程进展顺利，蓝图已经确认！",
        "安全帽要戴好，安全第一！",
        "测量了三遍，数据完全吻合，开工！",
        "每一个细节都很重要，不能马虎~",
        "工具箱里少了个扳手……算了用手拧吧",
        "今天的项目提前完成了，奖励自己休息一下！",
        "好的工程师要有耐心，就像解谜题一样~",
        "图纸画好了，接下来就是施工啦！",
    },
    pirate = {
        -- 小知识
        "古代船长用星盘来测量纬度，是最早的导航工具！",
        "历史上有很多了不起的女航海家，安妮·邦妮就是最有名的一位！",
        "船上有严格的规章制度，船长负责带领大家安全航行！",
        "大航海时代的水手靠星星导航，没有GPS也能环游世界！",
        "海水之所以是咸的，是因为含有大量氯化钠！",
        "地球表面71%都是海洋，比陆地大得多！",
        "最深的海沟是马里亚纳海沟，深达11034米！",
        "章鱼有三颗心脏和蓝色的血液，超级神奇！",
        -- 日常闲聊
        "今天风向不错，适合出海冒险！",
        "我的藏宝图上画了个X，宝藏就在那里！",
        "当船长最重要的是……勇气和智慧！",
        "嘿嘿，我藏了一些金币在秘密基地~",
        "大海那么大，总有新的岛屿等着我们去发现！",
        "船长日记：今天天气晴，适合寻宝~",
        "想不想听我讲一个海上冒险的故事？",
        "啊，海风的味道，真让人精神振奋！",
    },
    detective = {
        -- 小知识
        "指纹从出生到死亡都不会改变，而且没有两个人的指纹相同！",
        "福尔摩斯是英国作家柯南·道尔创造的虚构人物！",
        "人说谎时瞳孔会放大，这是无法控制的生理反应！",
        "世界上最早的警察组织出现在古埃及！",
        "人的记忆力会受到情绪的影响，开心时记忆力更好！",
        "每个人走路的姿势都是独一无二的，叫做'步态识别'！",
        "墨水在紫外线下会发出荧光，可以用来检测伪造文件！",
        "人类的大脑可以存储约2.5PB的信息，相当于300万小时的视频！",
        -- 日常闲聊
        "嗯……这里有个可疑的线索，让我仔细看看。",
        "优秀的侦探要善于观察，每个细节都可能是关键！",
        "我的放大镜从不离手，随时准备破案！",
        "今天又是充满谜题的一天，太棒了！",
        "让我推理一下……你今天心情不错对吧？",
        "真相永远藏在细节里，你觉得呢？",
        "我刚破了一个超难的谜题……就是你给我出的关卡！",
        "做侦探和解谜游戏一样，都需要逻辑思维~",
    },
    artist = {
        -- 小知识
        "蒙娜丽莎其实很小，只有77厘米×53厘米！",
        "梵高一生中画了2000多幅作品，但生前只卖出过一幅！",
        "蓝色是全世界最受欢迎的颜色！",
        "人眼可以分辨大约1000万种不同的颜色！",
        "最早的颜料是用矿物和植物制作的，已有4万年历史！",
        "彩虹有七种颜色：红橙黄绿蓝靛紫~",
        "毕加索从9岁就开始画画，真正的少年天才！",
        "中国水墨画有两千多年的历史，是世界级的艺术瑰宝！",
        -- 日常闲聊
        "今天的灵感特别多，想画好多好多东西！",
        "你看，这朵云像不像一只兔子？艺术家的眼睛总能发现美~",
        "我最喜欢用暖色调，因为让人感觉温暖又开心！",
        "画画的时候心情特别平静，你也试试吧~",
        "哎呀，颜料沾到围裙上了……不过这也是一种艺术！",
        "每个人都是天生的艺术家，只是需要被发现~",
        "我在构思一幅新作品，灵感来自于你！",
        "色彩是会说话的，红色代表热情，蓝色代表宁静~",
    },
    ninja = {
        -- 小知识
        "忍者最早出现在日本的室町时代，已有600多年历史！",
        "真正的忍者不穿黑衣，而是穿深蓝或深褐色的衣服！",
        "手里剑其实不是忍者的主要武器，而是用来分散注意力的！",
        "忍者的训练从小时候就开始，包括跑步、游泳和攀爬！",
        "忍术中有'五遁术'：金木水火土，各有不同的逃脱方法！",
        "忍者食物讲究高能量低体积，方便随身携带！",
        "历史上有名的忍者叫服部半藏，在德川家康手下效力！",
        "猫的平衡感和忍者一样好，都能在窄小的地方行走自如！",
        -- 日常闲聊
        "嘘……我在练习隐身术，你看不到我~",
        "忍者最重要的品质是耐心，就像解谜一样！",
        "今天的修行很充实，体术又进步了！",
        "我能在屋顶上跑来跑去，你信不信？",
        "忍者不仅要身体灵活，头脑也要聪明！",
        "我的忍者卷轴上记录了好多秘术……其实是游戏攻略啦",
        "影子是忍者最好的朋友~",
        "今天我偷偷练习了飞檐走壁……结果摔了一跤，嘿嘿",
    },
    doctor = {
        -- 小知识
        "人体有206块骨头，但婴儿出生时有大约270块！",
        "心脏每天跳动大约10万次，一年就是3600万次！",
        "人体最小的骨头在耳朵里，叫做镫骨，只有3毫米！",
        "打喷嚏时气流速度可达160公里/小时！",
        "人类的胃酸可以溶解金属，但胃壁有保护层不会被腐蚀！",
        "多吃蔬菜水果能让大脑更健康，记忆力更好！",
        "笑一次可以锻炼15块面部肌肉！",
        "人每天大约眨眼15000到20000次！",
        -- 日常闲聊
        "记得多喝水，保持身体健康！",
        "今天的体检报告一切正常，你很健康！",
        "医生的工作就是让每个人都开开心心的~",
        "勤洗手是预防生病最简单有效的方法！",
        "要按时吃饭、按时睡觉，这是健康的基本功~",
        "今天有没有运动？适量运动对身体很好哦！",
        "我的听诊器说，你的心跳很有力，棒棒的！",
        "做完游戏记得休息眼睛，保护视力很重要~",
    },
}

--- id -> 配置的快速索引
---@type table<string, table>
local skinById_ = {}
for _, s in ipairs(SKINS) do
    skinById_[s.id] = s
end

-- ============================================================================
-- 内部状态
-- ============================================================================
---@type string 当前选中的皮肤 ID
local currentId_ = "default"

---@type function[] 皮肤变更回调列表
local changeListeners_ = {}

---@type table<string, boolean> 已购买的皮肤 ID 集合
local purchasedSkins_ = {}

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 判断皮肤是否已解锁
---@param skinId string
---@return boolean
function M.isUnlocked(skinId)
    local skin = skinById_[skinId]
    if not skin then return false end
    if not skin.unlock then return true end  -- 无解锁条件 = 始终解锁

    if skin.unlock.type == "story" then
        local Storyline = require("modules.storyline.init")
        return Storyline.getNodeState(skin.unlock.nodeId) == "done"
    elseif skin.unlock.type == "purchase" then
        return purchasedSkins_[skinId] == true
    end

    return true
end

--- 获取皮肤锁定原因（未解锁时返回描述，已解锁返回 nil）
---@param skinId string
---@return table|nil  { type, label }
function M.getLockReason(skinId)
    if M.isUnlocked(skinId) then return nil end
    local skin = skinById_[skinId]
    if skin and skin.unlock then
        return { type = skin.unlock.type, label = skin.unlock.label }
    end
    return nil
end

--- 应用皮肤 ID（内部公共逻辑，校验 + 回退）
---@param id string
---@return string 最终使用的 skinId
local function applyOutfitId(id)
    if skinById_[id] then
        if not M.isUnlocked(id) then
            logger.warn(MODULE, "applyOutfitId", "outfit '" .. id .. "' is locked, fallback to default")
            return "default"
        end
        return id
    end
    logger.warn(MODULE, "applyOutfitId", "unknown outfit id: " .. tostring(id) .. ", fallback to default")
    return "default"
end

--- 通知所有变更监听器
local function notifyListeners()
    for _, fn in ipairs(changeListeners_) do
        fn(currentId_)
    end
end

--- 初始化（从云端加载当前皮肤和已购买列表），在 main.lua Start() 中调用
function M.init()
    currentId_ = "default"
    purchasedSkins_ = {}

    if clientCloud then
        -- 加载已购买皮肤列表
        clientCloud:Get("outfit_purchased", {
            ok = function(values, iscores)
                local purchasedData = values and values["outfit_purchased"]
                if purchasedData and type(purchasedData) == "table" then
                    for k, v in pairs(purchasedData) do
                        if v == true and skinById_[k] then
                            purchasedSkins_[k] = true
                        end
                    end
                    logger.info(MODULE, "init", "restored purchased skins from cloud")
                end
            end,
            error = function(code, reason)
                logger.warn(MODULE, "init", "cloud get outfit_purchased failed: " .. tostring(code) .. " " .. tostring(reason))
            end,
        })

        -- 加载当前皮肤
        clientCloud:Get("outfit_skin", {
            ok = function(values, iscores)
                local data = values and values["outfit_skin"]
                if data and type(data) == "table" and data.skinId then
                    local cloudId = data.skinId
                    if not skinById_[cloudId] then
                        logger.warn(MODULE, "init", "unknown cloud skinId: " .. tostring(cloudId) .. ", fallback to default")
                        cloudId = "default"
                    end
                    if cloudId ~= currentId_ then
                        currentId_ = cloudId
                        logger.info(MODULE, "init", "cloud outfit applied: " .. cloudId)
                        notifyListeners()
                    end
                else
                    logger.info(MODULE, "init", "cloud has no outfit data, using default")
                end
            end,
            error = function(code, reason)
                logger.warn(MODULE, "init", "cloud get outfit_skin failed: " .. tostring(code) .. " " .. tostring(reason))
            end,
        })
    end
end

--- 注册皮肤变更回调（云端加载完成或 setCurrent 时触发）
---@param fn fun(skinId: string)
function M.onChange(fn)
    changeListeners_[#changeListeners_ + 1] = fn
end

--- 获取当前皮肤 ID
---@return string
function M.getCurrent()
    return currentId_
end

--- 获取当前皮肤的贴图路径
---@return string
function M.getTexturePath()
    local skin = skinById_[currentId_]
    return skin and skin.texture or SKINS[1].texture
end

--- 获取当前皮肤名称
---@return string
function M.getCurrentName()
    local skin = skinById_[currentId_]
    return skin and skin.name or SKINS[1].name
end

--- 设置当前皮肤并持久化
---@param skinId string
---@return boolean 是否设置成功
function M.setCurrent(skinId)
    if not skinById_[skinId] then
        logger.warn(MODULE, "setCurrent", "unknown skin id: " .. tostring(skinId))
        return false
    end
    if not M.isUnlocked(skinId) then
        logger.warn(MODULE, "setCurrent", "skin '" .. skinId .. "' is locked")
        return false
    end
    if skinId == currentId_ then
        return true
    end
    currentId_ = skinId

    -- 持久化云端
    if clientCloud then
        clientCloud:Set("outfit_skin", { skinId = skinId }, {
            ok = function()
                logger.info(MODULE, "setCurrent", "cloud saved: " .. skinId)
            end,
            error = function(code, reason)
                logger.warn(MODULE, "setCurrent", "cloud save failed: " .. tostring(code) .. " " .. tostring(reason))
            end,
        })
    end

    logger.info(MODULE, "setCurrent", "changed to: " .. skinId)
    return true
end

--- 获取全部皮肤列表
---@return table[] { id, name, texture }
function M.getAllSkins()
    return SKINS
end

--- 通过 ID 获取皮肤配置
---@param skinId string
---@return table|nil
function M.getSkinById(skinId)
    return skinById_[skinId]
end

--- 获取当前皮肤的专属夸奖台词列表
---@return string[]
function M.getPraises()
    return SKIN_PRAISES[currentId_] or SKIN_PRAISES["default"]
end

--- 获取当前皮肤的专属聊天台词列表（小知识 + 日常闲聊）
---@return string[]
function M.getChats()
    return SKIN_CHATS[currentId_] or SKIN_CHATS["default"]
end

--- 获取皮肤价格
---@param skinId string
---@return number|nil 价格（元），nil 表示非购买类皮肤
function M.getPrice(skinId)
    local skin = skinById_[skinId]
    if skin and skin.unlock and skin.unlock.type == "purchase" then
        return skin.unlock.price or 3
    end
    return nil
end

--- 判断皮肤是否为购买类型
---@param skinId string
---@return boolean
function M.isPurchaseType(skinId)
    local skin = skinById_[skinId]
    return skin and skin.unlock and skin.unlock.type == "purchase"
end

--- 重置所有购买状态（清空存档时调用）
--- 清除内存中的已购买记录，并将皮肤切回默认
function M.resetPurchases()
    purchasedSkins_ = {}
    if currentId_ ~= "default" and M.isPurchaseType(currentId_) then
        currentId_ = "default"
        -- 持久化默认皮肤到云端
        if clientCloud then
            clientCloud:Set("outfit_skin", { skinId = "default" }, {
                ok = function()
                    logger.info(MODULE, "resetPurchases", "cloud skin reset to default")
                end,
                error = function(code, reason)
                    logger.warn(MODULE, "resetPurchases", "cloud reset failed: " .. tostring(code) .. " " .. tostring(reason))
                end,
            })
        end
        notifyListeners()
    end
    logger.info(MODULE, "resetPurchases", "all purchases cleared")
end

--- 模拟购买皮肤（解锁并持久化到云端）
---@param skinId string
---@param callback fun(success: boolean, msg: string)|nil
function M.purchaseSkin(skinId, callback)
    local skin = skinById_[skinId]
    if not skin then
        if callback then callback(false, "未知皮肤") end
        return
    end
    if not skin.unlock or skin.unlock.type ~= "purchase" then
        if callback then callback(false, "该皮肤无法购买") end
        return
    end
    if purchasedSkins_[skinId] then
        if callback then callback(false, "已购买") end
        return
    end

    -- 标记为已购买
    purchasedSkins_[skinId] = true

    -- 持久化到云端
    if clientCloud then
        clientCloud:Set("outfit_purchased", purchasedSkins_, {
            ok = function()
                logger.info(MODULE, "purchaseSkin", "cloud saved purchased: " .. skinId)
            end,
            error = function(code, reason)
                logger.warn(MODULE, "purchaseSkin", "cloud save failed: " .. tostring(code) .. " " .. tostring(reason))
            end,
        })
    end

    logger.info(MODULE, "purchaseSkin", "purchased: " .. skinId)
    if callback then callback(true, "购买成功") end
end

return M
