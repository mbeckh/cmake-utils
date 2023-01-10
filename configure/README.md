# configure
Configures CMake for generator Ninja adding the cmake-utils toolchain. This adds bootstrapping of vcpkg, sets common
compiler settings for MSVC and adds auto-generated targets for clang-tidy, include-what-you-use and the precompiled 
header check.

## Inputs
-   `build-root` - The path to the root build directory - relative to GitHub workspace - of the vcpkg build folder
    (optional, defaults to GitHub workspace directory).

-   `preset` - The CMake configure preset (optional) .

-   `source-dir` - The CMake source directory (optional, defaults to GitHub workspace directory if no preset is used).

-   `binary-dir` - The CMake binary directory (optional, defaults to GitHub workspace directory if no preset is used).

-   `generator` - The CMake generator (optional, defaults to Ninja if no preset is used).

-   `configuration` - The CMake build type for CMAKE_BUILD_TYPE (optional, defaults to `Release` if no preset is used).

-   `configurations` - The CMake configuration types for CMAKE_CONFIGURATION_TYPES (optional, defaults to
    `Debug;Release` if no preset is used and generator is Ninja Multi-Config).

-   `extra-args` - Additional arguments which are passed to CMake, e.g. for setting CMake variables (optional).

## Package Caching
The action sets up package caching using NuGet on GitHub. If an error occurs when updating a package that is used by
different repositories, it might be required to allow write access to this package for repositories other than the one
that created the package in the first place.

## Use Cases
### Configure a Simple Build
Configures a build for the Debug configuration in the path `build/bin`. Additional data for vcpkg is stored in other
folders inside `build`.
~~~yml
    - name: Configure
      uses: mbeckh/cmake-utils/configure@v1
      with:
        build-root: build
        binary-dir: build/bin
        configuration: Debug
~~~

### Configure a Multi-Config Build
Configure a build using a multi-config generator and using a preset.
~~~yml
    - name: Configure
      uses: mbeckh/cmake-utils/configure@v1
      with:
        build-root: build
        preset: x64
        binary-dir: build/bin
        generator: Ninja Multi-Config
~~~
