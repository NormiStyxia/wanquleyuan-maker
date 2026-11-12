--- Shared play-area balance. Do not stretch square pieces to fill portrait screens.
local M={}
function M.calc(w,h,rows,cols,top,bottom,options)
    options=options or {}
    local side=math.max(16,math.min(24,w*.045))
    local footer=math.min(options.footer or 184,h*.36)
    local gap=options.gap or 3
    local outer=options.outer or 0
    local availableW=w-side*2
    local availableH=math.max(1,h-top-math.max(bottom or 0,footer))
    local cell=math.floor(math.min((availableW-gap*(cols-1))/(cols+outer),
        (availableH-gap*(rows-1))/(rows+outer),options.maxCell or math.huge))
    cell=math.max(1,cell)
    local width=cell*cols+gap*(cols-1)
    local height=cell*rows+gap*(rows-1)
    local routePad=outer*(cell+gap)/2
    local slack=math.max(0,availableH-height-routePad*2)
    return {cell=cell,gap=gap,x=(w-width)/2,y=top+routePad+slack*.66,
        width=width,height=height,footer=footer}
end
return M
