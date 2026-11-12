--- 章节数据定义
--- 职责：章节列表 + 章节查找辅助

local M = {}

-- ============================================================================
-- 章节定义（对应 storyline.lua 中的注释结构）
-- ============================================================================
---@class ChapterDef
---@field name string 章节名称
---@field startNode number 起始节点索引（1-based）
---@field endNode number 结束节点索引（1-based，含）

---@type ChapterDef[]
M.CHAPTERS = {
    { name = "第一章：入门之旅",   startNode = 1,  endNode = 7  },
    { name = "第二章：进阶挑战",   startNode = 8,  endNode = 14 },
    { name = "第三章：精英试炼",   startNode = 15, endNode = 21 },
    { name = "第四章：奇迹觉醒",   startNode = 22, endNode = 28 },
    { name = "第五章：永恒之巅",   startNode = 29, endNode = 35 },
}

--- 游戏类型标签配色
M.GAME_TYPE_COLORS = {
    ["p1-puzzle-land"] = { 255, 150, 80 },
    ["p2-memory-flip"] = { 100, 200, 160 },
    ["p3-match-3"]     = { 180, 130, 255 },
    ["p4-link-match"]  = { 255, 120, 140 },
}

--- 游戏类型显示名称
M.GAME_TYPE_NAMES = {
    ["p1-puzzle-land"] = "推箱子",
    ["p2-memory-flip"] = "记忆翻牌",
    ["p3-match-3"]     = "消消乐",
    ["p4-link-match"]  = "连连看",
}

--- 获取指定节点索引所属的章节索引
---@param nodeIdx number 全局节点索引（1-based）
---@return number 章节索引（1-based）
function M.getChapterForNode(nodeIdx)
    for i, ch in ipairs(M.CHAPTERS) do
        if nodeIdx >= ch.startNode and nodeIdx <= ch.endNode then
            return i
        end
    end
    return 1
end

--- 获取章节总数（地图按章节分页：一章一页，总页数 = 章节数）
---@return number
function M.getChapterCount()
    return #M.CHAPTERS
end

--- 获取指定页（章节）对应的全局节点索引范围
---@param chapterIdx number 章节索引（1-based，即页码）
---@param nodeCount number 节点总数（用于裁剪最后一章，防止配置缺失时越界）
---@return number pageStart, number pageEnd
function M.getPageNodeRange(chapterIdx, nodeCount)
    local ch = M.CHAPTERS[chapterIdx] or M.CHAPTERS[1]
    return ch.startNode, math.min(ch.endNode, nodeCount)
end

return M
