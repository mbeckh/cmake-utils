#
# Run build command for one or several files.
# Can e.g. be used inside Visual Studio as an external tool to run clang-tidy, include-what-you-use or PCH check for a
# file from within the IDE with the following settings.
# - Command: Path of CMake.exe
# - Arguments: -D TOOL=[clang-tidy | iwyu | pch ] -D FILE="$(ItemPath)" -P <Path-of-this-File>
# - Initial Directory: $(SolutionDir)
# - Use Output window: checked
#
# Usage: cmake
#        -D TOOL=<name>
#        -D FILE=<file>
#        -P run-clang-tools.cmake
#
# MIT License, Copyright (c) 2021 Michael Beckh, see LICENSE
#

cmake_minimum_required(VERSION 3.20 FATAL_ERROR)

cmake_path(RELATIVE_PATH FILE BASE_DIRECTORY "${CMAKE_SOURCE_DIR}" OUTPUT_VARIABLE file_in_solution)
cmake_path(GET FILE PARENT_PATH solution_dir)
cmake_path(GET FILE ROOT_PATH root_path)
while(NOT solution_dir STREQUAL root_path AND NOT EXISTS "${solution_dir}/CMakeSettings.json")
	cmake_path(GET solution_dir PARENT_PATH solution_dir)
endwhile()

if(NOT EXISTS "${solution_dir}/CMakeSettings.json")
	message(FATAL_ERROR "CMake project not found containing ${CMAKE_BINARY_DIR}")
endif()
cmake_path(RELATIVE_PATH FILE BASE_DIRECTORY "${solution_dir}" OUTPUT_VARIABLE file)

file(READ "${solution_dir}/CMakeSettings.json" settings)

#
# Get first Debug configuration
#
string(JSON count LENGTH "${settings}" "configurations")
math(EXPR last_configuration "${count} - 1")
foreach(index RANGE ${last_configuration})
	string(JSON configurationName GET "${settings}" configurations ${index} "name")
	string(JSON configurationType GET "${settings}" configurations ${index} "configurationType")
	if(NOT build_root OR configurationType STREQUAL Debug)
		string(JSON build_root GET "${settings}" configurations ${index} "buildRoot")
		if(configurationType STREQUAL Debug)
			break()
		endif()
	endif()
endforeach()

#
# Get build path
#
function(replace_variables str)
	set(result "${${str}}")

	string(REGEX MATCHALL [[\${[^}]+}]] variables "${result}")
	if(variables)
		string(JSON count LENGTH "${settings}" environments)
		math(EXPR lastEnvironment "${count} - 1")
	endif()
	
	foreach(variable IN LISTS variables)
		string(REGEX MATCH [[\${(([^.}]+)\.)?([^.}]+)}]] parts "${variable}")
		set(prefix "${CMAKE_MATCH_2}")
		set(name "${CMAKE_MATCH_3}")

		unset(found)
		if(prefix)
			foreach(index RANGE ${lastEnvironment})
				string(JSON namespace ERROR_VARIABLE error GET "${settings}" environments ${index} namespace)
				if((prefix STREQUAL "env" AND NOT namespace) OR prefix STREQUAL namespace)
					string(JSON value GET "${settings}" environments ${index} "${name}")
					replace_variables(value)
					string(REPLACE "${variable}" "${value}" result "${result}")
					set(found YES)
					break()
				endif()
			endforeach()
		elseif(name STREQUAL "name")
			string(REPLACE "${variable}" "${configurationName}" result "${result}")
			set(found YES)
		elseif(name STREQUAL "projectDirName")
			cmake_path(GET project_dir FILENAME project_dir_name)
			string(REPLACE "${variable}" "${project_dir_name}" result "${result}")
			set(found YES)
		endif()
		if(NOT found)
			message(FATAL_ERROR "Unknown replacement: ${parts} in ${${str}}")
		endif()
	endforeach()

	set("${str}" "${result}" PARENT_SCOPE)
endfunction()

replace_variables(build_root)

#
# Get target
#
include("${CMAKE_CURRENT_LIST_DIR}/regex.cmake")

