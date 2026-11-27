cmake_minimum_required(VERSION 3.20)

# Where picofuse is installed (its `make install PREFIX=...`)
set(PICOFUSE_PREFIX "/opt/picofuse" CACHE PATH "Prefix of the picofuse installation")

# The board to build for (e.g. pico2_w), or else the host is built for
set(PICO_BOARD "" CACHE STRING "Pico board")

# LLVM Embedded Toolchain for Arm, which compiles for a Pico: the Arm GNU
# toolchain has no Objective-C compiler.
set(LLVM_ARM_TOOLCHAIN "/opt/LLVM-ET-Arm-19.1.5-Darwin-universal" CACHE PATH
    "LLVM Embedded Toolchain for Arm, used for Pico builds")

# Cross-compile for a board. This has to happen before project(), which checks
# that the compiler works.
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
endif()

project(picofuse-objc C)

# Objective-C is compiled by the same compiler as C
set(CMAKE_OBJC_COMPILER "${CMAKE_C_COMPILER}" CACHE FILEPATH "Objective-C compiler")
enable_language(OBJC)

if(APPLE AND CMAKE_OBJC_COMPILER_ID MATCHES "Clang")
    message(FATAL_ERROR "clang doesn't support the GCC Objective-C runtime on macOS: "
        "use GCC, e.g. -D CMAKE_C_COMPILER=gcc-16")
endif()

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE Release CACHE STRING "Build type" FORCE)
endif()

# picofuse. This also makes the libraries for the board or host known to
# pkg-config.
set(_picofuse "${PICOFUSE_PREFIX}/cmake/picofuse_executable.cmake")
if(NOT EXISTS "${_picofuse}")
    message(FATAL_ERROR "picofuse isn't installed in ${PICOFUSE_PREFIX}: set PICOFUSE_PREFIX")
endif()
include("${_picofuse}")
if(NOT PICOFUSE_TARGET)
    message(FATAL_ERROR "picofuse in ${PICOFUSE_PREFIX} is an older installation, "
        "without lib/<target>: run make install in picofuse again")
endif()
find_package(PkgConfig REQUIRED)
pkg_check_modules(PICOFUSE_SYS REQUIRED IMPORTED_TARGET picofuse-sys)

# Link Pico programs with the Arm GNU toolchain, as picofuse is compiled against
# its C library and its linker flags are for GNU ld. LLVM only compiles.
#
# noexecstack, as otherwise the linker warns about objects in the C library which
# don't say whether they need an executable stack, unlike those from LLVM. It
# only changes a marker in the .elf, which nothing on a Pico reads.
if(CMAKE_CROSSCOMPILING)
    find_program(ARM_GNU_GCC arm-none-eabi-gcc REQUIRED)
    foreach(_lang C OBJC)
        set(CMAKE_${_lang}_LINK_EXECUTABLE
            "\"${ARM_GNU_GCC}\" -Wl,-z,noexecstack <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")
    endforeach()
endif()

# Compile options. GCC compiles Objective-C as C89 otherwise, and not C as it
# does .c files. (CMake doesn't know that, so CMAKE_OBJC_STANDARD has no effect.)
add_compile_options(-Wall -Wextra $<$<COMPILE_LANGUAGE:OBJC>:-std=gnu11>)

# Install rules
include(${CMAKE_CURRENT_LIST_DIR}/cmake/install.cmake)

# Objective-C runtime
add_subdirectory(src/runtime/gcc)

# Foundation
add_subdirectory(src/Foundation)

# Application
add_subdirectory(src/Application)

# Tests
include(CTest)
add_subdirectory(test)
