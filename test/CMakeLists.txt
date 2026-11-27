# On a board, a test is flashed and run with picofuse's testrunner, through a
# debug probe. It comes from the installation's host build.
if(CMAKE_CROSSCOMPILING)
    set(TESTRUNNER "${PICOFUSE_PREFIX}/bin/testrunner")
    pkg_get_variable(_platform picosdk platform)
    string(REGEX REPLACE "-.*$" "" _chip "${_platform}") # rp2350-arm-s => rp2350
endif()

# objc_executable(NAME SOURCES... [LIBRARIES <lib> ...])
#
# Builds a program against the Objective-C runtime and any other LIBRARIES.
function(objc_executable NAME)
    cmake_parse_arguments(_ARG "" "" "LIBRARIES" ${ARGN})
    picofuse_executable(
        NAME ${NAME}
        LIBRARIES picofuse-sys
        SOURCES ${_ARG_UNPARSED_ARGUMENTS}
    )
    target_link_libraries(${NAME} PRIVATE ${_ARG_LIBRARIES} picofuse-objc-gcc)

    # Constant strings are part of Foundation, so the tests have their own otherwise
    if(NOT "picofuse-objc-foundation" IN_LIST _ARG_LIBRARIES)
        target_compile_options(${NAME} PRIVATE
            $<$<COMPILE_LANGUAGE:OBJC>:-fconstant-string-class=TestString>)
    endif()
endfunction()

# objc_test_add(NAME COMMAND...)
#
# Registers a program with CTest, which runs COMMAND on a host.
function(objc_test_add NAME)
    if(CMAKE_CROSSCOMPILING)
        add_test(NAME ${NAME}
            COMMAND ${TESTRUNNER} --target target/${_chip}.cfg $<TARGET_FILE:${NAME}>)

        # There's only one board
        set_tests_properties(${NAME} PROPERTIES RESOURCE_LOCK board)
    else()
        add_test(NAME ${NAME} COMMAND ${ARGN})
    endif()
endfunction()

# objc_test(NAME SOURCES... [LIBRARIES <lib> ...])
#
# Builds a test, and registers it with CTest.
function(objc_test NAME)
    objc_executable(${NAME} ${ARGN})
    objc_test_add(${NAME} ${NAME})
endfunction()

# objc_panic_test(NAME MESSAGE SOURCES... [DEFINITIONS <name>=<value> ...]
#                 [LIBRARIES <lib> ...])
#
# As objc_test(), but the test has to panic, with a message that matches a regular
# expression. A program can only panic once, so there's one for each case, for which
# DEFINITIONS can be used to choose between those in the same source.
function(objc_panic_test NAME MESSAGE)
    cmake_parse_arguments(_ARG "" "" "DEFINITIONS;LIBRARIES" ${ARGN})
    objc_executable(${NAME} ${_ARG_UNPARSED_ARGUMENTS} LIBRARIES ${_ARG_LIBRARIES})
    target_compile_definitions(${NAME} PRIVATE ${_ARG_DEFINITIONS})

    # A host program which aborts always fails, whatever it printed, other than in a
    # shell
    objc_test_add(${NAME} sh -c "\"$<TARGET_FILE:${NAME}>\" || true")
    set_tests_properties(${NAME} PROPERTIES
        PASS_REGULAR_EXPRESSION "\\[PANIC\\] ${MESSAGE}")
endfunction()

# Print "hello, world" from a constant string.
objc_test(objc_001
    objc_001/main.m
    TestString.m
)

# +initialize is called once, superclass first, with the class as the receiver.
objc_test(objc_002
    objc_002/main.m
)

# Constant strings: length, contents and equality.
objc_test(objc_003
    objc_003/main.m
    TestString.m
)

# Instances: class, name, identity, and messages to nil.
objc_test(objc_004
    objc_004/main.m
    TestObject.m
)

# Instance variables, overriding methods, and calling super.
objc_test(objc_005
    objc_005/main.m
    TestObject.m
)

