--- 皮肤解锁弹窗
--- 职责：用真实角色插画展示获得动画
--- 表现：纸卡落定 + 小幅淡入 + 1秒后显示确认按钮
--- 用法：
---   local popup = require("shared.components.outfit-unlock-popup")
---   popup.show(nvgCtx, skinId)           -- 展示弹窗
---   popup.update(dt)                     -- 在 Update 中调用
---   popup.render(vg, screenW, screenH)   -- 在 NanoVGRender 中调用
---   popup.handleClick(mx, my)            -- 点击处理

local OutfitManager = require("shared.outfit-manager")
local logger = require("shared.utils.logger")
local uiTap = require("shared.utils.ui-tap")

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local Portrait=require("shared.components.story-paper")
local M = {}
local MODULE = "outfit-unlock-popup"

-- ============================================================================
-- 状态
-- ============================================================================

---@type boolean
local active_ = false

---@type number 已经过时间
local elapsed_ = 0

---@type string|nil 当前展示的皮肤 ID
local skinId_ = nil

---@type table|nil 皮肤配置
local skinData_ = nil

---@type number NanoVG 图片句柄
local skinImage_ = -1

---@type userdata|nil 所属 NanoVG 上下文
local nvgCtx_ = nil

---@type function|nil 关闭回调
local onDismiss_ = nil

-- 确认按钮区域
---@type table|nil { x, y, w, h }
local confirmBtn_ = nil

-- ============================================================================
-- 动画常量
-- ============================================================================

local SKIN_APPEAR_DELAY  = 0.15  -- 皮肤图片开始出现的延迟
local SKIN_APPEAR_DUR    = 0.5   -- 皮肤弹出动画时长
local BTN_APPEAR_DELAY   = 1.0   -- 确认按钮出现延迟（1秒后显示）
local BTN_FADE_DUR       = 0.3   -- 按钮淡入时长

-- 弹窗尺寸
local POPUP_W = 280
local POPUP_H = 360

local font_="adv"

-- ============================================================================
-- 公共 API
-- ============================================================================

--- 是否正在显示
---@return boolean
function M.isActive()
    return active_
end

--- 显示皮肤解锁弹窗
---@param nvgCtx userdata NanoVG 上下文
---@param skinId string 解锁的皮肤 ID
---@param opts table|nil { fontName = string, onDismiss = function }
function M.show(nvgCtx, skinId, opts)
    opts = opts or {}
    local candidate = OutfitManager.getSkinById(skinId)
    if not candidate then
        logger.warn(MODULE, "show", "unknown skin: " .. tostring(skinId))
        return
    end

    if skinImage_>0 and nvgCtx_ then nvgDeleteImage(nvgCtx_,skinImage_) end
    skinImage_=-1
    skinData_=candidate
    font_=opts.fontName or "adv"
    nvgCtx_ = nvgCtx
    skinId_ = skinId
    elapsed_ = 0
    active_ = true
    confirmBtn_ = nil
    onDismiss_ = opts.onDismiss

    -- 加载皮肤贴图
    skinImage_ = nvgCreateImage(nvgCtx, skinData_.texture, 0)
    if skinImage_ < 0 then
        logger.warn(MODULE, "show", "failed to load skin image: " .. skinData_.texture)
    end

    logger.info(MODULE, "show", "unlocked: " .. skinData_.name)
end

--- 更新动画
---@param dt number
function M.update(dt)
    if not active_ then return end
    elapsed_ = elapsed_ + dt
end

--- 处理点击
---@param mx number
---@param my number
function M.handleClick(mx, my)
    if not active_ then return end

    -- 确认按钮点击
    if confirmBtn_ and elapsed_ >= BTN_APPEAR_DELAY then
        local b = confirmBtn_
        if mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
            uiTap.play()
            M.dismiss()
            return
        end
    end
end

--- 关闭弹窗
function M.dismiss()
    if not active_ then return end
    active_ = false
    if skinImage_>0 and nvgCtx_ then nvgDeleteImage(nvgCtx_,skinImage_) end
    skinImage_=-1
    nvgCtx_=nil
    skinId_ = nil
    skinData_ = nil
    confirmBtn_ = nil

    if onDismiss_ then
        local cb = onDismiss_
        onDismiss_ = nil
        cb()
    end
end

-- ============================================================================
-- 渲染
-- ============================================================================

function M.render(vg, screenW, screenH)
    if not active_ or not skinData_ then return end
    local appear=math.min(1,math.max(0,(elapsed_-0.05)/0.3))
    nvgBeginPath(vg);nvgRect(vg,0,0,screenW,screenH)
    nvgFillColor(vg,nvgRGBA(63,56,36,math.floor(140*math.min(1,elapsed_/0.2))));nvgFill(vg)
    if appear<=0 then return end
    local w,h=math.min(POPUP_W,screenW-40),math.min(POPUP_H,screenH-32)
    local x,y=(screenW-w)/2,(screenH-h)/2+8*(1-appear)^3
    local cx=screenW/2
    nvgSave(vg);nvgGlobalAlpha(vg,appear)
    Paper.panel(vg,x,y,w,h)
    Paper.text(vg,cx,y+28,"获得新皮肤！",24,C.ink,nil,font_)
    local progress=math.min(1,math.max(0,(elapsed_-SKIN_APPEAR_DELAY)/SKIN_APPEAR_DUR))
    local size=math.min(140,h-210)
    local py=y+62+6*(1-progress)^3
    if skinImage_>0 and progress>0 then
        nvgSave(vg);nvgGlobalAlpha(vg,appear*progress)
        Portrait.portrait(vg,skinImage_,cx-size/2,py,size,size)
        nvgRestore(vg)
    end
    Paper.burst(vg,cx,py+size/2,size,math.min(1,elapsed_/0.8))
    Paper.text(vg,cx,y+h-122,skinData_.name,20,C.ink,nil,font_)
    Paper.text(vg,cx,y+h-98,"可以在装扮页更换",12,C.muted,nil,font_)
    local alpha=math.min(1,math.max(0,(elapsed_-BTN_APPEAR_DELAY)/BTN_FADE_DUR))
    if alpha>0.01 then
        confirmBtn_={x=cx-80,y=y+h-66,w=160,h=44}
        local b=confirmBtn_
        Paper.button(vg,b.x,b.y,b.w,b.h,"太棒了！",true,true,font_,alpha)
    else confirmBtn_=nil end
    nvgRestore(vg)
end

return M
