cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

project("cmake-utils-test-subproject" VERSION 0.0.1
    DESCRIPTION "Test sub project for cmake-utils"
    HOMEPAGE_URL "https://github.com/mbeckh/cmake-utils"
    LANGUAGES CXX)

add_library(subproject "subproject.cpp")
