# Copyright 2021 Michael Beckh
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

project("cmake-utils-test-subproject" VERSION 0.0.1
    DESCRIPTION "Test sub project for cmake-utils"
    HOMEPAGE_URL "https://github.com/mbeckh/cmake-utils"
    LANGUAGES CXX)

add_library(subproject "subproject.cpp")
