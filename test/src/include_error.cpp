/*
MIT License, Copyright(c) 2021 Michael Beckh, see LICENSE
*/

#include <cstddef>  // system include in PCH
#include <cstdint>  // system include missing from PCH
#include <cstring>  // deliberate error for iwyu: not required

std::uint32_t include_error() {  // use cstdint
	std::size_t s = 3;           // use cstddef
	return static_cast<std::uint32_t>(s);
}
