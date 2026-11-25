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
@class NXNull;
@class NXNumber;
@class NXObject;
@class NXString;
@class NXThread;
@class NXZone;

// Types
#include "NXDuration.h"

// Class Definitions
#include "NXObject.h"
#include "NXAutoreleasePool.h"
#include "NXNull.h"
#include "NXNumber.h"
#include "NXString.h"
#include "NXConstantString.h"
#include "NXThread.h"
#include "NXZone.h"

#endif // __OBJC__
