--- 仅供美术排版预览：记录真实渲染器提交的矢量命令。产物不等于引擎截图。
local M = {}
local active_, requested_, commands_, colors_, paints_, images_ = false, false, {}, {}, {}, {}
local originalImage = nvgCreateImage
nvgCreateImage = function(vg, path, flags)
    local image = originalImage(vg, path, flags)
    -- 图片句柄仅在所属上下文内唯一，装扮页和 UI 弹窗可以同时持有相同整数句柄。
    images_[vg] = images_[vg] or {}
    images_[vg][image] = path
    return image
end
local rgba = nvgRGBA
nvgRGBA = function(r, g, b, a)
    local c = rgba(r, g, b, a)
    colors_[tostring(c)] = {r, g, b, a}
    return c
end
local pattern = nvgImagePattern
nvgImagePattern = function(vg, x, y, w, h, angle, image, alpha)
    local paint = pattern(vg, x, y, w, h, angle, image, alpha)
    if active_ then paints_[tostring(paint)] = {x = x, y = y, w = w, h = h, image = images_[vg] and images_[vg][image], alpha = alpha} end
    return paint
end
for _, name in ipairs({"nvgBeginPath", "nvgMoveTo", "nvgLineTo", "nvgBezierTo", "nvgQuadTo", "nvgClosePath",
    "nvgRect", "nvgRoundedRect", "nvgCircle", "nvgEllipse", "nvgArc", "nvgFill", "nvgStroke", "nvgStrokeWidth", "nvgLineCap", "nvgLineJoin",
    "nvgFontFace", "nvgFontSize", "nvgTextAlign", "nvgText", "nvgTextBox", "nvgTextLineHeight", "nvgTextLetterSpacing",
    "nvgSave", "nvgRestore", "nvgTranslate", "nvgRotate",
    "nvgScale", "nvgGlobalAlpha", "nvgScissor", "nvgIntersectScissor", "nvgResetScissor", "nvgFillColor", "nvgStrokeColor", "nvgFillPaint"}) do
    local fn = _G[name]
    _G[name] = function(vg, ...)
        if active_ then
            local args = {...}
            if name == "nvgFillColor" or name == "nvgStrokeColor" then args = colors_[tostring(args[1])] or {}
            elseif name == "nvgFillPaint" then args = { paints_[tostring(args[1])] or {} }
            elseif name == "nvgTextBox" then args = {args[1], args[2], args[3], args[4]} end
            commands_[#commands_ + 1] = {op = name, args = args}
        end
        return fn(vg, ...)
    end
end
function M.request() requested_ = true end
function M.begin()
    active_ = requested_
    requested_ = false
    if active_ then commands_, paints_ = {}, {} end
end
function M.finish(w, h, compact)
    if not active_ then return end
    active_ = false
    print("[AdventureArtTraceStart] " .. cjson.encode({w = w, h = h}))
    if compact=="packed" then
        for first=1,#commands_,64 do
            local batch={}
            for index=first,math.min(first+63,#commands_) do
                local cmd=commands_[index]
                batch[#batch+1]={index,cmd.op,cmd.args}
            end
            print("[GameSkinTraceBatch] "..cjson.encode(batch))
        end
        print("[AdventureArtTraceEnd]")
        return
    end
    if compact then
        -- 小卡片按批输出，避免逐条日志挤掉前面的验收证据。旧选关重放格式保持不变。
        for first = 1, #commands_, 16 do
            local batch = {}
            for index = first, math.min(first + 15, #commands_) do
                commands_[index].seq = index
                batch[#batch + 1] = commands_[index]
            end
            print("[StoryCardTraceBatch] " .. cjson.encode(batch))
        end
        print("[AdventureArtTraceEnd]")
        return
    end
    for index, command in ipairs(commands_) do
        command.seq = index -- 避免日志去重吞掉重复的 BeginPath / Fill 命令。
        print("[AdventureArtTraceOp] " .. cjson.encode(command))
    end
    print("[AdventureArtTraceEnd]")
end
return M
