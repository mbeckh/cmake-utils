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
# Calculate obsolete and missing includes for precompiled headers.
# Usage: cmake
#        -D TARGET=<name>
#        -D FILES=<file>;...
#        -D PCH_FILES=<file>;...
#        -D OUTPUT=<file>
#        -P check-pch.cmake
#
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

if(NOT FILES)
    message(FATAL_ERROR "No input files")
endif()

foreach(file IN LISTS FILES)
    file(STRINGS "${file}" entries)
    if(entries)
        if(file MATCHES "/.clang-tools/${TARGET}/cmake_pch.si$")
            list(APPEND pch "${entries}")
        else()
            list(APPEND includes "${entries}")
        endif()
    endif()
endforeach()

list(REMOVE_ITEM includes "")
list(SORT includes CASE INSENSITIVE)
list(REMOVE_DUPLICATES includes)

list(REMOVE_ITEM pch "")
list(SORT pch CASE INSENSITIVE)

set(missing "${includes}")
list(REMOVE_ITEM missing ${pch})

set(obsolete "${pch}")
list(REMOVE_ITEM obsolete ${includes})

list(REMOVE_ITEM pch ${obsolete})
if(missing)
    list(APPEND pch "${missing}")
endif()
list(SORT pch CASE INSENSITIVE)

list(JOIN PCH_FILES ", " pch_files)
string(REPLACE ";" "\\;" pch_files "${pch_files}")

unset(result)
if(NOT missing AND NOT obsolete)
    list(APPEND result "(${pch_files} has correct #includes for PCH)")
else()
    if(missing)
        list(APPEND result "${pch_files} should add these lines for PCH:")
        foreach(file IN LISTS missing)
            string(REPLACE ";" "\\;" file "${file}")
            list(APPEND result "  #include <${file}>")
        endforeach()
        list(APPEND result "")
    endif()
    if(obsolete)
        list(APPEND result "${pch_files} should remove these lines for PCH:")
        foreach(file IN LISTS obsolete)
            string(REPLACE ";" "\\;" file "${file}")
            list(APPEND result "  #include <${file}>")
        endforeach()
        list(APPEND result "")
    endif()
    list(APPEND result "The full include-list for ${pch_files}:")
    foreach(file IN LISTS pch)
        string(REPLACE ";" "\\;" file "${file}")
        list(APPEND result "  #include <${file}>")
    endforeach()
endif()
list(APPEND result "---")
list(APPEND result "")

list(JOIN result "\n" result)

file(WRITE "${OUTPUT}" "${result}")
