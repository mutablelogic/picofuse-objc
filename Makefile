# Build directory, and the prefix that picofuse is installed in, which this is
# also installed into
BUILD_DIR ?= build
PREFIX ?= /opt/picofuse
CMAKE_BUILD_TYPE ?= Release

# Tools
CMAKE ?= $(shell which cmake 2>/dev/null)
GIT ?= $(shell which git 2>/dev/null)
DOCKER ?= $(shell which docker 2>/dev/null)

# On a Mac, the host compiler has to be GCC: use the latest from Homebrew. For a
# board, the compiler is chosen by CMakeLists.txt.
ifeq ($(shell uname -s)$(PICO_BOARD),Darwin)
OBJC_COMPILER ?= $(lastword $(sort $(wildcard /opt/homebrew/bin/gcc-[0-9]* /usr/local/bin/gcc-[0-9]*)))
endif

# Determine the program version from git tags or commit hash
PROGRAM_VERSION ?= $(shell \
	if test -x "${GIT}"; then \
		${GIT} describe --tags --exact-match 2>/dev/null || \
		${GIT} rev-parse --short HEAD 2>/dev/null; \
	fi)

###############################################################################
# CONFIGURE AND BUILD

.PHONY: build
build: configure
	@${CMAKE} --build ${BUILD_DIR} --target all -j 8

.PHONY: configure
configure: dep-cmake
	@${CMAKE} -B ${BUILD_DIR} \
		-D CMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} \
		-D PICOFUSE_PREFIX=${PREFIX} \
		$(if ${OBJC_COMPILER},-D CMAKE_C_COMPILER=${OBJC_COMPILER}) \
		$(if ${PROGRAM_VERSION},-D PROGRAM_VERSION=${PROGRAM_VERSION}) \
		$(if ${PICO_BOARD},-D PICO_BOARD=${PICO_BOARD})

.PHONY: test
test: build
	@${CMAKE} --build ${BUILD_DIR} --target test

###############################################################################
# INSTALL

.PHONY: install
install: build
	@${CMAKE} --install ${BUILD_DIR} --prefix ${PREFIX}

###############################################################################
# CLEAN

.PHONY: clean
clean:
	@rm -rf ${BUILD_DIR}

###############################################################################
# DOCUMENTATION

.PHONY: doc
doc: dep-docker
	@echo
	@echo make doc
	@${DOCKER} run -v .:/data greenbone/doxygen doxygen /data/doxygen/Doxyfile

###############################################################################
# DEPENDENCIES

.PHONY: dep-cmake
dep-cmake:
	@test -f "${CMAKE}" && test -x "${CMAKE}" || (echo "Missing CMAKE: ${CMAKE}" && exit 1)

.PHONY: dep-docker
dep-docker:
	@test -f "${DOCKER}" && test -x "${DOCKER}" || (echo "Missing DOCKER: ${DOCKER}" && exit 1)
