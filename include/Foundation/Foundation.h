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
@class NXNumber;
@class NXObject;
@class NXThread;
@class NXZone;

// Types
#include "NXDuration.h"

// Class Definitions
#include "NXObject.h"
#include "NXAutoreleasePool.h"
#include "NXNumber.h"
#include "NXThread.h"
#include "NXZone.h"

#endif // __OBJC__
