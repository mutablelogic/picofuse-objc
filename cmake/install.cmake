# picofuse_objc_install(NAME DESCRIPTION <text>
#                       [REQUIRES <pkg> ...] [CFLAGS <flag> ...]
#                       [HEADERS <subdir-of-include> ...])
#
# Installs the static library NAME, its headers and its .pc file, using the same
# layout as picofuse: include/, and lib/<target>/ for the board or host. CFLAGS
# are what Objective-C code which uses the library has to be compiled with.
function(picofuse_objc_install NAME)
    cmake_parse_arguments(_ARG "" "DESCRIPTION" "REQUIRES;CFLAGS;HEADERS" ${ARGN})
    list(JOIN _ARG_REQUIRES " " _requires)
    list(JOIN _ARG_CFLAGS " " _cflags)
    set(_version "${PROGRAM_VERSION}")
    if(NOT _version)
        set(_version "0.0.0")
    endif()

    install(TARGETS ${NAME} ARCHIVE DESTINATION lib/${PICOFUSE_TARGET})
    foreach(_dir IN LISTS _ARG_HEADERS)
        install(DIRECTORY ${PROJECT_SOURCE_DIR}/include/${_dir}
            DESTINATION include
            FILES_MATCHING PATTERN "*.h")
    endforeach()

    set(_pc ${CMAKE_CURRENT_BINARY_DIR}/${NAME}.pc)
    file(WRITE ${_pc}
"prefix=\${pcfiledir}/../../..
libdir=\${prefix}/lib/${PICOFUSE_TARGET}
includedir=\${prefix}/include

Name: ${NAME}
Description: ${_ARG_DESCRIPTION} for ${PICOFUSE_TARGET}
Version: ${_version}
Requires: ${_requires}
Cflags: -I\${includedir} ${_cflags}
Libs: -L\${libdir} -l${NAME}
")
    install(FILES ${_pc} DESTINATION lib/${PICOFUSE_TARGET}/pkgconfig)
endfunction()