# Categories: adding methods to a class, including a root class.
objc_test(objc_006
    objc_006/main.m
    TestObject.m
    TestString.m
)

# A category replaces a method of its class, but not of the superclass.
objc_test(objc_007
    objc_007/main.m
    TestObject.m
)

# Class messages: to a returned class, and where method types conflict.
objc_test(objc_008
    objc_008/main.m
)

# Root classes, and looking up classes and superclasses by name.
objc_test(objc_009
    objc_009/main.m
)

# Whether classes and instances respond to selectors.
objc_test(objc_010
    objc_010/main.m
    TestObject.m
)

# Selector names, and the hidden _cmd argument.
objc_test(objc_011
    objc_011/main.m
)

# Type encodings.
objc_test(objc_012
    objc_012/main.m
)

# Instance variables which are bitfields, structs or of a forward class.
objc_test(objc_013
    objc_013/main.m
    TestObject.m
)

# A subclass without +initialize has its superclass's called for it.
objc_test(objc_014
    objc_014/main.m
)

# Adopting protocols, and objects of type id<protocol>.
objc_test(objc_015
    objc_015/main.m
    TestObject.m
)

# A class adopts a protocol in a category.
objc_test(objc_016
    objc_016/main.m
    TestObject.m
)

# Protocol objects: name, equality, and those which no class adopts.
objc_test(objc_017
    objc_017/main.m
)

# A protocol which incorporates another.
objc_test(objc_018
    objc_018/main.m
    TestObject.m
)

# Variable arguments, and statics within an implementation.
objc_test(objc_019
    objc_019/main.m
)

# The same protocol in more than one module.
objc_test(objc_020
    objc_020/main.m
    objc_020/other.m
)

# @synchronized within one thread: nesting, nil, and leaving the block early.
objc_test(objc_021
    objc_021/main.m
    TestObject.m
)

# @synchronized between two threads.
objc_test(objc_022
    objc_022/main.m
    TestObject.m
)

# Many classes, categories and methods.
objc_test(objc_023
    objc_023/main.m
)

# A category has a method of the same name as its class, but of different types.
objc_test(objc_024
    objc_024/main.m
    objc_024/wide.m
)

# Two threads send the first messages to classes at the same time.
objc_test(objc_025
    objc_025/main.m
)

# objc_getClassList: every class once, resolved.
objc_test(objc_026
    objc_026/main.m
)

###############################################################################
# Foundation

# Objects, with and without a default zone.
objc_test(foundation_001
    foundation_001/main.m
    LIBRARIES picofuse-objc-foundation
)

# Zones.
objc_test(foundation_002
    foundation_002/main.m
    LIBRARIES picofuse-objc-foundation
)

# Two threads using objects and a zone.
objc_test(foundation_003
    foundation_003/main.m
    LIBRARIES picofuse-objc-foundation
)

# Autorelease pools.
objc_test(foundation_004
    foundation_004/main.m
    LIBRARIES picofuse-objc-foundation
)

# Two threads, each with their own autorelease pools.
objc_test(foundation_005
    foundation_005/main.m
    LIBRARIES picofuse-objc-foundation
)

# Durations.
objc_test(foundation_006
    foundation_006/main.m
    LIBRARIES picofuse-objc-foundation
)

# Threads and cores.
objc_test(foundation_007
    foundation_007/main.m
    LIBRARIES picofuse-objc-foundation
)

# Numbers.
objc_test(foundation_008
    foundation_008/main.m
    LIBRARIES picofuse-objc-foundation
)

# Null.
objc_test(foundation_009
    foundation_009/main.m
    LIBRARIES picofuse-objc-foundation
)

# Floating point numbers which can't be integers.
foreach(_case nan inf minus_inf limit minus_limit)
    objc_panic_test(foundation_010_${_case}
        "-.NXNumberFloat64. value is out of range for an integer"
        foundation_010/main.m
        DEFINITIONS CASE_${_case}
        LIBRARIES picofuse-objc-foundation
    )
