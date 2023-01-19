@echo off
rem Copyright 2021-2023 Michael Beckh
rem
rem Licensed under the Apache License, Version 2.0 (the "License");
rem you may not use this file except in compliance with the License.
rem You may obtain a copy of the License at
rem
rem http://www.apache.org/licenses/LICENSE-2.0
rem
rem Unless required by applicable law or agreed to in writing, software
rem distributed under the License is distributed on an "AS IS" BASIS,
rem WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
rem See the License for the specific language governing permissions and
rem limitations under the License.

rem %%1 Command to run (compile, clang-tidy, clang-tidy-custom, iwyu, pch): %1
rem %%2 File ($(ItemPath)) %2
rem %%3 Path to vcvars64.bat (e.g. C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat): %3
rem %%4 Path to CMake executable (optional, e.g. C:\Program Files\CMake\bin\cmake.exe) %4
setlocal
set cmake=%4
if [%cmake%]==[] set cmake=cmake.exe
if [%1]==[clang-tidy-custom] %cmake% -D TOOL=%1-set-config -D FILE=%2 -P "%~dp0\run-clang-tools.cmake"
call %3
%cmake% -D TOOL=%1 -D FILE=%2 -P "%~dp0\run-clang-tools.cmake"
