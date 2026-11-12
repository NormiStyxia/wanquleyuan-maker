--- 游戏注册表模块
--- 负责：加载游戏配置 → Schema 校验 → 排序 → 过滤 → 提供有序游戏列表
local logger = require("shared.utils.logger")
local schema = require("config.schema.game-config-schema")

local M = {}
local MODULE = "game-registry"

-- 已注册的游戏配置文件路径列表（M1 硬编码，M2 改动态扫描）
local CONFIG_PATHS = {
    "config.games.p1-puzzle-land",
    "config.games.p2-memory-flip",
    "config.games.p3-match-3",
    "config.games.p4-link-match",
}

-- 内部缓存
local gameList_ = {}     -- 校验通过的有序游戏列表
local gameMap_ = {}      -- gameId -> config 快速查找

--- 加载并校验所有游戏配置
---@return boolean 是否至少有一个游戏可用
function M.loadAll()
    gameList_ = {}
    gameMap_ = {}

    for _, path in ipairs(CONFIG_PATHS) do
        local ok, config = pcall(require, path)
        if not ok then
            logger.error(MODULE, "load_config", "failed to require '" .. path .. "': " .. tostring(config))
        else
            local result = schema.validate(config)
            if result.ok then
                table.insert(gameList_, config)
                gameMap_[config.gameId] = config
                logger.info(MODULE, "load_config", "ok: " .. config.gameId)
            else
                for _, err in ipairs(result.errors) do
                    logger.error(MODULE, "validate_config", err, result.gameId)
                end
            end
        end
    end

    -- 过滤 offline 状态
    local filtered = {}
    for _, cfg in ipairs(gameList_) do
        if cfg.status ~= "offline" then
            table.insert(filtered, cfg)
        end
    end
    gameList_ = filtered

    -- 按 sortWeight 降序排列
    table.sort(gameList_, function(a, b)
        local wa = a.sortWeight or 0
        local wb = b.sortWeight or 0
        return wa > wb
    end)

    logger.info(MODULE, "loadAll", "total available: " .. #gameList_)
    return #gameList_ > 0
end

--- 获取有序游戏列表
---@return table[] 游戏配置数组
function M.getGameList()
    return gameList_
end

--- 根据 gameId 获取配置
---@param gameId string
---@return any
function M.getGameById(gameId)
    return gameMap_[gameId]
end

--- 获取可用游戏数量
---@return number
function M.getCount()
    return #gameList_
end

return M
