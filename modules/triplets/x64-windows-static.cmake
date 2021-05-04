#
# Common triplet for Visual Studio 2019.
#
# MIT License, Copyright (c) 2021 Michael Beckh, see LICENSE
#

set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE static)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CHAINLOAD_TOOLCHAIN_FILE "${CMAKE_CURRENT_LIST_DIR}/../../toolchain.cmake")
set(VCPKG_LOAD_VCVARS_ENV ON)
