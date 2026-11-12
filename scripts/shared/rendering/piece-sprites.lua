--- Mivo painted pieces. Image handles belong to one NanoVG context.
local M = {}
local images = {}
local root = 'image/handdrawn/pieces/'
local patternKeys = {diamond=true,house=true,fish=true,apple=true,cross=true,cloud=true,heart=true,star=true,leaf=true,sun=true,flower=true,circle=true,
    square=true,triangle=true,star4=true,['diagonal-cross']=true,halfcircle=true}
-- 连连看小格子内按各图案在 192x192 画布中的真实像素包围盒与面积占空比做宽高光学均衡，使所有图标视觉大小一致且留白充裕
local linkOpticalScale = {
    square           = { 0.66, 0.66 },
    circle           = { 0.69, 0.69 },
    ['diagonal-cross'] = { 0.69, 0.69 },
    house            = { 0.71, 0.71 },
    apple            = { 0.71, 0.71 },
    leaf             = { 0.72, 0.72 },
    cross            = { 0.72, 0.72 },
    diamond          = { 0.73, 0.73 },
    flower           = { 0.73, 0.75 },
    triangle         = { 0.72, 0.75 },
    heart            = { 0.73, 0.76 },
    star             = { 0.74, 0.75 },
    star4            = { 0.74, 0.74 },
    sun              = { 0.76, 0.77 },
    halfcircle       = { 0.68, 0.84 },
    fish             = { 0.70, 0.82 },
    cloud            = { 0.70, 0.82 },
}
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
function M.drawUI(vg,key,cx,cy,width,height,alpha)
    if width<=0 or height<=0 or (alpha or 1)<=0 then return true end
    local image=handle(vg,root..key..'.png')
    if not image or image<0 then return false end
    local x,y=cx-width/2,cy-height/2
    nvgBeginPath(vg); nvgRect(vg,x,y,width,height)
    nvgFillPaint(vg,nvgImagePattern(vg,x,y,width,height,0,image,alpha or 1)); nvgFill(vg)
    return true
end
function M.pattern(vg,key,cx,cy,size,colorIndex,mode)
    local index=((colorIndex or 1)-1)%24+1
    local flip=false
    if mode=='link' then
        if key=='star' and index%2==0 then key='star4' end
        if key=='diamond' then key='diagonal-cross' end
        flip=key=='triangle' and index%2==1
        if index==9 then index=21 elseif index==10 then index=25 elseif index==17 then index=20 elseif index==18 then index=23 end
    else
        if index==1 then index=2 elseif index==2 then index=1 elseif index==10 then index=25 end
    end
    if not patternKeys[key] then return false end
    local sc = mode=='link' and (linkOpticalScale[key] or { 0.72, 0.72 }) or { 1.0, 1.0 }
    local drawW, drawH = size * sc[1], size * sc[2]
    nvgSave(vg)
    if flip then nvgTranslate(vg,cx,cy); nvgScale(vg,1,-1); cx,cy=0,0 end
    local ok=M.rect(vg,'colors/'..key..'-'..index,cx,cy,drawW,drawH)
    nvgRestore(vg)
    return ok
end
function M.release(vg)
    if not vg then return end
    for _,h in pairs(images[vg] or {}) do if h>=0 then nvgDeleteImage(vg,h) end end
    images[vg]=nil
end
return M
