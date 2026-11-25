#include "hash.h"
#include "api.h"
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

/*
 * Returns the entry for a method, or if there isn't one, the free entry where it
 * would go. Returns NULL if there isn't one of those either.
 */
static struct objc_hashitem *__objc_hash_find(objc_class_t *cls,
                                              const char *name) {
  size_t index = __objc_hash_index(cls, name);
  for (size_t i = 0; i < OBJC_METHOD_CAPACITY; i++) {
    struct objc_hashitem *item = &hash_table[index];
    if (item->cls == NULL ||
        (item->cls == cls && strcmp(item->method->name, name) == 0)) {
      return item;
    }
    index = (index + 1) & (OBJC_METHOD_CAPACITY - 1);
  }
  return NULL;
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

bool __objc_hash_register(objc_class_t *cls, struct objc_method *method) {
  struct objc_hashitem *item = __objc_hash_find(cls, method->name);
  if (item == NULL) {
    return false;
  }
  item->method = method;
  item->cls = cls;
  return true;
}

struct objc_method *__objc_hash_lookup(objc_class_t *cls, const char *name,
                                       const char *types) {
  struct objc_hashitem *item = __objc_hash_find(cls, name);
  if (item == NULL || item->cls == NULL) {
    return NULL;
  }
  if (types != NULL && (item->method->types == NULL ||
                        strcmp(item->method->types, types) != 0)) {
    return NULL;
  }
  return item->method;
}
