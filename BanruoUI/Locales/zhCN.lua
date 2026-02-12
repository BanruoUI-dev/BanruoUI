-- Locales/zhCN.lua
local B = BanruoUI
if not B then return end

B.__locales = B.__locales or {}
local L = {}
B.__locales['zhCN'] = L

-- Step0 (v2.5) minimal strings for quick verification
L['LANG_GEAR_TOOLTIP'] = '设置'
L['LANG_MENU_TOGGLE'] = '切换语言'
L['LANG_TO_ZH'] = '切换到 中文'
L['LANG_TO_EN'] = '切换到 English'
L['LANG_AUTO'] = '跟随系统'
L['LANG_ZH'] = '中文'
L['LANG_EN'] = 'English'

-- Step1 (v2.5.2) Core/Frame top bar + restore popup
L['LABEL_THEME'] = '主题：'
L['DD_NO_THEME_PACK'] = '未检测到主题包'
L['BTN_SWITCH_THEME'] = '切换主题'
L['BTN_FORCE_RESTORE'] = '强制还原默认'
L['POPUP_CONTINUE'] = '继续'
L['POPUP_RESTORE_TEXT'] = [[确定要【强制还原默认】吗？

这会：
- 删除该主题在 WA 中的旧内容并重新导入作者默认

可能覆盖你的微调。]]

-- Step2 (v2.5.3) Core/Main localized
L["DD_NO_THEME_PACK"] = "未检测到主题包"
L["DD_UNKNOWN"] = "未知"
L["PREVIEW_NO_THEME_PACK"] = "未检测到主题包。\n\n请安装主题包插件（独立 AddOn），然后 /reload。\n点击右上【帮助】查看说明。"
L["PREVIEW_AUTHOR_LINE"] = "作者：%s"
L["PREVIEW_VERSION_LINE"] = "版本：%s"
L["PREVIEW_INCLUDES_LINE"] = "包含：%s"
L["PREVIEW_INCLUDES_BRE"] = "包含：BRE 主题数据"
L["PREVIEW_INCLUDES_NONE"] = "无（该主题只用于展示/扩展字段）"
L["PREVIEW_TIP_APPLY_REQUIRED"] = "点击上方【切换主题】才会真正生效。"
L["PREVIEW_TIP_SWITCH_NO_OVERRIDE"] = "普通切换不覆盖 WA 微调；回作者默认用【强制还原默认】。"
L["PREVIEW_TIP_ELVUI_MANUAL"] = "提示：本插件不再自动处理 ElvUI（如需 ElvUI 请自行在 ElvUI 中粘贴导入）。"
L["ERR_WA_ADAPTER_NOT_READY"] = "BRE 适配层未就绪"
L["ERR_WA_NO_GROUPNAME"] = "未提供 groupName"
L["ERR_THEME_NO_WA_REF"] = "该主题未提供 BRE 引用"
L["ERR_WA_REG_MISSING"] = "未找到 BRE 注册数据（theme.bre.main）"
L["WA_FORCE_RESTORE_OK"] = "BRE：已强制还原默认（已重新导入）"
L["WA_FIRST_IMPORT_OK"] = "BRE：首次载入完成（已导入）"
L["WA_HIDDEN_SWITCH_OK"] = "BRE：已隐藏式切换（不覆盖微调）"
L["PRINT_NO_THEME_PACK"] = "没有可切换的主题（未检测到主题包）。"
L["PRINT_ALREADY_ACTIVE"] = "该主题已生效，无需切换。"
L["PRINT_WA_FAIL"] = "BRE:失败 - %s"
L["PRINT_SWITCH_OK"] = "已切换主题：%s"
L["PRINT_WA_RESULT"] = "BRE：%s"
L["PRINT_RELOAD_SUGGEST"] = "如有显示异常建议 /reload。"
L["PRINT_LOADED_HINT"] = "已加载。输入 /banruo 打开面板。"

-- Step3 fix (v2.5.5): ThemePreview module texts
L['PREVIEW_HINT_TOP'] = '选择主题只做预览，点击上方【切换主题】才会真正生效。'
L['MODULE_THEME_PREVIEW'] = '主题预览'

-- Step4: module titles + ElementSwitch UI bits
L['MODULE_ELEMENT_SWITCH']   = '元素切换'
L['MODULE_STORY_COLLECTION'] = '故事集'
L['MODULE_JUKEBOX']          = '点歌机'
L['MODULE_ELVUI_STRING']     = 'ElvUI 字符串'

-- 元素切换 - 动态相框
L['ES_DPF_TITLE'] = '动态相框'
L['ES_DPF_FRAME'] = '框体'
L['ES_DPF_BG']    = '底纹'

L['ES_MM_TITLE'] = '小地图'
L['ES_MM_FRAME'] = '外框'
L['ES_MM_BG']    = '背景'

