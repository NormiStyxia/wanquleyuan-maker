--- 轻量路由模块 (ADR-003)
--- 支持 replace（tab 切换）和 push/pop（游戏进入/返回）
local logger = require("shared.utils.logger")

local M = {}
local MODULE = "router"

-- 内部状态
local pages_ = {}           -- pageId -> { create, destroy }
local stack_ = {}           -- 页面栈 { { id, params, node } }
local container_ = nil      -- UI 容器节点
local onNavigateCb_ = nil   -- 导航回调

--- 初始化路由，绑定页面容器
---@param container any UI.Panel 节点，路由将在此容器内切换页面
function M.init(container)
    container_ = container
    stack_ = {}
    logger.info(MODULE, "init", "ok")
end

--- 注册页面
---@param pageId string 页面 ID
---@param createFn function(params) -> uiNode 创建页面函数
---@param destroyFn function()|nil 销毁页面函数（可选）
function M.register(pageId, createFn, destroyFn)
    pages_[pageId] = {
        create  = createFn,
        destroy = destroyFn,
    }
end

--- 设置导航变化回调
---@param callback function(pageId, params)
function M.onNavigate(callback)
    onNavigateCb_ = callback
end

-- 内部：销毁栈顶页面 UI
local function destroyTop()
    if #stack_ == 0 then return end
    local top = stack_[#stack_]
    local page = pages_[top.id]
    if page and page.destroy then
        pcall(page.destroy)
    end
    if top.node and container_ then
        container_:RemoveChild(top.node)
    end
end

-- 内部：创建并显示页面
local function showPage(pageId, params)
    local page = pages_[pageId]
    if not page then
        logger.error(MODULE, "showPage", "page not registered: " .. pageId)
        return
    end
    local ok, node = pcall(page.create, params or {})
    if not ok then
        logger.error(MODULE, "showPage", "create failed for '" .. pageId .. "': " .. tostring(node))
        return
    end
    if container_ and node then
        container_:AddChild(node)
    end
    return node
end

-- 内部：通知回调
local function notify(pageId, params)
    if onNavigateCb_ then
        pcall(onNavigateCb_, pageId, params)
    end
end

--- replace：替换当前页面（用于 tab 切换，不压栈）
---@param pageId string
---@param params table|nil
function M.replace(pageId, params)
    -- 销毁当前页面
    destroyTop()
    if #stack_ > 0 then
        stack_[#stack_] = nil
    end
    -- 创建新页面
    local node = showPage(pageId, params)
    table.insert(stack_, { id = pageId, params = params, node = node })
    logger.info(MODULE, "replace", pageId)
    notify(pageId, params)
end

--- push：压入新页面（用于进入游戏，支持 pop 返回）
---@param pageId string
---@param params table|nil
function M.push(pageId, params)
    -- 隐藏当前页面（不销毁）
    if #stack_ > 0 then
        local top = stack_[#stack_]
        if top.node then
            top.node:SetVisible(false)
        end
    end
    -- 创建新页面
    local node = showPage(pageId, params)
    table.insert(stack_, { id = pageId, params = params, node = node })
    logger.info(MODULE, "push", pageId)
    notify(pageId, params)
end

--- pop：弹出当前页面，返回上一页
---@return boolean 是否成功返回
function M.pop()
    if #stack_ <= 1 then
        logger.warn(MODULE, "pop", "already at root, cannot pop")
        return false
    end
    -- 销毁栈顶
    destroyTop()
    table.remove(stack_)
    -- 恢复前一个页面
    local prev = stack_[#stack_]
    if prev and prev.node then
        prev.node:SetVisible(true)
    end
    logger.info(MODULE, "pop", "back to " .. (prev and prev.id or "nil"))
    if prev then
        notify(prev.id, prev.params)
    end
    return true
end

--- 获取当前页面 ID
---@return string|nil
function M.getCurrent()
    if #stack_ == 0 then return nil end
    return stack_[#stack_].id
end

--- 获取栈深度
---@return number
function M.getStackDepth()
    return #stack_
end

return M
