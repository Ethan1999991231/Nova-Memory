@echo off
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\Tools\VsDevCmd.bat" -arch=x64
if errorlevel 1 exit /b 1
cd /d "%~dp0"
set SDK=C:\Program Files (x86)\Windows Kits\10
set SDKVER=10.0.19041.0
cl /nologo /utf-8 /std:c++17 /O2 /EHsc /DWIN32 /D_WINDOWS /I"%SDK%\include\%SDKVER%\shared" /I"%SDK%\include\%SDKVER%\um" /I"%SDK%\include\%SDKVER%\winrt" /Fe:..\outputs\NovaMemory.exe main.cpp /link /SUBSYSTEM:WINDOWS user32.lib gdi32.lib shell32.lib ole32.lib /LIBPATH:"%SDK%\Lib\%SDKVER%\um\x64" /LIBPATH:"%SDK%\Lib\%SDKVER%\ucrt\x64" gdiplus.lib comctl32.lib dwmapi.lib psapi.lib advapi32.lib
exit /b %errorlevel%
