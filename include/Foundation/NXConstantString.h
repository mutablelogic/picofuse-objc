/**
 * @file NXConstantString.h
 * @brief Defines the NXConstantString class, for constant strings.
 */
#pragma once

/**
 * @brief The class of constant strings, such as `@"string"`.
 * @ingroup Foundation
 *
 * The compiler makes these, so they aren't allocated or deallocated. Nothing other than
 * the compiler needs to refer to this class: use NXString.
 *
 * \headerfile NXConstantString.h Foundation/Foundation.h
 */
@interface NXConstantString : NXString {
@private
  // The compiler lays these out, so there can't be any others, either here or in a
  // superclass
  const char *_data;
  unsigned int _length;
}
@end

#ifdef __clang__
@compatibility_alias NSString NXConstantString;
#endif
