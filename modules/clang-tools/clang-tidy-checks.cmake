# Copyright 2023 Michael Beckh
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
# Get list of additional clang-tidy checks from environment.
# Usage: cmake
#        -D TARGET=<target>
#        -D FILE=<file>
#        -P clang-tidy-checks.cmake
#
cmake_minimum_required(VERSION 3.25 FATAL_ERROR)

foreach(arg TARGET FILE)
    if(NOT ${arg})
        message(FATAL ERROR "${arg} is missing or empty")
    endif()
endforeach()

set(group-bugprone
    "bugprone-*"
    "-bugprone-bad-signal-to-kill-thread" # POSIX
    "-bugprone-narrowing-conversions" # Alias of cppcoreguidelines-narrowing-conversions
    "-bugprone-no-escape" # clang attribute
    "-bugprone-posix-return" # POSIX
    "-bugprone-signal-handler" # POSIX and < C++17 only
)
set(group-cert
    "cert-dcl21-cpp" # Modification of postfix operator result
    "cert-dcl50-cpp" # variadic functions are valid
    "cert-dcl58-cpp" # Modification of std namespace
    "cert-err33-c" # Other functions as bugprone-unused-return-value
    "cert-err34-c" # Results of atoi, scanf and the like
    "cert-err52-cpp" # setjmp and longjmp are valid code
    "cert-err58-cpp" # Exceptions in static initializers
    "cert-err60-cpp" # Non-copy-constructible exceptions
    "cert-flp30-c" # Floating point in for loops
    "cert-mem57-cpp" # Alignment in new
    "cert-msc50-cpp" # std::rand
    "cert-msc51-cpp" # Predictable random seeds
    "cert-oop57-cpp" # memset, memcpy, memcmp on non trivial types
    "cert-oop58-cpp" # Modification of source in copy operation
)
set(group-clang-analyzer
    "clang-analyzer-*")

set(group-concurrency
    "concurrency-mt-unsafe"
)
set(group-cppcoreguidelines
    "cppcoreguidelines-avoid-const-or-ref-data-members"
    "cppcoreguidelines-avoid-goto"
    "cppcoreguidelines-avoid-non-const-global-variables"
    "cppcoreguidelines-avoid-reference-coroutine-parameters"
    "cppcoreguidelines-init-variables"
    "cppcoreguidelines-interfaces-global-init"
    "cppcoreguidelines-narrowing-conversions"
    "cppcoreguidelines-no-malloc"
    "cppcoreguidelines-prefer-member-initializer"
    "cppcoreguidelines-pro-type-const-cast"
    "cppcoreguidelines-pro-type-cstyle-cast"
    "cppcoreguidelines-pro-type-member-init"
    "cppcoreguidelines-pro-type-static-cast-downcast"
    "cppcoreguidelines-pro-type-vararg"
    "cppcoreguidelines-slicing"
    "cppcoreguidelines-special-member-functions"
    "cppcoreguidelines-virtual-class-destructor"
)
set(group-google
    "google-build-explicit-make-pair"
    "google-build-namespaces"
    "google-build-using-namespace"
    "google-default-arguments"
    "google-explicit-constructor"
    "google-global-names-in-headers"
    "google-upgrade-googletest-case"
)
set(group-hicpp
    "hicpp-exception-baseclass"
    "hicpp-multiway-paths-covered"
    "hicpp-signed-bitwise"
)
set(group-llvm
    "llvm-namespace-comment"
)
set(group-misc
    "misc-*"
    "-misc-misplaced-const" # Diagnosed code is perfectly valid
    "-misc-no-recursion" # Recursion is perfectly valid
    "-misc-throw-by-value-catch-by-reference" # Requirement is overly strict and pointless
)
set(group-modernize
    "modernize-*"
    "-modernize-avoid-c-arrays" # Deliberate use of arrays is clearly visible and valid
    "-modernize-return-braced-init-list" # Worsens readability
    "-modernize-use-auto" # Worsens readability
    "-modernize-use-default-member-init"
    "-modernize-use-trailing-return-type" # Worsens readability
    "-modernize-use-transparent-functors" # Worsens readability
)
set(group-performance
    "performance-*"
)
set(group-portability
    "portability-std-allocator-const"
)
set(group-readability
    "readability-*"
    "-readability-function-cognitive-complexity" # Forces too many small functions that add no value
    "-readability-function-size" # Fixed thresholds do not really add value
    "-readability-identifier-length" # Fixed thresholds do not really add value
    "-readability-redundant-access-specifiers" # Using redundant specifiers for grouping class declarations
)
set(group-all
    "${group-bugprone}"
    "${group-cert}"
    "${group-clang-analyzer}"
    "${group-concurrency}"
    "${group-cppcoreguidelines}"
    "${group-google}"
    "${group-hicpp}"
    "${group-llvm}"
    "${group-misc}"
    "${group-modernize}"
    "${group-performance}"
    "${group-portability}"
    "${group-readability}"
)

set(group-slow
    "bugprone-reserved-identifier"
    "google-upgrade-googletest-case"
    "misc-confusable-identifiers"
    "misc-const-correctness"
    "readability-identifier-naming"
)

set(checks "$ENV{CMU_CLANG_TIDY_CHECKS}")
if(checks)
    # convert to a list
    string(REPLACE "," ";" checks "${checks}")
    # remove leading and trailing spaces
    list(TRANSFORM checks STRIP)
    # Replace groups
    foreach(check IN LISTS checks)
        if(check MATCHES [[^(-?)(bugprone|cert|clang-analyzer|concurrency|cppcoreguidelines|google|hicpp|llvm|misc|modernize|performance|portability|readability|all)$]])
            set(remove "${CMAKE_MATCH_1}")
            set(name "${CMAKE_MATCH_2}")
            set(group ${group-${name}})
            if(remove)
                if(name STREQUAL "all")
                    list(APPEND result "-*")
                elseif(name STREQUAL "slow")
                    list(TRANSFORM group PREPEND "-")
                    list(APPEND result ${group})
                else()
                    list(APPEND result "-${name}-*")
                endif()
            else()
                list(APPEND result ${group})
            endif()
        else()
            list(APPEND result "${check}")
        endif()
    endforeach()
    list(JOIN result "," result)
    set(checks "--checks=\"${result}\"")
endif()

if(EXISTS ${FILE})
    file(READ ${FILE} current)
    if(current STREQUAL checks)
        if(checks)
            message("clang-tidy: Keep checks for ${TARGET}: ${checks}")
        else()
            message("clang-tidy: Keep default checks for ${TARGET}. Set CMU_CLANG_TIDY_CHECKS to customize.")
        endif()
        return()
    endif()
endif()

if(checks)
    message("clang-tidy: Updating checks for ${TARGET}: ${checks}")
else()
    message("clang-tidy: Using default checks for ${TARGET}. Set CMU_CLANG_TIDY_CHECKS to customize.")
endif()
file(WRITE "${FILE}" "${checks}")
