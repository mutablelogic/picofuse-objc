#include "NXArgument+Private.h"
#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <runtime/gcc/runtime.h>

static NXString *string_of(const char *cStr) {
  return cStr == NULL || cStr[0] == '\0' ? nil : [NXString stringWithCString:cStr];
}

// The value picofuse parsed for a flag, which it has checked is of the flag's type
static id value_of(sys_env_arg_t *parsed, NXArgument *flag, const char *name, const char *text) {
  bool b;
  int64_t i;
  uint64_t u;
  double d;
  sys_date_t date;
  switch ([flag type]) {
  case sys_env_arg_type_string:
    return [NXString stringWithCString:text];
  case sys_env_arg_type_bool:
    return sys_env_arg_parse_bool(parsed, name, &b) ? [NXNumber numberWithBool:b] : nil;
  case sys_env_arg_type_int:
    return sys_env_arg_parse_int64(parsed, name, &i) ? [NXNumber numberWithInt64:i] : nil;
  case sys_env_arg_type_uint:
    return sys_env_arg_parse_uint64(parsed, name, &u) ? [NXNumber numberWithUnsignedInt64:u]
                                                      : nil;
  case sys_env_arg_type_float:
    return sys_env_arg_parse_float64(parsed, name, &d) ? [NXNumber numberWithFloat64:d] : nil;
  case sys_env_arg_type_duration:
    return sys_env_arg_parse_duration(parsed, name, &i) ? [NXNumber numberWithInt64:i] : nil;
  case sys_env_arg_type_date:
    if (!sys_env_arg_parse_date(parsed, name, &date)) {
      return nil;
    }
    return [[NXDate dateWithSeconds:date.seconds nanoseconds:date.nanoseconds]
        dateWithTimeZoneOffset:date.tzoffset];
  default:
    return nil;
  }
}

@implementation NXEnvironment

+ (NXEnvironment *)environmentWithArgc:(int)argc argv:(char **)argv {
  return [[[self alloc] initWithArgc:argc argv:argv] autorelease];
}

- (id)initWithArgc:(int)argc argv:(char **)argv {
  self = [super init];
  if (self != nil) {
    _argc = argv == NULL || argc < 0 ? 0 : argc;
    _argv = argv;
    _arguments = [[NXArray alloc] init];
    if (_arguments == nil) {
      [self release];
      return nil;
    }
  }
  return self;
}

- (void)dealloc {
  [_arguments release];
  [super dealloc];
}

- (NXMap *)parseFlags:(NXArray *)flags error:(NXString **)error {
  if (error != NULL) {
    *error = nil;
  }
  [_arguments release];
  _arguments = [[NXArray alloc] init];

  // Every flag is an NXArgument, with a name of its own
  size_t count = [flags count];
  NXMap *values = [NXMap mapWithCapacity:count];
  if (values == nil || _arguments == nil) {
    return nil;
  }
  for (id object in flags) {
    if (!object_isKindOfClass(object, [NXArgument class])) {
      if (error != NULL) {
        *error = [NXString stringWithFormat:@"%@ isn't an argument", object];
      }
      return nil;
    }
    NXArgument *flag = object;
    if ([values containsObject:[flag name]]) {
      if (error != NULL) {
        *error = [NXString stringWithFormat:@"--%@ is given twice", [flag name]];
      }
      return nil;
    }
    if (![values setObject:[flag defaultValue] forKey:[flag name]]) {
      return nil;
    }
  }

  // With nothing after the program's name, it's the defaults, which is so on a Pico,
  // where picofuse has no command line to parse
  if (_argc <= 1) {
    return values;
  }

  // picofuse's flags, without defaults, which end with one without a name
  sys_env_arg_flag_t *table = sys_malloc((count + 1) * sizeof(sys_env_arg_flag_t));
  if (table == NULL) {
    return nil;
  }
  for (size_t i = 0; i <= count; i++) {
    NXArgument *flag = i < count ? [flags objectAtIndex:i] : nil;
    table[i] = (sys_env_arg_flag_t){
        .long_name = flag == nil ? NULL : [[flag name] cStr],
        .short_name = [flag shortName] == nil ? NULL : [[flag shortName] cStr],
        .type = flag == nil ? (sys_env_arg_type_t)0 : [flag type],
        .value = NULL,
    };
  }

  // picofuse's parser is one for the process, so what it returns is copied under a lock
  NXString *failure = nil;
  BOOL ok = YES;
  @synchronized([NXEnvironment class]) {
    sys_env_set_args(_argc, _argv);
    sys_env_arg_t *parsed = sys_env_arg_parse(table);
    if (parsed == NULL) {
      const char *message = sys_env_arg_error();
      failure = message == NULL ? @"the command line couldn't be parsed" : string_of(message);
      ok = NO;
    }
    for (size_t i = 0; ok && i < count; i++) {
      // Those not given keep their defaults
      if (table[i].value == NULL) {
        continue;
      }
      NXArgument *flag = [flags objectAtIndex:i];
      id value = value_of(parsed, flag, table[i].long_name, table[i].value);
      if (value == nil) {
        failure = [NXString stringWithFormat:@"--%@: \"%s\" isn't valid", [flag name],
                                             table[i].value];
        ok = NO;
      } else {
        ok = [values setObject:value forKey:[flag name]];
      }
    }
    for (size_t i = 0; ok && i < sys_env_arg_count(parsed); i++) {
      const char *argument = sys_env_arg_string(parsed, i);
      ok = argument != NULL && [_arguments appendObject:[NXString stringWithCString:argument]];
    }
  }
  sys_free(table);

  if (!ok) {
    [_arguments removeAllObjects];
    if (error != NULL) {
      *error = failure;
    }
    return nil;
  }
  return values;
}

- (NXArray *)arguments {
  return _arguments;
}

- (NXString *)name {
  return string_of(sys_env_name());
}

- (NXString *)version {
  return string_of(sys_env_version());
}

- (NXString *)system {
  return string_of(sys_env_system());
}

- (NXString *)serial {
  return string_of(sys_env_serial());
}

@end
