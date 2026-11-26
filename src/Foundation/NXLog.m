#include "NXString+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <stdarg.h>

// The size of the buffer on the stack in which a line is formatted. A longer line is
// formatted twice, once to find its length.
#define BUFFER_SIZE 128

///////////////////////////////////////////////////////////////////////////////
// GLOBALS

// How deeply each thread is logging. On a Pico, there's one thread per core.
#ifdef SYSTEM_NAME_PICO
#define CORES 2
static uint8_t depths[CORES];
#else
static __thread uint8_t depth = 0;
#endif

///////////////////////////////////////////////////////////////////////////////
// PRIVATE METHODS

// Returns a pointer to the depth of the calling thread
static inline uint8_t *current_depth(void) {
#ifdef SYSTEM_NAME_PICO
  uint8_t core = sys_thread_core();
  objc_assert(core < CORES);
  return &depths[core];
#else
  return &depth;
#endif
}

// Formats and writes a line, after a prefix
static size_t log_line(const char *prefix, NXString *format, va_list args) {
  uint8_t *depth = current_depth();
  if (*depth >= NXLogDepthMax) {
    return sys_printf("%s[NXLog] nested more than %d deep\n", prefix,
                      (int)NXLogDepthMax);
  }

  // Formatted before it's written, as a description may itself log, in a buffer of its
  // own, so that it's formatted once if it fits
  char buffer[BUFFER_SIZE];
  char *line = buffer;
  (*depth)++;
  size_t length = NXStringFormat(buffer, sizeof(buffer), format, args);
  if (length >= sizeof(buffer)) {
    line = length < SIZE_MAX ? sys_malloc(length + 1) : NULL;
    if (line != NULL) {
      NXStringFormat(line, length + 1, format, args);
    }
  }
  (*depth)--;
  if (line == NULL) {
    return 0;
  }
  size_t written = sys_printf("%s%s\n", prefix, line);
  if (line != buffer) {
    sys_free(line);
  }
  return written;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

size_t NXLog(NXString *format, ...) {
  va_list args;
  va_start(args, format);
  size_t written = log_line("", format, args);
  va_end(args);
  return written;
}

size_t NXLogv(NXString *format, va_list args) {
  return log_line("", format, args);
}

size_t _NXDebug(NXString *format, ...) {
  va_list args;
  va_start(args, format);
  size_t written = log_line("[DEBUG] ", format, args);
  va_end(args);
  return written;
}
