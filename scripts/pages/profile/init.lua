--- 装扮页面（NanoVG 渲染，与主线/自由模式风格一致）
--- 分类切换：角色（皮肤选择）/ 背景（背景选择）
local UI = require("urhox-libs/UI")
local Colors = require("shared.constants.colors")
local Router = require("app.router")
local ScreenTransition = require("shared.components.screen-transition")
local logger = require("shared.utils.logger")
local uiTap = require("shared.utils.ui-tap")
local SoundManager = require("shared.sound-manager")
local SettingsPopup = require("shared.components.settings-popup")
local TabBar = require("shared.components.tab-bar")
local OutfitManager = require("shared.outfit-manager")
local bgManager = require("shared.background-manager")
local Storyline = require("modules.storyline.init")
local Density = require("shared.utils.density")
local PageHeader = require("shared.components.page-header")
local PurchasePopup = require("shared.components.purchase-popup")
local cloudAge = require("shared.cloud-age")

local Paper = require("shared.components.game-paper")
local Pen = require("shared.components.handdrawn")
local StoryPaper = require("shared.components.story-paper")
local C = Paper.colors
local ProfileLayout = require("pages.profile.layout")
local gridPage_ = {character=1,background=1}
local pageHitAreas_ = {}
local M = {}
local MODULE = "page-profile"

-- ============================================================================
-- NanoVG 状态
-- ============================================================================
---@type userdata|nil
local nvgCtx_ = nil
local fontHandle_ = -1
local active_ = false
local animTime_ = 0

-- UI 容器
---@type any
local pageContainer_ = nil

-- 页签栏点击区域
local tabBarHitAreas_ = nil

-- 设置弹窗管理器
local settingsHelper_ = SettingsPopup.createPageHelper()

-- ============================================================================
-- 分类切换状态
-- ============================================================================
---@type "character"|"background"
local category_ = "character"

-- ============================================================================
-- 背景分类状态
-- ============================================================================
---@type string 当前选中的背景 ID
local selectedBgId_ = "default"
---@type table[] 背景网格点击区域 { x, y, w, h, bgId }
local bgThumbHitAreas_ = {}
---@type table[] 分类栏点击区域 { x, y, w, h, cat }
local categoryHitAreas_ = {}

-- 分类切换动画
local categoryFade_ = 1.0       -- 1.0 = 完全显示
local CATEGORY_FADE_SPEED = 8.0 -- 淡入速度

-- 缓存屏幕尺寸（供子函数使用）
local cachedScreenH_ = 800

-- ============================================================================
-- 皮肤图片句柄
-- ============================================================================
---@type number 当前大图句柄
local previewImg_ = -1
---@type table<string, number> skinId -> nvgImage 句柄（缩略图）
local thumbImgs_ = {}
local previewImgs_ = {} -- 大图按需加载；不让小列表解码全部角色原画。
---@type string 当前选中的皮肤 ID（实时跟踪，用于 UI 高亮）
local selectedId_ = "default"

-- ============================================================================
-- 网格布局参数（平铺换装按钮，支持多行）
-- ============================================================================
local GRID_PAD_H = 24          -- 网格水平内边距
local GRID_CELL_SIZE = 76      -- 单元格缩略图尺寸
local GRID_CELL_R = 14         -- 单元格圆角
local GRID_CELL_GAP_X = 14     -- 水平间距
local GRID_CELL_GAP_Y = 16     -- 垂直间距（行间距）
local GRID_LABEL_GAP = 6       -- 缩略图与名称间距
local GRID_LABEL_H = 16        -- 名称标签高度
local GRID_TOP_PAD = 14        -- 网格区域顶部内边距

-- ============================================================================
-- 预览区布局参数
-- ============================================================================
local PREVIEW_MAX_SIZE = 200   -- 预览图最大尺寸

-- ============================================================================
-- 点击区域缓存
-- ============================================================================
---@type table[] { x, y, w, h, skinId }
local thumbHitAreas_ = {}

-- ============================================================================
-- 切换动画
-- ============================================================================
local switchAnim_ = 0          -- 0 = 无动画，>0 = 正在播放
local SWITCH_DURATION = 0.2    -- 切换动画时长

