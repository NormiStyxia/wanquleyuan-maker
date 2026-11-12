--- 功能开关模块（运行时可修改）
--- 所有开关默认开启（true），通过调试面板可切换
local logger = require("shared.utils.logger")

local M = {}
local MODULE = "feature-flags"

-- ============================================================================
-- 开关定义（默认值 + 元数据）
-- ============================================================================

--- 开关定义列表，按显示顺序排列
---@type { key: string, label: string, default: boolean }[]
M.definitions = {
    { key = "enableTransition",   label = "转场动画",   default = true },
    { key = "enableCelebration",  label = "庆祝特效",   default = true },
    { key = "enableSound",       label = "音效",       default = true },
    { key = "enableLog",         label = "日志输出",   default = true },
    { key = "enableSave",        label = "存档读写",   default = true },
    { key = "testIsAdult",       label = "测试-是成年人", default = true },
}

-- ============================================================================
-- 运行时状态
-- ============================================================================

--- 总开关（关闭后所有子开关视为 false）
local masterEnabled_ = false

--- 各子开关当前值
---@type table<string, boolean>
local flags_ = {}

-- 初始化默认值
for _, def in ipairs(M.definitions) do
    flags_[def.key] = def.default
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 获取总开关状态
---@return boolean
function M.isMasterEnabled()
    return masterEnabled_
end

--- 设置总开关
---@param enabled boolean
function M.setMasterEnabled(enabled)
    masterEnabled_ = enabled
    logger.info(MODULE, "setMaster", tostring(enabled))
end

--- 查询某个功能是否启用（总开关关闭时一律返回 false）
---@param key string
---@return boolean
function M.isEnabled(key)
    if not masterEnabled_ then return false end
    local v = flags_[key]
    if v == nil then return true end
    return v
end

--- 设置某个功能开关
---@param key string
---@param enabled boolean
function M.setEnabled(key, enabled)
    flags_[key] = enabled
    logger.info(MODULE, "set", key .. "=" .. tostring(enabled))
end

--- 切换某个功能开关
---@param key string
---@return boolean 切换后的值
function M.toggle(key)
    local newVal = not M.isEnabled(key)
    flags_[key] = newVal
    logger.info(MODULE, "toggle", key .. "=" .. tostring(newVal))
    return newVal
end

--- 获取所有开关的当前值快照
---@return table<string, boolean>
function M.getAll()
    local result = {}
    for _, def in ipairs(M.definitions) do
        result[def.key] = flags_[def.key]
    end
    return result
end

--- 重置所有开关为默认值
function M.resetAll()
    masterEnabled_ = true
    for _, def in ipairs(M.definitions) do
        flags_[def.key] = def.default
    end
    logger.info(MODULE, "resetAll", "ok")
end

return M
