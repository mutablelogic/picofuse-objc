set(NAME "picofuse-objc-foundation")

add_library(${NAME} STATIC
    NXArray.m
    NXAutoreleasePool.m
    NXConstantString.m
    NXDate.m
    NXDuration.m
    NXLog.m
    NXMutableString.m
    NXNull.m
    NXNumber.m
    NXNumberFloat.m
    NXNumberInteger.m
    NXNumberStatic.m
    NXObject.m
    NXScanner.m
    NXStream.m
    NXString.m
    NXThread.m
    NXZone.m
)
target_include_directories(${NAME} PUBLIC ${PROJECT_SOURCE_DIR}/include)
target_link_libraries(${NAME} PUBLIC picofuse-objc-gcc)

# PUBLIC, as everything which uses Foundation has its constant strings
set(OBJC_FLAGS -fconstant-string-class=NXConstantString)
target_compile_options(${NAME} PUBLIC "$<$<COMPILE_LANGUAGE:OBJC>:${OBJC_FLAGS}>")

# The class of constant strings is only referred to by name, when they're compiled by
# clang, so the linker has to be told that it's needed. Symbols have another underscore on
# a Mac.
set(LINK_FLAGS "-Wl,-u,__objc_class_name_NXConstantString")
if(APPLE)
    set(LINK_FLAGS "-Wl,-u,___objc_class_name_NXConstantString")
endif()
target_link_options(${NAME} INTERFACE ${LINK_FLAGS})

# Install alongside picofuse, for the same board or host
picofuse_objc_install(${NAME}
    DESCRIPTION "Objective-C Foundation framework"
    REQUIRES picofuse-objc-gcc
    CFLAGS ${OBJC_FLAGS}
    LIBS ${LINK_FLAGS}
    HEADERS Foundation
)
