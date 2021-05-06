/*
MIT License, Copyright(c) 2021 Michael Beckh, see LICENSE
*/

#include "cmake-utils/ok_2.h"  // auxiliary include

int ok_1() {
	return ok_2();  // use cmake-utils/ok_2.h
}

int main(int, char**) {
	return 0;
}
