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
# Regex helper functions.
#

#
# Escape variable's content for use as a regex pattern.
#
function(regex_escape_pattern var #[[ OUT <var> ]])
    cmake_parse_arguments(PARSE_ARGV 1 arg "" "OUT" "")
    if(NOT arg_OUT)
        set(arg_OUT "${var}")
    endif()
    # ] inside [ ], even as [\]] does not work as of CMake 3.20.0
    string(REGEX REPLACE [[([\^\\$.\[+?|()-]|\])]] [[\\\1]] result "${${var}}")
    set("${arg_OUT}" "${result}" PARENT_SCOPE)
endfunction()

#
# Escape variable's content for use as a regex replacement.
#
function(regex_escape_replacement var #[[ OUT <var> ]])
    cmake_parse_arguments(PARSE_ARGV 1 arg "" "OUT" "")
    if(NOT arg_OUT)
        set(arg_OUT "${var}")
    endif()
    string(REPLACE "\\" "\\\\" result "${${var}}")
    set("${arg_OUT}" "${result}" PARENT_SCOPE)
endfunction()
