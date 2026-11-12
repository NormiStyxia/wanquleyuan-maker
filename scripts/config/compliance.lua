--- 外部合规服务切换配置
---
--- true：启用游戏内模拟实名认证和防沉迷逻辑
--- false：关闭游戏内模拟逻辑，由外部正式系统负责合规处理
local M = {}

---@type boolean 是否启用游戏内模拟实名与防沉迷系统
M.enabled = false

---@return boolean
function M.isEnabled()
    return M.enabled == true
end

return M
