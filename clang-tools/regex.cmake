#
# Regex helper functions.
#
# MIT License, Copyright (c) 2021 Michael Beckh, see LICENSE
#

#
# Escape variable's content for use as a regex pattern.
#
function(clang_tools_regex_escape_pattern var #[[ OUT <var> ]])
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
function(clang_tools_regex_escape_replacement var #[[ OUT <var> ]])
    cmake_parse_arguments(PARSE_ARGV 1 arg "" "OUT" "")
    if(NOT arg_OUT)
        set(arg_OUT "${var}")
    endif()
    string(REPLACE "\\" "\\\\" result "${${var}}")
    set("${arg_OUT}" "${result}" PARENT_SCOPE)
endfunction()
