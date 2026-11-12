--- 记录真实资源调用CPU耗时，不修改加载顺序、断言阈值或存档。
---@diagnostic disable: undefined-global
local measurements={}
local function record(name,ms)
    local r=measurements[name] or {calls=0,ms=0}
    r.calls=r.calls+1;r.ms=r.ms+ms;measurements[name]=r
end
for _,name in ipairs({'nvgCreateImage','nvgCreateFont'}) do
    local original=_G[name]
    _G[name]=function(vg,path,...)
        local started=os.clock()
        local result=original(vg,path,...)
        record(name..':'..tostring(path),(os.clock()-started)*1000)
        return result
    end
end
local Profile=require('pages.profile.init')
local create=Profile.create
Profile.create=function(...)
    local started=os.clock()
    local results=table.pack(create(...))
    record('Profile.create',(os.clock()-started)*1000)
    return table.unpack(results,1,results.n)
end
require('tests.e2e.review-ui-secondary')
V.atFrame(129,function() print('[UICost] '..cjson.encode(measurements)) end)
