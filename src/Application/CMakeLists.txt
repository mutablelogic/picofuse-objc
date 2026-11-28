set(NAME "picofuse-objc-application")

add_library(${NAME} STATIC
    NXApplication.m
    NXApplicationMain.m
    NXPin.m
    NXAnalogInput.m
    NXRunLoop.m
    NXTimer.m
)
target_include_directories(${NAME} PUBLIC ${PROJECT_SOURCE_DIR}/include)
target_include_directories(${NAME} PRIVATE ${PROJECT_SOURCE_DIR}/src/Foundation)
target_link_libraries(${NAME} PUBLIC picofuse-objc-foundation PkgConfig::PICOFUSE_HID)

# Install alongside picofuse, for the same board or host
picofuse_objc_install(${NAME}
    DESCRIPTION "Objective-C Application framework"
    REQUIRES picofuse-objc-foundation picofuse-hid
    HEADERS Application
)
