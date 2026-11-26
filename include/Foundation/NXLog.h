/**
 * @file NXLog.h
 * @brief Defines NXLog and NXDebug, which write formatted lines to the standard output.
 */
#pragma once
#include <stdarg.h>
#include <stddef.h>

/**
 * @brief How deeply logs can be nested, as when a description itself logs, after which a
 * line saying so is written instead.
 * @ingroup Foundation
 */
#define NXLogDepthMax 4

/**
 * @brief Writes a formatted line to the standard output.
 * @ingroup Foundation
 * @param format The format, as for +[NXString stringWithFormat:], which can include %@
 * for the description of an object and %t for a duration. A line feed is added.
 * @return The number of bytes written, or zero if there isn't enough memory.
 *
 * It's formatted before anything is written, so the description of an object can itself
 * log, and its line is written first. A line of up to 127 bytes is formatted once, but a
 * longer one is formatted twice, to find its length, so the descriptions in it are found
 * twice. Logs nested more than NXLogDepthMax deep, as when a description logs itself,
 * write a line saying so instead of recursing. Lines from threads at the same time aren't
 * mixed. Don't log from an interrupt.
 */
size_t NXLog(NXString *format, ...);

/**
 * @brief Writes a formatted line to the standard output, from arguments.
 * @ingroup Foundation
 */
size_t NXLogv(NXString *format, va_list args);

/**
 * @def NXDebug(format, ...)
 * @brief Writes a formatted line to the standard output, after "[DEBUG] ", in a debug
 * build.
 * @ingroup Foundation
 *
 * As NXLog, but in a release build, where NDEBUG is defined, it does nothing, and its
 * arguments aren't evaluated.
 */
#ifndef NDEBUG
/** @cond INTERNAL */
size_t _NXDebug(NXString *format, ...);
/** @endcond */
#define NXDebug(format, ...) _NXDebug(format, ##__VA_ARGS__)
#else
#define NXDebug(format, ...) ((void)0)
#endif
