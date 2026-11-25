#pragma once
#include "class.h"

/*
 * The table of methods, by class, name and types. There's one entry for each
 * method, which refers to the description of it that the compiler generated.
 */
struct objc_hashitem {
  objc_class_t *cls;          // The class which has the method
  struct objc_method *method; // The method
};

/*
 * With the runtime locked, register a method, replacing any method of the class which has the same name
 * and types. Returns false if the table is full.
 */
bool __objc_hash_register(objc_class_t *cls, struct objc_method *method);

/*
 * Lookup a method of a class by name and types, or if types is NULL, the last
 * which was registered with that name. Returns NULL if there's no such method.
 * The superclass isn't considered.
 */
struct objc_method *__objc_hash_lookup(objc_class_t *cls, const char *name,
                                       const char *types);
