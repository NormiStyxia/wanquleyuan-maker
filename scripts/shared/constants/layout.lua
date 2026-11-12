-- 布局尺寸常量（单位：base pixel，等同于 CSS px）
return {
    -- 竖屏主设计比例 9:20；窗口仍按实际视口响应式布局。
    DESIGN_WIDTH      = 540,
    DESIGN_HEIGHT     = 1200,

    -- 主菜单
    MENU_PADDING      = 24,
    MENU_START_Y      = 16,      -- 内容起始 Y 偏移
    MENU_TITLE_GAP    = 30,      -- 标题区域上方间距
    MENU_GRID_GAP     = 14,      -- 标题与网格之间间距
    TITLE_FONT_SIZE   = 38,
    SUBTITLE_FONT_SIZE = 16,

    -- 游戏瓷砖网格（加大间距和圆角，适合儿童触控）
    TILE_COLUMNS      = 2,
    TILE_GAP          = 16,
    TILE_BORDER_RADIUS = 22,
    TILE_ICON_SIZE    = 50,

    -- 底部页签栏
    TAB_BAR_HEIGHT    = 56,

    -- 进度条
    PROGRESS_HEIGHT   = 8,
    PROGRESS_RADIUS   = 4,

    -- 游戏棋盘区域边距（统一配置）
    BOARD_SIDE_PADDING   = 30,    -- 左右各留白像素
    BOARD_TOP_PADDING    = 64,    -- 顶部 HUD 下方最小留白
    BOARD_BOTTOM_PADDING = 50,    -- 底部栏上方最小留白
    BOARD_Y_TOP_WEIGHT   = 1,     -- 上方留白权重（上下比例 1:3）
    BOARD_Y_BOTTOM_WEIGHT = 3,    -- 下方留白权重

    -- 保留兼容（game-container 等模块可能引用）
    TOP_BAR_HEIGHT    = 60,
    BOTTOM_NAV_HEIGHT = 58,
    PAGE_PADDING      = 16,
    CARD_GAP          = 16,
    CARD_COVER_HEIGHT = 160,
    CARD_BORDER_RADIUS = 14,
    BANNER_HEIGHT     = 140,
    BANNER_RADIUS     = 16,
    SECTION_TITLE_SIZE = 17,
    SECTION_DOT_SIZE  = 6,

    FONT_SIZE_TITLE   = 18,
    FONT_SIZE_BODY    = 14,
    FONT_SIZE_CAPTION = 12,
    FONT_SIZE_SMALL   = 11,

    -- 字号体系（扩充）
    FONT_SIZE_HINT        = 11,
    FONT_SIZE_BUTTON      = 15,
    FONT_SIZE_NORMAL      = 16,
    FONT_SIZE_MEDIUM      = 17,
    FONT_SIZE_HEADER      = 22,
    FONT_SIZE_POPUP_TITLE = 24,
    FONT_SIZE_BIG_TITLE   = 28,
    FONT_SIZE_DISPLAY     = 32,

    -- 圆角体系
    RADIUS_SMALL     = 4,
    RADIUS_BADGE     = 6,
    RADIUS_INPUT     = 8,
    RADIUS_PANEL     = 10,
    RADIUS_CARD      = 12,
    RADIUS_BUTTON_SM = 14,
    RADIUS_DIALOG    = 16,
    RADIUS_BUTTON    = 20,
    RADIUS_CAPSULE   = 22,
    RADIUS_LARGE     = 24,

    -- 间距体系
    GAP_SMALL   = 8,
    GAP_BUTTON  = 10,
    GAP_MEDIUM  = 12,
    GAP_LARGE   = 14,
    GAP_XLARGE  = 16,

    -- 阴影模糊
    SHADOW_SM   = 12,
    SHADOW_MD   = 16,
    SHADOW_LG   = 20,
    SHADOW_XL   = 24,

    -- 星星间距
    STAR_GAP_HUD          = 17,
    STAR_GAP_LEVEL_SELECT = 15,
    STAR_GAP_RESULT       = 42,

    -- 图标尺寸
    ICON_NAV    = 36,
    ICON_BUTTON = 30,
    ICON_AVATAR = 64,
}
