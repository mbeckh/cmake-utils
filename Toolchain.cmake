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
# Tool chain for use by project and vcpkg.
#

#
# Function to keep namespaces cleaner.
#
function(z_cmake_utils_toolchain)
    get_property(try_compile GLOBAL PROPERTY IN_TRY_COMPILE)
    if(try_compile)
        return()
    endif()

    if(VCPKG_CHAINLOAD_TOOLCHAIN_FILE)
        set(file "settings/vcpkg")
    else()
        set(file "cmake-utils")
    endif()

    if(CMAKE_PROJECT_INCLUDE)
        if(NOT CMAKE_PROJECT_INCLUDE STREQUAL "${CMAKE_CURRENT_LIST_DIR}/modules/${file}.cmake")
            message(FATAL_ERROR "Using cmake-utils together with CMAKE_PROJECT_INCLUDE is not yet supported")
        endif()
    else()
        # Inject common build settings
        set(CMAKE_PROJECT_INCLUDE "${CMAKE_CURRENT_LIST_DIR}/modules/${file}.cmake" CACHE FILEPATH "")
    endif()
endfunction()

z_cmake_utils_toolchain()
