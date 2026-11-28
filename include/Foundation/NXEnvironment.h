/**
 * @file NXEnvironment.h
 * @brief Defines the NXEnvironment class, for the command line and the system.
 */
#pragma once

/**
 * @brief The command line, and what the program and the system it runs on are.
 * @ingroup Foundation
 *
 * Flags are parsed with picofuse's parser, as described by NXArgument objects:
 *
 * @code
 * NXEnvironment *environment = [NXEnvironment environmentWithArgc:argc argv:argv];
 * NXString *error = nil;
 * NXMap *values = [environment parseFlags:[NXArray arrayWithObjects:
 *     [NXArgument argumentWithName:@"verbose" short:@"v"],
 *     [NXArgument argumentWithName:@"count" short:@"n" default:[NXNumber numberWithInt32:3]],
 *     nil] error:&error];
 * @endcode
 *
 * picofuse has one parser for the process, so parsing is done one at a time, and
 * everything it returns is copied.
 *
 * \headerfile NXEnvironment.h Foundation/Foundation.h
 */
@interface NXEnvironment : NXObject {
@private
  int _argc;            ///< The number of arguments, including the program's name
  char **_argv;         ///< The arguments, which aren't copied
  NXArray *_arguments;  ///< What's left after the flags, from the last parse
}

/**
 * @brief Returns an environment for a command line.
 * @param argc The number of arguments, including the program's name.
 * @param argv The arguments, which must stay valid while it's used.
 */
+ (NXEnvironment *)environmentWithArgc:(int)argc argv:(char **)argv;

/**
 * @brief Initializes an environment for a command line.
 */
- (id)initWithArgc:(int)argc argv:(char **)argv;

/**
 * @brief Parses the flags on the command line.
 * @param flags The NXArgument flags which can be given.
 * @param error Set to why it couldn't parse, such as "unknown flag --x", or nil if it
 * doesn't matter.
 * @return The value of every flag, keyed by its long name: as it's given, or its
 * default. Or nil if a flag is unknown or a value isn't of its type. With nothing
 * after the program's name, it's every default, which is so on a Pico.
 */
- (NXMap *)parseFlags:(NXArray *)flags error:(NXString **)error;

/**
 * @brief Returns the NXString arguments after the flags, from the last parse, or an
 * empty array if there hasn't been one or it failed.
 */
- (NXArray *)arguments;

/**
 * @brief Returns the program's name.
 */
- (NXString *)name;

/**
 * @brief Returns the program's version, or nil.
 */
- (NXString *)version;

/**
 * @brief Returns the system, such as "darwin", "linux" or a Pico board's name.
 */
- (NXString *)system;

/**
 * @brief Returns the device's serial number, or nil.
 */
- (NXString *)serial;

@end
