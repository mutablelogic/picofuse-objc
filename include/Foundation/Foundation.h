/**
 * @file Foundation.h
 * @brief Foundation framework header
 * @defgroup Foundation Foundation Framework
 * @ingroup objc
 *
 * Foundational classes and types.
 */
#pragma once
#include <runtime/gcc/objc.h>

#if __OBJC__

// Forward Declaration of classes
@class NXAutoreleasePool;
@class NXMutableString;
@class NXNull;
@class NXNumber;
@class NXObject;
@class NXScanner;
@class NXStream;
@class NXString;
@class NXThread;
@class NXZone;

// Types
#include "NXComparisonResult.h"
#include "NXDuration.h"
#include "NXHashAlgorithm.h"
#include "NXNotFound.h"

// Class Definitions
#include "NXObject.h"
#include "NXAutoreleasePool.h"
#include "NXNull.h"
#include "NXNumber.h"
#include "NXString.h"
#include "NXConstantString.h"
#include "NXMutableString.h"
#include "NXStream.h"
#include "NXScanner.h"
#include "NXThread.h"
#include "NXZone.h"

#endif // __OBJC__
