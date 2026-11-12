---@diagnostic disable: undefined-global
local UI=require("urhox-libs/UI")
V.atFrame(15,function()
    UI.Layout()
    local instance=SettingsLayoutInstance
    local ids={"settings-age-open","settings-privacy-policy","settings-logout","settings-extra-7","settings-extra-8","settings-close"}
    local clipIds={"settings-card","settings-scroll"}
    for _,id in ipairs(ids) do
        local widget=instance:Find(id)
        V.assert(widget~=nil,id.."存在")
        if widget then
            local b=widget:GetAbsoluteLayout()
            V.assert(b.w>0 and b.h>=44,id.."有足够点击尺寸")
            for _,clipId in ipairs(clipIds) do
                if not (id=="settings-close" and clipId=="settings-scroll") then
                    local p=instance:Find(clipId):GetAbsoluteLayout()
                    V.assert(b.x>=p.x-1 and b.y>=p.y-1 and b.x+b.w<=p.x+p.w+1 and b.y+b.h<=p.y+p.h+1,id.."完整位于"..clipId)
                end
            end
            print("[设置布局检查] "..id.." "..cjson.encode(b))
        end
    end
    local card=instance:Find("settings-card"):GetAbsoluteLayout()
    local w,h=UI.GetViewportSize()
    local top=graphics:GetWidth()==538 and 62 or 0
    local bottom=graphics:GetWidth()==538 and 34 or 0
    V.assert(card.x>=0 and card.y>=top-1 and card.x+card.w<=w+1 and card.y+card.h<=h-bottom+1,"弹窗位于安全区")
end)
local anti
local states={"anti-addiction-reminder","anti-addiction-force-exit","anti-addiction-curfew","anti-addiction-minor-7","anti-addiction-minor-12","anti-addiction-minor-17"}
V.atFrame(25,function()
    anti=assert(UI.LoadJSON("ui/anti-addiction.ui.json"))
    UI.SetRoot(anti:GetRoot())
    if graphics:GetWidth()==538 then anti:Find("safe_area"):SetStyle({paddingTop=62,paddingBottom=34}) end
end)
for index,stateId in ipairs(states) do
    local selected=stateId
    V.atFrame(30+index*5,function()
        for _,id in ipairs(states) do anti:Find(id):SetVisible(id==selected) end
        UI.Layout()
        local prefix=selected=="anti-addiction-reminder" and "" or selected:gsub("anti%-addiction%-","").."-"
        local card=anti:Find(prefix.."rest-card"):GetAbsoluteLayout()
        local w,h=UI.GetViewportSize()
        local top=graphics:GetWidth()==538 and 62 or 0
        local bottom=graphics:GetWidth()==538 and 34 or 0
        V.assert(card.x>=0 and card.y>=top-1 and card.x+card.w<=w+1 and card.y+card.h<=h-bottom+1,selected.."卡片完整位于安全区")
        for i=1,2 do
            local button=anti:Find(prefix.."rest-action-"..i)
            if button then
                local b=button:GetAbsoluteLayout()
                V.assert(b.x>=card.x-1 and b.y>=card.y-1 and b.x+b.w<=card.x+card.w+1 and b.y+b.h<=card.y+card.h+1,selected.."按钮完整位于卡片内")
                V.assert(b.h>=44,selected.."按钮高度合格")
            end
        end
        local content=anti:Find(prefix.."rest-paragraphs"):GetAbsoluteLayout()
        local viewport=anti:Find(prefix.."rest-scroll"):GetAbsoluteLayout()
        V.assert(content.h<=viewport.h+1,selected.."正文没有被裁切")
        print("[防沉迷布局检查] "..selected.." "..cjson.encode(card))
    end)
end
V.atFrame(75,function()
    for _,id in ipairs(states) do anti:Find(id):SetVisible(id==states[1]) end
    UI.Layout()
end)
