--- 真实 main 入口验收；仅 saves/ 与 clientCloud 使用独立内存，资源仍走原引擎。
---@diagnostic disable: undefined-global
print("[UIFlow] entry before require main")
local originalFile, originalFS = File, fileSystem
local files, cloud = {}, {}
local story = {currentNodeId="story-5",completedNodes={},updatedAt=0}
for i=1,4 do story.completedNodes["story-"..i]={completedAt=1} end
files["saves/storyline_progress.json"]=cjson.encode(story)
local function isSave(path)
    return type(path)=="string" and (path=="saves" or path:sub(1,6)=="saves/")
end
fileSystem=setmetatable({}, {__index=function(_,key)
    if key=="FileExists" then return function(_,path)
        if isSave(path) then return files[path]~=nil end
        return originalFS:FileExists(path)
    end end
    if key=="CreateDir" then return function(_,path)
        if isSave(path) then return true end
        return originalFS:CreateDir(path)
    end end
    if key=="Delete" then return function(_,path)
        if isSave(path) then files[path]=nil;return true end
        return originalFS:Delete(path)
    end end
    local value=originalFS[key]
    if type(value)=="function" then return function(_,...) return value(originalFS,...) end end
    return value
end})
File=function(path,mode)
    if not isSave(path) then return originalFile(path,mode) end
    local opened=mode~=FILE_READ or files[path]~=nil
    return {IsOpen=function() return opened end,
        ReadString=function() return files[path] or "" end,
        WriteString=function(_,value) assert(opened);files[path]=value;return true end,
        Close=function() opened=false end}
end
clientCloud={}
function clientCloud:Get(key,callbacks) if callbacks.ok then callbacks.ok({[key]=cloud[key]}) end end
function clientCloud:Set(key,value,callbacks) cloud[key]=value;if callbacks and callbacks.ok then callbacks.ok() end end
function clientCloud:BatchSet()
    local batch={}
    function batch:Set(key,value) cloud[key]=value;return self end
    function batch:Delete(key) cloud[key]=nil;return self end
    function batch:Save(_,callbacks) if callbacks and callbacks.ok then callbacks.ok() end end
    return batch
end
WANQU_UI_FLOW={files=files,cloud=cloud,errors={},imageFailures={}}
local log=require("shared.utils.logger")
local errorLog=log.error
log.error=function(...)
    WANQU_UI_FLOW.errors[#WANQU_UI_FLOW.errors+1]={...}
    return errorLog(...)
end
local create=nvgCreateImage
nvgCreateImage=function(vg,path,flags)
    local image=create(vg,path,flags)
    if not image or image<=0 then WANQU_UI_FLOW.imageFailures[#WANQU_UI_FLOW.imageFailures+1]=path end
    return image
end
require("main")
