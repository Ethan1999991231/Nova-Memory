# NovaMemory

轻量 Windows 内存优化工具：青色亚克力风格、实时内存监测、自动优化、进程管理、注册表启动项清理和启动项启用/禁用。

## 运行

直接双击 `outputs\NovaMemory.exe` 即可运行，不需要 Python 或其他运行时。

## 原生构建

使用 Visual Studio Build Tools 的 C++ 工具链执行：

```powershell
.\native\build.ps1
```

输出文件：`dist\NovaMemory.exe`。

设置保存在 `%APPDATA%\NovaMemory\settings.json`，因此阈值、自动优化开关和维护范围会在重启后保留。
