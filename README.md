# cmake-utils
Modules for building projects using [CMake](https://cmake.org/).

[![Release](https://img.shields.io/github/v/tag/mbeckh/cmake-utils?label=Release&style=flat-square)](https://github.com/mbeckh/cmake-utils/releases/)
[![Tests](https://img.shields.io/github/workflow/status/mbeckh/cmake-utils/build/master?label=Tests&logo=GitHub&style=flat-square)](https://github.com/mbeckh/cmake-utils/actions)
[![License](https://img.shields.io/github/license/mbeckh/cmake-utils?label=License&style=flat-square)](https://github.com/mbeckh/cmake-utils/blob/master/LICENSE)

## Features
-   Bootstrapping of [vcpkg](https://github.com/microsoft/vcpkg).
-   Supports vcpkg registries and vcpkg binary caching
-   Common build settings for Visual Studio 2019 v16.9 / MSVC 19.28
-   Run checks using [clang-tidy](https://clang.llvm.org/extra/clang-tidy/) and [include-what-you-use](https://include-what-you-use.org/)
-   Check includes of precompiled header files in a way similar to include-what-you-use
-   [Script](clang-tools/run-clang-tools.cmake) for running clang-tidy, include-what-you-use and the precompiled header check from within Visual Studio

## Usage
-   Set environment CMake variable `BUILD_ROOT` to the path of an output folder. A subfolder will be created therein for every project.
-   Supply the file [`Toolchain.cmake`](Toolchain.cmake) to CMake using `-DCMAKE_TOOLCHAIN_FILE=<path>/cmake-utils/Toolchain.cmake`. Everything else will configure itself, e.g. if vcpkg.json is found.
-   Optional user overrides are read from `cmake-utils/UserSettings.cmake` and `${CMAKE_SOURCE_DIR}/cmake/UserSettings.cmake`.

## System Requirements / Tested with
-   Visual Studio 2019 v16.9 or newer
-   CMake v3.20 or newer
-   clang-tidy executable v12 or newer. Set environment variable `clang-tidy_ROOT` to folder path if not found automatically.
-   include-what-you-use executable v0.15 or newer. Set environment variable `include-what-you-use_ROOT` to folder path if not found automatically.
    `iwyu_tool.py` is expected in the same path as well as the configuration file `stl.c.headers.imp`.
-   Running include-what-you-use requires Python. Set CMake variable `Python_EXECUTABLE` to file path if interpreter is not found automatically.
-   
## License
The code is released under the MIT License. Please see [LICENSE](LICENSE) and [NOTICE](NOTICE) for details.
