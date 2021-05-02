#
# Remove MSVC-only flags from compile_commands.json which are not understood by clang's MSVC driver.
# Usage: cmake -P compile_commands.cmake
#
# MIT License, Copyright (c) 2021 Michael Beckh, see LICENSE
#
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

file(READ "compile_commands.json" compile_commands)
string(JSON count LENGTH "${compile_commands}")
math(EXPR count "${count} - 1")
set(changed NO)

foreach(i RANGE ${count})
    string(JSON command GET "${compile_commands}" ${i} "command")

    ###
    string(REGEX REPLACE "(^| )[-/]external:I " " /clang:-isystem" command "${command}")
    separate_arguments(command NATIVE_COMMAND "${command}")
    list(FILTER command EXCLUDE REGEX "^[-/](Y[cu]|FI|Fp|d1trimfile:).*$")
    list(FILTER command EXCLUDE REGEX "^[-/](experimental:external|external:W[0-4])$")
    list(TRANSFORM command REPLACE [[\\]] [[\\\\]])
    list(JOIN command " " command)
    string(JSON compile_commands SET "${compile_commands}" ${i} "command" "\"${command}\"")
endforeach()

file(WRITE ".clang-tools/compile_commands.json" "${compile_commands}")
