#include "category.h"
#include "api.h"
#include "class.h"
#include "protocol.h"
#include <runtime/gcc/objc.h>
#include <picofuse/sys.h>
#include <string.h>

// clang emits a category of this class, which doesn't exist, in each module
// which has protocols. It's only there to list them.
#define CATEGORY_PROTOCOL_HOLDER "__ObjC_Protocol_Holder_Ugly_Hack"

static struct objc_category *category_table[OBJC_CATEGORY_CAPACITY];

///////////////////////////////////////////////////////////////////////////////

void __objc_category_register(struct objc_category *category) {
  if (category == NULL || category->name == NULL ||
      category->class_name == NULL) {
    return;
  }
#ifdef OBJCDEBUG
  sys_printf("__objc_category_register [%s+%s]\n", category->class_name,
             category->name);
#endif

  // Register protocols for the category
  __objc_protocol_list_register(category->protocols);
  if (strcmp(category->class_name, CATEGORY_PROTOCOL_HOLDER) == 0) {
    return;
  }

  for (int i = 0; i < OBJC_CATEGORY_CAPACITY; i++) {
    if (category_table[i] == category) {
      // Category is already registered, nothing to do
      return;
    }
    if (category_table[i] == NULL) {
      // Found empty slot, register the category
      category_table[i] = category;
      return;
    }
  }
  sys_panicf("Category table is full, cannot register category: %s",
             category->name);
}

static void __objc_category_load_category(struct objc_category *category) {
  // Lookup the class by name
  objc_class_t *cls = objc_lookup_class(category->class_name);
  if (cls == Nil) {
    return;
  }

#ifdef OBJCDEBUG
  sys_printf("  __objc_category_load_category [%s+%s]\n", cls->name,
             category->name);
#endif

  // Add the category's protocols to those of the class
  if (category->protocols != NULL) {
    struct objc_protocol_list *last = category->protocols;
    while (last->next != NULL) {
      last = last->next;
    }
    last->next = cls->protocols;
    cls->protocols = category->protocols;
  }

  // Register instance methods from the category
  if (category->instance_methods != NULL) {
    for (struct objc_method_list *ml = category->instance_methods; ml != NULL;
         ml = ml->next) {
      __objc_class_register_method_list(cls, ml);
    }
  }

  // Register class methods from the category
  if (category->class_methods != NULL && cls->metaclass != NULL) {
    for (struct objc_method_list *ml = category->class_methods; ml != NULL;
         ml = ml->next) {
      __objc_class_register_method_list(cls->metaclass, ml);
    }
  }
}

BOOL __objc_category_load() {
  static BOOL init = NO;
  if (init) {
    return NO; // Already loaded
  }
  init = YES;

  // Replace class name with resolved class
  for (int i = 0; i < OBJC_CATEGORY_CAPACITY; i++) {
    struct objc_category *category = category_table[i];
    if (category == NULL) {
      continue; // Skip empty slots and continue searching
    }
    __objc_category_load_category(category);
  }

  return YES;
}
