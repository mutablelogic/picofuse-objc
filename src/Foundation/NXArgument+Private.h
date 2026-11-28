#pragma once
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>

@interface NXArgument (Private)

// Returns nil if a name is empty
- (id)initWithName:(NXString *)name
             short:(NXString *)shortName
              type:(sys_env_arg_type_t)type
           default:(id)value;

// picofuse's type for it
- (sys_env_arg_type_t)type;

// Its value when it isn't given
- (id)defaultValue;

@end
