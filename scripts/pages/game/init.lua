--- 游戏页面
--- 展示游戏 UI
local UI = require("urhox-libs/UI")
local C = require("shared.constants.art").colors
local PaperUI = require("shared.components.paper-ui")
local Router = require("app.router")
local gameContainer = require("modules.game-container.init")
local logger = require("shared.utils.logger")

local M = {}
local MODULE = "page-game"

---@type any
local rootNode_ = nil
---@type any
local gameArea_ = nil

-- 与其他页面共用纸卡和安全区；加载被阻止或失败时仍能返回原页面。
local function unavailablePage()
    rootNode_ = UI.Panel {
        id = "game-unavailable", width = "100%", flexGrow = 1, flexBasis = 0,
        backgroundColor = C.paper,
        children = {
            UI.SafeAreaView {
                width = "100%", flexGrow = 1, flexBasis = 0, padding = 24,
                alignItems = "center", justifyContent = "center",
                children = {
                    UI.Panel {
                        id = "game-unavailable-card", width = "100%", maxWidth = 360,
                        padding = 24, gap = 16, backgroundColor = {255, 251, 238, 255},
                        borderWidth = 2, borderColor = C.ink, borderRadius = 12,
                        children = {
                            UI.Label {
                                text = "暂时没能进入关卡", fontSize = 22, fontColor = C.ink,
                                width = "100%", whiteSpace = "normal", textAlign = "center",
                            },
                            UI.Label {
                                text = "请先返回，稍后再试一次。",
                                width = "100%", fontSize = 16, fontColor = C.muted,
                                whiteSpace = "normal", textAlign = "center",
                            },
                            PaperUI.button {
                                id = "game-unavailable-back", text = "返回上一页", width = "100%", height = 48,
                                onClick = function()
                                    if not Router.pop() then Router.replace("home") end
                                end,
                            },
                        },
                    },
                },
            },
        },
    }
    return rootNode_
end

--- 创建游戏页面
---@param params { gameConfig: table }
---@return any UI 节点
function M.create(params)
    local gameConfig = params and params.gameConfig
    if not gameConfig then
        logger.error(MODULE, "create", "no gameConfig provided")
        return unavailablePage()
    end

    -- 通过 game-container 进入游戏（支持主线模式透传 storylineOpts）
    local storylineOpts = params and params.storylineOpts or nil
    local ok = gameContainer.enter(gameConfig, nil, storylineOpts)
    if not ok then
        logger.error(MODULE, "create", "game-container enter failed for " .. gameConfig.gameId)
        return unavailablePage()
    end

    -- 获取游戏 UI
    local gameUI = gameContainer.getGameUI()

    -- 游戏内容区
    gameArea_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
        children = gameUI and { gameUI } or {},
    }

    -- 根容器
    rootNode_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        children = {
            gameArea_,
        },
    }

    logger.info(MODULE, "create", "ok: " .. gameConfig.gameId)
    return rootNode_
end

--- 销毁游戏页面
function M.destroy()
    gameArea_ = nil
    rootNode_ = nil
    logger.info(MODULE, "destroy", "ok")
end

return M
