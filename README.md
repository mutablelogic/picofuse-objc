# picofuse-objc

Objective-C Framework for Picofuse

## Building

picofuse-objc is built against an installed copy of
[picofuse](https://github.com/mutablelogic/picofuse), and is installed into the
same place, so that the two make up one installation. That's `/opt/picofuse`,
unless you set `PREFIX` to another absolute path for both.

At present this builds and installs the Objective-C runtime, and the beginnings
of the Foundation framework:

* `lib/<target>/libpicofuse-objc-gcc.a` and `libpicofuse-objc-foundation.a`, with
  a `pkg-config` file for each in `lib/<target>/pkgconfig/`. `<target>` is the
  board, or the host (e.g. `darwin-arm64`)
* `include/runtime/` and `include/Foundation/` - their headers

### Mac

Requirements:

```sh
brew install cmake pkgconf gcc openssl@3 libusb
```

Install picofuse, then test and install this:

```sh
# In picofuse
make install

# In picofuse-objc
make test
make install
```

* This uses the latest version of GCC that Homebrew installed. Set
  `OBJC_COMPILER` for another.
* Apple's `clang` (and its `gcc` alias) can't be used: it doesn't support the
  GCC Objective-C runtime on a Mac.

### Linux

Requirements on Debian (tested with trixie), where `gobjc` is the Objective-C
compiler for GCC:

```sh
sudo apt install build-essential cmake git pkgconf gobjc libssl-dev libusb-1.0-0-dev
```

Install picofuse, then test and install this:

```sh
# In picofuse
make install

# In picofuse-objc
make test
make install
```

### Pico boards

Requirements, in addition to CMake and `pkg-config`:

* The Arm GNU Toolchain (`arm-none-eabi-gcc`), which compiles picofuse and
  links programs.
  On a Mac, `brew install --cask gcc-arm-embedded`
* Python 3, which the pico-sdk needs.
* The [LLVM Embedded Toolchain for Arm](https://github.com/ARM-software/LLVM-embedded-toolchain-for-Arm/releases),
  which compiles Objective-C: the Arm GNU Toolchain has no Objective-C compiler.
  It's expected in `/opt/LLVM-ET-Arm-19.1.5-Darwin-universal`

Install picofuse for the board, then this. For example, for a Pico 2 W:

```sh
# In picofuse
make PICO_BOARD=pico2_w BUILD_DIR=build-pico2_w install

# In picofuse-objc
make PICO_BOARD=pico2_w BUILD_DIR=build-pico2_w install
```

* Setting `PICO_BOARD` cross-compiles for that board.
* To flash and run the tests, connect the board through a debug probe, and use
  `make PICO_BOARD=pico2_w BUILD_DIR=build-pico2_w test`. This needs `openocd`,
  and the host installation of picofuse, for `testrunner`.
* If the LLVM toolchain is elsewhere, run
  `cmake -B <build directory> -D PICO_BOARD=<board> -D LLVM_ARM_TOOLCHAIN=<dir>`
  first.
* Use a separate build directory for each board.
* Use `pico` for the Pico, `pico_w` for the Pico W and `pico2` for the Pico 2.
