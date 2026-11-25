#include "class.h"
#include "api.h"
#include "hash.h"
#include "lock.h"
#include "protocol.h"
#include <runtime/gcc/objc.h>
#include <picofuse/sys.h>
#include <string.h>

static objc_class_t *class_table[OBJC_CLASS_CAPACITY];

///////////////////////////////////////////////////////////////////////////////

void __objc_class_register(objc_class_t *p) {
  if (p == NULL || p->name == NULL) {
    return;
  }
#ifdef OBJCDEBUG
  sys_printf("__objc_class_register %c[%s] @%p size=%lu\n",
             p->info & objc_class_flag_meta ? '+' : '-', p->name, p, p->size);
#endif
  for (int i = 0; i < OBJC_CLASS_CAPACITY; i++) {
    if (class_table[i] == p) {
      // Class is already registered, nothing to do
      return;
    }
    if (class_table[i] == NULL) {
      // Found empty slot, register the class
      class_table[i] = p;

      // Register protocols for the class
      if (p->protocols != NULL) {
        __objc_protocol_list_register(p->protocols);
      }
      return;
    }

    // Check for duplicate class names
    if (strcmp(class_table[i]->name, p->name) == 0) {
      sys_panicf("Duplicate class named: %s", p->name);
    }
  }
  sys_panicf("Class table is full, cannot register class: %s", p->name);
}

/**
 * Lookup the class in the class table by name.
 * Returns the class, or Nil if not found.
 */
objc_class_t *__objc_lookup_class(const char *name) {
  if (name == NULL) {
    return Nil;
  }
  for (int i = 0; i < OBJC_CLASS_CAPACITY; i++) {
    if (class_table[i] == NULL) {
      break; // The rest are empty
    }
    if (strcmp(class_table[i]->name, name) == 0) {
      return class_table[i];
    }
  }
  return Nil; // No class found
}

/**
 * Register a list of methods for a class.
 * This function registers all methods in the method list, for the named class.
 */
void __objc_class_register_method_list(objc_class_t *cls,
                                       struct objc_method_list *ml) {
  if (ml == NULL) {
    return; // Nothing to register
  }
  for (int i = 0; i < ml->count; i++) {
    struct objc_method *method = &ml->methods[i];
    if (method == NULL || method->name == NULL || method->imp == NULL) {
      continue; // Skip invalid methods
    }
#ifdef OBJCDEBUG
    sys_printf("    %c[%s %s] types=%s imp=%p\n",
               cls->info & objc_class_flag_meta ? '+' : '-', cls->name,
               method->name, method->types, method->imp);
#endif
    if (!__objc_hash_register(cls, method)) {
      sys_panicf("Method table is full, cannot register method: %c[%s %s]",
                 cls->info & objc_class_flag_meta ? '+' : '-', cls->name,
                 method->name);
    }
  }
}

/**
 * Register the methods of a class or metaclass, for lookup by objc_msg_lookup and
 * objc_msg_lookup_super.
 */
static void __objc_class_register_methods(objc_class_t *p) {
#ifdef OBJCDEBUG
  sys_printf("  __objc_class_register_methods %c[%s] @%p size=%lu\n",
             p->info & objc_class_flag_meta ? '+' : '-', p->name, p, p->size);
#endif
  for (struct objc_method_list *ml = p->methods; ml != NULL; ml = ml->next) {
    __objc_class_register_method_list(p, ml);
  }
}

/**
 * Resolve a class and its metaclass, and their superclasses, which are names until
 * then. Other threads can use a class as soon as it's marked as resolved, so that's
 * last. Must be called with the runtime locked.
 */
