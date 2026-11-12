--- Mivo painted pieces. Image handles belong to one NanoVG context.
local M = {}
local images = {}
local root = 'image/handdrawn/pieces/'
local patternKeys = {diamond=true,house=true,fish=true,apple=true,cross=true,cloud=true,heart=true,star=true,leaf=true,sun=true,flower=true,circle=true,
    square=true,triangle=true,star4=true,['diagonal-cross']=true,halfcircle=true}
local function handle(vg,path)
    images[vg] = images[vg] or {}
    local h = images[vg][path]
    if h == nil then h=nvgCreateImage(vg,path,0); images[vg][path]=h end
    return h
end
function M.rect(vg,key,cx,cy,width,height,alpha)
    if width<=0 or height<=0 or (alpha or 1)<=0 then return true end
    local image=handle(vg,root..key..'.png')
    if not image or image<0 then return false end
    local x,y=cx-width/2,cy-height/2
    nvgBeginPath(vg); nvgRect(vg,x,y,width,height)
    nvgFillPaint(vg,nvgImagePattern(vg,x,y,width,height,0,image,alpha or 1)); nvgFill(vg)
    return true
end
function M.draw(vg,key,cx,cy,size,alpha)
    return M.rect(vg,key,cx,cy,size,size,alpha)
end
function M.pattern(vg,key,cx,cy,size,colorIndex,mode)
    local index=((colorIndex or 1)-1)%24+1
    local flip=false
    if mode=='link' then
        if key=='star' and index%2==0 then key='star4' end
        if key=='diamond' then key='diagonal-cross' end
        flip=key=='triangle' and index%2==1
    else
        if index==1 then index=2 elseif index==2 then index=1 elseif index==10 then index=25 end
    end
    if not patternKeys[key] then return false end
    nvgSave(vg)
    if flip then nvgTranslate(vg,cx,cy); nvgScale(vg,1,-1); cx,cy=0,0 end
    local ok=M.draw(vg,'colors/'..key..'-'..index,cx,cy,size)
    nvgRestore(vg)
    return ok
end
function M.release(vg)
    if not vg then return end
    for _,h in pairs(images[vg] or {}) do if h>=0 then nvgDeleteImage(vg,h) end end
    images[vg]=nil
end
return M
