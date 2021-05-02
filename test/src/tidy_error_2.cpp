/*
MIT License, Copyright(c) 2021 Michael Beckh, see LICENSE
*/

#include "tidy_error_2.h"

#include "tidy_error.h"

int tidy_error_2() {              // use tidy_error_2.h
	char sz[] = "Test";           // deliberate error for clang-tidy
	return tidy_error() + sz[0];  // use tidy_error.h
}
