/*
MIT License, Copyright(c) 2021 Michael Beckh, see LICENSE
*/
#pragma once

int tidy_error_2();

inline int tidy_error_2_inline() {
	char sz[] = "Test";  // deliberate error for clang-tidy
	return sz[0];
}
