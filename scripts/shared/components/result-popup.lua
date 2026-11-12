--- 四种玩法共用的结算纸卡。评级、成绩和操作仍由调用方提供。
local Fx = require("shared.components.celebration-effects")
local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local M = {}
local celebration_ = nil

function M.startCelebration(w,h,opts)
    opts=opts or {}
    celebration_=Fx.create(w,h,{fireworkCount=3,confettiCount=22,
        enableRankAnim=opts.ratingType=="rank",elasticStyle="sin"})
    celebration_.ratingType,celebration_.ratingValue=opts.ratingType,opts.ratingValue
end
function M.updateCelebration(dt) if celebration_ then Fx.update(celebration_,dt) end end
function M.stopCelebration() celebration_=nil end
function M.getCelebration() return celebration_ end

local function star(vg,cx,cy,r,filled)
    nvgBeginPath(vg)
    for i=0,9 do
        local angle=-math.pi/2+i*math.pi/5
        local pr=i%2==0 and r or r*0.45
        local x,y=cx+math.cos(angle)*pr,cy+math.sin(angle)*pr
        if i==0 then nvgMoveTo(vg,x,y) else nvgLineTo(vg,x,y) end
    end
    nvgClosePath(vg); Pen.paint(vg,filled and C.orange or C.track,2)
end

local function buttons(vg,defs,x,y,w,h,alpha,enabled)
    if not enabled then return {} end
    local bw,bh,gap=math.min(224,w-40),44,10
    local bx=x+(w-bw)/2
    local by=y+h-20-#defs*bh-(#defs-1)*gap
    local hits={}
    for i,def in ipairs(defs) do
        local py=by+(i-1)*(bh+gap)
        Paper.button(vg,bx,py,bw,bh,def[1],i==1,true,nil,alpha)
        hits[i]={x=bx,y=py,w=bw,h=bh,action=def[2]}
    end
    return hits
end

local function wrap(vg,value,size,width)
    nvgFontFace(vg,"sans");nvgFontSize(vg,size)
    local lines,line={},""
    for _,code in utf8.codes(tostring(value)) do
        local char=utf8.char(code)
        if char=="\n" then lines[#lines+1]=line;line=""
        elseif line~="" and (nvgTextBounds(vg,0,0,line..char) or 0)>width then
            lines[#lines+1]=line;line=char
        else line=line..char end
    end
    lines[#lines+1]=line
    return lines
end

local function statRows(vg,stats,width)
    local rows,total={},0
    for _,stat in ipairs(stats) do
        nvgFontFace(vg,"sans");nvgFontSize(vg,15)
        local labelW=nvgTextBounds(vg,0,0,tostring(stat.label)) or 0
        nvgFontSize(vg,17)
        local valueW=nvgTextBounds(vg,0,0,tostring(stat.value)) or 0
        local stacked=labelW+valueW+16>width
        local row={stat=stat,stacked=stacked,height=28}
        if stacked then
            row.labels=wrap(vg,stat.label,15,width)
            row.values=wrap(vg,stat.value,17,width)
            row.height=#row.labels*22+#row.values*24+6
        end
        rows[#rows+1]=row;total=total+row.height
    end
    return rows,total
end

function M.drawCleared(vg,screenW,screenH,opts)
    opts=opts or {}
    local cel=opts.celebration or celebration_
    local alpha=cel and cel.dialogAlpha or 1
    -- 纸卡只做小幅落定，碰撞区始终使用真实绘制坐标。
    local elapsed=cel and cel.elapsed or 1
    local shift=8*(1-math.min(1,math.max(0,elapsed-0.3)/0.3))
    local stats=opts.stats or {}
    local defs={}
    if opts.storylineMode then
        defs={{"完成关卡","back"},{"再来一次","retry"}}
    else
        if opts.hasNextLevel~=false then defs[#defs+1]={"下一关","next_level"} end
        defs[#defs+1]={"再来一次","retry"}; defs[#defs+1]={"返回","back"}
    end
    local w=math.min(320,screenW-32)
    local rows,statsH=statRows(vg,stats,w-48)
    local h=154+statsH+(opts.isNewBest and 24 or 0)+#defs*44+(#defs-1)*10+28
    local x,y=(screenW-w)/2,(screenH-h)/2+shift
    nvgBeginPath(vg); nvgRect(vg,0,0,screenW,screenH)
    nvgFillColor(vg,nvgRGBA(63,56,36,math.floor(120*alpha))); nvgFill(vg)
    if alpha<=0.01 then return {} end
    nvgSave(vg); nvgGlobalAlpha(vg,alpha)
    Paper.panel(vg,x,y,w,h)
    Paper.text(vg,screenW/2,y+32,opts.storylineMode and "关卡完成！" or "通关！",26)
    local rank=opts.ratingValue or 1
    if opts.ratingType=="rank" then
        if opts.storylineMode then rank="S" end
        Paper.text(vg,screenW/2,y+86,tostring(rank),44,C.green)
    else
        if opts.storylineMode then rank=3 end
        for i=1,3 do star(vg,screenW/2+(i-2)*42,y+85,17,i<=rank) end
    end
    local sy=y+132
    if opts.isNewBest then
        Paper.text(vg,screenW/2,y+115,"新纪录！",14,C.green); sy=sy+24
    end
    for _,row in ipairs(rows) do
        local stat=row.stat
        if row.stacked then
            for i,line in ipairs(row.labels) do Paper.text(vg,x+24,sy+(i-1)*22,line,15,C.muted,NVG_ALIGN_LEFT) end
            for i,line in ipairs(row.values) do Paper.text(vg,x+w-24,sy+#row.labels*22+(i-1)*24,line,17,stat.color or C.ink,NVG_ALIGN_RIGHT) end
        else
            Paper.text(vg,x+24,sy,stat.label,15,C.muted,NVG_ALIGN_LEFT)
            Paper.text(vg,x+w-24,sy,stat.value,17,stat.color or C.ink,NVG_ALIGN_RIGHT)
        end
        sy=sy+row.height
    end
    nvgRestore(vg)
    local a=math.max(0,math.min(1,(elapsed-0.5)/0.3))*alpha
    local hits=buttons(vg,defs,x,y,w,h,a,elapsed>=0.5)
    -- 原P1庆祝数据与共享Fx结构不同；P1只复用纸卡，不传给共享粒子更新。
    if cel and cel==celebration_ then Fx.drawConfetti(vg,cel,screenH) end
    return hits
end

function M.drawFailed(vg,screenW,screenH,opts)
    opts=opts or {}
    local w=math.min(320,screenW-32)
    local h=opts.subMessage and 298 or 270
    local x,y=(screenW-w)/2,(screenH-h)/2
    nvgBeginPath(vg); nvgRect(vg,0,0,screenW,screenH)
    nvgFillColor(vg,nvgRGBA(63,56,36,120)); nvgFill(vg)
    Paper.panel(vg,x,y,w,h)
    Paper.text(vg,screenW/2,y+34,opts.title or "时间到！",26)
    -- 按实际文本宽度缩字号，目标较长时仍留左右内边距。
    local function message(text,py,size,color)
        nvgFontFace(vg,"sans"); nvgFontSize(vg,size)
        local width=nvgTextBounds(vg,0,0,text) or 0
        if width>w-40 then size=size*(w-40)/width end
        Paper.text(vg,screenW/2,py,text,size,color)
    end
    message(opts.message or "",y+86,17,C.ink)
    if opts.subMessage then message(opts.subMessage,y+116,15,C.muted) end
    return buttons(vg,{{"再试一次","retry"},{"返回","back"}},x,y,w,h,1,true)
end
return M
