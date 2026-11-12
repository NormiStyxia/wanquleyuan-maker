--- 公共输入处理模块
--- 统一鼠标/触屏的坐标转换、滑动检测、选关界面点击分发
--- 各游戏 adapter 只需提供 gameplay 分支的回调
local Density = require("shared.utils.density")
local FoxMascot = require("shared.components.fox-mascot")
local uiTap = require("shared.utils.ui-tap")

local M = {}

--- 水平滑动翻页最小距离（逻辑像素）
local PAGE_SWIPE_MIN = 40

--- 处理选关界面的点击/滑动逻辑（鼠标和触屏共用）
--- 返回 true 表示已消费该事件
---@param startX number 按下时的逻辑坐标 X
---@param startY number 按下时的逻辑坐标 Y
---@param endX number 抬起时的逻辑坐标 X
---@param endY number 抬起时的逻辑坐标 Y
---@param ctx table 上下文 { levelSelect, selectHitAreas, gotoLevel, extraActions? }
---@return boolean consumed
local function handleLevelSelectInput(startX, startY, endX, endY, ctx)
    local dx = endX - startX
    local dy = endY - startY

    -- 水平滑动翻页
    if math.abs(dx) >= PAGE_SWIPE_MIN and math.abs(dx) > math.abs(dy) * 1.5 then
        if dx > 0 then
            ctx.levelSelect.prevPage()
        else
            ctx.levelSelect.nextPage()
        end
        return true
    end

    -- 狐狸点击聊天
    local logW, logH = Density.getGameSize()
    if FoxMascot.hitTest(startX, startY, logW, logH, 0) then
        FoxMascot.notifyChat()
        return true
    end

    -- 按钮/关卡点击
    local action, lvIdx = ctx.levelSelect.hitTest(startX, startY, ctx.selectHitAreas)
    if action then uiTap.play() end

    if action == "back" then
        local gameContainer = require("modules.game-container.init")
        gameContainer.exit("user_back")
    elseif action == "select_level" and lvIdx then
        ctx.gotoLevel(lvIdx)
    elseif action == "prev_page" then
        ctx.levelSelect.prevPage()
    elseif action == "next_page" then
        ctx.levelSelect.nextPage()
    elseif ctx.extraActions and ctx.extraActions[action] then
        ctx.extraActions[action]()
    end

    return action ~= nil
end

--------------------------------------------------------------------------------
-- 创建输入处理器
--------------------------------------------------------------------------------

---@class InputHandlerConfig
---@field getScreen fun():string 获取当前屏幕名
---@field levelSelect table 选关模块（需要 hitTest/prevPage/nextPage/gotoPageForLevel）
---@field getSelectHitAreas fun():table|nil 获取当前选关点击区域
---@field gotoLevel fun(index:number) 进入关卡
---@field onGameplayClick fun(startX:number, startY:number)|nil 游戏画面点击
---@field onGameplaySwipe fun(startX:number, startY:number, endX:number, endY:number, dist:number)|nil 游戏画面滑动
---@field extraActions table<string, function>|nil 选关界面额外 hitTest 动作
---@field onPointerDown fun(x:number, y:number)|nil 按下时额外回调（编辑器等）
---@field swipeMinDist number|nil 游戏画面滑动识别最小距离（默认 10）
---@field onPointerUp fun(startX:number, startY:number, endX:number, endY:number, dx:number, dy:number, dist:number):boolean|nil 抬起时的自定义屏幕处理（返回 true 已消费）

---@param cfg InputHandlerConfig
---@return table handlers 包含 mouseStart/touchStart 状态和各事件处理函数
function M.create(cfg)
    local H = {}

    ---@type table|nil { x, y }
    H.mouseStart = nil
    ---@type table|nil { x, y, id }
    H.touchStart = nil

    -- ================================================================
    -- MouseButtonDown
    -- ================================================================
    ---@param eventType string
    ---@param eventData MouseButtonDownEventData
    function H.handleMouseDown(eventType, eventData)
        local button = eventData["Button"]:GetInt()
        if button ~= MOUSEB_LEFT then return end

        local mx = eventData["X"]:GetInt()
        local my = eventData["Y"]:GetInt()
        mx, my = Density.toGameCoords(mx, my)

        H.mouseStart = { x = mx, y = my }

        if cfg.onPointerDown then
            cfg.onPointerDown(mx, my)
        end
    end

    -- ================================================================
    -- MouseButtonUp
    -- ================================================================
    ---@param eventType string
    ---@param eventData MouseButtonUpEventData
    function H.handleMouseUp(eventType, eventData)
        if not H.mouseStart then return end

        local button = eventData["Button"]:GetInt()
        if button ~= MOUSEB_LEFT then return end

        local mx = eventData["X"]:GetInt()
        local my = eventData["Y"]:GetInt()
        mx, my = Density.toGameCoords(mx, my)

        local startX, startY = H.mouseStart.x, H.mouseStart.y
        H.mouseStart = nil

        H._dispatchUp(startX, startY, mx, my)
    end

    -- ================================================================
    -- TouchBegin
    -- ================================================================
    ---@param eventType string
    ---@param eventData TouchBeginEventData
    function H.handleTouchBegin(eventType, eventData)
        local tx = eventData["X"]:GetInt()
        local ty = eventData["Y"]:GetInt()
        local tid = eventData["TouchID"]:GetInt()

        tx, ty = Density.toGameCoords(tx, ty)

        if not H.touchStart then
            H.touchStart = { x = tx, y = ty, id = tid }

            if cfg.onPointerDown then
                cfg.onPointerDown(tx, ty)
            end
        end
    end

    -- ================================================================
    -- TouchEnd
    -- ================================================================
    ---@param eventType string
    ---@param eventData TouchEndEventData
    function H.handleTouchEnd(eventType, eventData)
        if not H.touchStart then return end

        local tid = eventData["TouchID"]:GetInt()
        if tid ~= H.touchStart.id then return end

        local tx = eventData["X"]:GetInt()
        local ty = eventData["Y"]:GetInt()
        tx, ty = Density.toGameCoords(tx, ty)

        local startX, startY = H.touchStart.x, H.touchStart.y
        H.touchStart = nil

        H._dispatchUp(startX, startY, tx, ty)
    end

    -- ================================================================
    -- 内部：统一的抬起分发
    -- ================================================================
    local swipeMin = cfg.swipeMinDist or 10

    function H._dispatchUp(startX, startY, endX, endY)
        local dx = endX - startX
        local dy = endY - startY
        local dist = math.sqrt(dx * dx + dy * dy)
        local screen = cfg.getScreen()

        -- 自定义屏幕处理（编辑器等）
        if cfg.onPointerUp then
            local consumed = cfg.onPointerUp(startX, startY, endX, endY, dx, dy, dist)
            if consumed then return end
        end

        if screen == "level_select" then
            handleLevelSelectInput(startX, startY, endX, endY, {
                levelSelect = cfg.levelSelect,
                selectHitAreas = cfg.getSelectHitAreas(),
                gotoLevel = cfg.gotoLevel,
                extraActions = cfg.extraActions,
            })
        elseif screen == "gameplay" then
            if cfg.onGameplaySwipe and dist > swipeMin then
                cfg.onGameplaySwipe(startX, startY, endX, endY, dist)
            elseif cfg.onGameplayClick then
                cfg.onGameplayClick(startX, startY)
            end
        end
    end

    --- 清理状态
    function H.reset()
        H.mouseStart = nil
        H.touchStart = nil
    end

    return H
end

return M
