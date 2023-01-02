# Copyright 2021-2022 Michael Beckh
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

if(CMAKE_VERSION VERSION_LESS "3.25")
    message(FATAL_ERROR "cmake-utils requires at least CMake 3.25 (found: ${CMAKE_VERSION})")
endif()

#
# Tool chain for use by project and vcpkg.
#

block()
    get_property(try_compile GLOBAL PROPERTY IN_TRY_COMPILE)
    if(NOT try_compile)
        if(VCPKG_CHAINLOAD_TOOLCHAIN_FILE)
            set(file "settings/vcpkg")

            # Disable building tests
            set(BUILD_TESTING OFF)
        else()
            set(file "cmake-utils")

            # Enable tests for top-level projects if not run by vcpkg
            option(BUILD_TESTING "Build tests" ${PROJECT_IS_TOP_LEVEL})
        endif()

        if(CMAKE_PROJECT_INCLUDE)
            if(NOT CMAKE_PROJECT_INCLUDE STREQUAL "${CMAKE_CURRENT_LIST_DIR}/modules/${file}.cmake")
                message(FATAL_ERROR "Using cmake-utils together with CMAKE_PROJECT_INCLUDE is not yet supported")
            endif()
        else()
            # Inject common build settings
            set(CMAKE_PROJECT_INCLUDE "${CMAKE_CURRENT_LIST_DIR}/modules/${file}.cmake" CACHE FILEPATH "")
        endif()
    endif()
endblock()
