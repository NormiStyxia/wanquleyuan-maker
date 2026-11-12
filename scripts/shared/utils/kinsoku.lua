--- 中文排版避头尾（禁则）处理工具
--- 对文本进行预处理，在合适位置插入换行符，确保标点不会出现在行首
--- 提供两种接口：
---   M.wrap(text, maxWidth, fontSize)        — 使用 UI.MeasureTextWidth（适用于 UI 组件）
---   M.wrapNvg(vg, text, maxWidth)           — 使用 nvgTextBounds（适用于 NanoVG 直接渲染，调用前需已设好字体/字号）

local M = {}

-- 行首禁止字符（不能出现在行首的标点）
-- 使用 [[...]] 长字符串避免 Unicode 引号干扰 Lua 字符串解析
local NO_START = {}
for _, ch in utf8.codes([[，。、；：！？）】》」』"'…—·～%)!?,.:;]]) do
    NO_START[utf8.char(ch)] = true
end

-- 行尾禁止字符（不能出现在行尾的标点）
local NO_END = {}
for _, ch in utf8.codes([[（【《「『"'(]]) do
    NO_END[utf8.char(ch)] = true
end

--- 将 UTF-8 字符串拆分为字符数组
---@param s string
---@return string[]
local function splitChars(s)
    local chars = {}
    for _, code in utf8.codes(s) do
        chars[#chars + 1] = utf8.char(code)
    end
    return chars
end

--- 核心换行逻辑（接收已测量好的字符宽度数组）
---@param chars string[] 字符数组
---@param widths number[] 每个字符的像素宽度
---@param maxWidth number 最大行宽
---@return string 处理后的文本（含 \n）
local function doWrap(chars, widths, maxWidth)
    local n = #chars
    local lines = {}
    local lineStart = 1
    local lineWidth = 0

    local i = 1
    while i <= n do
        local ch = chars[i]

        -- 遇到原文换行符，直接断行
        if ch == "\n" then
            lines[#lines + 1] = table.concat(chars, "", lineStart, i - 1)
            lineStart = i + 1
            lineWidth = 0
            i = i + 1
        else
            local newWidth = lineWidth + widths[i]

            if newWidth <= maxWidth then
                lineWidth = newWidth
                i = i + 1
            else
                -- 超出行宽，需要断行
                local breakBefore = i

                -- 避头规则：下一行首字符不能是禁止行首字符
                if breakBefore <= n and NO_START[chars[breakBefore]] then
                    while breakBefore > lineStart and NO_START[chars[breakBefore]] do
                        breakBefore = breakBefore - 1
                    end
                    if breakBefore <= lineStart then
                        breakBefore = i
                    end
                end

                -- 避尾规则：当前行末字符不能是禁止行尾字符
                if breakBefore > lineStart and NO_END[chars[breakBefore - 1]] then
                    breakBefore = breakBefore - 1
                    if breakBefore <= lineStart then
                        breakBefore = i
                    end
                end

                lines[#lines + 1] = table.concat(chars, "", lineStart, breakBefore - 1)
                lineStart = breakBefore
                lineWidth = 0
                i = breakBefore
            end
        end
    end

    -- 最后一行
    if lineStart <= n then
        lines[#lines + 1] = table.concat(chars, "", lineStart, n)
    end

    return table.concat(lines, "\n")
end

--- 使用 UI.MeasureTextWidth 进行避头尾换行（适用于 UI 组件）
--- 需要 UI.Init() 已完成
---@param text string 原始文本
---@param maxWidth number 最大行宽（基础像素）
---@param fontSize number 字号（pt）
---@param fontFamily string|nil 字体族（默认 "sans"）
---@return string 处理后的文本（含 \n）
function M.wrap(text, maxWidth, fontSize, fontFamily)
    if not text or text == "" or maxWidth <= 0 then return text end

    local UI = require("urhox-libs/UI")
    local Theme = require("urhox-libs/UI/Core/Theme")

    fontFamily = fontFamily or "sans"
    local nvgFS = Theme.FontSize(fontSize)

    local chars = splitChars(text)
    local n = #chars
    if n == 0 then return text end

    local widths = {}
    for idx = 1, n do
        widths[idx] = UI.MeasureTextWidth(chars[idx], nvgFS, fontFamily)
    end

    return doWrap(chars, widths, maxWidth)
end

--- 使用 NanoVG 上下文直接测量进行避头尾换行（适用于 NanoVG 直接渲染的组件）
--- 调用前必须已在 vg 上设好 nvgFontFace + nvgFontSize
---@param vg userdata NanoVG 上下文
---@param text string 原始文本
---@param maxWidth number 最大行宽（像素）
---@return string 处理后的文本（含 \n）
function M.wrapNvg(vg, text, maxWidth)
    if not vg or not text or text == "" or maxWidth <= 0 then return text end

    local chars = splitChars(text)
    local n = #chars
    if n == 0 then return text end

    local widths = {}
    for idx = 1, n do
        widths[idx] = nvgTextBounds(vg, 0, 0, chars[idx]) or 0
    end

    return doWrap(chars, widths, maxWidth)
end

return M
