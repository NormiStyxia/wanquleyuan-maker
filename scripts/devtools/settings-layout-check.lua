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