static void __objc_class_resolve(objc_class_t *cls) {
  if (cls->info & objc_class_flag_resolved) {
    return;
  }

  // Resolve the superclass
  if (cls->superclass != NULL) {
    const char *name = (const char *)cls->superclass;
    objc_class_t *superclass = __objc_lookup_class(name);
    if (superclass == Nil) {
      sys_panicf("Superclass %s not found for class %s", name, cls->name);
    }
    __objc_class_resolve(superclass);
    cls->superclass = superclass;
    if (cls->metaclass != NULL) {
      cls->metaclass->superclass = superclass->metaclass;
    }
  }

  // Register the methods
  __objc_class_register_methods(cls);
  if (cls->metaclass != NULL) {
    __objc_class_register_methods(cls->metaclass);
    __objc_flag_set(&cls->metaclass->info, objc_class_flag_resolved);
  }
  __objc_flag_set(&cls->info, objc_class_flag_resolved);
}

///////////////////////////////////////////////////////////////////////////////

/**
 * Lookup the class with the specified name, and resolve it and its metaclass if
 * that hasn't yet been done. If the class is not found, Nil is returned.
 */
Class objc_lookup_class(const char *name) {
  objc_class_t *cls = __objc_lookup_class(name);
  if (cls == Nil) {
    return Nil;
  }
#ifdef OBJCDEBUG
  sys_printf("objc_lookup_class %c[%s] @%p\n",
             cls->info & objc_class_flag_meta ? '+' : '-', name, cls);
#endif
  if (!__objc_flag_test(&cls->info, objc_class_flag_resolved)) {
    __objc_lock();
    __objc_class_resolve(cls);
    __objc_unlock();
  }
  return (Class)cls;
}

///////////////////////////////////////////////////////////////////////////////

/**
 * Class lookup function. Panics if the class is not found.
 */
Class objc_get_class(const char *name) {
  Class cls = objc_lookup_class(name);
  if (cls == Nil) {
    sys_panicf("objc_get_class: class %s not found", name);
    return Nil;
  }
  return cls;
}

/**
 * Looks up the class with the specified name. Returns Nil if the class is not
 * found.
 */
Class objc_lookupClass(const char *name) {
  return name ? objc_lookup_class(name) : Nil;
}

/**
 * Returns the name of the class, or NULL if the class is Nil.
 */
const char *class_getName(Class cls) { return cls ? cls->name : NULL; }

/**
 * Returns the name of the class of the object, or NULL if the object is nil.
 */
const char *object_getClassName(id obj) { return obj ? obj->isa->name : NULL; }

/**
 * Returns the class of the object. Returns Nil if the object is nil.
 */
Class object_getClass(id object) { return object ? object->isa : Nil; }

/**
 * Sets the class of the object to the specified class.
 */
void object_setClass(id object, Class cls) {
  if (object == NULL || cls == NULL) {
    sys_panicf("object_setClass: object or class is NULL");
    return;
  }
  if (cls->info & objc_class_flag_meta) {
    sys_panicf("object_setClass: cannot set class to a metaclass");
    return;
  }
  object->isa = cls; // Set the class of the object
}

/**
 * Checks if an instance class matches, or subclass of another class.
 */
BOOL object_isKindOfClass(id object, Class cls) {
  if (object == nil) {
    return NO;
  }
  if (cls == Nil) {
    sys_panicf("object_isKindOfClass: class is Nil");
    return NO;
  }
  Class objClass = object->isa; // Get the class of the object
  while (objClass != Nil) {
    if (objClass == cls) {
      return YES; // Found a match
    }
    objClass = objClass->superclass; // Move up the superclass chain
  }
  return NO; // No match found
}

/**
 * Returns the size of an instance of the named class, in bytes. Returns 0 if
 * the class is Nil
 */
size_t class_getInstanceSize(Class cls) { return cls ? cls->size : 0; }

/**
 * Returns the superclass of an instance, or Nil if it is a root class
 */
Class object_getSuperclass(id obj) { return obj ? obj->isa->superclass : Nil; }

/**
 * Returns the superclass of a class, or Nil if it is a root class
 */
Class class_getSuperclass(Class cls) { return cls ? cls->superclass : Nil; }
