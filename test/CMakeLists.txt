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
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

string(COMPARE EQUAL "${CMAKE_SOURCE_DIR}" "${CMAKE_CURRENT_SOURCE_DIR}" IS_MAIN_PROJECT)
option(BUILD_TESTING "Build tests" ${IS_MAIN_PROJECT})

project("cmake-utils-test" VERSION 0.0.1
    DESCRIPTION "Test project for cmake-utils"
    HOMEPAGE_URL "https://github.com/mbeckh/cmake-utils"
    LANGUAGES CXX)

set(CMAKE_DEBUG_POSTFIX d CACHE STRING "")
set(CMAKE_CXX_STANDARD 20 CACHE STRING "")
set(CMAKE_CXX_STANDARD_REQUIRED ON CACHE BOOL "")
set(CMAKE_CXX_EXTENSIONS OFF CACHE BOOL "")

add_compile_definitions(WIN32_LEAN_AND_MEAN=1)

add_executable(ok
    "src/ok_1.cpp"
    "src/ok_2.cpp"
    "include/cmake-utils/ok.h"
    "include/cmake-utils/ok_2.h"
)
target_precompile_headers(ok PRIVATE "src/ok_pch.h")
target_include_directories(ok PUBLIC "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>" "$<INSTALL_INTERFACE:include>")


add_library(tidy_error
    "src/tidy_error_1.cpp"
    "src/tidy_error_2.cpp"
    "src/tidy_error_2.h"
    "src/tidy_error.h"
)
target_precompile_headers(tidy_error PRIVATE "src/tidy_error_pch.h")
target_include_directories(tidy_error PUBLIC "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>" "$<INSTALL_INTERFACE:include>")


add_library(include_error
    "src/include_error.cpp"
)
target_precompile_headers(include_error PRIVATE "src/include_error_pch.h")
target_include_directories(include_error PUBLIC "$<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include>" "$<INSTALL_INTERFACE:include>")

add_subdirectory(subdirectory)
add_subdirectory(subproject)

#
# Tests
#

if(NOT BUILD_TESTING)
    return()
endif()

enable_testing()

string(REPLACE ";" "\\;" include "$ENV{INCLUDE}")

#
# Clean
#
add_test(NAME cmake-utils.common.clean
         COMMAND "${CMAKE_COMMAND}" --build . --target clean)
set_tests_properties(cmake-utils.common.clean PROPERTIES
                     ENVIRONMENT "INCLUDE=${include}"
                     FIXTURES_SETUP clean)

#
# Build
#
foreach(target clang-tidy iwyu pch)
    add_test(NAME cmake-utils.common.build-${target}
             COMMAND "${CMAKE_COMMAND}" --build . --target ${target})

    set_tests_properties(cmake-utils.common.build-${target} PROPERTIES
                         DISABLED "$<AND:$<OR:$<STREQUAL:${target},iwyu>,$<STREQUAL:${target},pch>>,$<NOT:$<TARGET_EXISTS:${target}>>>"
                         ENVIRONMENT "INCLUDE=${include}"
                         DEPENDS cmake-utils.common.clean
                         FIXTURES_SETUP build-${target}
                         FIXTURES_REQUIRED clean
                         RESOURCE_LOCK build)
endforeach()


unset(no_link_tests)
foreach(target ok tidy_error include_error subdirectory subproject)
    add_test(NAME cmake-utils.common.no-link-${target}
             COMMAND "${CMAKE_COMMAND}" -E md5sum "$<TARGET_FILE:${target}>")
    set_tests_properties(cmake-utils.common.no-link-${target} PROPERTIES
                         FIXTURES_REQUIRED build-${target}
                         DEPENDS cmake-utils.common.build-${target}
                         WILL_FAIL YES)
    list(APPEND no_link_tests cmake-utils.common.no-link-${target})
endforeach()

add_test(NAME cmake-utils.common.build-binaries
         COMMAND "${CMAKE_COMMAND}" --build . --target all)
set_tests_properties(cmake-utils.common.build-binaries PROPERTIES
                     ENVIRONMENT "INCLUDE=${include}"
                     DEPENDS "cmake-utils.common.build;${no_link_tests}"
                     FIXTURES_SETUP build-binaries)

foreach(target ok tidy_error include_error subdirectory subproject)
    add_test(NAME cmake-utils.common.link-${target}
             COMMAND "${CMAKE_COMMAND}" -E md5sum "$<TARGET_FILE:${target}>")
    set_tests_properties(cmake-utils.common.link-${target} PROPERTIES
                         FIXTURES_REQUIRED build-binaries
                         DEPENDS cmake-utils.common.build-binaries)
endforeach()

