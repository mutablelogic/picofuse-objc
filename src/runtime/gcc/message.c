#include "api.h"
#include "category.h"
#include "class.h"
#include "hash.h"
#include "lock.h"
#include "protocol.h"
#include "statics.h"
#include <runtime/gcc/objc.h>
#include <picofuse/sys.h>

///////////////////////////////////////////////////////////////////////////////

// This function is called when a message is sent to a nil object.
static id __objc_nil_method(id receiver, SEL selector OBJC_UNUSED) {
  return receiver;
}

static IMP __objc_msg_lookup(objc_class_t *cls, SEL selector) {
  if (cls == Nil || selector == NULL) {
    return NULL; // Invalid parameters
  }

  // TODO: Initialize the dispatch table for the class if it doesn't exist
  // Consider mutex in multi-threaded environment
  // TODO: Lookup selector->sel_id in the dispatch table first
  // If found, return the IMP directly

#ifdef OBJCDEBUG
  sys_printf("objc_msg_lookup %c[%s %s]\n",
             cls->info & objc_class_flag_meta ? '+' : '-', cls->name,
             sel_getName(selector));
#endif

  // Descend through the classes looking for the method
  // TODO: Also look at the categories of the class
  while (cls != Nil) {
#ifdef OBJCDEBUG
    sys_printf("  %c[%s %s] types=%s\n",
               cls->info & objc_class_flag_meta ? '+' : '-', cls->name,
               sel_getName(selector), selector->sel_type);
#endif
    struct objc_method *method =
        __objc_hash_lookup(cls, selector->sel_id, selector->sel_type);
    if (method != NULL) {
      // Consider mutex in multi-threaded environment
      // TODO: Lookup selector->sel_id in the dispatch table first
      // If found, return the IMP directly
      return method->imp; // Return the implementation pointer
    }
    cls = cls->superclass;
  }

  return NULL; // Method not found
}

// A class which is being sent +initialize, and the thread that's doing that
struct objc_initializing {
  objc_class_t *cls;
  uintptr_t owner;
  struct objc_initializing *next;
};

// Those at present, which are on the stacks of their threads
static struct objc_initializing *initializing = NULL;

// Returns the thread which is sending +initialize to a class or one of its
// superclasses, or zero
static uintptr_t __objc_initialize_owner(objc_class_t *cls) {
  for (; cls != Nil; cls = cls->superclass) {
    for (struct objc_initializing *node = initializing; node != NULL;
         node = node->next) {
      if (node->cls == cls) {
        return node->owner;
      }
    }
  }
  return 0;
}

// Returns YES if a class has been initialized, and marks it as such if it and all of
// its superclasses have been sent +initialize. A superclass may not have been if it's
// its +initialize which sent a message to this class.
static BOOL __objc_initialized(objc_class_t *cls) {
  unsigned long *info = &cls->metaclass->info;
  if (__objc_flag_test(info, objc_class_flag_initialized)) {
    return YES;
  }
  if (!__objc_flag_test(info, objc_class_flag_initialize_sent)) {
    return NO;
  }
  if (cls->superclass != Nil && !__objc_initialized(cls->superclass)) {
    return NO;
  }
  __objc_flag_set(info, objc_class_flag_initialized);
  return YES;
}

// Begin to send +initialize to a class, and return YES, unless it's already been
// done, or is being done by this thread, in which case the class can be used. If
// another thread is doing it, wait until that's done.
static BOOL __objc_initialize_begin(struct objc_initializing *node,
                                    objc_class_t *cls) {
  uintptr_t self = __objc_thread_self();
  for (;;) {
    __objc_lock();
    if (__objc_initialized(cls)) {
      __objc_unlock();
      return NO;
    }
    BOOL sent = __objc_flag_test(&cls->metaclass->info,
                                 objc_class_flag_initialize_sent);
    uintptr_t owner = 0;
    for (struct objc_initializing *n = initializing; n != NULL; n = n->next) {
      if (n->cls == cls) {
        owner = n->owner;
        break;
      }
    }
    if (sent) {
      owner = __objc_initialize_owner(cls);
    } else if (owner == 0) {
      node->cls = cls;
      node->owner = self;
      node->next = initializing;
      initializing = node;
      __objc_unlock();
      return YES;
    }
    __objc_unlock();
    if (owner == self) {
      return NO;
    }
    __objc_lock_wait();
  }
}

// Record that a class has been sent +initialize
static void __objc_initialize_end(struct objc_initializing *node) {
  __objc_lock();
  struct objc_initializing **link = &initializing;
  while (*link != node) {
    link = &(*link)->next;
  }
  *link = node->next;
  __objc_flag_set(&node->cls->metaclass->info, objc_class_flag_initialize_sent);
  __objc_initialized(node->cls);
  __objc_unlock();
}

// Send +initialize to a class (not a metaclass), and to its superclasses
// before it, if that hasn't already been done. Whether it's been done is
// recorded in the metaclass. The runtime isn't locked meanwhile, so that
// +initialize can wait for other threads.
static void __objc_send_initialize(objc_class_t *cls) {
  if (cls == Nil || cls->metaclass == Nil ||
      __objc_flag_test(&cls->metaclass->info, objc_class_flag_initialized)) {
    return;
  }

  // Superclass first
  __objc_send_initialize(cls->superclass);

  struct objc_initializing node;
  if (!__objc_initialize_begin(&node, cls)) {
    return;
  }

  // Find and call the initialize method. The selector has no type encoding,
  // so that it matches whatever the size of a pointer is: the encoding
  // includes the offsets of the arguments.
  static struct objc_selector initialize = {
      .sel_id = "initialize", // The selector for the initialize method
      .sel_type = NULL,
  };
  IMP imp = __objc_msg_lookup(cls->metaclass, &initialize);
  if (imp != NULL) {
    // Call the initialize method - suppress function cast warning as this is a
    // legitimate cast from variadic IMP to non-variadic function for
    // +initialize which takes no parameters
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wcast-function-type"
    ((void (*)(id, SEL))imp)(
        (id)cls, &initialize); // Call the initialize method on the class
#pragma GCC diagnostic pop
  }

  __objc_initialize_end(&node);
}

