/**
 * @file NXScanner.h
 * @brief Defines the NXScanner class, which reads tokens from a string or stream.
 */
#pragma once
#include <picofuse/sys.h>
#include <stddef.h>

/**
 * @brief Which tokens a scanner recognizes, besides runs of spaces, letters and digits.
 * @ingroup Foundation
 *
 * Combine them with |. Those such as NXScannerNumbersHex include the one they extend.
 *
 * \headerfile NXScanner.h Foundation/Foundation.h
 */
typedef enum {
  NXScannerNone = sys_scanner_none, ///< Only runs of spaces, letters and digits
  NXScannerEscapes = sys_scanner_escapes,   ///< Escapes such as \\n and \\u0041
  NXScannerNewlines = sys_scanner_newlines, ///< Line feeds, apart from other spaces
  NXScannerKeywords = sys_scanner_keywords, ///< Letters followed by letters and digits
  NXScannerKeywordsWithUnderscores =
      sys_scanner_keywords_withunderscores, ///< Keywords which can include _
  NXScannerKeywordsWithDashes =
      sys_scanner_keywords_withdashes,                  ///< Keywords which can include -
  NXScannerQuotesSingle = sys_scanner_quotes_single,     ///< Strings in '
  NXScannerQuotesDouble = sys_scanner_quotes_double,     ///< Strings in "
  NXScannerQuotes = sys_scanner_quotes,                  ///< Strings in ' or "
  NXScannerCommentsHash = sys_scanner_comments_hash,     ///< Comments from # to a line end
  NXScannerCommentsSlash = sys_scanner_comments_slash,   ///< Comments from // to a line end
  NXScannerComments = sys_scanner_comments,              ///< Comments from # or //
  NXScannerNumbers = sys_scanner_numbers,                ///< Integers, with a sign
  NXScannerNumbersOctal = sys_scanner_numbers_octal,     ///< And 0o17 or 017
  NXScannerNumbersBinary = sys_scanner_numbers_binary,   ///< And 0b101
  NXScannerNumbersHex = sys_scanner_numbers_hex,         ///< And 0x1F
  NXScannerNumbersFloat = sys_scanner_numbers_float,     ///< And 3.14 or 1e-3
  NXScannerDatesISO8601 = sys_scanner_dates_iso8601, ///< Dates such as 2026-09-06T11:37:05Z
  NXScannerDates = sys_scanner_dates,                ///< Dates in every format scanned
  NXScannerDurations = sys_scanner_durations,        ///< Durations such as 1h30m or 1.5s
} NXScannerFlags;

/**
 * @brief The class of a token.
 * @ingroup Foundation
 *
 * Punctuation, symbols, control characters and line feeds are one character each; the
 * others can be longer.
 *
 * \headerfile NXScanner.h Foundation/Foundation.h
 */
typedef enum {
  NXScannerClassOther = sys_scanner_other,     ///< Not one of the others, or no token
  NXScannerClassSpace = sys_scanner_space,     ///< Spaces
  NXScannerClassDigit = sys_scanner_digit,     ///< Digits
  NXScannerClassAlpha = sys_scanner_alpha,     ///< Letters
  NXScannerClassPunct = sys_scanner_punct,     ///< A punctuation character
  NXScannerClassSymbol = sys_scanner_symbol,   ///< A symbol, such as = or +
  NXScannerClassControl = sys_scanner_control, ///< A control character
  NXScannerClassEscape = sys_scanner_escape,   ///< An escape (NXScannerEscapes)
  NXScannerClassNewline = sys_scanner_newline, ///< A line feed (NXScannerNewlines)
  NXScannerClassKeyword = sys_scanner_keyword, ///< A keyword (NXScannerKeywords)
  NXScannerClassString = sys_scanner_string, ///< A string, with its quotes (NXScannerQuotes)
  NXScannerClassComment = sys_scanner_comment, ///< A comment (NXScannerComments)
  NXScannerClassNumber = sys_scanner_number,   ///< A number (NXScannerNumbers)
  NXScannerClassDate = sys_scanner_date,       ///< A date (NXScannerDates)
  NXScannerClassDuration = sys_scanner_duration, ///< A duration (NXScannerDurations)
} NXScannerClass;

/**
 * @brief Reads tokens, one at a time, from a string or a stream.
 * @ingroup Foundation
 *
 * The stream must have a position, as the scanner looks ahead and goes back. It starts at
 * the stream's position, and after each token the stream is just after it, so the stream
 * can be read between tokens, and the scanner carries on from wherever it is.
 *
 * A string which isn't closed by its quote runs to the end. It's only closed if it's at
 * least two bytes, ends with the quote it starts with, and that quote doesn't have an odd
 * number of backslashes before it, which would escape it. The stream shouldn't have a zero
 * byte, which picofuse doesn't scan correctly.
 *
 * Example:
 * @code
 * NXScanner *scanner = [NXScanner scannerWithString:@"x = 42"
 *                                             flags:NXScannerKeywords | NXScannerNumbers];
 * while ([scanner next]) {
 *   if ([scanner tokenClass] == NXScannerClassNumber) {
 *     ...
 *   }
 * }
 * @endcode
 *
 * \headerfile NXScanner.h Foundation/Foundation.h
 */
@interface NXScanner : NXObject {
@private
  NXStream *_stream;      ///< What's read
  sys_scanner_t _scanner; ///< The scanner of picofuse
  BOOL _scanned;          ///< Whether there's a token
}

/**
 * @brief Returns a scanner which reads a string.
 * @return The scanner, or nil if too many streams are open or there isn't enough memory.
 */
+ (id)scannerWithString:(NXString *)string flags:(NXScannerFlags)flags;

/**
 * @brief Returns a scanner which reads a stream, from its position.
 * @return The scanner, or nil if the stream doesn't have a position.
 */
+ (id)scannerWithStream:(NXStream *)stream flags:(NXScannerFlags)flags;

/**
 * @brief Initializes a scanner which reads a string.
 */
- (id)initWithString:(NXString *)string flags:(NXScannerFlags)flags;

/**
 * @brief Initializes a scanner which reads a stream, from its position.
 */
- (id)initWithStream:(NXStream *)stream flags:(NXScannerFlags)flags;

/**
 * @brief Returns the stream which is read.
 */
- (NXStream *)stream;

/**
 * @brief Moves to the next token.
 * @return YES if there is one, or NO at the end, or if the stream is closed.
 */
- (BOOL)next;

/**
 * @brief Returns the class of the token, or NXScannerClassOther if there isn't one.
 */
- (NXScannerClass)tokenClass;

/**
 * @brief Returns the token, or nil if there isn't one or there isn't enough memory. It
 * stops at a zero byte.
 */
- (NXString *)token;

/**
 * @brief Returns the length of the token in bytes, or zero if there isn't one.
 */
- (size_t)tokenLength;

/**
 * @brief Returns the number of characters in the token, or zero if there isn't one.
 */
- (size_t)tokenRuneCount;

/**
 * @brief Returns the position of the token in the stream, or NXNotFound if there isn't
 * one.
 */
- (size_t)tokenPosition;

@end