#
# clang-tidy
#
add_test(NAME cmake-utils.clang-tidy.logs
         COMMAND "${CMAKE_COMMAND}" -E cat
                 "${CMAKE_BINARY_DIR}/clang-tidy-ok.log"
                 "${CMAKE_BINARY_DIR}/clang-tidy-tidy_error.log"
                 "${CMAKE_BINARY_DIR}/clang-tidy-include_error.log"
                 "${CMAKE_BINARY_DIR}/clang-tidy-subdirectory.log"
                 "${CMAKE_BINARY_DIR}/clang-tidy-subproject.log")

set_tests_properties(cmake-utils.clang-tidy.logs PROPERTIES
                     FIXTURES_REQUIRED build-clang-tidy
                     DEPENDS cmake-utils.common.build-clang-tidy)


add_test(NAME cmake-utils.clang-tidy.ok
         COMMAND "${CMAKE_COMMAND}" --build . --target clang-tidy-ok)

set_tests_properties(cmake-utils.clang-tidy.ok PROPERTIES
                     ENVIRONMENT "INCLUDE=${include}"
                     FIXTURES_REQUIRED build-clang-tidy
                     DEPENDS cmake-utils.common.build-clang-tidy
                     PASS_REGULAR_EXPRESSION [[
^\[1/1\] clang-tidy \(ok\)
clang-tidy: ok
$]])


add_test(NAME cmake-utils.clang-tidy.tidy_error
         COMMAND "${CMAKE_COMMAND}" --build . --target clang-tidy-tidy_error)

string(CONFIGURE [[
^\[1/1\] clang-tidy \(tidy_error\)
clang-tidy: tidy_error
src/tidy_error\.h:.+\[modernize-avoid-c-arrays\]
.+"@CMAKE_BUILD_TYPE@".+// deliberate error.+
 +\^
src/tidy_error_2\.h:.+\[modernize-avoid-c-arrays\]
.+"@CMAKE_BUILD_TYPE@".+// deliberate error.+
 +\^
src/tidy_error_1\.cpp:.+\[modernize-avoid-c-arrays\]
.+"@CMAKE_BUILD_TYPE@".+// deliberate error.+
 +\^
src/tidy_error_2\.cpp:.+\[modernize-avoid-c-arrays\]
.+"@CMAKE_BUILD_TYPE@".+// deliberate error.+
 +\^
$]] pass @ONLY)

set_tests_properties(cmake-utils.clang-tidy.tidy_error PROPERTIES
                     ENVIRONMENT "INCLUDE=${include}"
                     FIXTURES_REQUIRED build-clang-tidy
                     DEPENDS cmake-utils.common.build-clang-tidy
                     PASS_REGULAR_EXPRESSION "${pass}")


add_test(NAME cmake-utils.clang-tidy.include_error
         COMMAND "${CMAKE_COMMAND}" --build . --target clang-tidy-include_error)

set_tests_properties(cmake-utils.clang-tidy.include_error PROPERTIES
                     ENVIRONMENT "INCLUDE=${include}"
                     FIXTURES_REQUIRED build-clang-tidy
                     DEPENDS cmake-utils.common.build-clang-tidy
                     PASS_REGULAR_EXPRESSION [[
^\[1/1\] clang-tidy \(include_error\)
clang-tidy: include_error
$]])


add_test(NAME cmake-utils.clang-tidy.subdirectory
         COMMAND "${CMAKE_COMMAND}" --build . --target clang-tidy-subdirectory)

set_tests_properties(cmake-utils.clang-tidy.subdirectory PROPERTIES
                     ENVIRONMENT "INCLUDE=${include}"
                     FIXTURES_REQUIRED build-clang-tidy
                     DEPENDS cmake-utils.common.build-clang-tidy
                     PASS_REGULAR_EXPRESSION [[
^\[1/1\] clang-tidy \(subdirectory\)
clang-tidy: subdirectory
$]])


add_test(NAME cmake-utils.clang-tidy.subproject
         COMMAND "${CMAKE_COMMAND}" --build . --target clang-tidy-subproject)

set_tests_properties(cmake-utils.clang-tidy.subproject PROPERTIES
                     ENVIRONMENT "INCLUDE=${include}"
                     FIXTURES_REQUIRED build-clang-tidy
                     DEPENDS cmake-utils.common.build-clang-tidy
                     PASS_REGULAR_EXPRESSION [[
^\[1/1\] clang-tidy \(subproject\)
clang-tidy: subproject
$]])


#
# include-what-you-use
#

