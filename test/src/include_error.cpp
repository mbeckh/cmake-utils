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

#include <cstddef>  // system include in PCH
#include <cstdint>  // system include missing from PCH
#include <cstring>  // deliberate error for iwyu: not required

std::uint32_t include_error() {  // use cstdint
	std::size_t s = 3;           // use cstddef
	return static_cast<std::uint32_t>(s);
}
