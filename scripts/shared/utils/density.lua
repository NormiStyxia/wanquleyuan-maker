--- 屏幕密度缩放因子
--- 让 NanoVG 绘制的 UI 在平板等大屏上保持与手机一致的视觉比例
local M = {}

--- 基准高度（逻辑像素），对应 iPhone Plus/Max 系列（竖屏高度）
local PHONE_REF = 896

--- 最大宽高比（width / height），超过时两侧加黑边
local MAX_RATIO = 1.0 / 1.2  -- 0.833

--- 缓存
local cachedW_ = 0
local cachedH_ = 0
local cachedFactor_ = 1.0

--- beginFrame 缓存（供 toGameCoords / getGameSize 使用）
local cachedOffsetX_ = 0
local cachedGameW_ = 0
local cachedGameH_ = 0

--- 获取密度缩放因子
--- 手机上 ≈ 1.0，平板上 > 1.0
---@return number factor
function M.getFactor()
    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    if w == cachedW_ and h == cachedH_ then return cachedFactor_ end
    cachedW_, cachedH_ = w, h
    local dpr = graphics:GetDPR()
    local heightLogical = h / dpr
    local factor = heightLogical / PHONE_REF
    factor = math.max(0.85, math.min(factor, 2.5))
    cachedFactor_ = factor
    return factor
end

--- 获取缩放后的 nvgBeginFrame 参数
---@return number logW 缩放后逻辑宽度
---@return number logH 缩放后逻辑高度
---@return number scale 传给 nvgBeginFrame 的第三个参数
function M.getScaledFrame()
    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local factor = M.getFactor()
    local scale = dpr * factor
    return w / scale, h / scale, scale
end

--- 开始 NanoVG 帧，自动处理宽屏黑边 + 居中
--- 替代手动调用 nvgBeginFrame
---@param vg userdata NanoVG 上下文
---@return number gameW 游戏区逻辑宽度
---@return number gameH 游戏区逻辑高度
function M.beginFrame(vg)
    local w = graphics:GetWidth()
    local h = graphics:GetHeight()
    local dpr = graphics:GetDPR()
    local factor = M.getFactor()
    local scale = dpr * factor

    local fullLogW = w / scale
    local fullLogH = h / scale

    local gameW = fullLogW
    local offsetX = 0
    if fullLogW / fullLogH > MAX_RATIO then
        gameW = fullLogH * MAX_RATIO
        offsetX = (fullLogW - gameW) / 2
    end

    cachedOffsetX_ = offsetX
    cachedGameW_ = gameW
    cachedGameH_ = fullLogH

    nvgBeginFrame(vg, fullLogW, fullLogH, scale)

    -- 超宽时绘制黑色背景（游戏内容会覆盖中间区域）
    if offsetX > 0 then
        nvgBeginPath(vg)
        nvgRect(vg, 0, 0, fullLogW, fullLogH)
        nvgFillColor(vg, nvgRGBA(0, 0, 0, 255))
        nvgFill(vg)
    end

    -- 平移 + 裁剪到游戏区
    nvgSave(vg)
    nvgTranslate(vg, offsetX, 0)
    nvgScissor(vg, 0, 0, gameW, fullLogH)

    return gameW, fullLogH
end

--- 结束 NanoVG 帧（与 beginFrame 配对）
---@param vg userdata NanoVG 上下文
function M.endFrame(vg)
    local ok, ScreenTransition = pcall(require, "shared.components.screen-transition")
    if ok and ScreenTransition and ScreenTransition.isAnimating() then
        ScreenTransition.renderNanoVG(vg, cachedGameW_, cachedGameH_)
    end
    nvgRestore(vg)
    nvgEndFrame(vg)
end

--- 物理输入坐标转换为游戏区逻辑坐标
---@param physX number 物理像素 X
---@param physY number 物理像素 Y
---@return number gameX 游戏区逻辑 X
---@return number gameY 游戏区逻辑 Y
function M.toGameCoords(physX, physY)
    local scale = graphics:GetDPR() * M.getFactor()
    return physX / scale - cachedOffsetX_, physY / scale
end

--- 获取当前游戏区逻辑尺寸（由最近一次 beginFrame 计算）
---@return number gameW
---@return number gameH
function M.getGameSize()
    return cachedGameW_, cachedGameH_
end

return M