-- ============================================================================
-- 加载 / 释放图片资源
-- ============================================================================
local function previewFor(vg, skinId)
    if previewImgs_[skinId] then return previewImgs_[skinId] end
    local skin = OutfitManager.getSkinById(skinId)
    if not vg or not skin then return -1 end
    local image = nvgCreateImage(vg, skin.texture, 0)
    if image and image > 0 then previewImgs_[skinId] = image; return image end
    return thumbImgs_[skinId] or -1
end

local function loadImages(vg)
    local skins = OutfitManager.getAllSkins()
    for _, skin in ipairs(skins) do
        local handle = nvgCreateImage(vg, skin.thumbnail or skin.texture, 0)
        if handle >= 0 then
            thumbImgs_[skin.id] = handle
        else
            logger.warn(MODULE, "loadImages", "failed to load: " .. skin.texture)
        end
    end
    previewImg_ = previewFor(vg, selectedId_)
end

local function freeImages(vg)
    local released = {}
    if vg then
        for _, images in ipairs({thumbImgs_, previewImgs_}) do
            for _, handle in pairs(images) do
                if handle > 0 and not released[handle] then
                    nvgDeleteImage(vg, handle); released[handle] = true
                end
            end
        end
    end
    thumbImgs_ = {}
    previewImgs_ = {}
    previewImg_ = -1
end

-- ============================================================================
-- 渲染
-- ============================================================================

--- 绘制标题区域（委托给公共组件）
local function renderHeader(vg, screenW, t)
    PageHeader.render(vg, screenW, PageHeader.PRESET_PROFILE)
end

-- ============================================================================
-- 分类切换栏
-- ============================================================================
local CAT_BAR_Y = 88           -- 分类栏 Y 偏移（标题区下方）
local CAT_BAR_H = ProfileLayout.categoryH           -- 胶囊高度
local CAT_BAR_GAP = 8          -- 两个胶囊间距
local CAT_PILL_W = 90          -- 单个胶囊宽度

--- 绘制分类切换栏（角色 / 背景）
local function renderCategoryBar(vg, screenW, t)
    local totalW = CAT_PILL_W * 2 + CAT_BAR_GAP
    local startX = (screenW - totalW) / 2
    local cy = CAT_BAR_Y + CAT_BAR_H / 2

    categoryHitAreas_ = {}

    local cats = {
        { id = "character",  label = "角色" },
        { id = "background", label = "背景" },
    }

    for i, cat in ipairs(cats) do
        local px = startX + (i - 1) * (CAT_PILL_W + CAT_BAR_GAP)
        local isActive = (cat.id == category_)

        Paper.button(vg,px,CAT_BAR_Y,CAT_PILL_W,CAT_BAR_H,cat.label,isActive,true,"profile")

        table.insert(categoryHitAreas_, {
            x = px, y = CAT_BAR_Y,
            w = CAT_PILL_W, h = CAT_BAR_H,
            cat = cat.id,
        })
    end
end

-- ============================================================================
-- 背景预览区
-- ============================================================================
local BG_PREVIEW_MARGIN = 24   -- 左右边距

--- 绘制背景预览区（缩放渲染当前背景 + 装饰粒子 + 切换回弹与星花特效）
local function renderBgPreview(vg, screenW, areaTop, areaBottom, t)
    local bgConfig = bgManager.getCurrent()
    if not bgConfig then return end

    local previewH=math.max(60,areaBottom-areaTop-48)
    local previewW=previewH*9/20
    local previewX=(screenW-previewW)/2
    local floatY = math.sin(t * 1.6) * 2.2
    local previewY=areaTop+6+floatY

    local scale = 1.0
    if switchAnim_ > 0 then
        local p = 1.0 - (switchAnim_ / SWITCH_DURATION)
        scale = 0.92 + 0.12 * math.sin(p * math.pi * 0.72)
    end

    local cx, cy = screenW / 2, previewY + previewH / 2
    nvgSave(vg)
    if math.abs(scale - 1.0) > 0.001 then
        nvgTranslate(vg, cx, cy)
        nvgScale(vg, scale, scale)
        nvgTranslate(vg, -cx, -cy)
    end
    Paper.panel(vg,previewX-3,previewY-3,previewW+6,previewH+6)
    nvgSave(vg)
    nvgIntersectScissor(vg,previewX,previewY,previewW,previewH)
    nvgTranslate(vg,previewX,previewY)
    local s=previewW/200
    nvgScale(vg,s,s)
    bgManager.renderBackground(vg,200,200*20/9,t,bgConfig)
    nvgRestore(vg)
    nvgRestore(vg)

    if switchAnim_ > 0 then
        local bp = 1.0 - (switchAnim_ / SWITCH_DURATION)
        Paper.burst(vg, cx, cy, math.max(previewW, previewH) * 0.85, bp)
    end

    -- 底部名称胶囊
    local nameY = previewY + previewH + 14
    local bgName = bgConfig.name or "默认"
    nvgFontFace(vg, "profile")
    nvgFontSize(vg, 14)
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)
    local nameW = nvgTextBounds(vg, 0, 0, bgName) or 0
    if nameW < 1 then nameW = #bgName * 14 * 0.5 end
    local pillW = nameW + 28
    local pillH = 28

    Pen.plaque(vg,cx-pillW/2,nameY-pillH/2,pillW,pillH,C.paper,1.5)
    nvgFillColor(vg,Pen.color(C.ink))
    nvgText(vg,cx,nameY,bgName)
