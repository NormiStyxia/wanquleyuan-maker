--- 统一日志工具
--- 日志格式：[模块] action | result | errorCode
local M = {}

---@param module string 模块名
---@param action string 动作描述
---@param result string 结果
---@param errorCode string|nil 错误码
function M.info(module, action, result, errorCode)
    local msg = "[" .. module .. "] " .. action .. " | " .. result
    if errorCode then
        msg = msg .. " | " .. errorCode
    end
    print(msg)
end

---@param module string
---@param action string
---@param result string
---@param errorCode string|nil
function M.error(module, action, result, errorCode)
    local msg = "[ERROR][" .. module .. "] " .. action .. " | " .. result
    if errorCode then
        msg = msg .. " | " .. errorCode
    end
    print(msg)
end

---@param module string
---@param action string
---@param result string
function M.warn(module, action, result)
    print("[WARN][" .. module .. "] " .. action .. " | " .. result)
end

return M