add_test(NAME cmake-utils.iwyu.logs
            COMMAND "${CMAKE_COMMAND}" -E cat
                    "${CMAKE_BINARY_DIR}/iwyu-ok.log"
                    "${CMAKE_BINARY_DIR}/iwyu-tidy_error.log"
                    "${CMAKE_BINARY_DIR}/iwyu-include_error.log"
                    "${CMAKE_BINARY_DIR}/iwyu-subdirectory.log"
                    "${CMAKE_BINARY_DIR}/iwyu-subproject.log")

set_tests_properties(cmake-utils.iwyu.logs PROPERTIES
                     DISABLED "$<NOT:$<TARGET_EXISTS:iwyu>>"
                     FIXTURES_REQUIRED build-iwyu
                     DEPENDS cmake-utils.common.build-iwyu)


add_test(NAME cmake-utils.iwyu.ok
         COMMAND "${CMAKE_COMMAND}" --build . --target iwyu-ok)
set_tests_properties(cmake-utils.iwyu.ok PROPERTIES
                     DISABLED "$<NOT:$<TARGET_EXISTS:iwyu>>"
                     ENVIRONMENT "INCLUDE=${include}"
                     FIXTURES_REQUIRED build-iwyu
                     DEPENDS cmake-utils.common.build-iwyu
                     PASS_REGULAR_EXPRESSION [[
^\[1/1\] include-what-you-use \(ok\)
include-what-you-use: ok

include/cmake-utils/ok\.h should add these lines:

include/cmake-utils/ok\.h should remove these lines:

The full include-list for include/cmake-utils/ok\.h:
---

src/ok_1\.cpp should add these lines:

src/ok_1\.cpp should remove these lines:

The full include-list for src/ok_1\.cpp:
#include "cmake-utils/ok_2\.h"  // for ok_2
---


include/cmake-utils/ok_2\.h should add these lines:

include/cmake-utils/ok_2\.h should remove these lines:

The full include-list for include/cmake-utils/ok_2\.h:
#include "ok\.h"     // for ok
#include <cstdint>  // for uint32_t
---

src/ok_2\.cpp should add these lines:

src/ok_2\.cpp should remove these lines:

The full include-list for src/ok_2\.cpp:
#include "cmake-utils/ok_2\.h"
#include <cstddef>  // for size_t
---

$]])


add_test(NAME cmake-utils.iwyu.tidy_error
         COMMAND "${CMAKE_COMMAND}" --build . --target iwyu-tidy_error)
set_tests_properties(cmake-utils.iwyu.tidy_error PROPERTIES
                     DISABLED "$<NOT:$<TARGET_EXISTS:iwyu>>"
                     ENVIRONMENT "INCLUDE=${include}"
                     FIXTURES_REQUIRED build-iwyu
                     DEPENDS cmake-utils.common.build-iwyu
                     PASS_REGULAR_EXPRESSION [[
^\[1/1\] include-what-you-use \(tidy_error\)
include-what-you-use: tidy_error

src/tidy_error\.h should add these lines:

src/tidy_error\.h should remove these lines:

The full include-list for src/tidy_error\.h:
---

src/tidy_error_1\.cpp should add these lines:

src/tidy_error_1\.cpp should remove these lines:

The full include-list for src/tidy_error_1\.cpp:
#include "tidy_error\.h"    // for tidy_error
#include "tidy_error_2\.h"  // for tidy_error_2
---


src/tidy_error_2\.h should add these lines:

src/tidy_error_2\.h should remove these lines:

The full include-list for src/tidy_error_2\.h:
---

src/tidy_error_2\.cpp should add these lines:

src/tidy_error_2\.cpp should remove these lines:

The full include-list for src/tidy_error_2\.cpp:
#include "tidy_error_2\.h"
#include "tidy_error\.h"  // for tidy_error
---

$]])
#]=]


add_test(NAME cmake-utils.iwyu.include_error
         COMMAND "${CMAKE_COMMAND}" --build . --target iwyu-include_error)
set_tests_properties(cmake-utils.iwyu.include_error PROPERTIES
                     DISABLED "$<NOT:$<TARGET_EXISTS:iwyu>>"
                     ENVIRONMENT "INCLUDE=${include}"
                     FIXTURES_REQUIRED build-iwyu
                     DEPENDS cmake-utils.common.build-iwyu
                     PASS_REGULAR_EXPRESSION [[
^\[1/1\] include-what-you-use \(include_error\)
include-what-you-use: include_error

src/include_error\.cpp should add these lines:

src/include_error\.cpp should remove these lines:
- #include <cstring>.+

The full include-list for src/include_error\.cpp:
#include <cstddef>.+
#include <cstdint>.+
---

$]])

add_test(NAME cmake-utils.iwyu.subdirectory
         COMMAND "${CMAKE_COMMAND}" --build . --target iwyu-subdirectory)
