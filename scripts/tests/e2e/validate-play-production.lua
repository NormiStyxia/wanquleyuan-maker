--- Exercise production gameplay.render, not just isolated renderer calls. No save callbacks.
---@diagnostic disable: undefined-global
local F=require("tests.e2e.game-skin-fixture")
local Fox=require("shared.components.fox-mascot")
local current,initialized,lastPage
local names={'p1-puzzle-land','p2-memory-flip','p3-match-3','p4-link-match'}
local function enter(index)
    if current then current.leave() end
    current=require('games.'..names[index]..'.screens.gameplay')
    local level=require('config.storyline-levels.story-'..index)
    local options={storylineMode=true,hasNextLevel=false}
    if index==1 then
        level=assert(require('games.p1-puzzle-land.logic.level-loader').load(level))
        current.enter(level,options)
    else current.enter(level,{completedLevels={}},options) end
    lastPage=index
end
F.update=function(dt) if current then current.update(dt) end;Fox.update(dt) end
F.draw=function(vg,w,h)
    if not initialized then Fox.init(vg);initialized=true end
    if current then current.render(vg,w,h,function() Fox.render(vg,w,h,lastPage==4 and 34 or 0,{handdrawn=true}) end) end
end
for i=1,4 do
    V.atFrame(4+(i-1)*18,function() enter(i) end)
    V.atFrame(16+(i-1)*18,function() V.assert(current.isActive(),'生产页面保持活跃：'..names[i]) end)
end
V.atFrame(80,function() current.leave();V.assert(not current.isActive(),'离开页面清理棋盘状态');current=nil;V.finish() end)
