/**
 * @file NXData.h
 * @brief Defines the NXData class, for bytes.
 */
#pragma once
#include "NXHashAlgorithm.h"
#include <stddef.h>
#include <stdint.h>

/**
 * @brief Bytes, which can be added to.
 * @ingroup Foundation
 *
 * The bytes can be any value, including zero. They're kept one after another in memory
 * from the zone of the data, which is twice as big when more room is needed.
 *
 * Any number of threads can read data at once, but while one changes it, no other thread can use it, and it doesn't lock itself. See \ref foundation_threads.
 *
 * \headerfile NXData.h Foundation/Foundation.h
 */
@interface NXData : NXObject {
@private
  uint8_t *_bytes;  ///< The bytes, or NULL if there's no room yet
  size_t _length;   ///< The number of bytes
  size_t _capacity; ///< The number of bytes there's room for
}

/**
 * @brief Returns empty data.
 */
+ (id)data;

/**
 * @brief Returns empty data with room for a number of bytes.
 * @return The data, or nil if there isn't enough memory.
 */
+ (id)dataWithCapacity:(size_t)capacity;

/**
 * @brief Returns a copy of some bytes.
 * @param bytes The bytes, or NULL if the length is zero.
 * @return The data, or nil if there isn't enough memory, or the bytes are NULL but the
 * length isn't zero.
 */
+ (id)dataWithBytes:(const void *)bytes length:(size_t)length;

/**
 * @brief Returns the bytes encoded in base64.
 * @param string The whole of it is base64, in the standard alphabet of RFC 4648, with or
 * without "=" padding. Nothing else is allowed, such as spaces or line breaks.
 * @return The data, or nil if it isn't base64 or there isn't enough memory.
 */
+ (id)dataWithBase64String:(NXString *)string;

/**
 * @brief Initializes empty data with room for a number of bytes.
 */
- (id)initWithCapacity:(size_t)capacity;

/**
 * @brief Initializes a copy of some bytes.
 */
- (id)initWithBytes:(const void *)bytes length:(size_t)length;

/**
 * @brief Initializes the bytes encoded in base64.
 */
- (id)initWithBase64String:(NXString *)string;

/**
 * @brief Returns the number of bytes.
 */
- (size_t)length;

/**
 * @brief Returns the number of bytes there's room for, before more memory is needed.
 */
- (size_t)capacity;

/**
 * @brief Returns the bytes, which are only valid until the data is changed or
 * deallocated, or NULL if there are none.
 */
- (const void *)bytes;

/**
 * @brief Adds bytes to the end.
 * @return YES if they were added, or NO if there isn't enough memory, or the bytes are
 * NULL but the length isn't zero.
 */
- (BOOL)appendBytes:(const void *)bytes length:(size_t)length;

/**
 * @brief Adds the bytes of other data to the end, which can be this data.
 * @return YES if they were added, or NO if there isn't enough memory.
 */
- (BOOL)appendData:(NXData *)data;

/**
 * @brief Returns the bytes encoded in base64, in the standard alphabet of RFC 4648 with
 * "=" padding, or nil if there isn't enough memory.
 */
- (NXString *)base64String;

/**
 * @brief Returns a hash of the bytes, as data.
 * @return The hash, or nil if it isn't available or there isn't enough memory. The
 * bytes are hashed where they are, without a copy.
 */
- (NXData *)hashWithAlgorithm:(NXHashAlgorithm)algorithm;

/**
 * @brief Returns YES if another object is data with the same bytes.
 */
- (BOOL)isEqual:(id)anObject;

/**
 * @brief Returns a hash of the bytes, which is the same for equal data.
 */
- (uintptr_t)hash;

/**
 * @brief Returns new data with the same bytes, or nil if there isn't enough memory. The
 * caller owns it and has to release it.
 */
- (id)copy;

/**
 * @brief Returns the bytes in hexadecimal, such as "<0a1b2c>".
 */
- (NXString *)description;

@end
