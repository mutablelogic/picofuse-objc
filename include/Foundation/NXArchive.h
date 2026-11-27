/**
 * @file NXArchive.h
 * @brief Defines the NXArchive class and the NXArchiving protocol, for writing objects
 * out and reading them back in.
 */
#pragma once
#include <stdint.h>

/**
 * @brief The formats of an archive.
 * @ingroup Foundation
 */
typedef enum {
  NXArchiveFormatJSON,   ///< JSON, with keys, and no classes unless they differ
  NXArchiveFormatBinary, ///< Values in order, little-endian, with a hash of each class
} NXArchiveFormat;

@class NXArchive;

/**
 * @brief Objects which can be written to an archive and read back.
 * @ingroup Foundation
 *
 * NXString, NXNumber, NXNull, NXArray, NXMap, NXData and NXDate can be archived as
 * well, without adopting it, as JSON's own types.
 *
 * \headerfile NXArchive.h Foundation/Foundation.h
 */
@protocol NXArchiving

/**
 * @brief Writes the object's values to an archive, with the encode methods.
 * @return YES, or NO if it couldn't, which fails the archive.
 */
- (BOOL)encodeWithArchive:(NXArchive *)archive;

/**
 * @brief Initializes an object from an archive, with the decode methods.
 * @return The object, or nil if it couldn't, which fails the archive. Check
 * -[NXArchive failed] once the values are decoded, and return nil if it has.
 */
- (id)initWithArchive:(NXArchive *)archive;

@end

/**
 * @brief Writes objects out as JSON or binary, and reads them back.
 * @ingroup Foundation
 *
 * The code which decodes says which class it expects, as with Go's json.Unmarshal, so
 * the JSON is what would be written by hand: an object which adopts NXArchiving is a
 * JSON object of its keys, and strings, numbers, null, arrays and maps are JSON's own.
 * Data is a base64 string, and a date an ISO 8601 string. A map's keys have to be
 * strings, and they're written in order.
 *
 * Objects are written as a tree: one which is reached twice is written twice, and the
 * maximum depth stops a cycle. The first error sticks: after it, encoding and decoding
 * do nothing and give zero or nil, and failed and failure say what it was. JSON is
 * read whole before anything is decoded, as keys can be in any order. A string with a
 * \\u escape of a UTF-16 surrogate pair can't be read. Floating point numbers are written
 * with picofuse's printf, which writes 9 significant digits at most, so a float32 reads
 * back as it was, but a float64 only to 9 digits.
 *
 * Binary starts with "PF" and a version, which is 1. It has no keys: values are read
 * back in the order they were written, so decode
 * the same types, in the same order, as were encoded. Numbers are little-endian, and
 * floating point numbers are exact. Each object starts with a 32-bit FNV-1a hash of its
 * class's name, which is checked when it's read, so a subclass is read as itself. The
 * classes which adopt NXArchiving are found the first time one is read, and if two of
 * their names have the same hash, it panics. Renaming a class changes its hash, so
 * archives written before can't be read. Lengths are checked against the maximum
 * before anything is allocated.
 *
 * \headerfile NXArchive.h Foundation/Foundation.h
 */
@interface NXArchive : NXObject {
@private
  NXStream *_stream;  ///< What's written to
  BOOL _encoding;     ///< YES for an encoder
  unsigned _indent;   ///< Spaces for each level, or zero for one line
  unsigned _maxDepth; ///< The deepest objects can be nested
  size_t _maxLength;  ///< The longest a string, array or map can be, when decoding
  NXString *_failure; ///< The first error, or nil
  void *_levels;      ///< Where the encoder is, at each level
  unsigned _depth;    ///< How deep the encoder or decoder is
  Class _class;       ///< The class to write as "@class" in the next object, or Nil
  id _root;           ///< What was read, for a decoder
  id _current;        ///< The map whose keys are being decoded, or the root
  BOOL _read;         ///< YES once the decoder has read the stream
  NXArchiveFormat _format; ///< JSON or binary
  BOOL _top;          ///< YES once the value at the top of a binary archive is done
}

/**
 * @brief Returns a new archive which writes JSON to a stream.
 * @param stream The stream, which it writes to as values are encoded.
 * @param indent The number of spaces for each level, or zero to write one line.
 */
+ (id)JSONEncoderWithStream:(NXStream *)stream indent:(unsigned)indent;

/**
 * @brief Returns a new archive which reads JSON from a stream. It reads all of it when
 * the first value is decoded, so limits can be set first.
 */
+ (id)JSONDecoderWithStream:(NXStream *)stream;

/**
 * @brief Returns a new archive which writes binary to a stream.
 */
+ (id)binaryEncoderWithStream:(NXStream *)stream;

/**
 * @brief Returns a new archive which reads binary from a stream, as each value is
 * decoded.
 */
+ (id)binaryDecoderWithStream:(NXStream *)stream;

/**
 * @brief Writes an object to a stream, on one line.
 * @return YES, or NO if it couldn't be written.
 */
