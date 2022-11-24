# cmake-utils
Modules for building projects using [CMake](https://cmake.org/).

[![Release](https://img.shields.io/github/v/release/mbeckh/cmake-utils?display_name=tag&sort=semver&label=Release&style=flat-square)](https://github.com/mbeckh/cmake-utils/releases/)
[![Tests](https://img.shields.io/github/workflow/status/mbeckh/cmake-utils/Test/master?label=Tests&logo=GitHub&style=flat-square)](https://github.com/mbeckh/cmake-utils/actions)
[![License](https://img.shields.io/github/license/mbeckh/cmake-utils?label=License&style=flat-square)](https://github.com/mbeckh/cmake-utils/blob/master/LICENSE)

## Features
-   Common build settings for Visual Studio 2019 and 2022.

-   Bootstrapping of [vcpkg](https://github.com/microsoft/vcpkg).

-   Supports vcpkg registries and vcpkg binary caching.

-   Use local source of vcpkg library instead of version from repository. This allows working in two projects in parallel, e.g.
    a library and a user of this library, without lengthy round trips to update the vcpkg repository.

-   Run checks using [clang-tidy](https://clang.llvm.org/extra/clang-tidy/) and
    [include-what-you-use](https://include-what-you-use.org/).

-   Check includes of precompiled header files in a way similar to include-what-you-use.

-   Supports unity builds for build and clang-tidy (no support for include-what-you-use and precompiled header check).

-   [Script](#visual-studio-integration) for running single file compilation, clang-tidy, include-what-you-use and
    the precompiled header check from within Visual Studio. Single file compilation is provided as an alternative to
    the built-in feature of Visual Studio which fails with an error message if a precompiled header is used.

-   [GitHub action](#github-action) for bootstrapping cmake-utils.

## Usage
-   Set environment CMake variable `BUILD_ROOT` to the path of an output folder. A subfolder will be created therein 
    for every project.

-   Supply the file [`Toolchain.cmake`](Toolchain.cmake) to CMake using `-DCMAKE_TOOLCHAIN_FILE=<path>/cmake-utils/Toolchain.cmake`.
    Everything else will configure itself, e.g. if vcpkg.json is found.

-   Optional user overrides are read from `cmake-utils/UserSettings.cmake` and `${CMAKE_SOURCE_DIR}/cmake/UserSettings.cmake`.

-   Setting CMake variable `CMU_DISABLE_DEBUG_INFORMATION` or `CMU_DISABLE_DEBUG_INFORMATION_<Config>` to `true`
    skips generation of debug information and PDB to speed up builds when debug information is not required
    (e.g. in some CI scenarios).
    
-   If CMake variable `CMU_DISABLE_CLANG_TOOLS` is set to `true`, configure will skip detection of clang. This can speed up
    generation of CMake cache in some scenarios (e.g. slow detection of Python interpreter) if a plain build is sufficient.
    
## Changes to Build
-   Enables CMake option `BUILD_TESTING` if a project is at the top level (`PROJECT_IS_TOP_LEVEL`).

-   Setup vcpkg toolchain automatically, if `vcpkg.json` if present in the project root folder.

-   Enables the features `test`, `tests` and `testing` for vcpkg if available in the top level target and 
    `BUILD_TESTING` is set. This allows providing dependencies for running tests in the top level target while not
    creating a transitive to those test-only dependencies for all users of a package.

-   Set `LOCAL_<Package Name>_ROOT` in `UserSettings.cmake` to use a local source tree instead of the version from 
    vcpkg and add the respective targets to the current project as local targets. However, the package MUST exist in
    vcpkg. Please note, that while the includes of the local copy have higher precedence, the original include path is
    still available. This might lead to unexpected results if a file is removed in the local copy. Use the feature at 
    your discretion for local development, but always check that the build still works in a clean environment.

-   Creates targets `clang-tidy`, `iwyu` and `pch` to run the respective checks on all targets.

-   Creates targets `clang-tidy-<target>`, `iwyu-<target>` and `pch-<target>` to run the respective checks on a single
    target.

## GitHub Action
Configures CMake for generator Ninja adding the cmake-utils toolchain. This adds bootstrapping of vcpkg, sets common
compiler settings for MSVC and adds auto-generated targets for clang-tidy, include-what-you-use and the precompiled 
header check.

Example:
~~~yml
    - name: Configure
      uses: mbeckh/cmake-utils/configure@v1
      with:
        build-root: build
        binary-dir: build/Debug
        configuration: Debug
~~~

The [test workflow](.github/workflow/test.yml) includes additional steps for configuring the MSVC build environment
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
-   Command: Path of `scripts/run-clang-tools.bat`.

-   Arguments: `<tool> "$(ItemPath)" "<vcvars>" [ "<cmake>" ]` with
    -   `tool` set to either `compile`, `clang-tidy`, `iwyu` or `pch`, `compile` runs a build for a single file (which is broken in MSVC as of v16.11 when using precompiled headers).
    -   `vcvars` set to the full path of a batch script to set the build environment, e.g. `C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64.bat` and
    -   `cmake` optionally set to the full file path of `cmake.exe`. If `cmake` is not provided, `cmake.exe` from the current path is used.

-   Initial Directory: `$(SolutionDir)`.

-   Use Output window: checked.

## System Requirements / Tested with
-   Visual Studio 2019 v16.11 or newer.

-   CMake v3.22 or newer running on Microsoft Windows. v3.22 is required to support `-external:I` for system includes.

-   clang 13.0.0 or newer is required for precompiled header analysis. Set environment variable `clang_ROOT` to folder 
    path if not found automatically.

-   clang-tidy 13.0.0 or newer. Set environment variable `clang-tidy_ROOT` to folder path if not found
    automatically. Script `run-clang-tidy.py` is expected in the same path.

-   include-what-you-use executable 0.16 or newer. Set environment variable `include-what-you-use_ROOT` to folder path
    if not found automatically. `iwyu_tool.py` is expected in the same path as well as the configuration file
    `stl.c.headers.imp`.

-   Running clang-tidy (required only for unity builds, but always checked) and include-what-you-use requires Python.
    Set CMake variable `Python_EXECUTABLE` to file path if interpreter is not found automatically.

## License
The code is released under the Apache License Version 2.0. Please see [LICENSE](LICENSE) for details.
