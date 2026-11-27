set(NAME "picofuse-objc-gcc")

add_library(${NAME} STATIC
    category.c
    class.c
    enumeration.c
    hash.c
    init.m
    lock.c
    message.c
    module.c
    mutex.c
    Object.m
    Protocol.m
    protocol.c
    statics.c
)
target_include_directories(${NAME} PUBLIC ${PROJECT_SOURCE_DIR}/include)
target_link_libraries(${NAME} PUBLIC PkgConfig::PICOFUSE_SYS)

# PUBLIC, as everything which uses the runtime has to be compiled for it too
if(CMAKE_OBJC_COMPILER_ID MATCHES "Clang")
    set(OBJC_FLAGS -fobjc-runtime=gcc -fno-constant-cfstrings)
else()
    # Without -fobjc-exceptions, GCC doesn't accept @synchronized
    set(OBJC_FLAGS -fgnu-runtime -fobjc-exceptions)
endif()
target_compile_options(${NAME} PUBLIC "$<$<COMPILE_LANGUAGE:OBJC>:${OBJC_FLAGS}>")

# Install alongside picofuse, for the same board or host
picofuse_objc_install(${NAME}
    DESCRIPTION "Objective-C runtime"
    REQUIRES picofuse-sys
    CFLAGS ${OBJC_FLAGS}
    HEADERS runtime
)
