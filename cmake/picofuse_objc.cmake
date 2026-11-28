# picofuse_objc.cmake: builds Objective-C programs against an installation of
# picofuse and picofuse-objc, for the host or a Pico board. Include it before
# project(), as it chooses the compiler, then call picofuse_objc_executable():
#
#   cmake_minimum_required(VERSION 3.20)
#   include(/opt/picofuse/cmake/picofuse_objc.cmake)
#   project(helloworld C)
#   picofuse_objc_executable(NAME helloworld SOURCES main.m)
#
# Configure with -D PICO_BOARD=<board> for a board (pico_w, pico2_w, ...), or
# without for the host. On a Mac, the host compiler is the latest GCC from
# Homebrew, as clang doesn't support the GCC Objective-C runtime there.

# The prefix this file is installed in, so the one to build against
get_filename_component(_picofuse_objc_prefix "${CMAKE_CURRENT_LIST_DIR}" DIRECTORY)
set(PICOFUSE_PREFIX "${_picofuse_objc_prefix}" CACHE PATH
    "Prefix of the picofuse and picofuse-objc installation")

# The board to build for, or else the host is built for
set(PICO_BOARD "" CACHE STRING "Pico board")

# LLVM Embedded Toolchain for Arm, which compiles for a board: the Arm GNU
# toolchain has no Objective-C compiler, but links, as picofuse is built against
# its C library
set(LLVM_ARM_TOOLCHAIN "/opt/LLVM-ET-Arm-19.1.5-Darwin-universal" CACHE PATH
    "LLVM Embedded Toolchain for Arm, used for Pico builds")

if(PICO_BOARD)
    set(CMAKE_SYSTEM_NAME Generic)
    set(CMAKE_SYSTEM_PROCESSOR arm)
    set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
    if(NOT CMAKE_C_COMPILER)
        set(CMAKE_C_COMPILER "${LLVM_ARM_TOOLCHAIN}/bin/clang")
        if(NOT EXISTS "${CMAKE_C_COMPILER}")
            message(FATAL_ERROR "${CMAKE_C_COMPILER} not found: set LLVM_ARM_TOOLCHAIN")
        endif()
    endif()
    set(CMAKE_C_COMPILER_TARGET arm-none-eabi)
    set(CMAKE_OBJC_COMPILER_TARGET arm-none-eabi)
elseif(CMAKE_HOST_APPLE AND NOT CMAKE_C_COMPILER)
    file(GLOB _picofuse_objc_gccs /opt/homebrew/bin/gcc-[0-9]* /usr/local/bin/gcc-[0-9]*)
    if(NOT _picofuse_objc_gccs)
        message(FATAL_ERROR "GCC not found: install it with Homebrew, or set CMAKE_C_COMPILER")
    endif()
    list(SORT _picofuse_objc_gccs COMPARE NATURAL)
    list(GET _picofuse_objc_gccs -1 CMAKE_C_COMPILER)
endif()

# picofuse_objc_executable(NAME <target>
#                          SOURCES <file> ...
#                          [LIBRARIES <lib> ...]
#                          [VERSION <version>])
#
# Builds SOURCES into <target> (<target>.elf for a board), linked against the
# Application framework, and so Foundation and the runtime, and any other
# installed LIBRARIES. NAME and VERSION are what the program reports as its name
# and version on a board. It's a macro, as the first call sets the compiler and
# linker up in the calling directory.
macro(picofuse_objc_executable)
    if(NOT _PICOFUSE_OBJC_READY)
        set(_PICOFUSE_OBJC_READY TRUE)

        # Objective-C is compiled by the same compiler as C, and GCC compiles it
        # as C89 otherwise
        set(CMAKE_OBJC_COMPILER "${CMAKE_C_COMPILER}")
        enable_language(OBJC)
        if(CMAKE_HOST_APPLE AND NOT CMAKE_CROSSCOMPILING AND CMAKE_OBJC_COMPILER_ID MATCHES "Clang")
            message(FATAL_ERROR "clang doesn't support the GCC Objective-C runtime on macOS: "
                "use GCC, e.g. -D CMAKE_C_COMPILER=gcc-16")
        endif()
        add_compile_options($<$<COMPILE_LANGUAGE:OBJC>:-std=gnu11>)

        # Link a board's programs with the Arm GNU toolchain. noexecstack, as the
        # linker warns otherwise about objects in its C library.
        if(CMAKE_CROSSCOMPILING)
            find_program(ARM_GNU_GCC arm-none-eabi-gcc REQUIRED)
            foreach(_picofuse_objc_lang C OBJC)
                set(CMAKE_${_picofuse_objc_lang}_LINK_EXECUTABLE
                    "\"${ARM_GNU_GCC}\" -Wl,-z,noexecstack <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")
            endforeach()
        endif()

        # picofuse's own, which finds the libraries for the board or host
        set(_picofuse_objc_executable "${PICOFUSE_PREFIX}/cmake/picofuse_executable.cmake")
        if(NOT EXISTS "${_picofuse_objc_executable}")
            message(FATAL_ERROR "picofuse isn't installed in ${PICOFUSE_PREFIX}: set PICOFUSE_PREFIX")
        endif()
        include("${_picofuse_objc_executable}")
    endif()
    _picofuse_objc_executable(${ARGN})
endmacro()

function(_picofuse_objc_executable)
    cmake_parse_arguments(_ARG "" "NAME;VERSION" "LIBRARIES;SOURCES" ${ARGN})
    if(NOT _ARG_NAME OR NOT _ARG_SOURCES)
        message(FATAL_ERROR "picofuse_objc_executable: NAME and SOURCES are required")
    endif()
    set(_version)
    if(_ARG_VERSION)
        set(_version VERSION ${_ARG_VERSION})
    endif()
    picofuse_executable(
        NAME ${_ARG_NAME}
        ${_version}
        LIBRARIES picofuse-objc-application ${_ARG_LIBRARIES}
        SOURCES ${_ARG_SOURCES}
    )
endfunction()
