# 新版角色动作场

双击 `play.bat` 进入动作场，默认装备长枪。用 WASD 移动，停步后按 J 起手，连段中再按 J 续击。Q/E 循环切换武器，1–6 切换外观，Esc 暂停与恢复。两份批处理使用项目约定的 Windows Godot 4.7.2 普通版。

[四种武器正常速度实机演示](previews/four-weapons.mp4) · [圆木重锤带声演示](previews/hammer.mp4)

| 去哪里改 | 内容及来源 |
|---|---|
| `character/art/cast/<形象>/`、`character/data/presets.json` | 六套新绘部件、共用表情、贴图配准、鞋宽与脚底偏移。按注册表中的部件 ID 和挂点查找。 |
| `character/data/rig.json`、`character/art/base/` | 原作提取的角色层级、枢轴、基础贴图、贴图引用及来源记录。 |
| `character/pose_sampler.gd`、`character/cast_rig.gd` | 来源曲线采样、层级变换和层序到 Godot 的适配，以及新版外观换图。 |
| `weapons/bow/`、`weapons/greatsword/`、`weapons/spear/` | 各自的武器贴图、装备挂点、片段及控制器配置。三者共用 `weapons/standing_combo_controller.gd` 执行已核对的站立普攻。弓三段、大剑四段、长枪三段。 |
| `weapons/hammer/` | 本项目原创圆木重锤。长柄、双手握点、前砸和空翻砸地在 `action.json`。目录内还包含时钟、武器绘制、接地反馈、扬尘和声音。 |
| `scenes/arena.tscn` | 输入、地面边界和展示。 |

**在其他场景复用。** 实例化 `character/actor.tscn`，连接 `displacement_requested(delta)`，在回调里同步把角色移到碰撞处理后的地面位置。宿主每帧调用 `advance(delta, direction)`，用 `attack(direction)` 处理攻击按键，`select_cast(0…5)` 换装，`select_weapon(0…3)` 依次选择弓、大剑、长枪、锤。暂停使用 `set_paused(value)`。角色内部采样动作、处理连段并播放落锤反馈。宿主可订阅 `slam_contact(at)` 获取锤面接地的世界坐标。

**验证。** 双击 `verify.bat`，依次执行编译导入、来源动作与部件回归、重锤动作与腿部连接、228 个姿势的渲染对照，以及键盘输入场景测试。`tests/baseline/` 的 19 张无损图来自迁移前独立原型，每张包含六套形象左右镜像。测试在相同视口、姿势、采样时间和比例下比较透明角色画面；测试报告写入 Godot 用户目录。演示按 30 fps 从实际场景输出，重锤音轨用游戏采集到的触地帧和同一音源合成。

本阶段覆盖动作预览。大剑原有 18 组原生对照中的 10 个离散属性差异继续保留，涉及刀光、嘴部和一次碰撞开关。来源 JSON 中的提取路径和哈希只用于溯源。敌人命中、伤害与冒险流程属于后续阶段。