// Load the protocols, static instances and categories, before any message is sent
static void __objc_load(void) {
  static unsigned long loaded = NO;
  if (__objc_flag_test(&loaded, YES)) {
    return;
  }
  __objc_lock();
  if (!loaded) {
    __objc_protocol_load();
    __objc_statics_load();
    __objc_category_load();
    __objc_flag_set(&loaded, YES);
  }
  __objc_unlock();
}

/**
 * Message dispatch function. Returns the implementation pointer for
 * the specified selector. Returns the nil_method if the receiver is nil,
 * and panics if the selector is not found.
 */
IMP objc_msg_lookup(id receiver, SEL selector) {
  if (receiver == NULL) {
    return (IMP)__objc_nil_method;
  }

  // First load the protocols, static instances and categories
  __objc_load();

  // Get the class of the receiver
  objc_class_t *cls = receiver->isa;
  if (cls == Nil) {
    sys_panicf("objc_msg_lookup: receiver @%p class is Nil (selector=%s)",
               receiver, sel_getName(selector));
    return NULL;
  }

  IMP imp = __objc_msg_lookup(cls, selector);
  if (imp == NULL) {
    sys_panicf(
        "objc_msg_lookup: class=%c[%s %s] selector->types=%s cannot send "
        "message\n",
        OBJC_LOAD_RELAXED(&receiver->isa->info) & objc_class_flag_meta ? '+' : '-',
        receiver->isa->name, sel_getName(selector), selector->sel_type);
  } else {
#ifdef OBJCDEBUG
    sys_printf("    => IMP @%p\n", imp);
#endif
  }

  // If the class has of the receiver not been initialized, then this is the
  // time to do it
  BOOL is_meta = (OBJC_LOAD_RELAXED(&cls->info) & objc_class_flag_meta) != 0;
  objc_class_t *meta_cls = is_meta ? cls : cls->metaclass;
  if (!__objc_flag_test(&meta_cls->info, objc_class_flag_initialized)) {
#ifdef OBJCDEBUG
    sys_printf("  +[%s initialize] \n", cls->name);
#endif
    // Call the class's initialize method. If the receiver's class is a
    // metaclass, then the receiver is itself the class.
    __objc_send_initialize(is_meta ? (objc_class_t *)receiver : cls);
  }

  return imp;
}

/**
 * Message superclass dispatch function. Returns the implementation pointer for
 * the specified selector, for the receiver superclass. Returns nil if the
 * receiver is nil.
 */
IMP objc_msg_lookup_super(struct objc_super *super, SEL selector) {
  if (super == NULL || super->receiver == nil) {
    return NULL;
  }
  IMP imp = __objc_msg_lookup(super->superclass, selector);
  if (imp == NULL) {
    sys_panicf(
        "objc_msg_lookup: class=%c[%s %s] selector->types=%s not found\n",
        OBJC_LOAD_RELAXED(&super->receiver->isa->info) & objc_class_flag_meta
            ? '+'
            : '-',
        super->receiver->isa->name, sel_getName(selector), selector->sel_type);
  }
  return imp;
}

///////////////////////////////////////////////////////////////////////////////

BOOL class_respondsToSelector(Class cls, SEL selector) {
  if (cls == Nil) {
    return NO;
  }
  if (selector == NULL) {
    sys_panicf("class_respondsToSelector: SEL is NULL");
    return NO;
  }
#ifdef OBJCDEBUG
  sys_printf("class_respondsToSelector %c[%s %s] types=%s\n",
             cls->info & objc_class_flag_meta ? '+' : '-', cls->name,
             sel_getName(selector), selector->sel_type);
#endif
  return __objc_msg_lookup(cls, selector) == NULL
             ? NO
             : YES; // Check if the class responds to the selector
}

BOOL object_respondsToSelector(id object, SEL selector) {
  if (object == NULL) {
    return NO; // If the object is nil, it cannot respond to any selector
  }
  if (selector == NULL) {
    sys_panicf("object_respondsToSelector: SEL is NULL");
    return NO;
  }
  Class cls = object_getClass(object);
#ifdef OBJCDEBUG
  sys_printf("object_respondsToSelector %c[%s %s] types=%s\n",
             cls->info & objc_class_flag_meta ? '+' : '-', cls->name,
             sel_getName(selector), selector->sel_type);
#endif
  return __objc_msg_lookup(cls, selector) == NULL ? NO : YES;
}

BOOL class_metaclassRespondsToSelector(Class cls, SEL selector) {
  if (cls == Nil) {
    return NO;
  }
  if (!(OBJC_LOAD_RELAXED(&cls->info) & objc_class_flag_meta)) {
    cls = cls->metaclass; // Use the metaclass for class methods
  }
  return class_respondsToSelector(
      cls, selector); // Check if the class responds to the selector
}

const char *sel_getName(SEL sel) {
  if (sel == NULL) {
    return NULL;
  }
  return sel->sel_id; // Return the selector name
}
