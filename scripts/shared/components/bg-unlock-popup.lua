--- 背景解锁弹窗
--- 职责：通关解锁新背景时展示获得动画
--- 表现：真实背景纸卡 + 轻微落定 + 1秒后显示确认按钮
--- 用法与 outfit-unlock-popup 一致

local BackgroundManager = require("shared.background-manager")
local logger = require("shared.utils.logger")
local uiTap = require("shared.utils.ui-tap")

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local C = Paper.colors
local M = {}
local MODULE = "bg-unlock-popup"

-- ============================================================================
-- 状态
-- ============================================================================

---@type boolean
local active_ = false

---@type number
local elapsed_ = 0

---@type string|nil
local bgId_ = nil

---@type table|nil
local bgData_ = nil

---@type userdata|nil
local nvgCtx_ = nil

---@type function|nil
local onDismiss_ = nil

---@type table|nil { x, y, w, h }
local confirmBtn_ = nil

-- ============================================================================
-- 动画常量
-- ============================================================================

local BTN_APPEAR_DELAY = 1.0
local BTN_FADE_DUR     = 0.3
local POPUP_W          = 280
local POPUP_H          = 400
local font_ = "adv"

-- ============================================================================
-- 公共 API
-- ============================================================================

function M.isActive()
    return active_
end

---@param nvgCtx userdata
---@param bgId string
---@param opts table|nil { fontName = string, onDismiss = function }
function M.show(nvgCtx, bgId, opts)
    opts = opts or {}
    local candidate
    local all = BackgroundManager.getAll()
    for _, bg in ipairs(all) do
        if bg.id == bgId then
            candidate = bg
            break
        end
    end
    if not candidate then
        logger.warn(MODULE, "show", "unknown bg: " .. tostring(bgId))
        return
    end

    bgData_ = candidate
    font_ = opts.fontName or "adv"
    nvgCtx_ = nvgCtx
    bgId_ = bgId
    elapsed_ = 0
    active_ = true
    confirmBtn_ = nil
    onDismiss_ = opts.onDismiss

    logger.info(MODULE, "show", "unlocked bg: " .. bgData_.name)
end

function M.update(dt)
    if not active_ then return end
    elapsed_ = elapsed_ + dt
end

function M.handleClick(mx, my)
    if not active_ then return end
    if confirmBtn_ and elapsed_ >= BTN_APPEAR_DELAY then
        local b = confirmBtn_
        if mx >= b.x and mx <= b.x + b.w and my >= b.y and my <= b.y + b.h then
            uiTap.play()
            M.dismiss()
        end
    end
end

function M.dismiss()
    if not active_ then return end
    active_ = false
    bgId_ = nil
    bgData_ = nil
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
    if not active_ or not bgData_ then return end
    local appear=math.min(1,math.max(0,(elapsed_-0.05)/0.3))
    nvgBeginPath(vg);nvgRect(vg,0,0,screenW,screenH)
    nvgFillColor(vg,nvgRGBA(63,56,36,math.floor(140*math.min(1,elapsed_/0.2))));nvgFill(vg)
    if appear<=0 then return end
    local w,h=math.min(POPUP_W,screenW-40),math.min(POPUP_H,screenH-32)
    local x,y=(screenW-w)/2,(screenH-h)/2+8*(1-appear)^3
    local cx=screenW/2
    nvgSave(vg);nvgGlobalAlpha(vg,appear)
    Paper.panel(vg,x,y,w,h)
    Paper.text(vg,cx,y+28,"解锁新背景！",24,C.ink,nil,font_)
    -- 9:20 的实际背景预览，和应用后的背景使用同一配置。
    local ph=h-200
    local pw=ph*9/20
    local px,py=cx-pw/2,y+56
    Paper.panel(vg,px-3,py-3,pw+6,ph+6)
    nvgSave(vg);nvgIntersectScissor(vg,px,py,pw,ph);nvgTranslate(vg,px,py)
    nvgScale(vg,pw/200,pw/200)
    BackgroundManager.renderBackground(vg,200,200*20/9,elapsed_,bgData_)
    nvgRestore(vg)
    Paper.burst(vg,cx,py+ph/2,ph*0.7,math.min(1,elapsed_/0.8))
    Paper.text(vg,cx,py+ph+26,bgData_.name,20,C.ink,nil,font_)
    Paper.text(vg,cx,py+ph+50,"可以在装扮页更换",12,C.muted,nil,font_)
    local alpha=math.min(1,math.max(0,(elapsed_-BTN_APPEAR_DELAY)/BTN_FADE_DUR))
    if alpha>0.01 then
        confirmBtn_={x=cx-80,y=y+h-66,w=160,h=44}
        local b=confirmBtn_
        Paper.button(vg,b.x,b.y,b.w,b.h,"太棒了！",true,true,font_,alpha)
    else confirmBtn_=nil end
    nvgRestore(vg)
end

return M
