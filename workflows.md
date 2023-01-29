# Re-usable GitHub Workflows
## Build
The workflow [`run-build.yml`](.github/workflows/run-build.yml) creates and runs a build in the binary directory `build/bin`  using the Ninja Multi-Config generator.

### Build Inputs
-   `source-dir` - Path of the CMake source directory (optional, defaults to working directory).
-   `unity` - Use unity build in CMake (optional, defaults to true).
-   `pch` - Use precompiled headers (optional, defaults to true - even for unity builds).
-   `configure-args` - Extra arguments for CMake configure (optional).
-   `build-and-test` - Run the CMake build and CTest test suite (optional, defaults to true).
-   `build-args` - Extra arguments for CMake build (optional).
-   `test-args` - Extra arguments for CTest (optional). `--output-on-failure` is added by default.
-   `analyze` - Analyze with clang-tidy (optional, defaults to true).
-   `clean-caches`- Clean caches of deleted branches (optional, defaults to true).
 
### Build Use Cases
#### Run Build
Add the following job to a GitHub workflow.
~~~yml
  build-workflow:
    name: Build Workflow
    uses: mbeckh/cmake-utils/.github/workflows/run-build.yml@v1
    secrets: inherit
    permissions:
      actions: write
      contents: read
      packages: write
~~~

#### Only Run a Single Test
To only run a particular test for both tests and coverage.
~~~yml
  build-workflow:
    name: Build Workflow
    uses: mbeckh/cmake-utils/.github/workflows/run-build.yml@v1
    with-args:
      test-args: --tests-regex "^MyTest$"
    secrets: inherit
    permissions:
      actions: write
      contents: read
      packages: write
~~~

## CodeQL
The workflow [`run-codeql.yml`](.github/workflows/run-codeql.yml) runs code analysis using CodeQL. This never uses unity builds because they do not work with CodeQL.

### CodeQL Inputs
-   `source-dir` - Path of the CMake source directory (optional, defaults to working directory).
-   `configure-args` - Extra arguments for CMake configure (optional).
-   `build-args` - Extra arguments for CMake build (optional).

### CodeQL Use Cases
#### Analyze Code
Add the following job to a GitHub workflow.
~~~yml
  codeql-workflow:
    name: CodeQL Workflow
    uses: mbeckh/cmake-utils/.github/workflows/run-codeql.yml@v1
    secrets: inherit
    permissions:
      actions: write
      contents: read
      packages: write
      security-events: write
~~~
