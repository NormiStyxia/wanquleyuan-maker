--- 公共页面头部组件
--- 提取自首页、冒险页、换装页的重复标题渲染代码
--- 支持通过配置表自定义标题文字、字体、大小、副标题、装饰间距等

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local M = {}

--- 预设配置：首页
M.PRESET_HOME = {
    fontName = "menu",
    titleText = "玩趣乐园",
    titleSize = 30,
    titleY = nil,          -- nil 表示由 curY 动态计算（curY + 28）
    subtitle = "自由模式",
    starSpread = 120,
    lineW = 28,
    lineGap = 90,
    gradientSpread = 80,
    bgGradientBottom = nil, -- nil 表示 titleY + 50
}

--- 预设配置：冒险页
M.PRESET_ADVENTURE = {
    fontName = "adv",
    titleText = "玩趣乐园",
    titleSize = 30,
    titleY = 58,
    subtitle = "主线冒险模式",
    starSpread = 120,
    lineW = 28,
    lineGap = 90,
    gradientSpread = 80,
    bgGradientTop = 0,
    bgGradientBottom = 110, -- HEADER_H(90) + 20
}

--- 预设配置：换装页
M.PRESET_PROFILE = {
    fontName = "profile",
    titleText = "装扮",
    titleSize = 26,
    titleY = 52,
    subtitle = nil,        -- 无副标题
    starSpread = 80,
    lineW = 22,
    lineGap = 60,
    gradientSpread = 50,
    bgGradientTop = 0,
    bgGradientBottom = 92, -- titleY(52) + 40
}

--- 渲染页面头部
--- @param vg userdata NanoVG 上下文
--- @param screenW number 屏幕宽度
--- @param preset table 预设配置表
--- @param curY number|nil 动态起始 Y（仅首页使用，其他页面传 nil）
--- @return number|nil 新的 curY（仅首页返回，其他页面返回 nil）
function M.render(vg,screenW,preset,curY)
    local y=preset.titleY or ((curY or 0)+28)
    local size=preset.titleSize or 30
    local w=math.min(screenW-40,math.max(136,utf8.len(preset.titleText)*size+44))
    Paper.panel(vg,(screenW-w)/2,y-size*0.8,w,size*1.6)
    Paper.text(vg,screenW/2,y,preset.titleText,size,C.ink,nil,preset.fontName)
    if preset.subtitle then
        Paper.text(vg,screenW/2,y+size*0.8+19,preset.subtitle,14,C.muted,nil,preset.fontName)
    end
    if curY then return y+size*0.8+(preset.subtitle and 34 or 8) end
end
return M
