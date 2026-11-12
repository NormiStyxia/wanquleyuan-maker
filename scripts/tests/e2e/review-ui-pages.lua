--- 捕获实际 Yoga 控件/棋盘/图标绘制命令；供手绘换肤预览，不冒充原生截图。
---@diagnostic disable: undefined-global
local Trace=require("devtools.adventure-art-trace")
require("tests.e2e.validate-ui-pages")
local UI=require("urhox-libs/UI")
local F=require("tests.e2e.game-skin-fixture")
local function capture(label)
    print("[UIPaperPage] "..label)
    Trace.request();Trace.begin();UI.Render()
    local w,h=UI.GetViewportSize();Trace.finish(w,h,"packed")
end
V.atFrame(22,function() capture("隐私政策") end)
V.atFrame(60,function() capture("模拟实名认证") end)
V.atFrame(94,function() capture("休息提醒") end)
V.atFrame(154,function() capture("未成年人保护提示") end)
local function raw(label,render)
    local w,h=require("shared.utils.density").getGameSize()
    local vg=UI.GetNVGContext()
    print("[UIPaperPage] "..label)
    nvgBeginFrame(vg,w,h,1);Trace.request();Trace.begin()
    render(vg,w,h);Trace.finish(w,h,"packed");nvgEndFrame(vg)
end
V.atFrame(156,function()
    raw("摆正棋盘",function(vg,w,h) F.page=1;F.draw(vg,w,h) end)
end)
V.atFrame(158,function()
    raw("大厅图标与导航",function(vg,w,h)
        nvgBeginPath(vg);nvgRect(vg,0,0,w,h);nvgFillColor(vg,nvgRGBA(255,246,220,255));nvgFill(vg)
        local Card=require("shared.components.game-card")
        local data={{"p1-puzzle-land","推箱子","动动脑筋"},{"p2-memory-flip","记忆翻牌","记住每一个图案"},
            {"p3-match-3","消消乐","连出小惊喜"},{"p4-link-match","连连看","找到相同图案"}}
        local size=(w-54)/2
        for i,d in ipairs(data) do
            Card.drawTile(vg,18+((i-1)%2)*(size+18),100+math.floor((i-1)/2)*(size+18),size,
                {gameId=d[1],title=d[2],subtitle=d[3]},i)
        end
        require("shared.components.tab-bar").render(vg,w,h,"home",0,"sans",nil,{handdrawn=true})
    end)
end)
