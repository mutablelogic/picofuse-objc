#include <runtime/gcc/objc.h>

@implementation Object

+ (void)initialize {
  // No-op
}

- (id)init {
  return self;
}

- (Class)class {
  return object_getClass(self);
}

+ (Class)class {
  return self;
}

- (Class)superclass {
  return object_getSuperclass(self);
}

+ (Class)superclass {
  return class_getSuperclass(self);
}

+ (const char *)name {
  return class_getName(self);
}

- (BOOL)isEqual:(id)anObject {
  return self == anObject;
}

- (BOOL)isKindOfClass:(Class)cls {
  return object_isKindOfClass(self, cls);
}

/**
 * @brief Checks if the class conforms to a protocol.
 */
+ (BOOL)conformsTo:(Protocol *)aProtocolObject {
  return class_conformsTo(self, (objc_protocol_t *)aProtocolObject);
}

/**
 * @brief Checks if the receiver's class conforms to a protocol.
 */
- (BOOL)conformsTo:(Protocol *)aProtocolObject {
  return class_conformsTo(object_getClass(self),
                          (objc_protocol_t *)aProtocolObject);
}

/**
 * @brief Checks if the receiver responds to a selector.
 */
- (BOOL)respondsToSelector:(SEL)aSelector {
  return object_respondsToSelector(self, aSelector);
}

@end