file(READ "${build_root}/compile_commands.json" compile_commands)
string(JSON count LENGTH "${compile_commands}")
math(EXPR last_file "${count} - 1")
cmake_path(NORMAL_PATH FILE OUTPUT_VARIABLE input_file_path)
foreach(index RANGE ${last_file})
	string(JSON file_path GET "${compile_commands}" ${index} "file")
	cmake_path(NORMAL_PATH file_path)
	cmake_path(COMPARE "${input_file_path}" EQUAL "${file_path}" is_equal)
	if(is_equal)
		string(JSON command GET "${compile_commands}" ${index} "command")
		cmake_path(NATIVE_PATH file relative_file_path)
        clang_tools_regex_escape_pattern(relative_file_path)
		string(REGEX MATCH " /FoCMakeFiles\\\\(.+)\\.dir\\\\${relative_file_path}\\.obj " match "${command}")
		if(match)
			set(target "${CMAKE_MATCH_1}")
		endif()
		break()
	endif()
endforeach()

if(NOT target)
	message(FATAL_ERROR "${file} not found in compile_commands.json")
endif()

#
# Run build
#

if(TOOL STREQUAL "clang-tidy")
	set(result_file ".clang-tools/${target}/${file}.tidy")
elseif(TOOL STREQUAL "iwyu")
	set(result_file ".clang-tools/${target}/${file}.iwyu")
elseif(TOOL STREQUAL "pch")
	set(result_file "./pch-${target}.log")
else()
	message(FATAL_ERROR "Unknown tool: ${TOOL}")
endif()

execute_process(COMMAND "${CMAKE_COMMAND}" --build . --target "${result_file}"
				COMMAND "${CMAKE_COMMAND}" -E true
				WORKING_DIRECTORY "${build_root}"
				RESULTS_VARIABLE results
				OUTPUT_VARIABLE output
				ERROR_VARIABLE error
				COMMAND_ECHO NONE
				COMMAND_ERROR_IS_FATAL LAST)

message(">------ ${file_in_solution} (${target}, ${configurationName}) - ${build_root} ------\n")
if(error)
	message("${error}")
	message(FATAL_ERROR "Error running build: ${result_file}")
endif()

#
# Post-process output
#

file(READ "${build_root}/${result_file}" output)
string(REPLACE ";" "\\;" output "${output}")
string(REPLACE "\n" ";" output "${output}")
unset(result)
if(TOOL STREQUAL clang-tidy)
	foreach(line IN LISTS output)
		string(REGEX MATCH "^([^ ].+):([0-9]+):([0-9]+): ([^ ]+): (.+) \\[(.+)\\]$" parts "${line}")
		if(parts)
			cmake_path(NATIVE_PATH CMAKE_MATCH_1 native)
			set(line "${native}(${CMAKE_MATCH_2},${CMAKE_MATCH_3}): ${CMAKE_MATCH_4} [${CMAKE_MATCH_6}]: ${CMAKE_MATCH_5}")
		endif()
		string(REPLACE ";" "\\;" line "${line}")
		list(APPEND result "${line}")
	endforeach()
elseif(TOOL STREQUAL iwyu OR TOOL STREQUAL pch)
	foreach(line IN LISTS output)
		string(REGEX MATCH "^([^ ].+)( should.+$)" parts "${line}")
		if(parts)
			cmake_path(NATIVE_PATH CMAKE_MATCH_1 native)
			set(line "${native}:${CMAKE_MATCH_2}")
		else()
			string(REGEX MATCH "^\\((.+)( has correct.+)\\)$" parts "${line}")
			if(parts)
				cmake_path(NATIVE_PATH CMAKE_MATCH_1 native)
				set(line "${native}:${CMAKE_MATCH_2}")
			else()
				string(REGEX MATCH "^(The full include-list) for (.+):$" parts "${line}")
				if(parts)
					cmake_path(NATIVE_PATH CMAKE_MATCH_2 native)
					set(line "${native}: ${CMAKE_MATCH_1}:")
				endif()
			endif()
		endif()
		string(REPLACE ";" "\\;" line "${line}")
		list(APPEND result "${line}")
	endforeach()
endif()
list(JOIN result "\n" result)
string(REPLACE "\\;" ";" output "${result}")
message("${output}")
