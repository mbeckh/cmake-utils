# Copyright 2021 Michael Beckh
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

#
# Run include-what-you-use for input adding --check_also for auxiliary includes.
# Usage: cmake
#        -D MSVC_VERSION=<version>
#        -D Python_EXECUTABLE=<file>
#        -D include-what-you-use_PY=<file>
#        [ -D include-what-you-use_MAPPING_FILES=<file>;... ]
#        -D TARGET=<name>
#        -D FILES=<file>;...
#        -D AUX_INCLUDES_FILES=<file>;...
#        -D OUTPUT=<file>
#        -P run-include-what-you-use.cmake
#
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

if(NOT FILES)
    message(FATAL_ERROR "No input files")
endif()
if(NOT OUTPUT)
    message(FATAL_ERROR "No output file")
endif()

foreach(file aux_includes_file IN ZIP_LISTS FILES AUX_INCLUDES_FILES)
    if(NOT EXISTS "${aux_includes_file}")
        message(FATAL_ERROR "Include analysis missing: ${aux_includes_file}")
    endif()
    file(STRINGS "${aux_includes_file}" entries)
    if(entries)
        list(APPEND aux_includes "${entries}")
    endif()
    if(file MATCHES [[(^|[/\\])([^/\\]+)\.test\.[^/\\]+]])
        list(APPEND aux_includes "*/${CMAKE_MATCH_2}.h*")
    endif()
endforeach()
list(SORT aux_includes CASE INSENSITIVE)
list(REMOVE_DUPLICATES aux_includes)

unset(options)

list(TRANSFORM include-what-you-use_MAPPING_FILES PREPEND "--mapping_file=")

list(TRANSFORM aux_includes PREPEND "--check_also=")

if(include-what-you-use_MAPPING_FILES)
    list(APPEND options "${include-what-you-use_MAPPING_FILES}")
endif()
list(APPEND options "--mapping_file=${CMAKE_CURRENT_LIST_DIR}/msvc.imp"
                    --verbose=2 --update_comments --quoted_includes_first --cxx17ns --max_line_length=256)
if(aux_includes)
    list(APPEND options "${aux_includes}")
endif()

list(LENGTH options stop)
math(EXPR stop "${stop} - 1")
foreach(index RANGE 0 ${stop})
    math(EXPR pos "${index} * 2")
    list(INSERT options ${pos} -Xiwyu)
endforeach()

execute_process(COMMAND "${Python_EXECUTABLE}" "${include-what-you-use_PY}" -p ".clang-tools/${TARGET}" ${FILES} --
                        ${options}
                        --driver-mode=cl "-fmsc-version=${MSVC_VERSION}"
                        -Wno-unknown-attributes -Qunused-arguments
                        -D__clang_analyzer__ -D__iwyu__ -D_CRT_USE_BUILTIN_OFFSETOF
                RESULT_VARIABLE result
                ERROR_VARIABLE error
                OUTPUT_FILE "${OUTPUT}"
                COMMAND_ECHO NONE)
# IWYU returns 1 as result when no errors happened
if(NOT result EQUAL 0 AND NOT result EQUAL 1)
    message(FATAL_ERROR "Error ${result}:\n${error}")
endif()
