# msvc-dev-env
Sets environment variables for MSVC development environment.

## Inputs
-   `arch` - The CPU architecture for the build (optional, defaults to `amd64` aka `x64`).

-   `env-file` - A path relative to the GitHub workspace where the environment variables are written in
    addition to setting the environment (optional).

## Use Cases
### Set Development Environment
~~~yml
    - name: Set-up MSVC Environment
      uses: mbeckh/cmake-utils/msvc-dev-env@v1
~~~

### Set Environment and Store for Re-Use
The following code saves the environment in a file `my.env` in the GitHub workspace.
~~~yml
    - name: Set-up MSVC Environment
      uses: mbeckh/cmake-utils/msvc-dev-env@v1
      with:
        env-file: my.env
~~~

To re-use the environment
~~~yml
    - name: Re-use MSVC Environment
      shell: bash
      run: cat my.env >> $GITHUB_ENV
~~~
