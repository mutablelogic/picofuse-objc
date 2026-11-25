#include "protocol.h"
#include "api.h"
#include "class.h"
#include <runtime/gcc/objc.h>
#include <picofuse/sys.h>
#include <string.h>

// Protocols whose class hasn't been set yet, linked through their class field:
// until it's set, all that's there is a version number from the compiler.
// Several may have the same name, as each module has its own copy of the
// protocols that it uses.
static objc_protocol_t *protocol_pending = NULL;

// The class of all protocols, once it's known
static Class protocol_class = Nil;

///////////////////////////////////////////////////////////////////////////////

void __objc_protocol_register(objc_protocol_t *p) {
  if (p == NULL || p->name == NULL) {
    return;
  }
#ifdef OBJCDEBUG
  sys_printf("__objc_protocol_register <%s>\n", p->name);
#endif
  if (protocol_class != Nil) {
    p->class = protocol_class;
  } else {
    for (objc_protocol_t *q = protocol_pending; q != NULL;
         q = (objc_protocol_t *)q->class) {
      if (q == p) {
        return; // Already registered
      }
    }
    p->class = (Class)protocol_pending;
    protocol_pending = p;
  }

  // Register the protocols it incorporates
  __objc_protocol_list_register(p->protocol_list);
}

void __objc_protocol_load() {
  protocol_class = objc_lookup_class("Protocol");
  while (protocol_pending != NULL) {
    objc_protocol_t *p = protocol_pending;
    protocol_pending = (objc_protocol_t *)p->class;
    p->class = protocol_class;
  }
}

void __objc_protocol_list_register(struct objc_protocol_list *list) {
  if (list == NULL) {
    return; // Nothing to register
  }
  for (size_t i = 0; i < list->count; i++) {
    objc_protocol_t *protocol = list->protocols[i];
    if (protocol != NULL && protocol->name != NULL) {
      __objc_protocol_register(protocol);
    }
  }
  if (list->next != NULL) {
    __objc_protocol_list_register(list->next); // Register next protocol list
  }
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

/**
 * @brief Returns the name of a protocol.
 */
const char *proto_getName(objc_protocol_t *protocol) {
  if (protocol == NULL || protocol->name == NULL) {
    return NULL; // Cannot get name of NULL protocol
  }
  return protocol->name; // Return the name of the protocol
}

/**
 * @brief Checks if a protocol conforms to another protocol.
 */
BOOL proto_conformsTo(objc_protocol_t *protocol,
                      objc_protocol_t *otherProtocol) {
  if (protocol == NULL || otherProtocol == NULL) {
    return NO; // Cannot check conformance with NULL protocols
  }
  // Check for same protocol
  if (protocol == otherProtocol) {
    return YES; // Protocols are the same
  }
  // Check for name
  if (strcmp(protocol->name, otherProtocol->name) == 0) {
    return YES; // Protocols are the same
  }
  // Check other protocols in the list
  struct objc_protocol_list *proto = protocol->protocol_list;
  while (proto != NULL) {
    for (size_t i = 0; i < proto->count; i++) {
      if (proto_conformsTo(proto->protocols[i], otherProtocol)) {
        return YES; // Found a matching protocol
      }
    }
    proto = proto->next; // Move to next protocol list
  }
  // No matching protocol found
  return NO;
}

/**
 * @brief Checks if a class conforms to a protocol.
 */
BOOL class_conformsTo(Class cls, objc_protocol_t *otherProtocol) {
  if (cls == Nil || otherProtocol == NULL) {
    return NO; // Cannot check conformance with Nil class or NULL protocol
  }

  // Check if the class implements the protocol directly
  struct objc_protocol_list *proto = cls->protocols;
  while (proto != NULL) {
    for (size_t i = 0; i < proto->count; i++) {
      if (proto_conformsTo(proto->protocols[i], otherProtocol)) {
        return YES; // Found a matching protocol
      }
    }
    proto = proto->next; // Move to next protocol list
  }

  // Get superclass and check if it conforms
  Class superclass = class_getSuperclass(cls);
  if (superclass != Nil) {
    return class_conformsTo(superclass, otherProtocol); // Check superclass
  }

  // Class does not conform to the protocol
  return NO;
}
