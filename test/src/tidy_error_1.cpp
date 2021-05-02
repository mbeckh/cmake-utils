/*
MIT License, Copyright(c) 2021 Michael Beckh, see LICENSE
*/

#include "tidy_error.h"
#include "tidy_error_2.h"

int tidy_error_1() {
	char sz[] = "Test";                            // deliberate error for clang-tidy
	return tidy_error() + tidy_error_2() + sz[0];  // use tidy_error.h and tidy_error_2.h
}
