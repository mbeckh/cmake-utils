/*
MIT License, Copyright(c) 2021 Michael Beckh, see LICENSE
*/
#pragma once

#include "ok.h"

#include <cstdint>  // system include in PCH

int ok_2();

inline std::uint32_t ok_2_cstdint() {  // use cstdint
	return ok() + 1;                   // use "ok.h"
}
