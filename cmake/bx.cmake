# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
cmake_minimum_required(VERSION 3.24)

include_guard(GLOBAL)

function(bx_cmake)
    message(STATUS "Configuring FetchContent provisioning mode.")
    set(fetch_content_shim "${CMAKE_CURRENT_LIST_DIR}/use-fetch-content.cmake")

    set(shim_applied FALSE)
    set(ii 3) # Skip: cmake -P bx
    while (ii LESS CMAKE_ARGC)
    # If -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES exists, add the fetch_content_shim to it
    if (CMAKE_ARGV${ii} MATCHES "-DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=")
        message(TRACE "Appending \"${fetch_content_shim}\" to -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES.")
        list(APPEND command_line "${CMAKE_ARGV${ii}};${fetch_content_shim}")
        set(shim_applied TRUE)
    else()
        list(APPEND command_line "${CMAKE_ARGV${ii}}")
    endif()
    math(EXPR ii "${ii} + 1")
    endwhile()

    if(NOT shim_applied)
    message(TRACE "Appending -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES to command line.")
    list(APPEND command_line "-DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=${fetch_content_shim}")
    endif()

    # make a space delimited list of the command line arguments
    string(REPLACE ";" " " command_line_str "${command_line}")
    message(STATUS "Running: ${command_line_str}")
    execute_process(COMMAND ${command_line})
endfunction(bx_cmake)

bx_cmake()
