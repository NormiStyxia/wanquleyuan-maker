--- Independent painted set dressing, kept outside every live cell and toolbar.
local Sprites=require("shared.rendering.piece-sprites")
local M={}
function M.layout(w,h,rect,background)
    local path=background and background.themeImage or ''
    local theme=path:find('/ice.png',1,true) and 'ice'
        or path:find('/candy.png',1,true) and 'candy' or 'garden'
    local result={}
    local upperStart,upperEnd=116,rect.y-16
    if upperEnd-upperStart>=32 then
        local width=math.min(w*.48,190,(upperEnd-upperStart)*2)
        result.top={x=w*.52,y=(upperStart+upperEnd)/2,w=width,h=width/2,key='scenes/'..theme..'-top'}
    end
    local lowerStart,lowerEnd=rect.y+rect.h+20,h-48
    if lowerEnd-lowerStart>=46 then
        local width=math.min(w*.46,190,(lowerEnd-lowerStart)*1.5)
        result.bottom={x=w*.72,y=(lowerStart+lowerEnd)/2,w=width,h=width*2/3,key='scenes/'..theme..'-bottom'}
    end
    return result
end
function M.draw(vg,w,h,rect,background,time)
    local layout=M.layout(w,h,rect,background)
    for _,name in ipairs({'top','bottom'}) do
        local p=layout[name]
        if p then
            nvgSave(vg)
            if name=='top' then
                -- Rotate about the top hanging point; under one degree, never through the board.
                nvgTranslate(vg,p.x,p.y-p.h/2)
                nvgRotate(vg,math.sin((time or 0)*1.2)*.012)
                Sprites.rect(vg,p.key,0,p.h/2,p.w,p.h)
            else
                -- 地面小物以底边为锚轻呼吸，不改变摆放或进入棋盘点按区。
                local breath=math.sin((time or 0)*1.35+1.1)*.007
                nvgTranslate(vg,p.x,p.y+p.h/2)
                nvgScale(vg,1+breath*.45,1+breath)
                Sprites.rect(vg,p.key,0,-p.h/2,p.w,p.h)
            end
            nvgRestore(vg)
        end
    end
    return layout
end
return M