set_tests_properties(cmake-utils.iwyu.subdirectory PROPERTIES
                     DISABLED "$<NOT:$<TARGET_EXISTS:iwyu>>"
                     ENVIRONMENT "INCLUDE=${include}"
                     FIXTURES_REQUIRED build-iwyu
                     DEPENDS cmake-utils.common.build-iwyu
                     PASS_REGULAR_EXPRESSION [[
^\[1/1\] include-what-you-use \(subdirectory\)
include-what-you-use: subdirectory
$]])

add_test(NAME cmake-utils.iwyu.subproject
         COMMAND "${CMAKE_COMMAND}" --build . --target iwyu-subproject)
set_tests_properties(cmake-utils.iwyu.subproject PROPERTIES
                     DISABLED "$<NOT:$<TARGET_EXISTS:iwyu>>"
                     ENVIRONMENT "INCLUDE=${include}"
                     FIXTURES_REQUIRED build-iwyu
                     DEPENDS cmake-utils.common.build-iwyu
                     PASS_REGULAR_EXPRESSION [[
^\[1/1\] include-what-you-use \(subproject\)
include-what-you-use: subproject
$]])


#
# pch
#

add_test(NAME cmake-utils.pch.logs
         COMMAND "${CMAKE_COMMAND}" -E cat
                 "${CMAKE_BINARY_DIR}/pch-ok.log"
                 "${CMAKE_BINARY_DIR}/pch-tidy_error.log"
                 "${CMAKE_BINARY_DIR}/pch-include_error.log")

set_tests_properties(cmake-utils.pch.logs PROPERTIES
                     DISABLED "$<NOT:$<TARGET_EXISTS:pch>>"
                     FIXTURES_REQUIRED build-pch
                     DEPENDS cmake-utils.common.build-pch)


foreach(target subdirectory subproject)
    add_test(NAME cmake-utils.pch.no-log-${target}
             COMMAND "${CMAKE_COMMAND}" -E cat "${CMAKE_BINARY_DIR}/pch-${target}.log")

    set_tests_properties(cmake-utils.pch.no-log-${target} PROPERTIES
                         DISABLED "$<NOT:$<TARGET_EXISTS:pch>>"
                         FIXTURES_REQUIRED build-pch
                         DEPENDS cmake-utils.common.build-pch
                         WILL_FAIL YES)
endforeach()


add_test(NAME cmake-utils.pch.ok
         COMMAND "${CMAKE_COMMAND}" --build . --target pch-ok)
set_tests_properties(cmake-utils.pch.ok PROPERTIES
                     DISABLED "$<NOT:$<TARGET_EXISTS:pch>>"
                     ENVIRONMENT "INCLUDE=${include}"
                     FIXTURES_REQUIRED build-pch
                     DEPENDS cmake-utils.common.build-pch
                     PASS_REGULAR_EXPRESSION [[
^\[1/1\] pch \(ok\)
pch: ok
\(src/ok_pch\.h has correct #includes for PCH\)
---
$]])


add_test(NAME cmake-utils.pch.tidy_error
         COMMAND "${CMAKE_COMMAND}" --build . --target pch-tidy_error)
set_tests_properties(cmake-utils.pch.tidy_error PROPERTIES
                     DISABLED "$<NOT:$<TARGET_EXISTS:pch>>"
                     ENVIRONMENT "INCLUDE=${include}"
                     FIXTURES_REQUIRED build-pch
                     DEPENDS cmake-utils.common.build-pch
                     PASS_REGULAR_EXPRESSION [[
^\[1/1\] pch \(tidy_error\)
pch: tidy_error
\(src/tidy_error_pch\.h has correct #includes for PCH\)
---
$]])


add_test(NAME cmake-utils.pch.include_error
         COMMAND "${CMAKE_COMMAND}" --build . --target pch-include_error)
set_tests_properties(cmake-utils.pch.include_error PROPERTIES
                     DISABLED "$<NOT:$<TARGET_EXISTS:pch>>"
                     ENVIRONMENT "INCLUDE=${include}"
                     FIXTURES_REQUIRED build-pch
                     DEPENDS cmake-utils.common.build-pch
                     PASS_REGULAR_EXPRESSION [[
^\[1/1\] pch \(include_error\)
pch: include_error
src/include_error_pch\.h should add these lines for PCH:
  #include <cstdint>
  #include <cstring>

src/include_error_pch\.h should remove these lines for PCH:
  #include <vector>

The full include-list for src/include_error_pch\.h:
  #include <cstddef>
  #include <cstdint>
  #include <cstring>
---
$]])
