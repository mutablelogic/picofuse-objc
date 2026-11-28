#include "NXArgument+Private.h"
#include "NXNumber+Private.h"
#include <Foundation/Foundation.h>
#include <runtime/gcc/runtime.h>

@implementation NXArgument

+ (NXArgument *)argumentWithName:(NXString *)name short:(NXString *)shortName {
  return [self argumentWithName:name short:shortName default:[NXNumber falseValue]];
}

+ (NXArgument *)argumentWithName:(NXString *)name short:(NXString *)shortName default:(id)value {
  if (value == nil) {
    return nil;
  }

  // The type is the default's
  sys_env_arg_type_t type;
  if (object_isKindOfClass(value, [NXString class])) {
    type = sys_env_arg_type_string;
  } else if (object_isKindOfClass(value, [NXDate class])) {
    type = sys_env_arg_type_date;
  } else if (object_isKindOfClass(value, [NXNumberBool class])) {
    type = sys_env_arg_type_bool;
  } else if (object_isKindOfClass(value, [NXNumber class])) {
    if ([(NXNumber *)value isFloat]) {
      type = sys_env_arg_type_float;
    } else if (object_isKindOfClass(value, [NXNumberUnsignedInt16 class]) ||
               object_isKindOfClass(value, [NXNumberUnsignedInt32 class]) ||
               object_isKindOfClass(value, [NXNumberUnsignedInt64 class])) {
      type = sys_env_arg_type_uint;
    } else {
      type = sys_env_arg_type_int;
    }
  } else {
    return nil;
  }
  return [[[self alloc] initWithName:name short:shortName type:type default:value] autorelease];
}

+ (NXArgument *)argumentWithName:(NXString *)name
                           short:(NXString *)shortName
                        duration:(NXDuration)value {
  NXNumber *ns = [NXNumber numberWithInt64:value];
  if (ns == nil) {
    return nil;
  }
  return [[[self alloc] initWithName:name short:shortName type:sys_env_arg_type_duration
                             default:ns] autorelease];
}

- (void)dealloc {
  [_name release];
  [_shortName release];
  [_default release];
  [super dealloc];
}

- (NXString *)name {
  return _name;
}

- (NXString *)shortName {
  return _shortName;
}

- (NXString *)description {
  return [NXString stringWithFormat:@"--%@=%@", _name, _default];
}

@end

@implementation NXArgument (Private)

- (id)initWithName:(NXString *)name
             short:(NXString *)shortName
              type:(sys_env_arg_type_t)type
           default:(id)value {
  self = [super init];
  if (self == nil) {
    return nil;
  }
  if (name == nil || [name length] == 0 || (shortName != nil && [shortName length] == 0)) {
    [self release];
    return nil;
  }
  _name = [name copy];
  _shortName = [shortName copy];
  _default = [value retain];
  _type = (int)type;
  if (_name == nil || (shortName != nil && _shortName == nil)) {
    [self release];
    return nil;
  }
  return self;
}

- (sys_env_arg_type_t)type {
  return (sys_env_arg_type_t)_type;
}

- (id)defaultValue {
  return _default;
}

@end
