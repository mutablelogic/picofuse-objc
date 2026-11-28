# Prints the temperature sensor's reading whenever it changes, read every
# --interval, until it's interrupted. Built as examples/helloworld is.
cmake_minimum_required(VERSION 3.20)

set(PICOFUSE_PREFIX "/opt/picofuse" CACHE PATH "Prefix of the picofuse installation")
include("${PICOFUSE_PREFIX}/cmake/picofuse_objc.cmake")

project(temperature C)

picofuse_objc_executable(NAME temperature SOURCES main.m)