endforeach()

# Constant strings.
objc_test(foundation_011
    foundation_011/main.m
    LIBRARIES picofuse-objc-foundation
)

# Nothing other than a constant string refers to Foundation.
objc_test(foundation_012
    foundation_012/main.m
    LIBRARIES picofuse-objc-foundation
)

# Strings, and formats.
objc_test(foundation_013
    foundation_013/main.m
    LIBRARIES picofuse-objc-foundation
)

# Mutable strings.
objc_test(foundation_014
    foundation_014/main.m
    LIBRARIES picofuse-objc-foundation
)

# Descriptions.
objc_test(foundation_015
    foundation_015/main.m
    LIBRARIES picofuse-objc-foundation
)

# Comparing, searching and changing strings.
objc_test(foundation_016
    foundation_016/main.m
    LIBRARIES picofuse-objc-foundation
)

# Streams.
objc_test(foundation_017
    foundation_017/main.m
    LIBRARIES picofuse-objc-foundation
)

# Hashes of streams.
objc_test(foundation_018
    foundation_018/main.m
    LIBRARIES picofuse-objc-foundation
)

# Scanners.
objc_test(foundation_019
    foundation_019/main.m
    LIBRARIES picofuse-objc-foundation
)

# Dates.
objc_test(foundation_020
    foundation_020/main.m
    LIBRARIES picofuse-objc-foundation
)

# Numbers and strings from strings.
objc_test(foundation_021
    foundation_021/main.m
    LIBRARIES picofuse-objc-foundation
)

# Durations and dates from strings.
objc_test(foundation_022
    foundation_022/main.m
    LIBRARIES picofuse-objc-foundation
)

# Arrays.
objc_test(foundation_023
    foundation_023/main.m
    LIBRARIES picofuse-objc-foundation
)

# Hashes and copies.
objc_test(foundation_024
    foundation_024/main.m
    LIBRARIES picofuse-objc-foundation
)

# Maps.
objc_test(foundation_025
    foundation_025/main.m
    LIBRARIES picofuse-objc-foundation
)

# Logging.
objc_test(foundation_026
    foundation_026/main.m
    foundation_026/release.m
    LIBRARIES picofuse-objc-foundation
)

# Data.
objc_test(foundation_027
    foundation_027/main.m
    LIBRARIES picofuse-objc-foundation
)

# for...in loops over arrays and maps.
objc_test(foundation_028
    foundation_028/main.m
    LIBRARIES picofuse-objc-foundation
)

# Adding, removing or sorting objects in a for...in loop panics.
foreach(_case array_append array_remove array_remove_only array_sort map_add map_remove
              map_remove_only map_remove_rest)
    objc_panic_test(foundation_029_${_case}
        "Collection changed while it was being enumerated"
        foundation_029/main.m
        DEFINITIONS CASE_${_case}
        LIBRARIES picofuse-objc-foundation
    )
endforeach()

# NXArray subarrays, joining and sorting, and comparing numbers.
objc_test(foundation_030
    foundation_030/main.m
    LIBRARIES picofuse-objc-foundation
)

# Splitting strings by a separator, and into words.
objc_test(foundation_031
    foundation_031/main.m
    LIBRARIES picofuse-objc-foundation
)

# Locks, conditions, wait groups and atomics, across threads.
objc_test(foundation_032
    foundation_032/main.m
    LIBRARIES picofuse-objc-foundation
)

# Misusing a wait group panics.
objc_panic_test(foundation_033_done "-.NXWaitGroup done. the count is already zero"
    foundation_033/main.m
    DEFINITIONS CASE_done
    LIBRARIES picofuse-objc-foundation
)
objc_panic_test(foundation_033_add "-.NXWaitGroup add:. can't add -1"
    foundation_033/main.m
    DEFINITIONS CASE_add
    LIBRARIES picofuse-objc-foundation
)

