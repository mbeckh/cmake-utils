# Common Build Options
The following build settings are configured for both local projects and libraries built by vcpkg.

## Compiler
-   Common preprocessor macros `UNICODE=1`, `_UNICODE=1`, `WIN32=1`, `_WINDOWS=1`, `WINVER=0x0A00`,
    `_WIN32_WINNT=0x0A00` and either `_DEBUG=1` or `NDEBUG=1`.

-   Multi-threaded static MSVC runtime library in release or debug flavor (`/MT`, `/MTd`).

-   Enable interprocedural optimization (aka link-time code generation) by default for all configurations but Debug
    (`/Gy`, `/LTCG`).

-   Just my code debugging for configurations Debug and RelWithDebInfo (`/JMC`); never enabled for packages built by vcpkg.

-   Debugging information for edit and continue (`/ZI`) for configurations Debug and RelWithDebInfo, embedded (`/Z7`)
    for all other configurations and for all packages built by vcpkg (all configurations).

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

## Linker
-   Postfix `d` for debug libraries.

-   Enable interprocedural optimization (aka link-time code generation) by default for all configurations but Debug
    (`/LTCG`).

-   Additional linker options
    -   `/CGTHREADS` (if using interprocedural optimization) - use all available CPUs.
    -   `/DEBUG:NONE` (if no debugging information is generated)
    -   `/DEBUG:FULL` (whenever debugging information is generated) - FULL is faster than FASTLINK.
    -   `/INCREMENTAL` (Debug configuration only) - speed up linking.
    -   `/INCREMENTAL:NO` (all configurations but Debug) - keep binary size small.
    -   `/OPT:REF` (all configurations but Debug) - remove unreferenced functions and data.
    -   `/OPT:ICF` (all configurations but Debug) - identical COMDAT folding.
    -   `/WX` (all configurations but Debug) - treat warnings as errors.