end

-- ============================================================================
-- 背景网格
-- ============================================================================
local BG_GRID_CELL = 76        -- 与皮肤网格一致
local BG_GRID_R = 14
local BG_GRID_GAP_X = 14
local BG_GRID_GAP_Y = 16
local BG_GRID_LABEL_GAP = 6
local BG_GRID_LABEL_H = 16
local BG_GRID_TOP_PAD = 14

local function gridSurface(vg,w,top,bottom)
    nvgBeginPath(vg);nvgRect(vg,0,top,w,bottom-top)
    nvgFillColor(vg,Pen.color(C.paper));nvgFill(vg)
    nvgBeginPath(vg);nvgMoveTo(vg,24,top);nvgLineTo(vg,w-24,top)
    nvgStrokeColor(vg,Pen.color(C.track));nvgStrokeWidth(vg,1.5);nvgStroke(vg)
end
local function tileState(vg,x,y,size,selected,unlocked)
    if not unlocked then
        nvgBeginPath(vg);nvgRoundedRect(vg,x,y,size,size,11)
        nvgFillColor(vg,nvgRGBA(255,246,220,90));nvgFill(vg)
        local cx,cy=x+size/2,y+size/2
        Pen.plaque(vg,cx-9,cy-2,18,15,C.paper,2)
        nvgBeginPath(vg);nvgArc(vg,cx,cy-2,6,math.pi,0,NVG_CW)
        nvgStrokeColor(vg,Pen.color(C.ink));nvgStrokeWidth(vg,2.5);nvgStroke(vg)
    end
    nvgBeginPath(vg);nvgRoundedRect(vg,x,y,size,size,11)
    nvgStrokeColor(vg,Pen.color(selected and unlocked and C.orange or C.ink))
    nvgStrokeWidth(vg,selected and unlocked and 3 or 2);nvgStroke(vg)
    if selected and unlocked then
        local cx,cy=x+size-10,y+10
        Pen.circle(vg,cx,cy,10,C.green,1.5)
        nvgBeginPath(vg);nvgMoveTo(vg,cx-4,cy);nvgLineTo(vg,cx-1,cy+3);nvgLineTo(vg,cx+4,cy-3)
        nvgStrokeColor(vg,Pen.color(C.paper));nvgStrokeWidth(vg,2);nvgStroke(vg)
    end
end

