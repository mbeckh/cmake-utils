# clang-tidy Checks
Set the environment variable `CMU_CLANG_TIDY_CHECKS` to customize the checks of clang-tidy. By default, clang-tidy uses
the config file `.clang-tidy` in the source directory and its respective parents.

This default set of rules can be customized using the syntax for the [`--checks` argument of clang-tidy](https://clang.llvm.org/extra/clang-tidy/index.html).
Enable or disable groups of check using the keywords `<name>` or `-<name>` according to the following list.
-   `bugprone`
-   `cert`
-   `clang-analyzer`
-   `concurrency`
-   `cppcoreguidelines`
-   `google`
-   `hicpp`
-   `llvm`
-   `misc`
-   `modernize`
-   `performance`
-   `portability`
-   `readability`
-   `all` - all of the above

The checks aim to detect possibly hard to spot errors, but allow constructs such as arrays, macros, assembler etc. which
may be hard to use but are perfectly valid. After all, this is C++ development!

The specification of `-*,all` results in the following checks being enabled.

| Check | Comment |
| --- | --- |
| `-abseil-*` | Currently not using library. |
| `-altera-*` | Currently not targeting platform. |
| `-android-*` | Currently not targeting platform. |
| `-boost-*` | Currently not using library. |
| `bugprone-argument-comment` | |
| `bugprone-assert-side-effect` | |
| `bugprone-assignment-in-if-condition` | |
| `-bugprone-bad-signal-to-kill-thread` | POSIX |
| `bugprone-bool-pointer-implicit-conversion` | |
| `bugprone-branch-clone` | |
| `bugprone-copy-constructor-init` | |
| `bugprone-dangling-handle` | |
| `bugprone-dynamic-static-initializers` | |
| `bugprone-easily-swappable-parameters` | |
| `bugprone-exception-escape` | |
| `bugprone-fold-init-type` | |
| `bugprone-forward-declaration-namespace` | |
| `bugprone-forwarding-reference-overload` | |
| `bugprone-implicit-widening-of-multiplication-result` | |
| `bugprone-inaccurate-erase` | |
| `bugprone-incorrect-roundings` | |
| `bugprone-infinite-loop` | |
| `bugprone-integer-division` | |
| `bugprone-lambda-function-name` | |
| `bugprone-macro-parentheses` | |
| `bugprone-macro-repeated-side-effects` | |
| `bugprone-misplaced-operator-in-strlen-in-alloc` | |
| `bugprone-misplaced-pointer-arithmetic-in-alloc` | |
| `bugprone-misplaced-widening-cast` | |
| `bugprone-move-forwarding-reference` | |
| `bugprone-multiple-statement-macro` | |
| `-bugprone-narrowing-conversions` | Alias of `cppcoreguidelines-narrowing-conversions` |
| `-bugprone-no-escape` | clang attribute |
| `bugprone-not-null-terminated-result` | |
| `bugprone-parent-virtual-call` | |
| `-bugprone-posix-return` | POSIX |
| `bugprone-redundant-branch-condition` | |
| `bugprone-reserved-identifier` | |
| `bugprone-shared-ptr-array-mismatch` | |
| `-bugprone-signal-handler` | POSIX and < C++17 only |
| `bugprone-signed-char-misuse` | |
| `bugprone-sizeof-container` | |
| `bugprone-sizeof-expression` | |
| `bugprone-spuriously-wake-up-functions` | |
| `bugprone-standalone-empty` | |
| `bugprone-string-constructor` | |
| `bugprone-string-integer-assignment` | |
| `bugprone-string-literal-with-embedded-nul` | |
| `bugprone-stringview-nullptr` | |
| `bugprone-suspicious-enum-usage` | |
| `bugprone-suspicious-include` | |
| `bugprone-suspicious-memory-comparison` | |
| `bugprone-suspicious-memset-usage` | |
| `bugprone-suspicious-missing-comma` | |
| `bugprone-suspicious-realloc-usage` | |
| `bugprone-suspicious-semicolon` | |
| `bugprone-suspicious-string-compare` | |
| `bugprone-swapped-arguments` | |
| `bugprone-terminating-continue` | |
| `bugprone-throw-keyword-missing` | |
| `bugprone-too-small-loop-variable` | |
| `bugprone-unchecked-optional-access` | |
| `bugprone-undefined-memory-manipulation` | |
| `bugprone-undelegated-constructor` | |
| `bugprone-unhandled-exception-at-new` | |
| `bugprone-unhandled-self-assignment` | |
| `bugprone-unused-raii` | |
| `bugprone-unused-return-value` | |
| `bugprone-use-after-move` | |
| `bugprone-virtual-near-miss` | |
| `-cert-con36-c` | Alias of `bugprone-spuriously-wake-up-functions` |
| `-cert-con54-cpp` | Alias of `bugprone-spuriously-wake-up-functions` |
| `-cert-dcl03-c` | Alias of `misc-static-assert` |
| `-cert-dcl16-c` | Alias of `readability-uppercase-literal-suffix` |
| `cert-dcl21-cpp` | Modification of postfix operator result |
| `-cert-dcl37-c` | Alias of `bugprone-reserved-identifier` |
| `cert-dcl50-cpp` | variadic functions are valid |
| `-cert-dcl51-cpp` | Alias of `bugprone-reserved-identifier` |
| `-cert-dcl54-cpp` | Alias of `misc-new-delete-overloads` |
| `cert-dcl58-cpp` | Modification of std namespace |
| `-cert-dcl59-cpp` | Alias of `google-build-namespaces` |
| `-cert-env33-c` | POSIX |
| `-cert-err09-cpp` | Alias of `misc-throw-by-value-catch-by-reference` |
| `cert-err33-c` | Other functions as bugprone-unused-return-value |
| `cert-err34-c` | Results of atoi, scanf and the like |
| `cert-err52-cpp` | setjmp and longjmp are valid code |
| `cert-err58-cpp` | Exceptions in static initializers |
| `cert-err60-cpp` | Non-copy-constructible exceptions |
| `-cert-err61-cpp` | Alias of `misc-throw-by-value-catch-by-reference` |
| `-cert-exp42-c` | Alias of `bugprone-suspicious-memory-comparison` |
| `-cert-fio38-c` | Alias of `misc-non-copyable-objects` |
| `cert-flp30-c` | Floating point in for loops |
| `-cert-flp37-c` | Alias of `bugprone-suspicious-memory-comparison` |
| `cert-mem57-cpp` | Alignment in new |
| `-cert-msc30-c` | Alias of `cert-msc50-cpp` |
| `-cert-msc32-c` | Alias of `cert-msc51-cpp` |
| `cert-msc50-cpp` | std::rand |
| `cert-msc51-cpp` | Predictable random seeds |
| `-cert-msc54-cpp` | Alias of `bugprone-signal-handler` |
| `-cert-oop11-cpp` | Alias of `performance-move-constructor-init` |
| `-cert-oop54-cpp` | Alias of `bugprone-unhandled-self-assignment` |
| `cert-oop57-cpp` | memset, memcpy, memcmp on non trivial types |
| `cert-oop58-cpp` | Modification of source in copy operation |
| `-cert-pos44-c` | Alias of `bugprone-bad-signal-to-kill-thread` |
| `-cert-pos47-c` | Alias of `concurrency-thread-canceltype-asynchronous` |
| `-cert-sig30-c` | Alias of `bugprone-signal-handler` |
| `-cert-str34-c` | Alias of `bugprone-signed-char-misuse` |
| `clang-analyzer-*` | Project is expected to set sensible defaults |
| `clang-diagnostic-*` | |
| `-clang-diagnostic-gnu-zero-variadic-macro-arguments` | |
| `-clang-diagnostic-gnu-language-extension-token` | |
| `concurrency-mt-unsafe` | |
| `-concurrency-thread-canceltype-asynchronous` | POSIX |
| `-cppcoreguidelines-avoid-c-arrays` | Alias of `modernize-avoid-c-arrays` |
| `cppcoreguidelines-avoid-const-or-ref-data-members` | |
| `-cppcoreguidelines-avoid-do-while` | do-while is perfectly valid |
| `cppcoreguidelines-avoid-goto` | |
| `-cppcoreguidelines-avoid-magic-numbers` | Alias of `readability-magic-numbers` |
| `cppcoreguidelines-avoid-non-const-global-variables` | |
| `cppcoreguidelines-avoid-reference-coroutine-parameters` | |
| `-cppcoreguidelines-c-copy-assignment-signature` | Alias of `misc-unconventional-assign-operator` |
| `-cppcoreguidelines-explicit-virtual-functions` | Alias of `modernize-use-override` |
| `cppcoreguidelines-init-variables` | |
| `cppcoreguidelines-interfaces-global-init` | |
| `-cppcoreguidelines-macro-usage` | If macros are used, it's a deliberate choice |
| `cppcoreguidelines-narrowing-conversions` | |
| `cppcoreguidelines-no-malloc` | |
| `-cppcoreguidelines-non-private-member-variables-in-classes` | Alias of `misc-non-private-member-variables-in-classes` |
| `-cppcoreguidelines-owning-memory` | Not using gsl |
| `cppcoreguidelines-prefer-member-initializer` | |
| `-cppcoreguidelines-pro-bounds-*` | Required when using arrays |
| `cppcoreguidelines-pro-type-const-cast` | |
| `cppcoreguidelines-pro-type-cstyle-cast` | |
| `cppcoreguidelines-pro-type-member-init` | |
| `-cppcoreguidelines-pro-type-reinterpret-cast` | reinterpret-cast, if required, is perfectly valid |
| `cppcoreguidelines-pro-type-static-cast-downcast` | |
| `-cppcoreguidelines-pro-type-union-access` | Use of unions is clearly visible and perfectly valid |
| `cppcoreguidelines-pro-type-vararg` | |
| `cppcoreguidelines-slicing` | |
| `cppcoreguidelines-special-member-functions` | |
| `cppcoreguidelines-virtual-class-destructor` | |
| `-darwin-*` | Currently not targeting platform |
| `-fuchsia-*` | Currently not targeting platform |
| `google-build-explicit-make-pair` | |
| `google-build-namespaces` | |
| `google-build-using-namespace` | |
| `google-default-arguments` | |
| `google-explicit-constructor` | |
| `google-global-names-in-headers` | |
| `-google-objc-*` | Currently not targeting Objective-C |
| `-google-readability-avoid-underscore-in-googletest-name` | Rule makes ugly test names, accept risk of changes (cf. "The rule is more constraining than necessary" in the docs) |
| `-google-readability-braces-around-statements` | Alias of `readability-braces-around-statements` |
| `-google-readability-casting` | Duplicate of cppcoreguidelines-pro-type-... |
| `-google-readability-function-size` | Alias of `readability-function-size` |
| `-google-readability-namespace-comments` | Alias of `llvm-namespace-comment` |
| `-google-readability-todo` | Not using TODO comments |
| `-google-runtime-int` | int etc. are perfectly valid types |
| `-google-runtime-operator` | operator&, if defined, is perfectly valid |
| `google-upgrade-googletest-case` | |
| `-hicpp-avoid-c-arrays` | Alias of `modernize-avoid-c-arrays` |
| `-hicpp-avoid-goto` | Duplicate of cppcoreguidelines-avoid-goto |
| `-hicpp-braces-around-statements` | Alias of `readability-braces-around-statements` |
| `-hicpp-deprecated-headers` | Alias of `modernize-deprecated-headers` |
| `hicpp-exception-baseclass` | |
| `-hicpp-explicit-conversions` | Alias of `google-explicit-constructor` |
| `-hicpp-function-size` | Alias of `readability-function-size` |
| `-hicpp-invalid-access-moved` | Alias of `bugprone-use-after-move` |
| `-hicpp-member-init` | Alias of `cppcoreguidelines-pro-type-member-init` |
| `-hicpp-move-const-arg` | Alias of `performance-move-const-arg` |
| `hicpp-multiway-paths-covered` | |
| `-hicpp-named-parameter` | Alias of `readability-named-parameter` |
| `-hicpp-new-delete-operators` | Alias of `misc-new-delete-overloads` |
| `-hicpp-no-array-decay` | Alias of `cppcoreguidelines-pro-bounds-array-to-pointer-decay` |
| `-hicpp-no-assembler` | Assembler, if used, is pclearly visible and erfectly valid |
| `-hicpp-no-malloc` | Alias of `cppcoreguidelines-no-malloc` |
| `-hicpp-noexcept-move` | Alias of `performance-noexcept-move-constructor` |
| `hicpp-signed-bitwise` | |
| `-hicpp-special-member-functions` | Alias of `cppcoreguidelines-special-member-functions` |
| `-hicpp-static-assert` | Alias of `misc-static-assert` |
| `-hicpp-undelegated-constructor` | Alias of `bugprone-undelegated-constructor` |
| `-hicpp-uppercase-literal-suffix` | Alias of `readability-uppercase-literal-suffix` |
| `-hicpp-use-auto` | Alias of `modernize-use-auto` |
| `-hicpp-use-emplace` | Alias of `modernize-use-emplace` |
| `-hicpp-use-equals-default` | Alias of `modernize-use-equals-default` |
| `-hicpp-use-equals-delete` | Alias of `modernize-use-equals-delete` |
| `-hicpp-use-noexcept` | Alias of `modernize-use-noexcept` |
| `-hicpp-use-nullptr` | Alias of `modernize-use-nullptr` |
| `-hicpp-use-override` | Alias of `modernize-use-override` |
| `-hicpp-vararg` | Alias of `cppcoreguidelines-pro-type-vararg` |
| `-linuxkernel-*` | Currently not targeting platform. |
| `-llvm-else-after-return` | Alias of `readability-else-after-return` |
| `-llvm-header-guard` | Using shorter #pragma once |
| `-llvm-include-order` | LLVM specific |
| `llvm-namespace-comment` | |
| `-llvm-prefer-isa-or-dyn-cast-in-conditionals` | LLVM specific |
| `-llvm-prefer-register-over-unsigned` | LLVM specific |
| `-llvm-qualified-auto` | Alias of `readability-qualified-auto` |
| `-llvm-twine-local` | LLVM specific |
| `-llvmlibc-*` | LLVM specific |
| `misc-confusable-identifiers` | |
| `misc-const-correctness` | |
| `misc-definitions-in-headers` | |
| `misc-misleading-bidirectional` | |
| `misc-misleading-identifier` | |
| `-misc-misplaced-const` | Diagnosed code is perfectly valid |
| `misc-new-delete-overloads` | |
| `-misc-no-recursion` | Recursion is perfectly valid |
| `misc-non-copyable-objects` | |
| `misc-non-private-member-variables-in-classes` | |
| `misc-redundant-expression` | |
| `misc-static-assert` | |
| `-misc-throw-by-value-catch-by-reference` | Requirement is overly strict and pointless |
| `misc-unconventional-assign-operator` | |
| `misc-uniqueptr-reset-release` | |
| `misc-unused-alias-decls` | |
| `misc-unused-parameters` | |
| `misc-unused-using-decls` | |
| `misc-use-anonymous-namespace` | |
| `modernize-avoid-bind` | |
| `-modernize-avoid-c-arrays` | Deliberate use of arrays is clearly visible and valid |
| `modernize-concat-nested-namespaces` | |
| `modernize-deprecated-headers` | |
| `modernize-deprecated-ios-base-aliases` | |
| `modernize-loop-convert` | |
| `modernize-macro-to-enum` | |
| `modernize-make-shared` | |
| `modernize-make-unique` | |
| `modernize-pass-by-value` | |
| `modernize-raw-string-literal` | |
| `modernize-redundant-void-arg` | |
| `modernize-replace-auto-ptr` | |
| `modernize-replace-disallow-copy-and-assign-macro` | |
| `modernize-replace-random-shuffle` | |
| `-modernize-return-braced-init-list` | Worsens readability |
| `modernize-shrink-to-fit` | |
| `modernize-unary-static-assert` | |
| `-modernize-use-auto` | Worsens readability |
| `modernize-use-bool-literals` | |
| `-modernize-use-default-member-init` | |
| `modernize-use-emplace` | |
| `modernize-use-equals-default` | |
| `modernize-use-equals-delete` | |
| `modernize-use-nodiscard` | |
| `modernize-use-noexcept` | |
| `modernize-use-nullptr` | |
| `modernize-use-override` | |
| `-modernize-use-trailing-return-type` | Worsens readability |
| `-modernize-use-transparent-functors` | Worsens readability |
| `modernize-use-uncaught-exceptions` | |
| `modernize-use-using` | |
| `-mpi-*` | Currently not targeting platform |
| `-objc-*` | Currently not targeting Objective-C |
| `-openmp-*` | Currently not targeting OpenMP |
| `performance-faster-string-find` | |
| `performance-for-range-copy` | |
| `performance-implicit-conversion-in-loop` | |
| `performance-inefficient-algorithm` | |
| `performance-inefficient-string-concatenation` | |
| `performance-inefficient-vector-operation` | |
| `performance-move-const-arg` | |
| `performance-move-constructor-init` | |
| `performance-no-automatic-move` | |
| `performance-no-int-to-ptr` | |
| `performance-noexcept-move-constructor` | |
| `performance-trivially-destructible` | |
| `performance-type-promotion-in-math-fn` | |
| `performance-unnecessary-copy-initialization` | |
| `performance-unnecessary-value-param` | |
| `-portability-restrict-system-includes` | Allow all includes |
| `-portability-simd-intrinsics` | Allow all SIMD intrinsics |
| `portability-std-allocator-const` | |
| `readability-avoid-const-params-in-decls` | |
| `readability-braces-around-statements` | |
| `readability-const-return-type` | |
| `readability-container-contains` | |
| `readability-container-data-pointer` | |
| `readability-container-size-empty` | |
| `readability-convert-member-functions-to-static` | |
| `readability-delete-null-pointer` | |
| `readability-duplicate-include` | |
| `readability-else-after-return` | |
| `-readability-function-cognitive-complexity` | Forces too many small functions that add no value |
| `-readability-function-size` | Fixed thresholds do not really add value |
| `-readability-identifier-length` | Fixed thresholds do not really add value |
| `readability-identifier-naming` | |
| `readability-implicit-bool-conversion` | |
| `readability-inconsistent-declaration-parameter-name` | |
| `readability-isolate-declaration` | |
| `readability-magic-numbers` | |
| `readability-make-member-function-const` | |
| `readability-misleading-indentation` | |
| `readability-misplaced-array-index` | |
| `readability-named-parameter` | |
| `readability-non-const-parameter` | |
| `readability-qualified-auto` | |
| `-readability-redundant-access-specifiers` | Using redundant specifiers for grouping class declarations |
| `readability-redundant-control-flow` | |
| `readability-redundant-declaration` | |
| `readability-redundant-function-ptr-dereference` | |
| `readability-redundant-member-init` | |
| `readability-redundant-preprocessor` | |
| `readability-redundant-smartptr-get` | |
| `readability-redundant-string-cstr` | |
| `readability-redundant-string-init` | |
| `readability-simplify-boolean-expr` | |
| `readability-simplify-subscript-expr` | |
| `readability-static-accessed-through-instance` | |
| `readability-static-definition-in-anonymous-namespace` | |
| `readability-string-compare` | |
| `readability-suspicious-call-argument` | |
| `readability-uniqueptr-delete-release` | |
| `readability-uppercase-literal-suffix` | |
| `readability-use-anyofallof` | |
| `-zircon-*` | Currently not targeting platform |
