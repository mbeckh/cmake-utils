/*
MIT License, Copyright(c) 2021 Michael Beckh, see LICENSE
*/

#include "cmake-utils/ok_2.h"  // main include

#include <cstddef>  // system include in PCH

int ok_2() {            // use cmake-utils/ok_2.h
	std::size_t s = 3;  // use cstddef
	return static_cast<int>(s);
}
