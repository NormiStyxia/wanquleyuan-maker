--- 游戏接入配置 Schema 校验器
--- 错误码：CFG-001 字段缺失, CFG-002 字段类型非法, CFG-003 入口模块不可加载
local M = {}

-- 必填字段定义：{ 字段名, 期望类型 }
local REQUIRED_FIELDS = {
    { "gameId",      "string" },
    { "title",       "string" },
    { "entryModule", "string" },
    { "status",      "string" },
    { "version",     "string" },
}

-- 可选字段类型约束
local OPTIONAL_FIELDS = {
    subtitle      = "string",
    icon          = "string",
    cover         = "string",
    entryRoute    = "string",
    isNew         = "boolean",
    isHot         = "boolean",
    sortWeight    = "number",
    openCondition = "table",
}

-- status 合法值
local VALID_STATUS = { online = true, offline = true, dev = true }

--- 校验单个游戏配置
---@param config table 游戏配置 table
---@return table { ok: boolean, gameId: string, errors: string[] }
function M.validate(config)
    local result = {
        ok = true,
        gameId = (type(config) == "table" and type(config.gameId) == "string") and config.gameId or "unknown",
        errors = {},
    }

    -- 基本类型检查
    if type(config) ~= "table" then
        result.ok = false
        table.insert(result.errors, "CFG-002: config is not a table")
        return result
    end

    -- 必填字段检查
    for _, field in ipairs(REQUIRED_FIELDS) do
        local name, expectedType = field[1], field[2]
        local value = config[name]
        if value == nil then
            result.ok = false
            table.insert(result.errors, "CFG-001: missing required field '" .. name .. "'")
        elseif type(value) ~= expectedType then
            result.ok = false
            table.insert(result.errors, "CFG-002: field '" .. name .. "' expected " .. expectedType .. ", got " .. type(value))
        end
    end

    -- status 合法值检查
    if type(config.status) == "string" and not VALID_STATUS[config.status] then
        result.ok = false
        table.insert(result.errors, "CFG-002: field 'status' must be online/offline/dev, got '" .. config.status .. "'")
    end

    -- 可选字段类型检查
    for name, expectedType in pairs(OPTIONAL_FIELDS) do
        local value = config[name]
        if value ~= nil and type(value) ~= expectedType then
            result.ok = false
            table.insert(result.errors, "CFG-002: field '" .. name .. "' expected " .. expectedType .. ", got " .. type(value))
        end
    end

    return result
end

return M
