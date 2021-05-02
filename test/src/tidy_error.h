/*
MIT License, Copyright(c) 2021 Michael Beckh, see LICENSE
*/
#pragma once

inline int tidy_error() {
	char sz[] = "Test";  // deliberate error for clang-tidy
	return sz[0];
}
