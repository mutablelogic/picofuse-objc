#include "NXStream+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

@implementation NXScanner

///////////////////////////////////////////////////////////////////////////////
// LIFECYCLE

+ (id)scannerWithString:(NXString *)string flags:(NXScannerFlags)flags {
  return [[[self alloc] initWithString:string flags:flags] autorelease];
}

+ (id)scannerWithStream:(NXStream *)stream flags:(NXScannerFlags)flags {
  return [[[self alloc] initWithStream:stream flags:flags] autorelease];
}

- (id)initWithString:(NXString *)string flags:(NXScannerFlags)flags {
  NXStream *stream = [[NXStream alloc] initWithString:string];
  self = [self initWithStream:stream flags:flags];
  [stream release];
  return self;
}

- (id)initWithStream:(NXStream *)stream flags:(NXScannerFlags)flags {
  self = [super init];
  if (self == nil || stream == nil || [stream position] == NXNotFound) {
    [self release];
    return nil;
  }
  _stream = [stream retain];
  _scanner = sys_scanner_init([stream stream], (sys_scanner_flags_t)flags);
  _scanned = NO;
  return self;
}

- (void)dealloc {
  [_stream release];
  [super dealloc];
}

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

- (NXStream *)stream {
  return _stream;
}

- (NXScannerClass)tokenClass {
  return _scanned ? (NXScannerClass)_scanner.isa : NXScannerClassOther;
}

- (size_t)tokenLength {
  return _scanned ? _scanner.bytes : 0;
}

- (size_t)tokenRuneCount {
  return _scanned ? _scanner.runes : 0;
}

- (size_t)tokenPosition {
  return _scanned ? (size_t)_scanner.start : NXNotFound;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

- (BOOL)next {
  // The stream of picofuse is gone once it's closed
  _scanned = ![_stream isClosed] && sys_scanner_next(&_scanner);
  return _scanned;
}

- (NXString *)token {
  if (!_scanned || [_stream isClosed]) {
    return nil;
  }

  // Read it, and go back to where the stream was
  size_t position = [_stream position];
  NXString *token = nil;
  if ([_stream seek:_scanner.start relative:NO]) {
    token = [_stream readStringWithLength:_scanner.bytes];
  }
  [_stream seek:(ptrdiff_t)position relative:NO];
  return token;
}

@end
