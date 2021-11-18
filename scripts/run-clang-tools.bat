@echo off
rem %%1 Command to run (compile, clang-tidy, iwyu, pch): %1
rem %%2 File ($(ItemPath)) %2
rem %%3 Path to vcvars64.bat (e.g. C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat): %3
rem %%4 Path to CMake executable (optional, e.g. C:\Program Files\cmake-3.21.1-windows-x86_64\bin\cmake.exe) %4
call %3
set cmake=%4
if [%cmake%]==[] set cmake=cmake.exe
%cmake% -D TOOL=%1 -D FILE=%2 -P "%~dp0\run-clang-tools.cmake"
