#include <Foundation/Foundation.h>
#include <picofuse/sys.h>
#include <string.h>

///////////////////////////////////////////////////////////////////////////////
// TYPES

// What a thread is to run
typedef struct {
  SEL selector;
  id target;
  id argument;
  BOOL has_argument;
} thread_context_t;

// For a thread which can run on any core
#define ANY_CORE -1

///////////////////////////////////////////////////////////////////////////////
// PRIVATE METHODS

// Retain or release an object, if it's one which can be
static void retain(id object) {
  if (object_isKindOfClass(object, [NXObject class])) {
    [(NXObject *)object retain];
  }
}

static void release(id object) {
  if (object_isKindOfClass(object, [NXObject class])) {
    [(NXObject *)object release];
  }
}

// Returns the number of arguments a method has
static size_t arguments(SEL selector) {
  size_t count = 0;
  for (const char *name = sel_getName(selector); *name != '\0'; name++) {
    if (*name == ':') {
      count++;
    }
  }
  return count;
}

// Returns YES if a method can be called as if it returned nothing. That's not so if
// it returns a struct, for example, as it's then passed where to put that.
static BOOL returns_scalar(const char *types) {
  types += strspn(types, "rnNoORVA"); // Qualifiers
  return *types != '\0' && strchr("v@#:*^cCsSiIlLqQBfd", *types) != NULL;
}

// Returns YES if the last argument of a method is an object. Each type is followed
// by the offset of the argument.
static BOOL takes_object(const char *types) {
  size_t length = strlen(types);
  while (length > 0 && strchr("0123456789+-", types[length - 1]) != NULL) {
    length--;
  }
  return length > 1 && strchr("@#", types[length - 1]) != NULL &&
         types[length - 2] != '^';
}

static void thread_main(void *arg) {
  thread_context_t context = *(thread_context_t *)arg;
  sys_free(arg);

  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  if (pool == nil) {
    sys_panicf("+[NXThread run:target:] out of memory");
  }

  void (*imp)(void) =
      (void (*)(void))objc_msg_lookup(context.target, context.selector);
  if (context.has_argument) {
    ((void (*)(id, SEL, id))imp)(context.target, context.selector,
                                 context.argument);
  } else {
    ((void (*)(id, SEL))imp)(context.target, context.selector);
  }

  // Deallocating these may autorelease other objects
  release(context.argument);
  release(context.target);
  [pool release];
}

// Start a thread, and return YES if successful
static BOOL thread_start(thread_context_t run, int core) {
  if (run.target == nil || run.selector == NULL ||
      arguments(run.selector) != (run.has_argument ? 1 : 0)) {
    return NO;
  }
  const char *types = object_getMethodTypes(run.target, run.selector);
  if (types == NULL || !returns_scalar(types) ||
      (run.has_argument && !takes_object(types))) {
    return NO;
  }

  thread_context_t *context = sys_malloc(sizeof(thread_context_t));
  if (context == NULL) {
    return NO;
  }
  *context = run;
  retain(run.target);
  retain(run.argument);

  BOOL started = core == ANY_CORE
                     ? sys_thread_create(thread_main, context)
                     : sys_thread_create_on_core(thread_main, context,
                                                 (uint8_t)core);
  if (!started) {
    release(run.argument);
    release(run.target);
    sys_free(context);
  }
  return started;
}

@implementation NXThread

///////////////////////////////////////////////////////////////////////////////
// PROPERTIES

+ (uint8_t)numberOfCores {
  return sys_thread_numcores();
}

+ (uint8_t)coreNumber {
  return sys_thread_core();
}

///////////////////////////////////////////////////////////////////////////////
// PUBLIC METHODS

+ (void)sleepForDuration:(NXDuration)duration {
  // What can be slept for at once is limited
  const NXDuration limit = UINT32_MAX * NXMillisecond;
  while (duration > 0) {
    sys_sleep_ms(NXDurationMilliseconds(duration));
    duration = duration > limit ? duration - limit : 0;
  }
}

+ (void)halt {
  sys_halt();
}

+ (BOOL)run:(SEL)selector target:(id)target {
  thread_context_t run = {.selector = selector, .target = target};
  return thread_start(run, ANY_CORE);
}

+ (BOOL)run:(SEL)selector target:(id)target core:(uint8_t)core {
  thread_context_t run = {.selector = selector, .target = target};
  return thread_start(run, core);
}

+ (BOOL)run:(SEL)selector target:(id)target argument:(id)argument {
  thread_context_t run = {.selector = selector,
                          .target = target,
                          .argument = argument,
                          .has_argument = YES};
  return thread_start(run, ANY_CORE);
}

+ (BOOL)run:(SEL)selector
     target:(id)target
   argument:(id)argument
       core:(uint8_t)core {
  thread_context_t run = {.selector = selector,
                          .target = target,
                          .argument = argument,
                          .has_argument = YES};
  return thread_start(run, core);
}

@end
