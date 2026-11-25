#pragma once

#include "api.h"
#include <runtime/gcc/objc.h>

///////////////////////////////////////////////////////////////////////////////////
// TYPES

typedef struct objc_protocol objc_protocol_t;

///////////////////////////////////////////////////////////////////////////////////
// METHODS

/*
 * Sets the class of the protocols registered so far, so that they can be sent
 * messages. It can only be called once all classes have been registered.
 */
void __objc_protocol_load();

/*
 * Register a protocol, and those it incorporates, in the Objective-C runtime.
 */
void __objc_protocol_register(objc_protocol_t *protocol);

/*
 * Register protocols from a list of protocols
 */
void __objc_protocol_list_register(struct objc_protocol_list *list);
