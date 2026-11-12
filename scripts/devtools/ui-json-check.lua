---@diagnostic disable: undefined-global
-- 仅在验证环境加载独立 UI 资源；不触发游戏按钮、认证、支付或存档。
local UI = require("urhox-libs/UI")
local files = {
    "adventure", "adventure-chapter-2", "adventure-chapter-3", "adventure-chapter-4", "adventure-chapter-5", "adventure-reference",
    "home", "profile", "bottom-tabs", "splash", "health-advisory", "settings-popup", "level-select", "pause-menu", "result-popup",
    "outfit-unlock", "background-unlock", "purchase-popup", "dialogue", "fun-fact", "real-name-auth", "anti-addiction", "privacy-policy",
    "game-puzzle", "game-memory", "game-match3", "game-link",
}
local retained = {}
local index = 0
local function loadNext()
    index = index + 1
    local name = files[index]
    if not name then return end
    local instance, err = UI.LoadJSON("ui/" .. name .. ".ui.json")
    V.assert(instance ~= nil, name .. " 能被 UI.LoadJSON 加载：" .. tostring(err))
    if not instance then return end
    retained[#retained + 1] = instance
    local root = instance:GetRoot()
    V.assert(root ~= nil, name .. " 有根控件")
    if not root then return end
    UI.SetRoot(root)
    UI.Layout()
    local b = root:GetLayout()
    V.assert(b.w > 0 and b.h > 0, name .. " 有有效布局尺寸")
    print("[UI资源验证] " .. name .. " " .. tostring(b.w) .. "x" .. tostring(b.h))
end
for i = 1, #files do V.atFrame(i * 3 + 6, loadNext) end
V.atFrame(94, function()
    local instance, err = UI.LoadJSON("ui/adventure-reference.ui.json")
    V.assert(instance ~= nil, "参考地图可重复加载：" .. tostring(err))
    if instance then
        retained[#retained + 1] = instance
        UI.SetRoot(instance:GetRoot())
        UI.Layout()
    end
end)