-- 元素切换 - 动作条
L['ES_AB_TITLE']       = '动作条'
L['ES_AB_BG']          = '背景'
L['ES_AB_ORB_R']       = '右能量球'
L['ES_AB_ORB_R_DECOR'] = '右球装饰'
L['ES_AB_ORB_L']       = '左能量球'
L['ES_AB_ORB_L_DECOR'] = '左球装饰'

-- 元素切换：散件装饰
L['ES_MISC_TITLE']       = '散件装饰'
L['ES_MISC_TRIM_TOP']    = '顶部材质条'
L['ES_MISC_TRIM_BOTTOM'] = '底部材质条'
L['ES_MISC_DECOR_1']     = '装饰 I'
L['ES_MISC_DECOR_2']     = '装饰 II'
L['ES_MISC_DECOR_3']     = '装饰 III'
L['ES_MISC_DECOR_4']     = '装饰 IV'

-- Alias keys (keep existing button ids to avoid touching logic)
L['BTN_APPLY_THEME'] = L['BTN_SWITCH_THEME']
L['BTN_RESET']       = '重置'

L['BTN_REFRESH_LIST']    = '刷新列表'
L['BTN_ELEMENT_MANAGER'] = '元素管理'

-- ElvUI String 页面：导出源选择 + 一键复制
L['BTN_COPY'] = '复制'
L['ELVUI_STRING_SOURCE_ELVUI'] = 'ElvUI'
L['ELVUI_STRING_SOURCE_NDUI']  = 'NDui'
L['ELVUI_STRING_HINT'] = '仅展示/复制：本页不执行导入，不调用 ElvUI。请复制后在 ElvUI 导入界面手动粘贴。'
L['ELVUI_STRING_META_NO_ACTIVE'] = '当前已生效主题：未知（请先在【主题预览】点击【切换主题】生效）'
L['ELVUI_STRING_BODY_NO_ACTIVE'] = '主题未生效，无法读取导出字符串。'
L['ELVUI_STRING_META_ACTIVE_FMT'] = '当前已生效主题：%s'
L['ELVUI_STRING_META_PROFILE_FMT'] = 'Profile：%s'
L['ELVUI_STRING_BODY_NO_STRING'] = '主题包未提供 ElvUI 适配字符串。\n\n主题作者可在主题包中写入：theme.elvui.importString'
L['ELVUI_STRING_NDUI_PLACEHOLDER'] = 'NDui 导出字符串暂未提供。'
L['ELVUI_STRING_COPY_NOTICE'] = '已全选，请 Ctrl+C 复制。'

L['TEXT_NO_ACTIVE_THEME']   = '当前没有“已生效主题”。'
L['TEXT_CLICK_APPLY_THEME'] = '请先在【主题预览】里点击【切换主题】使主题生效，然后再来这里开关元素。'

L['TEXT_PLACEHOLDER_UNAVAILABLE'] = '不可用 / 敬请期待'

L["ELEMENT_3D_PORTRAIT"] = "3D 人物"

L["ES_DPF_PORTRAIT"] = "3D 人物"

L["ES_DECOR_V"] = "装饰 V"

L["ES_DECOR_VI"] = "装饰 VI"

L["ES_DECOR_VII"] = "装饰 VII"

L["ES_DECOR_VIII"] = "装饰 VIII"

L["ES_MISC_DECOR_5"] = "装饰 V"

L["ES_MISC_DECOR_6"] = "装饰 VI"

L["ES_MISC_DECOR_7"] = "装饰 VII"

L["ES_MISC_DECOR_8"] = "装饰 VIII"

-- BrMusic
L['MODULE_BRMUSIC'] = '点歌台'
L['BRMUSIC_ENABLE'] = '启用点歌台（BrMusic）'
L['BRMUSIC_ENABLE_TIP'] = '关闭后仅禁用功能；如需彻底禁用，请在插件列表禁用 BrMusic 并 /reload。'
L['BRMUSIC_BTN_PLAY_TIP'] = '播放'
L['BRMUSIC_BTN_STOP_TIP'] = '停止'
L['BRMUSIC_BTN_NEXT_TIP'] = '下一首'
L['BRMUSIC_MODE_AUTO'] = '自动'
L['BRMUSIC_MODE_MANUAL'] = '手动'

L['BRMUSIC_STATE_IDLE'] = '未播放'
L['BRMUSIC_STATE_PLAYING'] = '播放中'

L['BRMUSIC_CUSTOM_01'] = '自定义 01'
L['BRMUSIC_CUSTOM_02'] = '自定义 02'
L['BRMUSIC_CUSTOM_03'] = '自定义 03'
L['BRMUSIC_CUSTOM_04'] = '自定义 04'
L['BRMUSIC_CUSTOM_05'] = '自定义 05'

L['BRMUSIC_GAME_01'] = '暴雪曲目 01'
L['BRMUSIC_GAME_02'] = '暴雪曲目 02'
L['BRMUSIC_GAME_03'] = '暴雪曲目 03'
L['BRMUSIC_GAME_04'] = '暴雪曲目 04'
L['BRMUSIC_GAME_05'] = '暴雪曲目 05'