# Arrays and maps used across threads in ways which aren't misuse.
objc_test(foundation_034
    foundation_034/main.m
    LIBRARIES picofuse-objc-foundation
)

# Arrays, maps, mutable strings and data changed by two threads at once, read while
# another thread changes them, or changed in the middle of a change, panic.
objc_panic_test(foundation_035_array_two_threads "-.NXArray insertObject:atIndex:. changed by two threads at once"
    foundation_035/main.m
    DEFINITIONS CASE_array_two_threads
    LIBRARIES picofuse-objc-foundation
)
objc_panic_test(foundation_035_array_read "-.NXArray count. used while another thread changes it"
    foundation_035/main.m
    DEFINITIONS CASE_array_read
    LIBRARIES picofuse-objc-foundation
)
objc_panic_test(foundation_035_array_nested "-.NXArray insertObject:atIndex:. changed while it was being changed"
    foundation_035/main.m
    DEFINITIONS CASE_array_nested
    LIBRARIES picofuse-objc-foundation
)
objc_panic_test(foundation_035_map_two_threads "-.NXMap setObject:forKey:. changed by two threads at once"
    foundation_035/main.m
    DEFINITIONS CASE_map_two_threads
    LIBRARIES picofuse-objc-foundation
)
objc_panic_test(foundation_035_map_read "-.NXMap objectForKey:. used while another thread changes it"
    foundation_035/main.m
    DEFINITIONS CASE_map_read
    LIBRARIES picofuse-objc-foundation
)
objc_panic_test(foundation_035_map_nested "-.NXMap removeObjectForKey:. changed while it was being changed"
    foundation_035/main.m
    DEFINITIONS CASE_map_nested
    LIBRARIES picofuse-objc-foundation
)
objc_panic_test(foundation_035_array_equal_other "-.NXArray isEqual:. used while another thread changes it"
    foundation_035/main.m
    DEFINITIONS CASE_array_equal_other
    LIBRARIES picofuse-objc-foundation
)
objc_panic_test(foundation_035_map_equal_other "-.NXMap isEqual:. used while another thread changes it"
    foundation_035/main.m
    DEFINITIONS CASE_map_equal_other
    LIBRARIES picofuse-objc-foundation
)
objc_panic_test(foundation_035_map_remove_all "-.NXMap removeAllObjects. changed by two threads at once"
    foundation_035/main.m
    DEFINITIONS CASE_map_remove_all
    LIBRARIES picofuse-objc-foundation
)
objc_panic_test(foundation_035_string_two_threads "-.NXMutableString appendCString:. changed by two threads at once"
    foundation_035/main.m
    DEFINITIONS CASE_string_two_threads
    LIBRARIES picofuse-objc-foundation
)
objc_panic_test(foundation_035_string_read "-.NXMutableString length. used while another thread changes it"
    foundation_035/main.m
    DEFINITIONS CASE_string_read
    LIBRARIES picofuse-objc-foundation
)
objc_panic_test(foundation_035_data_two_threads "-.NXData appendBytes:length:. changed by two threads at once"
    foundation_035/main.m
    DEFINITIONS CASE_data_two_threads
    LIBRARIES picofuse-objc-foundation
)
objc_panic_test(foundation_035_data_read "-.NXData length. used while another thread changes it"
    foundation_035/main.m
    DEFINITIONS CASE_data_read
    LIBRARIES picofuse-objc-foundation
)

# Archiving objects as JSON.
objc_test(foundation_036
    foundation_036/main.m
    LIBRARIES picofuse-objc-foundation
)

# Archiving objects as binary.
objc_test(foundation_037
    foundation_037/main.m
    LIBRARIES picofuse-objc-foundation
)

# +new, maps from arrays of objects and keys, and data from strings.
objc_test(foundation_038
    foundation_038/main.m
    LIBRARIES picofuse-objc-foundation
)
