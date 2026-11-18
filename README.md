# 新版角色动作场

双击 `play.bat` 进入动作场，默认装备长枪。用 WASD 移动，停步后按 J 起手，连段中再按 J 续击。圆木重锤点按三次 J 依次前砸、柄尾撞、踏步横抡。横抡时松开第三次按键，再按住 J 至少 0.16 秒接空翻重砸。Q/E 循环切换武器，1–6 切换外观，Esc 暂停与恢复。两份批处理使用项目约定的 Windows Godot 4.7.2 普通版。

[四种武器正常速度实机演示](previews/four-weapons.mp4) · [圆木重锤带声演示 · 向左三段收招、向右四段重砸](previews/hammer.mp4)

前三击在前砸、柄尾顶出和横抡压身的位置分别定势约 0.15、0.135 和 0.13 秒，期间可以缓存下一击。第四击连续翻过最高点，加速下落，着地后再用 0.12 秒挥锤砸地。柄尾撞中杂兵时有约一帧接触停顿。

[横抡三连 GIF](previews/hammer-three-hit.gif) · [横抡接空翻四连 GIF](previews/hammer-four-hit.gif)

**哥布林打击测试。** 双击 `play-goblin.bat`，角色会带圆木锤面对旧工程的「苔牙杂兵」。停步后点按 J 续击，第三击中再长按 J 接重砸。WASD 可测试距离和前后错位，R 可将双方复位。杂兵会承受击退、倒地，并在倒地 1.5 秒后复位供下一轮测试。[实机回放](previews/hammer-goblin.gif)

`enemies/raider/` 保留旧工程苔牙杂兵的三组动画帧、时长、脚底锚点、300 HP、身高和半径。测试场使用被动站位，伤害和击退是本场的调试参数。第一、三击检查挥动的锤头，第二击检查柄尾凸起，第四击在锤面落地时检查命中。同一段对同一只杂兵最多结算一次。

| 去哪里改 | 内容及来源 |
|---|---|
| `character/art/cast/<形象>/`、`character/data/presets.json` | 六套新绘部件、共用表情、贴图配准、鞋宽与脚底偏移。按注册表中的部件 ID 和挂点查找。 |
| `character/data/rig.json`、`character/art/base/` | 原作提取的角色层级、枢轴、基础贴图、贴图引用及来源记录。 |
| `character/pose_sampler.gd`、`character/cast_rig.gd` | 来源曲线采样、层级变换和层序到 Godot 的适配，以及新版外观换图。 |
| `weapons/bow/`、`weapons/greatsword/`、`weapons/spear/` | 各自的武器贴图、装备挂点、片段及控制器配置。三者共用 `weapons/standing_combo_controller.gd` 执行已核对的站立普攻。弓三段、大剑四段、长枪三段。 |
| `weapons/hammer/` | 本项目原创圆木重锤。木质撞头与柄尾风线由武器节点绘制，滑握距离、双手握点、前砸、柄尾撞、踏步横抡和空翻砸地在 `action.json`。目录内还包含时钟、武器绘制、接地反馈、扬尘和声音。 |
| `scenes/arena.tscn` | 输入、地面边界和展示。 |

**在其他场景复用。** 实例化 `character/actor.tscn`，连接 `displacement_requested(delta)`，在回调里同步把角色移到碰撞处理后的地面位置。宿主每帧调用 `advance(delta, direction)`，用 `attack(direction)` 处理按下，用 `release_attack()` 处理松开，`select_cast(0…5)` 换装，`select_weapon(0…3)` 依次选择弓、大剑、长枪、锤。暂停使用 `set_paused(value)`。角色内部采样动作、处理连段并播放落锤反馈。宿主可订阅 `slam_contact(at)` 获取锤面接地的世界坐标。

**验证。** 双击 `verify.bat`，依次执行编译导入、来源动作与部件回归、重锤动作与腿部连接、240 个姿势的渲染对照，以及键盘输入场景测试。`tests/baseline/` 的 20 张无损图中，12 张保存弓、大剑和长枪的迁移前画面，8 张保存新版圆木锤的实机姿势，每张包含六套形象左右镜像。测试在相同视口、姿势、采样时间和比例下比较透明角色画面；测试报告写入 Godot 用户目录。演示按 30 fps 从实际场景输出，重锤音轨用游戏采集到的触地帧和同一音源合成。

普通动作场供四种武器预览，哥布林打击场用于测试原创锤子的命中和受击。大剑原有 18 组原生对照中的 10 个离散属性差异继续保留，涉及刀光、嘴部和一次碰撞开关。来源 JSON 中的提取路径和哈希只用于溯源。
