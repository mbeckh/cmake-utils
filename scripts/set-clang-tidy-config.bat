@echo off
rem Copyright 2023 Michael Beckh
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

rem Helper script for run-clang-tools.bat
rem %1 File with .clang-tidy overrides
setlocal
set "current="
if not exist "%1" goto :skip
for /f "delims= usebackq" %%f in ("%1") do set "current=%%f"
:skip

if "%current%" == "" echo Current checks: Default
if not "%current%" == "" echo Current checks: & echo %current%

echo %1
echo:
echo Append clang-tidy checks to config from .clang-tidy [^<keep^>/"default"/checks glob]:
set /p "checks="

if /i "%checks%" == "" goto :eof
if /i "%checks%" == "default" del "%1" & goto :eof
if not "%current%" == "%checks%" <nul set /p "out=%checks%" > "%1"
