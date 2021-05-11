/*
Copyright 2021 Michael Beckh

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

#include "tidy_error.h"
#include "tidy_error_2.h"

int tidy_error_1() {
#ifdef _DEBUG
	const char sz[] = "Debug";  // deliberate error for clang-tidy
#else
	const char sz[] = "Release";  // deliberate error for clang-tidy
#endif
	return tidy_error() + tidy_error_2() + sz[0];  // use tidy_error.h and tidy_error_2.h
}