--- 绘制背景网格
local function renderBgGrid(vg,screenW,gridTop,gridBottom,t,layout)
    local backgrounds=bgManager.getAll()
    gridSurface(vg,screenW,gridTop,gridBottom)
    bgThumbHitAreas_={}
    for i=layout.first,layout.last do
        local bg=backgrounds[i]
        local index=i-layout.first
        local x=layout.startX+(index%layout.cols)*90
        local y=gridTop+14+math.floor(index/layout.cols)*114
        local selected,unlocked=bg.id==selectedBgId_,bgManager.isUnlocked(bg.id)
        -- 缩略图显示背景最上方 1:1 区域，四周保留 3px 边框缝隙。
        Pen.plaque(vg,x,y,76,76,C.paper,0)
        local psize=70
        nvgSave(vg);nvgTranslate(vg,x+3,y+3)
        nvgIntersectScissor(vg,0,0,psize,psize)
        nvgScale(vg,psize/200,psize/200)
        bgManager.renderBackground(vg,200,200*20/9,t,bg)
        nvgRestore(vg)
        tileState(vg,x,y,76,selected,unlocked)
        local label=bg.name
        if not unlocked then
            label=bgManager.getUnlockLabel(bg.id) or "未解锁"
            if bgManager.isPurchaseType(bg.id) then label="￥"..tostring(bgManager.getPrice(bg.id) or "?") end
        end
        Paper.text(vg,x+38,y+90,label,unlocked and 12 or 11,selected and unlocked and C.ink or C.muted,nil,"profile")
        bgThumbHitAreas_[#bgThumbHitAreas_+1]={x=x,y=y,w=76,h=98,bgId=bg.id,locked=not unlocked}
    end
end

--- 绘制预览大图（在给定区域内居中）
---@param areaTop number 预览区域顶部 Y
---@param areaBottom number 预览区域底部 Y
local function renderPreview(vg, screenW, areaTop, areaBottom, t)
    if previewImg_ < 0 then return end

    local cx = screenW / 2
    local areaH = areaBottom - areaTop

    -- 计算预览图尺寸（保持正方形，适配可用空间）
    local nameSpace = 36
    local previewSize = math.min(PREVIEW_MAX_SIZE, areaH - nameSpace - 20, screenW - 80)
    if previewSize < 60 then return end

    -- 垂直居中（预览图 + 名称胶囊作为整体）
    local totalH = previewSize + nameSpace
    local previewY = areaTop + (areaH - totalH) / 2

    -- 轻微浮动动画
    local floatY = math.sin(t * 1.5) * 3
    previewY = previewY + floatY

    -- 切换动画缩放
    local scale = 1.0
    if switchAnim_ > 0 then
        local p = switchAnim_ / SWITCH_DURATION
        if p > 0.5 then
            scale = 0.9 + (1.0 - p) * 0.2
        else
            scale = 1.0 - p * 0.2
        end
    end

    nvgSave(vg)
    if scale ~= 1.0 then
        nvgTranslate(vg, cx, previewY + previewSize / 2)
        nvgScale(vg, scale, scale)
        nvgTranslate(vg, -cx, -(previewY + previewSize / 2))
    end

    StoryPaper.portrait(vg,previewImg_,cx-previewSize/2,previewY,previewSize,previewSize)

    nvgRestore(vg)

    if switchAnim_ > 0 then
        local bp = 1.0 - (switchAnim_ / SWITCH_DURATION)
        Paper.burst(vg, cx, previewY + previewSize / 2, previewSize * 0.9, bp)
    end

    -- 皮肤名称胶囊（预览图下方）
    local nameY = previewY + previewSize + 16
    local skinName = OutfitManager.getCurrentName()
    nvgFontFace(vg, "profile")
    nvgFontSize(vg, 16)
    nvgTextAlign(vg, NVG_ALIGN_CENTER | NVG_ALIGN_MIDDLE)

    local nameW = nvgTextBounds(vg, 0, 0, skinName) or 0
    if nameW < 1 then nameW = #skinName * 16 * 0.5 end
    local pillW = nameW + 36
    local pillH = 28
    nvgBeginPath(vg)
    nvgRoundedRect(vg, cx - pillW / 2, nameY - pillH / 2, pillW, pillH, pillH / 2)
    nvgFillColor(vg, Pen.color(C.paper))
    nvgFill(vg)

    nvgFillColor(vg, Pen.color(C.ink))
    nvgText(vg, cx, nameY, skinName)

    -- 矢量勾号
    local checkX = cx + nameW / 2 + 12
    nvgBeginPath(vg)
    nvgMoveTo(vg, checkX - 4, nameY)
    nvgLineTo(vg, checkX - 1, nameY + 3)
    nvgLineTo(vg, checkX + 4, nameY - 3)
    nvgStrokeWidth(vg, 2)
    nvgLineCap(vg, NVG_ROUND)
    nvgLineJoin(vg, NVG_ROUND)
    nvgStrokeColor(vg, Pen.color(C.ink))
    nvgStroke(vg)
end

--- 计算网格布局信息（列数、行数、所需高度）
---@param screenW number
---@return number cols, number rows, number cellH, number gridNeededH
local function calcGridLayout(screenW)
    local availW = screenW - GRID_PAD_H * 2
    local cols = math.max(1, math.floor((availW + GRID_CELL_GAP_X) / (GRID_CELL_SIZE + GRID_CELL_GAP_X)))
    local skins = OutfitManager.getAllSkins()
    local rows = math.ceil(#skins / cols)
    local cellH = GRID_CELL_SIZE + GRID_LABEL_GAP + GRID_LABEL_H
    local gridNeededH = GRID_TOP_PAD + rows * cellH + math.max(0, rows - 1) * GRID_CELL_GAP_Y + 12
    return cols, rows, cellH, gridNeededH
end

--- 绘制网格换装按钮（多行平铺，支持扩展）
---@param gridTop number 网格区域顶部 Y
---@param gridBottom number 网格区域底部 Y
local function renderGrid(vg,screenW,gridTop,gridBottom,t,layout)
    local skins=OutfitManager.getAllSkins()
    gridSurface(vg,screenW,gridTop,gridBottom)
    thumbHitAreas_={}
    for i=layout.first,layout.last do
        local skin=skins[i]
        local index=i-layout.first
        local x=layout.startX+(index%layout.cols)*90
        local y=gridTop+14+math.floor(index/layout.cols)*114
        local selected,unlocked=skin.id==selectedId_,OutfitManager.isUnlocked(skin.id)
        Pen.plaque(vg,x,y,76,76,C.paper,2)
        local handle=thumbImgs_[skin.id]
        if handle and handle>0 then
            nvgSave(vg)
            nvgGlobalAlpha(vg,unlocked and 1 or 0.55)
            StoryPaper.portrait(vg,handle,x+3,y+3,70,70)
            nvgRestore(vg)
        end
        tileState(vg,x,y,76,selected,unlocked)
        local label=skin.name
        if not unlocked then local reason=OutfitManager.getLockReason(skin.id);label=reason and reason.label or "未解锁" end
        Paper.text(vg,x+38,y+90,label,unlocked and 12 or 11,selected and unlocked and C.ink or C.muted,nil,"profile")
        thumbHitAreas_[#thumbHitAreas_+1]={x=x,y=y,w=76,h=98,skinId=skin.id,locked=not unlocked}
    end
end

--- 主渲染
local function renderAll(vg, screenW, screenH, t)
    cachedScreenH_ = screenH

    -- 标题
    renderHeader(vg, screenW, t)

    -- 分类切换栏
    renderCategoryBar(vg, screenW, t)

    local count=category_=="character" and #OutfitManager.getAllSkins() or #bgManager.getAll()
    local layout=ProfileLayout.calculate(screenW,screenH,count,gridPage_[category_])
    gridPage_[category_]=layout.page
    nvgSave(vg)
    nvgGlobalAlpha(vg,0.65+0.35*categoryFade_)
    if category_=="character" then
        renderPreview(vg,screenW,layout.previewTop,layout.gridTop,t)
    else
        renderBgPreview(vg,screenW,layout.previewTop,layout.gridTop,t)
    end
    nvgSave(vg);nvgIntersectScissor(vg,0,layout.gridTop,screenW,layout.gridBottom-layout.gridTop)
    if category_=="character" then
        renderGrid(vg,screenW,layout.gridTop,layout.gridBottom,t,layout)
    else
        renderBgGrid(vg,screenW,layout.gridTop,layout.gridBottom,t,layout)
    end
    nvgRestore(vg);nvgRestore(vg)
    pageHitAreas_={}
    if layout.pages>1 then
        for i,area in ipairs({layout.previous,layout.next}) do
            local enabled=area.delta<0 and layout.page>1 or area.delta>0 and layout.page<layout.pages
            Paper.button(vg,area.x,area.y,area.w,area.h,i==1 and "上一页" or "下一页",false,enabled,"profile")
            if enabled then pageHitAreas_[#pageHitAreas_+1]=area end
        end
        Paper.text(vg,screenW/2,layout.next.y+22,layout.page.." / "..layout.pages,13,C.muted,nil,"profile")
    end

    -- 底部页签栏
    local lockedTabs = Storyline.getNodeState("story-4") ~= "done" and { home = true } or nil
    tabBarHitAreas_ = TabBar.render(vg, screenW, screenH, "profile", t, "profile", lockedTabs, { handdrawn = true })
end

-- ============================================================================
-- 选中皮肤
-- ============================================================================
local function selectSkin(skinId)
    if skinId == selectedId_ then return end

    selectedId_ = skinId
    OutfitManager.setCurrent(skinId)

    -- 更新预览图句柄
    previewImg_ = previewFor(nvgCtx_,skinId)

    -- 触发切换动画
    switchAnim_ = SWITCH_DURATION

    logger.info(MODULE, "selectSkin", "selected: " .. skinId)
end

-- ============================================================================
-- 点击处理
-- ============================================================================
local function handleClickAt(screenX, screenY)
    if not active_ then return end
    -- 购买弹窗打开时，优先处理弹窗点击
    if PurchasePopup.isActive() then
        local lx, ly = Density.toGameCoords(screenX, screenY)
        PurchasePopup.handleClick(lx, ly)
        return
    end
    -- 设置弹窗打开时，不处理 NanoVG 层点击（UI 层会拦截弹窗内的点击）
    if settingsHelper_.isOpen() then return end

    local lx, ly = Density.toGameCoords(screenX, screenY)

    -- 页签栏点击
    local tabAction = TabBar.handleClick(lx, ly, tabBarHitAreas_)
    if tabAction then
        if tabAction.type == "tab" and tabAction.id ~= "profile" then
            uiTap.play()
            ScreenTransition.run(function()
                Router.replace(tabAction.id)
            end)
        elseif tabAction.type == "settings" then
            uiTap.play()
            settingsHelper_.open(pageContainer_)
        end
        return
    end

    -- 分类切换栏点击
    for _, area in ipairs(categoryHitAreas_) do
        if lx >= area.x and lx <= area.x + area.w
           and ly >= area.y and ly <= area.y + area.h then
            if area.cat ~= category_ then
                uiTap.play()
                category_ = area.cat
                categoryFade_ = 0
                logger.info(MODULE, "category", "switched to: " .. category_)
            end
            return
        end
    end

    for _,area in ipairs(pageHitAreas_) do
        if lx>=area.x and lx<=area.x+area.w and ly>=area.y and ly<=area.y+area.h then
            uiTap.play();gridPage_[category_]=gridPage_[category_]+area.delta
            return
        end
    end

    if category_ == "character" then
        -- 皮肤缩略图点击
        for _, area in ipairs(thumbHitAreas_) do
            if lx >= area.x and lx <= area.x + area.w
               and ly >= area.y and ly <= area.y + area.h then
                if area.locked then
                    -- 购买类皮肤：弹出购买弹窗
                    if OutfitManager.isPurchaseType(area.skinId) and nvgCtx_ then
                        uiTap.play()
                        PurchasePopup.show(nvgCtx_, area.skinId, {
                            fontName = "profile",
                            skinImage = previewFor(nvgCtx_,area.skinId),
                            onPurchased = function(skinId)
                                selectedId_ = skinId
                                OutfitManager.setCurrent(skinId)
                                previewImg_ = previewFor(nvgCtx_,skinId)
                                switchAnim_ = SWITCH_DURATION
                                logger.info(MODULE, "onPurchased", "purchased and selected: " .. skinId)
                            end,
                        })
                    end
                    return
                end
                uiTap.play()
                selectSkin(area.skinId)
                return
            end
        end
    else
        -- 背景缩略图点击
        for _, area in ipairs(bgThumbHitAreas_) do
            if lx >= area.x and lx <= area.x + area.w
               and ly >= area.y and ly <= area.y + area.h then
                if area.locked then
                    if bgManager.isPurchaseType(area.bgId) and nvgCtx_ then
                        -- 购买类背景：弹出购买弹窗
                        uiTap.play()
                        -- 云存档年龄拦截：命中时显示"禁止游戏付费服务"弹窗，不进入购买
                        if cloudAge.isPurchaseBlocked() then
                            PurchasePopup.showBlocked(nvgCtx_, { fontName = "profile" })
                            return
                        end
                        bgManager.purchase(area.bgId, function(ok, msg)
                            if ok then
                                selectedBgId_ = area.bgId
                                switchAnim_ = SWITCH_DURATION
                                logger.info(MODULE, "bgPurchased", "purchased and selected: " .. area.bgId)
                            end
                        end)
                    end
                    -- 主线解锁类：不做处理（不弹窗）
                    return
                end
                -- 已解锁背景：直接选中
                uiTap.play()
                if area.bgId ~= selectedBgId_ then
                    selectedBgId_ = area.bgId
                    bgManager.select(area.bgId)
                    switchAnim_ = SWITCH_DURATION
                    logger.info(MODULE, "selectBg", "selected: " .. area.bgId)
                end
                return
            end
        end
    end
end

-- ============================================================================
-- 事件回调（全局函数名）
-- ============================================================================

---@param eventType string
---@param eventData table
function Profile_HandleNanoVGRender(eventType, eventData)
    if not active_ or not nvgCtx_ then return end

    local dt = 1.0 / 60.0
    animTime_ = animTime_ + dt
    categoryFade_ = math.min(1,categoryFade_+dt*CATEGORY_FADE_SPEED)

    -- 切换动画推进
    if switchAnim_ > 0 then
        switchAnim_ = math.max(0, switchAnim_ - dt)
    end

    local logW, logH = Density.beginFrame(nvgCtx_)

    -- 背景（跟随装扮页面选择）
    bgManager.renderBackground(nvgCtx_, logW, logH, animTime_, nil)

    renderAll(nvgCtx_, logW, logH, animTime_)

    -- 购买弹窗（在主内容之上绘制）
    if PurchasePopup.isActive() then
        PurchasePopup.update(1.0 / 60.0)
        PurchasePopup.render(nvgCtx_, logW, logH)
    end

    Density.endFrame(nvgCtx_)
end

---@param eventType string
---@param eventData table
function Profile_HandleMouseDown(eventType, eventData)
    if not active_ then return end
    local button = eventData["Button"]:GetInt()
    if button ~= MOUSEB_LEFT then return end
    local x = eventData["X"]:GetInt()
    local y = eventData["Y"]:GetInt()
    handleClickAt(x, y)
end

---@param eventType string
---@param eventData table
function Profile_HandleTouchEnd(eventType, eventData)
    if not active_ then return end
    local x = eventData["X"]:GetInt()
    local y = eventData["Y"]:GetInt()
    handleClickAt(x, y)
end

-- ============================================================================
-- 页面生命周期
-- ============================================================================

function M.setActive(a)
    active_ = a
    if a then
        SubscribeToEvent("MouseButtonDown", "Profile_HandleMouseDown")
        SubscribeToEvent("TouchEnd", "Profile_HandleTouchEnd")
        -- 同步最新皮肤状态
        selectedId_ = OutfitManager.getCurrent()
        previewImg_ = previewFor(nvgCtx_,selectedId_)
        -- 同步最新背景状态
        selectedBgId_ = bgManager.getCurrentId()
    end
end

---@param params table|nil
---@return any UI 节点
function M.create(params)
    -- 同步当前皮肤和背景
    selectedId_ = OutfitManager.getCurrent()
    selectedBgId_ = bgManager.getCurrentId()
    category_ = "character"
    gridPage_={character=1,background=1};pageHitAreas_={};categoryFade_=1

    if not nvgCtx_ then
        nvgCtx_ = nvgCreate(1)
        if nvgCtx_ then
            fontHandle_ = nvgCreateFont(nvgCtx_, "profile", "Fonts/LongZhuTi-Regular.ttf")
            if fontHandle_ < 0 then
                logger.warn(MODULE, "create", "font load failed")
            end
            loadImages(nvgCtx_)
            SubscribeToEvent(nvgCtx_, "NanoVGRender", "Profile_HandleNanoVGRender")
        else
            logger.error(MODULE, "create", "failed to create NanoVG context")
        end
    end

    active_ = true
    animTime_ = 0
    switchAnim_ = 0
    thumbHitAreas_ = {}

    SubscribeToEvent("MouseButtonDown", "Profile_HandleMouseDown")
    SubscribeToEvent("TouchEnd", "Profile_HandleTouchEnd")

    logger.info(MODULE, "create", "wardrobe page ready")

    pageContainer_ = UI.Panel {
        width = "100%",
        flexGrow = 1,
        flexBasis = 0,
    }
    return pageContainer_
end

function M.destroy()
    active_ = false
    thumbHitAreas_ = {}
    bgThumbHitAreas_ = {}
    categoryHitAreas_ = {}
    tabBarHitAreas_ = nil
    category_ = "character"
    settingsHelper_.close()
    PurchasePopup.dismiss()
    pageContainer_ = nil

    freeImages(nvgCtx_)

    if nvgCtx_ then
        bgManager.clearThemeCache(nvgCtx_)
        nvgDelete(nvgCtx_)
        nvgCtx_ = nil
    end

    -- 全局输入事件由各页共享；销毁时由 active_ 门控，保留具名回调供再次进入。
    -- 不调用全局退订，否则会移除 UI 系统和其他页面的同名事件。


    logger.info(MODULE, "destroy", "ok")
end

return M
