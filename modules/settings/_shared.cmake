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
# Common build settings for Visual Studio 2019 used in both vcpkg and regular builds.
#

# include_guard is already present in including file

include(ProcessorCount)

#
# Function to keep global scope cleaner.
#
function(z_cmake_utils_settings_shared)
    # Safe guard against unintended use
    get_property(try_compile GLOBAL PROPERTY IN_TRY_COMPILE)
    if(try_compile)
        mesage(FATAL_ERROR "try_compile SHALL NOT use custom settings")
    endif()

    # Default postfix
    set(CMAKE_DEBUG_POSTFIX "d" CACHE STRING "")

    # Favor e.g. vcpkg's gtest over FindGTest
    set(CMAKE_FIND_PACKAGE_PREFER_CONFIG ON CACHE BOOL "Prefer config mode for vcpkg")

    set(CMAKE_OPTIMIZE_DEPENDENCIES ON CACHE BOOL "")

    # Unicode for Windows 10
    add_compile_definitions(UNICODE=1 _UNICODE=1
                            WIN32=1 _WINDOWS=1
                            "$<$<CONFIG:Debug>:_DEBUG=1>" "$<$<CONFIG:Release>:NDEBUG=1>"
                            WINVER=0x0A00 _WIN32_WINNT=0x0A00)

    ProcessorCount(cpu_count)
    if(NOT cpu_count)
        mesage(STATUS "Cannot determine CPU count")
    else()
        get_cmake_property(job_pools JOB_POOLS)
        if(NOT job_pools MATCHES [[(^|;)use_all_cpus=[0-9]+]])
            set_property(GLOBAL APPEND PROPERTY JOB_POOLS "use_all_cpus=${cpu_count}")
        endif()
    endif()

    # Remaining settings are MSVC only (i.e. not relevant for analysis with clang-tidy)
    if(NOT MSVC)
        return()
    endif()

    # Run-time library
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>" CACHE STRING "")
    # and for compatibility mode with old versions of CMake (e.g. in port files)
    cmake_policy(GET CMP0091 msvc_runtime_library)
    if(NOT msvc_runtime_library STREQUAL NEW)
        add_compile_options("$<$<COMPILE_LANGUAGE:C,CXX>:/MT$<$<CONFIG:Debug>:d>>")
    endif()

    #
    # Remove conflicting default compiler and linker flags
    #
    foreach(suffix "" "_DEBUG" "_RELEASE")
        foreach(language C CXX)
            if(CMAKE_${language}_FLAGS${suffix})
                string(REGEX REPLACE "(^| )[/-]((D(WIN32|_WINDOWS|_?UNICODE|[_N]DEBUG|WINVER|_WIN32_WINNT)(=[^ ]*)?)|GR-?|M[DT]d?|EH([sc]|sc)|Z[7iI]|O[12dgistxy]|Ob[0-9]|RTC1|bigobj|w|W[0-4])($| )" " " flags "${CMAKE_${language}_FLAGS${suffix}}")
                string(STRIP "${flags}" flags)
                string(REGEX REPLACE "  +" " " flags "${flags}")
                set(CMAKE_${language}_FLAGS${suffix} "${flags}" CACHE STRING "" FORCE)
            endif()
        endforeach()

        foreach(output EXE SHARED MODULE STATIC)
            if(CMAKE_${output}_LINKER_FLAGS${suffix})
                string(REGEX REPLACE "(^| )[/-](([Ll][Tt][Cc][Gg]|[Oo][Pp][Tt]|[Dd][Ee][Bb][Uu][Gg]|[Ii][Nn][Cc][Rr][Ee][Mm][Ee][Nn][Tt][Aa][Ll])(:[^ ]*)?)($| )" " " flags "${CMAKE_${output}_LINKER_FLAGS${suffix}}")
                string(STRIP "${flags}" flags)
                string(REGEX REPLACE "  +" " " flags "${flags}")
                set(CMAKE_${output}_LINKER_FLAGS${suffix} "${flags}" CACHE STRING "" FORCE)
            endif()
        endforeach()
    endforeach()

    #
    # Compiler options
    #

    # Language 
    add_compile_options("$<$<COMPILE_LANGUAGE:CXX>:/EHsc;/GR-;/permissive-;$<$<CONFIG:Release>:/Zc:inline>>")

    # Optimizations
    add_compile_options("$<$<COMPILE_LANGUAGE:C,CXX>:$<$<CONFIG:Debug>:/Od>;$<$<CONFIG:Release>:/O2;/Ob3;/GL;/Gw>>")

    # Checks
    add_compile_options("$<$<COMPILE_LANGUAGE:C,CXX>:$<$<CONFIG:Debug>:/RTC1>;/sdl>")

    # Warnings
    add_compile_options("$<$<COMPILE_LANGUAGE:C,CXX>:/W4;/wd4373;$<$<CONFIG:Release>:/WX>>")

    # Compiler behavior
    add_compile_options("$<$<COMPILE_LANGUAGE:C,CXX>:/nologo;/MP;/diagnostics:caret;/bigobj>")

    #
    # Linker options
    #

    # Optimization
    add_link_options("$<$<CONFIG:Release>:/LTCG;/OPT:ICF;/OPT:REF>")
    if(NOT CMAKE_STATIC_LINKER_FLAGS_RELEASE MATCHES "(^| )[/-]LTCG( |$)")
        string(APPEND CMAKE_STATIC_LINKER_FLAGS_RELEASE " /LTCG")
        string(STRIP "${CMAKE_STATIC_LINKER_FLAGS_RELEASE}" CMAKE_STATIC_LINKER_FLAGS_RELEASE)
        set(CMAKE_STATIC_LINKER_FLAGS_RELEASE "${CMAKE_STATIC_LINKER_FLAGS_RELEASE}" CACHE STRING "" FORCE)
    if(cpu_count)
        add_link_options("$<$<OR:$<BOOL:$<TARGET_PROPERTY:INTERPROCEDURAL_OPTIMIZATION>>,$<BOOL:$<TARGET_PROPERTY:INTERPROCEDURAL_OPTIMIZATION_$<UPPER_CASE:$<CONFIG>>>>>:/CGTHREADS:${cpu_count}>")
        if(CMAKE_INTERPROCEDURAL_OPTIMIZATION OR CMAKE_INTERPROCEDURAL_OPTIMIZATION_${CMAKE_BUILD_TYPE})
            set(CMAKE_JOB_POOL_LINK "use_all_cpus" CACHE STRING "")
        endif()
    endif()

    # Debug information
    add_link_options(/PDBALTPATH:%_PDB%)

    # Linker behavior
    add_link_options(/NOLOGO "/INCREMENTAL$<$<CONFIG:Release>::NO>")
    if(NOT CMAKE_STATIC_LINKER_FLAGS MATCHES "(^| )[/-]NOLOGO( |$)")
        string(APPEND CMAKE_STATIC_LINKER_FLAGS " /NOLOGO")
        string(STRIP "${CMAKE_STATIC_LINKER_FLAGS}" CMAKE_STATIC_LINKER_FLAGS)
        set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS}" CACHE STRING "" FORCE)
    endif()

    # Warnings
    add_link_options("$<$<CONFIG:Release>:/WX>")
    if(NOT CMAKE_STATIC_LINKER_FLAGS_RELEASE MATCHES "(^| )[/-]WX( |$)")
        string(APPEND CMAKE_STATIC_LINKER_FLAGS_RELEASE " /WX")
        string(STRIP "${CMAKE_STATIC_LINKER_FLAGS_RELEASE}" CMAKE_STATIC_LINKER_FLAGS_RELEASE)
        set(CMAKE_STATIC_LINKER_FLAGS_RELEASE "${CMAKE_STATIC_LINKER_FLAGS_RELEASE}" CACHE STRING "" FORCE)
    endif()

	#
	# Resource compiler options
	#

    if(NOT CMAKE_RC_FLAGS MATCHES "(^| )[/-][Nn][Oo][Ll][Oo][Gg][Oo]( |$)")
        string(APPEND CMAKE_RC_FLAGS " /nologo")
        string(STRIP "${CMAKE_RC_FLAGS}" CMAKE_RC_FLAGS)
        set(CMAKE_RC_FLAGS "${CMAKE_RC_FLAGS}" CACHE STRING "" FORCE)
    endif()
endfunction()

z_cmake_utils_settings_shared()
