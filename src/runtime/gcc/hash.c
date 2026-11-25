#include "hash.h"
#include "api.h"
#include "lock.h"
#include <runtime/gcc/objc.h>
#include <string.h>

_Static_assert((OBJC_METHOD_CAPACITY & (OBJC_METHOD_CAPACITY - 1)) == 0,
               "OBJC_METHOD_CAPACITY must be a power of two");

static struct objc_hashitem hash_table[OBJC_METHOD_CAPACITY];

///////////////////////////////////////////////////////////////////////////////
// PRIVATE METHODS

/*
 * Returns the index in the table at which to start looking for a method. The
 * name is hashed by its contents, as each module has its own copy.
 */
static inline size_t __objc_hash_index(objc_class_t *cls, const char *name) {
  // Classes are at least four-byte aligned
  size_t hash = ((uintptr_t)cls >> 2) * 31;
  for (const char *p = name; *p; p++) {
    hash = (hash * 31) + (unsigned char)*p;
  }
  return (hash ^ (hash >> 10)) & (OBJC_METHOD_CAPACITY - 1);
}

static inline size_t __objc_hash_next(size_t index) {
  return (index + 1) & (OBJC_METHOD_CAPACITY - 1);
}

static inline bool __objc_hash_types_equal(const char *a, const char *b) {
  return a == b || (a != NULL && b != NULL && strcmp(a, b) == 0);
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

bool __objc_hash_register(objc_class_t *cls, struct objc_method *method) {
  const char *name = method->name;
  const char *types = method->types;
  size_t index = __objc_hash_index(cls, name);
  for (size_t i = 0; i < OBJC_METHOD_CAPACITY; i++) {
    struct objc_hashitem *item = &hash_table[index];
    if (item->cls == NULL) {
      // Other threads may see the class as soon as it's there
      OBJC_STORE_RELEASE(&item->method, method);
      OBJC_STORE_RELEASE(&item->cls, cls);
      return true;
    }
    if (item->cls == cls && strcmp(item->method->name, name) == 0) {
      // Put this method first, and move the one that was here along, unless it's
      // been replaced
      struct objc_method *moved = item->method;
      OBJC_STORE_RELEASE(&item->method, method);
      if (__objc_hash_types_equal(moved->types, types)) {
        return true;
      }
      method = moved;
    }
    index = __objc_hash_next(index);
  }
  return false;
}

struct objc_method *__objc_hash_lookup(objc_class_t *cls, const char *name,
                                       const char *types) {
  size_t index = __objc_hash_index(cls, name);
  for (size_t i = 0; i < OBJC_METHOD_CAPACITY; i++) {
    struct objc_hashitem *item = &hash_table[index];
    objc_class_t *item_cls = OBJC_LOAD_ACQUIRE(&item->cls);
    if (item_cls == NULL) {
      return NULL;
    }
    if (item_cls == cls) {
      struct objc_method *method = OBJC_LOAD_ACQUIRE(&item->method);
      if (strcmp(method->name, name) == 0 &&
          (types == NULL || __objc_hash_types_equal(method->types, types))) {
        return method;
      }
    }
    index = __objc_hash_next(index);
  }
  return NULL;
}
