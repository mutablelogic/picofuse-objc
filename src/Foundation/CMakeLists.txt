set(NAME "picofuse-objc-foundation")

add_library(${NAME} STATIC
    NXAutoreleasePool.m
    NXObject.m
    NXZone.m
)
target_include_directories(${NAME} PUBLIC ${PROJECT_SOURCE_DIR}/include)
target_link_libraries(${NAME} PUBLIC picofuse-objc-gcc)

# Install alongside picofuse, for the same board or host
picofuse_objc_install(${NAME}
    DESCRIPTION "Objective-C Foundation framework"
    REQUIRES picofuse-objc-gcc
    HEADERS Foundation
)
