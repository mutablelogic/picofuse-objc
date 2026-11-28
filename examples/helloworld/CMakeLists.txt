# Prints "Hello world", then quits. Built against an installation of picofuse
# and picofuse-objc, for the host:
#
#   cmake -B build && cmake --build build && build/helloworld
#
# or for a board, with -D PICO_BOARD=pico_w, when it's build/helloworld.elf.
# Set -D PICOFUSE_PREFIX if they're installed somewhere other than /opt/picofuse.
cmake_minimum_required(VERSION 3.20)

set(PICOFUSE_PREFIX "/opt/picofuse" CACHE PATH "Prefix of the picofuse installation")
include("${PICOFUSE_PREFIX}/cmake/picofuse_objc.cmake")

project(helloworld C)

picofuse_objc_executable(NAME helloworld SOURCES main.m)
