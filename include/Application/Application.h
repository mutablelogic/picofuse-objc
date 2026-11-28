/**
 * @file Application.h
 * @brief Application framework header
 * @defgroup Application Application Framework
 * @ingroup objc
 *
 * An application, and the run loop which dispatches its events on one or more cores.
 */
#pragma once
#include <Foundation/Foundation.h>

#if __OBJC__

@class NXApplication;
@class NXRunLoop;
@class NXTimer;

#include "NXEvent.h"
#include "NXEventSource.h"
#include "NXRunLoop.h"
#include "NXApplication.h"
#include "NXTimer.h"
#include "NXPin.h"

#endif
