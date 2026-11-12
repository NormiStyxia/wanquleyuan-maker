--- 全部主题实际资源、棋盘叠加与跨上下文资源生命周期；不读写用户进度。
---@diagnostic disable: undefined-global
local UI=require("urhox-libs/UI")
local Bg=require("shared.background-manager")
local F=require("tests.e2e.game-skin-fixture")
local Trace=require("devtools.adventure-art-trace")
local pending,seen,firstVg
seen={}
local create=nvgCreateImage
nvgCreateImage=function(vg,path,flags)
    local handle=create(vg,path,flags)
    if path:find("LevelThemes/",1,true) or path:find("handdrawn/backgrounds/",1,true) then
        V.assert(handle and handle>0,"实际背景可加载："..path)
        if handle and handle>0 then
            local w,h=nvgImageSize(vg,handle)
            V.assert(math.abs(w/h-9/20)<0.001,"背景保持9:20："..path)
            seen[path]=true
        end
    end
    return handle
end
local draw=F.draw
F.draw=function(vg,w,h)
    firstVg=vg
    if pending then
        print("[GameSkinPage] "..pending);Trace.request();Trace.begin()
    end
    draw(vg,w,h)
    if pending then Trace.finish(w,h,"packed");pending=nil end
end
V.atFrame(8,function()
    local a,b=nvgCreate(1),nvgCreate(1)
    local count,deleted=0,0
    local make,del=nvgCreateImage,nvgDeleteImage
    nvgCreateImage=function(...) count=count+1;return make(...) end
    nvgDeleteImage=function(...) deleted=deleted+1;return del(...) end
    local cfg=Bg.getAll()[1]
    local function paint(vg)
        nvgBeginFrame(vg,100,200,1)
        Bg.renderBackground(vg,90,200,0,cfg)
        nvgEndFrame(vg)
    end
    paint(a);paint(b);paint(a);paint(b)
    V.assert(count==2,"交替上下文只各自解码一次背景")
    Bg.clearThemeCache(a)
    V.assert(deleted==1,"离开页面释放所属背景图片")
    paint(b)
    V.assert(count==2,"释放一个页面不破坏另一个页面缓存")
    Bg.clearThemeCache(a)
    V.assert(deleted==1,"重复释放不删除失效句柄")
    Bg.clearThemeCache(b)
    V.assert(deleted==2,"所有背景句柄均有归属并释放")
    nvgCreateImage,nvgDeleteImage=make,del
    nvgDelete(a);nvgDelete(b)
end)
local themes={"garden","starlight","ice","candy","maze","rainbow","starry_sky","mist","chain","aurora","kaleidoscope","eternal_garden"}
for index,name in ipairs(themes) do
    local at=18+(index-1)*8
    V.atFrame(at,function()
        F.page=(index-1)%4+1
        F.background=Bg.getBackgroundForLevel({themeBackground="Textures/LevelThemes/"..name..".png"})
    end)
    V.atFrame(at+4,function() pending="主题·"..name end)
end
for index,bg in ipairs(Bg.getAll()) do
    V.atFrame(122+(index-1)*4,function()
        F.background=bg
        F.page=(index-1)%4+1
        local vg=UI.GetNVGContext()
        nvgBeginFrame(vg,200,200*20/9,1)
        Bg.renderBackground(vg,200,200*20/9,0,bg)
        nvgEndFrame(vg)
        V.assert(bg.themeImage and bg.previewImage and not bg.decorations,"装扮采用真实手绘插画："..bg.id)
    end)
    V.atFrame(124+(index-1)*4,function() pending="壁纸·"..bg.id end)
end
V.atFrame(154,function()
    for _,name in ipairs(themes) do V.assert(seen["Textures/LevelThemes/"..name..".png"],"覆盖关卡主题："..name) end
    for _,bg in ipairs(Bg.getAll()) do
        V.assert(seen[bg.previewImage],"覆盖小预览："..bg.id)
        V.assert(seen[bg.themeImage],"覆盖实际应用壁纸："..bg.id)
    end
    Bg.clearThemeCache(firstVg);Bg.clearThemeCache(UI.GetNVGContext())
    nvgCreateImage=create
    V.finish()
end)
