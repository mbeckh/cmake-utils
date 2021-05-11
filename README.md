# cmake-utils
Modules for building projects using [CMake](https://cmake.org/).

[![Release](https://img.shields.io/github/v/tag/mbeckh/cmake-utils?label=Release&style=flat-square)](https://github.com/mbeckh/cmake-utils/releases/)
[![Tests](https://img.shields.io/github/workflow/status/mbeckh/cmake-utils/test/master?label=Tests&logo=GitHub&style=flat-square)](https://github.com/mbeckh/cmake-utils/actions)
[![License](https://img.shields.io/github/license/mbeckh/cmake-utils?label=License&style=flat-square)](https://github.com/mbeckh/cmake-utils/blob/master/LICENSE)

## Features
-   Bootstrapping of [vcpkg](https://github.com/microsoft/vcpkg).

-   Supports vcpkg registries and vcpkg binary caching.

-   Common build settings for Visual Studio 2019 v16.9 / MSVC 19.28.

-   Run checks using [clang-tidy](https://clang.llvm.org/extra/clang-tidy/) and
    [include-what-you-use](https://include-what-you-use.org/).

-   Check includes of precompiled header files in a way similar to include-what-you-use.

-   [Script](#visual-studio-integration) for running clang-tidy, include-what-you-use and the precompiled header check
    from within Visual Studio.

-   [GitHub action](#github-action) for bootstrapping cmake-utils.

## Usage
-   Set environment CMake variable `BUILD_ROOT` to the path of an output folder. A subfolder will be created therein for every project.

-   Supply the file [`Toolchain.cmake`](Toolchain.cmake) to CMake using `-DCMAKE_TOOLCHAIN_FILE=<path>/cmake-utils/Toolchain.cmake`.
    Everything else will configure itself, e.g. if vcpkg.json is found.

-   Optional user overrides are read from `cmake-utils/UserSettings.cmake` and `${CMAKE_SOURCE_DIR}/cmake/UserSettings.cmake`.

## GitHub Action
Configures CMake for generator Ninja adding the cmake-utils toolchain. This adds bootstrapping of vcpkg, sets common
compiler settings for MSVC and adds auto-generated targets for clang-tidy, include-what-you-use and the precompiled 
header check.

Example:
~~~yml
    - name: Configure
      uses: mbeckh/cmake-utils/configure@master
      with:
        build-root: build
        binary-dir: build/Debug
        configuration: Debug
~~~

The [test workflow](.github/workflow/test.yml) includes additional steps for configureing the MSVC build environment
and cache vcpkg artifacts to speed up the builds.

### Inputs for `configure`
-   `source-dir` - The CMake source directory (optional, defaults to GitHub workspace directory).

-   `build-root` - The path to the root build directory - relative to GitHub workspace - which includes the vcpkg 
    build folder (optional, defaults to GitHub workspace directory).

-   `binary-dir` - The CMake binary directory (optional, defaults to GitHub workspace directory).
    default: .

-   `configuration` - The CMake build type (optional, defaults to `Release`).

-   `extra-args` - Additional arguments which are passed to CMake, e.g. for setting CMake variables (optional).

## Visual Studio Integration
Add one or more external tools within Visual Studio with the following settings:
-   Command: Path of `cmake.exe`
-   Arguments: `-D TOOL=<tool> -D FILE="$(ItemPath)" -P "<script>"` with
    -   `tool` set to either `clang-tidy`, `iwyu` or `pch` and 
	-   `script` set to the full file path of `scripts/run-clang-tools.cmake`.
- Initial Directory: `$(SolutionDir)`
- Use Output Window: checked

## System Requirements / Tested with
-   Visual Studio 2019 v16.9 or newer

-   CMake v3.20 or newer

-   clang-tidy executable v11 or newer. Set environment variable `clang-tidy_ROOT` to folder path if not found
    automatically.

-   include-what-you-use executable v0.15 or newer. Set environment variable `include-what-you-use_ROOT` to folder path
    if not found automatically. `iwyu_tool.py` is expected in the same path as well as the configuration file
	`stl.c.headers.imp`.

-   Running include-what-you-use requires Python. Set CMake variable `Python_EXECUTABLE` to file path if interpreter is
    not found automatically.
   
## License
The code is released under the Apache License Version 2.0. Please see [LICENSE](LICENSE) for details and
[NOTICE](NOTICE) for the required information when using llamalog in your own work.

