--- 验收专用：真实棋盘与渲染器，不写存档、不经过付费和进度回调。
local M={page=1,elapsed=0,layouts={},hits={}}
local Art=require("shared.constants.art")
local P1=require("games.p1-puzzle-land.view.board-renderer")
local P2=require("games.p2-memory-flip.view.card-renderer")
local P3=require("games.p3-match-3.view.board-renderer")
local P4=require("games.p4-link-match.view.board-renderer")
local H2=require("games.p2-memory-flip.view.hud-renderer")
local H3=require("games.p3-match-3.view.hud-renderer")
local H4=require("games.p4-link-match.view.hud-renderer")
local Paper=require("shared.components.game-paper")
local Layout=require("shared.constants.layout")
local Scenery=require("shared.rendering.game-scenery")
local Fox=require("shared.components.fox-mascot")
local Result=require("shared.components.result-popup")
local Pause=require("shared.components.pause-overlay")
M.renderers={P1,P2,P3,P4}
function M.setup()
    local loader=require("games.p1-puzzle-land.logic.level-loader")
    local level,err=loader.load(require("config.storyline-levels.story-1"))
    assert(level,err)
    M.boards={require("games.p1-puzzle-land.logic.board").new(level),
        require("games.p2-memory-flip.logic.board").new(require("config.storyline-levels.story-2"),42),
        require("games.p3-match-3.logic.board").new(require("config.storyline-levels.story-3"),42),
        require("games.p4-link-match.logic.board").new(require("config.storyline-levels.story-4"))}
    M.anim=require("games.p1-puzzle-land.view.animations").new()
    P2.resetAnims();P2.resetMatchEffects();P3.resetAll()
end
function M.update(dt)
    M.elapsed=M.elapsed+dt
    if M.scenery then Fox.update(dt) end
    if not M.boards then return end
    M.anim:update(dt)
    P2.updateAnims(dt,M.boards[2],M.layouts[2]);P2.updateMatchEffects(dt)
    P3.updateAnim(dt);Result.updateCelebration(dt)
end
function M.draw(vg,w,h)
    if M.scenery and not M.foxInitialized then Fox.init(vg); M.foxInitialized=true end
    if M.background then
        require("shared.background-manager").renderBackground(vg,w,h,M.elapsed,M.background)
    else
        nvgBeginPath(vg);nvgRect(vg,0,0,w,h)
        nvgFillColor(vg,nvgRGBA(255,246,220,255));nvgFill(vg)
    end
    if not M.boards then return end
    local p=M.page;local board=M.boards[math.min(p,4)]
    local function surroundings(l)
        if not M.scenery then return end
        local rect={x=l.x or l.startX or l.offsetX,y=l.y or l.startY or l.offsetY,
            w=l.totalW or l.gridW or l.boardW,h=l.totalH or l.gridH or l.boardH}
        M.sceneryLayout=Scenery.draw(vg,w,h,rect,M.background,M.elapsed)
        Fox.render(vg,w,h,p==4 and 34 or 0,{handdrawn=true})
    end
    if p==1 then
        local l=P1.calcLayout(w,h,board.width,board.height);M.layouts[1]=l
        surroundings(l)
        P1.drawHUD(vg,w,board,"慧慧的花园课堂",l);P1.drawBoard(vg,board,M.anim,l,M.elapsed)
        M.hits[1]=P1.drawBottomButtons(vg,w,h,l);P1.drawHintText(vg,w,h,l,1)
    elseif p==2 then
        local l=P2.calcLayout(w,h,board.rows,board.cols,H2.TOP_BAR_H+Layout.BOARD_TOP_PADDING);M.layouts[2]=l
        surroundings(l)
        H2.drawTop(vg,w,board,"泡泡的捉迷藏");P2.drawCards(vg,board,l);M.hits[2]=H2.drawBottom(vg,w,h)
    elseif p==3 then
        local l=P3.calcLayout(w,h,board.rows,board.cols,H3.TOP_BAR_H+Layout.BOARD_TOP_PADDING,Layout.BOARD_BOTTOM_PADDING);M.layouts[3]=l
        surroundings(l)
        H3.drawTop(vg,w,board,"糖糖的花园");P3.draw(vg,board,w,h);M.hits[3]=H3.drawBottom(vg,w,h)
    elseif p==4 then
        local l=P4.calcLayout(w,h,board.rows,board.cols,H4.TOP_BAR_H+Layout.BOARD_TOP_PADDING,Layout.BOARD_BOTTOM_PADDING);M.layouts[4]=l
        surroundings(l)
        H4.drawTop(vg,w,board,"豆豆的图案配对");P4.drawBoard(vg,board,l,M.elapsed);P4.drawLinkLine(vg,board,l)
        M.hits[4]=H4.drawBottom(vg,w,h,board);H4.drawTimeBar(vg,w,h,board,M.elapsed)
    elseif p==5 then
        M.hits[5]=Pause.draw(vg,w,h)
    elseif p==6 then
        M.hits[6]=Result.drawCleared(vg,w,h,{ratingType="stars",ratingValue=3,
            stats={{label="本次得分",value=1280},{label="历史最佳",value=1280},
                {label="剩余时间",value="00:45"},{label="目标完成",value="收集蓝色图案 12/12"}},isNewBest=true})
    elseif p==7 then
        M.hits[7]=Result.drawFailed(vg,w,h,{title="时间到！",message="再试一次，一定可以！",subMessage="得分：1280"})
    elseif p==8 then
        -- 用同一画布覆盖所有既有图案，防止只测第一关遗漏高级图案。
        local shapes=require("shared.rendering.vector-shapes")
        local link=require("games.p4-link-match.view.tile-renderer")
        local i=0
        for key,fn in pairs(shapes) do
            i=i+1;local size=math.min(40,(w-32)/8)
            local x,y=20+((i-1)%8)*size+size/2,70+math.floor((i-1)/8)*size
            fn(vg,x,y,size,nvgRGBA(132,166,78,255))
            link.drawPattern(vg,key,x,y+math.ceil(60/8)*size+30,size,2)
        end
    elseif p>=9 and p<=12 then
        local name=({"p1-puzzle-land","p2-memory-flip","p3-match-3","p4-link-match"})[p-8]
        local data=require("games."..name..".data.levels")
        local levels=p==9 and data or data.levels
        local first=p==9 and levels[1].id or levels[1].levelId
        local entry=p==9 and 3 or {bestStar=3,bestTimeMs=15000,bestScore=1200}
        local hits=require("games."..name..".screens.level-select").draw(vg,w,h,levels,{completedLevels={[first]=entry}},function()
            if M.scenery then Fox.render(vg,w,h,0,{handdrawn=true}) end
        end)
        M.hits[p]={hits.backBtn}
        if hits.prevBtn then M.hits[p][#M.hits[p]+1]=hits.prevBtn end
        if hits.nextBtn then M.hits[p][#M.hits[p]+1]=hits.nextBtn end
        for _,b in pairs(hits.levelBtns) do M.hits[p][#M.hits[p]+1]=b end
    end
end
return M
