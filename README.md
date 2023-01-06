# cmake-utils
Modules for building projects using [CMake](https://cmake.org/).

[![Release](https://img.shields.io/github/v/release/mbeckh/cmake-utils?display_name=tag&sort=semver&label=Release&style=flat-square)](https://github.com/mbeckh/cmake-utils/releases/)
[![Tests](https://img.shields.io/github/actions/workflow/status/mbeckh/cmake-utils/test.yml?branch=master&label=Tests&logo=GitHub&style=flat-square)](https://github.com/mbeckh/cmake-utils/actions)
[![License](https://img.shields.io/github/license/mbeckh/cmake-utils?label=License&style=flat-square)](https://github.com/mbeckh/cmake-utils/blob/master/LICENSE)

## Features
-   Common build settings for Visual Studio 2019 and 2022.

-   Bootstrapping of [vcpkg](https://github.com/microsoft/vcpkg).

-   Supports vcpkg registries and vcpkg binary caching.

-   Supports CMake generators `Ninja` and `Ninja Multi-Config` 

-   Allow use of local source for vcpkg library instead of version from repository. This allows working in two projects
    in parallel, e.g. a library and a user of this library, without lengthy round trips to update the vcpkg repository.
    For a local source, the library directory is added to the consuming project using `add_subdirectory` and setting
    the directory's `SYSTEM` property.

-   Run checks using [clang-tidy](https://clang.llvm.org/extra/clang-tidy/) and
    [include-what-you-use](https://include-what-you-use.org/).

-   Check includes of precompiled header files in a way similar to include-what-you-use.

-   Supports unity builds for build and clang-tidy (no support for include-what-you-use and precompiled header check).

-   [Script](#visual-studio-integration) for running single file compilation, clang-tidy, include-what-you-use and
    the precompiled header check from within Visual Studio. Single file compilation is provided as an alternative to
    the built-in feature of Visual Studio 2019 which fails with an error message if a precompiled header is used.
    Single file compilation seems to work in Visual Studio 2022, so this feature might be removed in the future.

-   [GitHub action](#github-action) for bootstrapping cmake-utils.

## Usage
-   Set environment CMake variable `BUILD_ROOT` to the path of an output folder. A subfolder will be created therein 
    for every project.

-   Supply the file [`Toolchain.cmake`](Toolchain.cmake) to CMake using `-DCMAKE_TOOLCHAIN_FILE:FILEPATH=<path>/cmake-utils/Toolchain.cmake`.
    Everything else will configure itself, e.g. if `vcpkg.json` is found.

-   Optional user overrides are read from `cmake-utils/UserSettings.cmake` and `${CMAKE_SOURCE_DIR}/cmake/UserSettings.cmake`.

-   Setting CMake variable `CMU_DISABLE_DEBUG_INFORMATION` or `CMU_DISABLE_DEBUG_INFORMATION_<Config>` to `true`
    skips generation of debug information and PDB to speed up builds when debug information is not required
    (e.g. in some CI scenarios).
    
-   If CMake variable `CMU_DISABLE_CLANG_TOOLS` is set to `true`, configure will skip detection of clang but retain
    common build settings and vcpkg integration. This can speed up generation of CMake cache in some scenarios if a
    plain build is sufficient.
    
## Changes to Build
-   Sets common build options for both local projects and libraries built by vcpkg.
    -   Postfix `d` for debug executable.

    -   Common preprocessor macros `UNICODE=1`, `_UNICODE=1`, `WIN32=1`, `_WINDOWS=1`, `WINVER=0x0A00`, `_WIN32_WINNT=0x0A00` and either `_DEBUG=1` or `NDEBUG=1`.

    -   Multi-threaded static MSVC runtime library in release or debug flavor (`/MT`, `/MTd`).

    -   Enable interprocedural optimization (aka link-time code generation) by default for all configurations but Debug (`/Gy`, `/LTCG`).

    -   Just my code debugging for configurations Debug and RelWithDebInfo (`/JMC`); never enabled for packages built by vcpkg.

    -   Debugging information for edit and continue (`/ZI`) for configurations Debug and RelWithDebInfo, embedded (`/Z7`) for all other configurations and for all packages built by vcpkg (all configurations).

    -   Additional compiler options
        -   Optimization
            -   `/Od` (Debug configuration only) - switch off optimizations for debug builds
            -   `/O2` (all configurations but Debug) - generate fast code
            -   `/Ob3` (all configurations but Debug) - aggressive inlining

        -   Code generation
            -   `/EHsc` - enable C++ exceptions, C is `nothrow`.
            -   `/GR-` - disable runtime type identification (RTTI).
            -   `/Gw` (all configurations but Debug) - whole-program global data optimzation.
            -   `/RTC1`  (Debug configuration only) - enable runtime checks.

        -   Language
            -   `/permissive-` - better standards conformance.
            -   `/Zc:inline` (all configurations but Debug) - remove unreferenced functions.

        -   Miscellaneous
            -   `/bigobj` - high number of sections in object files required by tests and LTCG.
            -   `/FC` (Debug configuration and only if linking with googletest libraries ) - full paths required for linking to source in test errors.
            -   `/FS` (configurations Debug and RelWithDebInfo only) - required to prevent errors during build.
            -   `/MP` - required by CodeQL scanning on GitHub.
            -   `/utf-8` - standard character set for source and runtime.

        -   Diagnostics
            -   `/diagnostics:caret` - show location of errors and warnings.
            -   `/sdl` - more security warnings.
            -   `/W4` - better code quality.
            -   `/wd4373` - disable a legacy warning in valid C++ code which exists for pre 2008 versions of MSVC.
            -   `/WX` (all configurations but Debug) - treat warnings as errors.

    -   Additional linker options
        -   `/CGTHREADS` (if using interprocedural optimization) - use all available CPUs.
        -   `/DEBUG:NONE` (if no debugging information is generated)
        -   `/DEBUG:FULL` (whenever debugging information is generated) - FULL is faster than FASTLINK.
        -   `/INCREMENTAL` (Debug configuration only) - speed up linking.
        -   `/INCREMENTAL:NO` (all configurations but Debug) - keep binary size small.
        -   `/OPT:REF` (all configurations but Debug) - remove unreferenced functions and data.
        -   `/OPT:ICF` (all configurations but Debug) - identical COMDAT folding.
        -   `/WX` (all configurations but Debug) - treat warnings as errors.

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

## GitHub Actions
### `configure` - Configure a Build
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

#### Inputs for `configure`
-   `build-root` - The path to the root build directory - relative to GitHub workspace - which includes the vcpkg 
    build folder (optional, defaults to GitHub workspace directory).

-   `preset` - The CMake configure preset (optional) .

-   `source-dir` - The CMake source directory (optional, defaults to GitHub workspace directory if no preset is used).

-   `binary-dir` - The CMake binary directory (optional, defaults to GitHub workspace directory if no preset is used).

-   `generator` - The CMake generator (optional, defaults to Ninja if no preset is used).

-   `configuration` - The CMake build type for CMAKE_BUILD_TYPE (optional, defaults to `Release` if no preset is used).

-   `configurations` - The CMake configuration types for CMAKE_CONFIGURATION_TYPES (optional, defaults to
    `Debug;Release` if no preset is used and generator is Ninja Multi-Config).

-   `extra-args` - Additional arguments which are passed to CMake, e.g. for setting CMake variables (optional).

#### Packages
The action sets up package caching using NuGet on GitHub. If an error occurs when updating a package that is used by
different repositories, it might be required to allow write access to this package for repositories other than the one
that created the package in the first place.

### `msvc-dev-env` - Set-up MSVC Development Environment
Sets environment variables for MSVC using `vcpkg env`. The action enables pass-through of `PATH` environmen variable
using `VCPKG_KEEP_ENV_VARS`.

Example:
~~~yml
    - name: Set-up MSVC Environment
      uses: mbeckh/cmake-utils/msvc-dev-env@v1
~~~

#### Inputs for `msvc-dev-env`
-   `triplet` - The vcpkg triplet to configure the build (optional, defaults to `x64-windows-static`).

## Visual Studio Integration
Add one or more external tools within Visual Studio with the following settings:
-   Command: Path of `scripts/run-clang-tools.bat`.

-   Arguments: `<tool> "$(ItemPath)" "<vcvars>" [ "<cmake>" ]` with
    -   `tool` set to either `compile`, `clang-tidy`, `iwyu` or `pch`, `compile` runs a build for a single file (which is broken in MSVC as of v16.11 when using precompiled headers).
    -   `vcvars` set to the full path of a batch script to set the build environment, e.g. `C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat` and
    -   `cmake` optionally set to the full file path of `cmake.exe`. If `cmake` is not provided, `cmake.exe` from the current path is used.

-   Initial Directory: `$(SolutionDir)`.

-   Use Output window: checked.

## System Requirements / Tested with
-   Visual Studio 2019 v16.11 or newer.

-   CMake v3.25 or newer running on Microsoft Windows.

-   clang 13.0.0 or newer is required for precompiled header analysis. Set environment variable `clang_ROOT` to folder 
    path if not found automatically.

-   clang-tidy 13.0.0 or newer. Set environment variable `clang-tidy_ROOT` to folder path if not found
    automatically.

-   include-what-you-use executable 0.16 or newer. Set environment variable `include-what-you-use_ROOT` to folder path
    if not found automatically. `stl.c.headers.imp` is expected in the same path.

-   Visual Studio integration requires the use of a CMakePresets file which sets the environment variable `BINARY_DIR`.

## License
The code is released under the Apache License Version 2.0. Please see [LICENSE](LICENSE) for details.
