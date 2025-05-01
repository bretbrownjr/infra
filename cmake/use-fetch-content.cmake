# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
cmake_minimum_required(VERSION 3.24)

include(FetchContent)

if(NOT BX_LOCKFILE)
    set(BX_LOCKFILE
        "${CMAKE_SOURCE_DIR}/bx.lockfile.json"
        CACHE FILEPATH
        "Path to the dependency lockfile."
    )
endif()

# Set Bx_parentDir to the directory containing the lockfile
get_filename_component(dir "${BX_LOCKFILE}" DIRECTORY)
message(TRACE "Bx_parentDir=\"${Bx_parentDir}\"")

message(TRACE "BX_LOCKFILE=\"${BX_LOCKFILE}\"")
# Note: Silences a deprecation warning that does not affect the behavior of
# this code. When the cmake_minimum_required version is set to 3.24 or higher,
# the following line can be harmlessly deleted.
cmake_policy(SET CMP0152 OLD)
file(
    REAL_PATH
    "${BX_LOCKFILE}"
    Bx_lockfile
    BASE_DIRECTORY "${Bx_parentDir}"
    EXPAND_TILDE
)
message(DEBUG "Using lockfile: \"${Bx_lockfile}\"")

# Force CMake to reconfigure the project if the lockfile changes
set_property(
    DIRECTORY "${Bx_parentDir}"
    APPEND
    PROPERTY CMAKE_CONFIGURE_DEPENDS "${Bx_lockfile}"
)

# For more on the protocol for this function, see:
# https://cmake.org/cmake/help/latest/command/cmake_language.html#provider-commands
function(Bx_provideDependency method package_name)
    # Read the lockfile
    file(READ "${Bx_lockfile}" Bx_rootObj)

    # Get the "dependencies" field and store it in Bx_dependenciesObj
    string(
        JSON
        Bx_dependenciesObj
        ERROR_VARIABLE Bx_error
        GET "${Bx_rootObj}"
        "dependencies"
    )
    if(Bx_error)
        message(FATAL_ERROR "${Bx_lockfile}: ${Bx_error}")
    endif()

    # Get the length of the libraries array and store it in Bx_dependenciesObj
    string(
        JSON
        Bx_numDependencies
        ERROR_VARIABLE Bx_error
        LENGTH "${Bx_dependenciesObj}"
    )
    if(Bx_error)
        message(FATAL_ERROR "${Bx_lockfile}: ${Bx_error}")
    endif()

    # Check if the dependencies array is empty
    if(Bx_numDependencies EQUAL 0)
        message(STATUS "No dependencies found in ${Bx_lockfile}.")
        return()
    endif()

    # Loop over each dependency object
    math(EXPR Bx_maxIndex "${Bx_numDependencies} - 1")
    foreach(Bx_index RANGE "${Bx_maxIndex}")
        set(Bx_errorPrefix
            "${Bx_lockfile}, dependency ${Bx_index}"
        )

        # Get the dependency object at Bx_index
        # and store it in Bx_depObj
        string(
            JSON
            Bx_depObj
            ERROR_VARIABLE Bx_error
            GET "${Bx_dependenciesObj}"
            "${Bx_index}"
        )
        if(Bx_error)
            message(
                FATAL_ERROR
                "${Bx_errorPrefix}: ${Bx_error}"
            )
        endif()

        # Get the "name" field and store it in Bx_name
        string(
            JSON
            Bx_name
            ERROR_VARIABLE Bx_error
            GET "${Bx_depObj}"
            "name"
        )
        if(Bx_error)
            message(
                FATAL_ERROR
                "${Bx_errorPrefix}: ${Bx_error}"
            )
        endif()

        # Get the "package_name" field and store it in Bx_pkgName
        string(
            JSON
            Bx_pkgName
            ERROR_VARIABLE Bx_error
            GET "${Bx_depObj}"
            "package_name"
        )
        if(Bx_error)
            message(
                FATAL_ERROR
                "${Bx_errorPrefix}: ${Bx_error}"
            )
        endif()

        # Get the "git_repository" field and store it in Bx_repo
        string(
            JSON
            Bx_repo
            ERROR_VARIABLE Bx_error
            GET "${Bx_depObj}"
            "git_repository"
        )
        if(Bx_error)
            message(
                FATAL_ERROR
                "${Bx_errorPrefix}: ${Bx_error}"
            )
        endif()

        # Get the "git_tag" field and store it in Bx_tag
        string(
            JSON
            Bx_tag
            ERROR_VARIABLE Bx_error
            GET "${Bx_depObj}"
            "git_tag"
        )
        if(Bx_error)
            message(
                FATAL_ERROR
                "${Bx_errorPrefix}: ${Bx_error}"
            )
        endif()

        if(method STREQUAL "FIND_PACKAGE")
            if(package_name STREQUAL Bx_pkgName)
                string(
                    APPEND
                    Bx_debug
                    "Redirecting find_package calls for ${Bx_pkgName} "
                    "to FetchContent logic fetching ${Bx_repo} at "
                    "${Bx_tag} according to ${Bx_lockfile}."
                )
                message(DEBUG "${Bx_debug}")
                FetchContent_Declare(
                    "${Bx_name}"
                    GIT_REPOSITORY "${Bx_repo}"
                    GIT_TAG "${Bx_tag}"
                    EXCLUDE_FROM_ALL
                )
                set(INSTALL_GTEST OFF) # Disable GoogleTest installation
                FetchContent_MakeAvailable("${Bx_name}")

                # Important! <PackageName>_FOUND tells CMake that `find_package` is
                # not needed for this package anymore
                set("${Bx_pkgName}_FOUND" TRUE PARENT_SCOPE)
            endif()
        endif()
    endforeach()
endfunction()

cmake_language(
    SET_DEPENDENCY_PROVIDER Bx_provideDependency
    SUPPORTED_METHODS FIND_PACKAGE
)
