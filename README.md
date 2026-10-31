# NovaMemory

轻量 Windows 内存优化工具：原生 Win32 + GDI+，单文件 EXE，亚克力风格界面，不依赖 Python 或额外运行库。

## 运行

双击 `outputs\NovaMemory-final.exe`（`outputs\NovaMemory-<版本>.exe` 是同一份文件的归档副本）。

- 默认请求管理员权限（注册表清理、系统级操作需要）；拒绝 UAC 也能正常使用，只是相关操作会提示受限。
- 自动化/提权受限场景可加参数 `--no-elevate` 跳过提权。
- 单实例运行：重复启动会把已有窗口唤到前台，不会开第二个进程。
- 关闭主窗口默认隐藏到托盘，托盘右键菜单可显示主窗口、立即优化、开关开机自启、退出。

设置与运行数据都放在 `%APPDATA%\NovaMemory`：

| 文件 | 内容 |
| --- | --- |
| `settings.json` | 阈值、主题、透明度、强调色、整体色、背景图、注册失败原因 |
| `history.txt` | 每次优化/清理记录（`时间戳\|类型\|释放字节`），用于首页「本周释放」统计 |
| `RegistryBackup-*.reg` | 注册表清理前的完整备份（UTF-16LE + BOM，可直接双击导入） |

## 页面与功能

| 页面 | 能力 |
| --- | --- |
| 内存概览 | 内存环形图、近 60 秒曲线（250 ms 采样 240 点）、自动优化开关与触发阈值、优化效果统计、左下「运行状态」卡片 |
| 实时监测 | 内存/处理器负载/系统盘可用/开机时长四张卡，每秒刷新；电脑配置为静态快照 |
| App 清理 | 扫描 `LocalAppData`/`Roaming` 各应用目录真实占用，标出未在已安装列表中登记的疑似残留，可回收站删除或打开目录 |
| 存储空间 | 按目录统计系统盘占用并出分段色块；可切换「寻找大文件」，列出全盘 ≥200 MB 大文件，点击在资源管理器中定位 |
| 风险检测 | 逐项核对防火墙、Defender 实时保护、远程桌面、UAC、SMB1、自动更新、磁盘余量、启动项数量、内存压力，每项可直接跳到对应系统设置 |
| 系统维护 | 注册表体检（失效启动项/残留卸载项/无效文件关联/失效应用路径，先备份再删除，删除后复查）、缓存探测与清理（真实统计、只删可重建缓存、被占用自动跳过）、进程管理、启动项启用/禁用与自定义启动项 |
| AI 诊断 | 离线规则引擎：读取本机真实读数后按优先级给建议，一键跳转到对应维护页；不上传任何数据 |
| 偏好设置 | 常规：自动优化、阈值、优化方式、进程/启动项范围、开机自启动开关、注册/取消注册到系统、检查更新；外观：主题、透明度、RGB 强调色、全局整体色、自定义背景图 |

其它细节：

- 开机自启优先写入计划任务 `NovaMemoryAutostart`（`/rl highest`，登录时不弹 UAC）；无权限时回退到 `HKCU\...\Run`。托盘菜单与设置页共用同一状态。
- 注册到系统只注册当前运行的 EXE；取消注册时若发现更高版本存在，会自动改为注册该版本。
- 检查更新读取 `https://api.github.com/repos/Ethan1999991231/Nova-Memory/releases/latest`，不联网也能正常使用其它功能。
- 所有提示都在应用内（无 `MessageBox`）；长文本统一按盒子宽度省略号裁剪，不换行溢出。

## 原生构建

使用 Visual Studio Build Tools 的 C++ 工具链：

```powershell
.\native\build.ps1
```

`build.ps1` 会先结束正在运行的实例（避免 `LNK1104` 文件占用），编译后按 `native\app.rc` 的 `FILEVERSION` 归档为 `outputs\NovaMemory-<版本>.exe`。

图标由 `tools\make_icon.py` 从 `assets\cat-fish.jpg` 生成：去纸面背景 → 去投影 → 裁切居中 → 外扩颜色防白边 → 输出 9 档 ICO 与预览图。

旧构建请用 `tools\archive-builds.ps1` 归档到 `outputs\backup\`，避免版本比较逻辑被历史副本干扰。

## 验证

静态契约（36 条断言，含功能存在性、编码与安全约束）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\ui_contract.ps1
```

交互验证脚本（均为 PostMessage 客户区点击 + 截图，需要在桌面会话中运行）：

| 脚本 | 验证内容 |
| --- | --- |
| `tools\verify-window.ps1` | 状态卡弹层、复制配置到剪贴板、关闭到托盘、托盘恢复、托盘退出、EXE 图标 |
| `tools\probe-cache.ps1` | 缓存页真实读数 + 自种样本被真正清理 |
| `tools\probe-registry.ps1` | 注册表体检发现自种死项、生成 UTF-16LE 备份、清理后复查 |
| `tools\probe-autostart-task.ps1` | 开机自启开关写入/删除 Run 项 |
| `tools\probe-settings-features.ps1` | 背景图、开机自启、设置保存 |
| `tools\probe-pages.ps1` | 八个页面截图 + 注册到系统写出快捷方式 |
| `tools\probe-storage.ps1` | 存储页目录统计与大文件列表 |
| `tools\probe-new-features.ps1` | 历史统计、大文件、整体色、单实例 |

截图会保存到 `assets\`，用于人工核对不穿模。

注意：PowerShell 5.1 读取无 BOM 的 UTF-8 脚本会按 GBK 解码，脚本里不要直接写中文路径字面量，统一用 `$PSScriptRoot` 相对路径。
