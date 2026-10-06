# 离线审阅证据，不是游戏接入截图

before-deploy-720p.png是06原部署截图副本；after-layout-overlay-720p.png是精确逻辑格线及一名狐火的离线示意，空UI框不是要删去游戏文字。两者只做最小美术前后对照。

本目录由.gdignore隔离Godot资源导入；06导出时也应排除本目录，不将提示词、脚本或对照图加入PCK。上层board-courtyard.png才是唯一候选运行PNG。

在有Python 3/Pillow的环境执行 `python3 build_overlay_preview.py` 可重建after图，仅写本审阅目录，不启动游戏。底图及当前production狐火均以脚本位置推导的仓库相对路径读取，无本机绝对路径。重建不能取代真实部署/射程/混战截图复核。原底图不变，不重绘角色。
