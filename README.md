# NovaMemory

轻量 Windows 内存优化工具：亚克力风格、实时内存监测、自动优化、三种外观主题、进程管理和启动项启用/禁用。

## 运行

直接双击 `outputs\NovaMemory-final.exe` 即可运行。它是原生 Windows EXE，不需要 Python 或额外的 Visual C++ 运行库。

常规设置中的“添加到开始菜单”会为当前 Windows 用户创建快捷方式，可从开始菜单搜索 `NovaMemory` 找到应用；它不会设置开机自启。

外观页可调整青雾玻璃、深海蓝、月白主题、窗口透明度和 RGB 强调色。保存后会在下次启动时恢复。设置存放在 `%APPDATA%\NovaMemory\settings.json`。

注册表安全清理会先显示应用内预览并创建备份；注册表编辑器按钮只打开 Windows 注册表编辑器。系统维护列表覆盖 Run、RunOnce 和启动文件夹；启动项复选框切换启用状态，进程复选框用于多选结束。

## 原生构建

使用 Visual Studio Build Tools 的 C++ 工具链执行：

```powershell
.\native\build.ps1
```

输出文件：`outputs\NovaMemory-final.exe`。