+ (BOOL)encodeObject:(id)object toStream:(NXStream *)stream format:(NXArchiveFormat)format;

/**
 * @brief Reads an object of a class, or a subclass, from a stream.
 * @param cls The class, or Nil for whatever is there, as maps, arrays, strings and
 * numbers.
 * @param stream The stream to read from.
 * @param format The format of the stream.
 * @return The object, or nil if it couldn't be read or isn't of the class.
 */
+ (id)decodeObjectOfClass:(Class)cls
               fromStream:(NXStream *)stream
                   format:(NXArchiveFormat)format;

/**
 * @brief Returns the format.
 */
- (NXArchiveFormat)format;

/**
 * @brief Returns YES if it writes, or NO if it reads.
 */
- (BOOL)isEncoding;

/**
 * @brief Returns YES if there's been an error.
 */
- (BOOL)failed;

/**
 * @brief Returns what the first error was, or nil if there hasn't been one.
 */
- (NXString *)failure;

/**
 * @brief Sets the deepest that objects can be nested, which is 32 to start with. Set
 * it before the first value is encoded or decoded.
 */
- (void)setMaximumDepth:(unsigned)depth;

/**
 * @brief Sets the longest, in bytes or objects, that a string, array or map which is
 * read can be. There's no limit to start with. Set it before the first value is
 * decoded.
 */
- (void)setMaximumLength:(size_t)length;

/**
 * @brief Writes a value. The key names it in a JSON object; it's nil for the value
 * which is the whole archive.
 * @return YES, or NO if the archive has failed.
 */
- (BOOL)encodeBool:(BOOL)value forKey:(NXString *)key;
- (BOOL)encodeInt32:(int32_t)value forKey:(NXString *)key;            ///< \copydoc encodeBool:forKey:
- (BOOL)encodeInt64:(int64_t)value forKey:(NXString *)key;            ///< \copydoc encodeBool:forKey:
- (BOOL)encodeUnsignedInt32:(uint32_t)value forKey:(NXString *)key;   ///< \copydoc encodeBool:forKey:
- (BOOL)encodeUnsignedInt64:(uint64_t)value forKey:(NXString *)key;   ///< \copydoc encodeBool:forKey:
- (BOOL)encodeFloat32:(float)value forKey:(NXString *)key;            ///< Not a number or infinity fails
- (BOOL)encodeFloat64:(double)value forKey:(NXString *)key;           ///< Not a number or infinity fails

/**
 * @brief Writes an object, which is nil, NXNull, a string, number, array, map, data or
 * date, or adopts NXArchiving.
 * @return YES, or NO if the archive has failed, or the object can't be archived.
 */
- (BOOL)encodeObject:(id)object forKey:(NXString *)key;

/**
 * @brief As encodeObject:forKey:, but if the object is of a subclass of a class, the
 * JSON object says which, as "@class", so it's decoded as that.
 */
- (BOOL)encodeObject:(id)object asClass:(Class)cls forKey:(NXString *)key;

/**
 * @brief Returns YES if the JSON object being decoded has a key. It's always YES for
 * binary, which has no keys.
 */
- (BOOL)containsKey:(NXString *)key;

/**
 * @brief Reads a value. The key is nil for the value which is the whole archive.
 * @return The value, or zero if there's no such key, or it's null. If it's of another
 * type, or out of range, the archive fails, and it's zero.
 */
- (BOOL)decodeBoolForKey:(NXString *)key;
- (int32_t)decodeInt32ForKey:(NXString *)key;           ///< \copydoc decodeBoolForKey:
- (int64_t)decodeInt64ForKey:(NXString *)key;           ///< \copydoc decodeBoolForKey:
- (uint32_t)decodeUnsignedInt32ForKey:(NXString *)key;  ///< \copydoc decodeBoolForKey:
- (uint64_t)decodeUnsignedInt64ForKey:(NXString *)key;  ///< \copydoc decodeBoolForKey:
- (float)decodeFloat32ForKey:(NXString *)key;           ///< \copydoc decodeBoolForKey:
- (double)decodeFloat64ForKey:(NXString *)key;          ///< \copydoc decodeBoolForKey:

/**
 * @brief Reads an object of a class, or of a subclass if the JSON names one with
 * "@class".
 * @param cls The class, or Nil for whatever is there.
 * @param key The key, or nil for the value which is the whole archive.
 * @return The object, or nil if there's no such key, or it's null. If it isn't of the
 * class, the archive fails, and it's nil.
 */
- (id)decodeObjectOfClass:(Class)cls forKey:(NXString *)key;

/**
 * @brief Reads an array whose objects are of a class, as decodeObjectOfClass:forKey:
 * reads each. A null in the array is NXNull.
 */
- (NXArray *)decodeArrayOfClass:(Class)cls forKey:(NXString *)key;

/**
 * @brief Reads a map whose objects are of a class, as decodeObjectOfClass:forKey:
 * reads each. Its keys are strings.
 */
- (NXMap *)decodeMapOfClass:(Class)cls forKey:(NXString *)key;

@end
