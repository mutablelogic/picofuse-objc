# Prints whether the board's user button is pressed whenever it changes, until it's
# interrupted. Built as examples/helloworld is.
cmake_minimum_required(VERSION 3.20)

set(PICOFUSE_PREFIX "/opt/picofuse" CACHE PATH "Prefix of the picofuse installation")
include("${PICOFUSE_PREFIX}/cmake/picofuse_objc.cmake")

project(userbutton C)

picofuse_objc_executable(NAME userbutton SOURCES main.m)
