#include "NXApplication+Private.h"
#include "NXEventSource+Private.h"
#include <Application/Application.h>
#include <picofuse/hid.h>
#include <picofuse/hw.h>
#include <picofuse/sys.h>
#include <runtime/gcc/runtime.h>

///////////////////////////////////////////////////////////////////////////////
// GLOBALS

// The status for a command line which doesn't parse, and for a delegate which can't
// be made
#define STATUS_USAGE 2
#define STATUS_FAILED 1

///////////////////////////////////////////////////////////////////////////////
// SIGNALS

// A source which terminates the application on a signal, with 128 + its number
@interface NXSignalSource : NXObject <NXEventSourcePrivate> {
@private
  void *_device;
}
@end

@implementation NXSignalSource

- (BOOL)attachToHID:(hid_t *)hid {
  BOOL attached = NO;
  @synchronized(self) {
    if (_device == NULL) {
      _device = hid_register_signal(hid, NULL);
    }
    attached = _device != NULL;
  }
  return attached;
}

- (void)detachFromHID:(hid_t *)hid {
  @synchronized(self) {
    if (_device != NULL) {
      hid_deregister(hid, _device);
      _device = NULL;
    }
  }
}

- (BOOL)ownsEvent:(hid_event_t *)event {
  BOOL owns;
  @synchronized(self) {
    owns = _device != NULL && event->type == hid_event_type_signal && event->device == _device;
  }
  return owns;
}

- (void)handleEvent:(hid_event_t *)event {
  int number;
  switch (event->data.signal.signal) {
  case sys_env_signal_int:
    number = 2;
    break;
  case sys_env_signal_quit:
    number = 3;
    break;
  default:
    number = 15;
    break;
  }
  [[NXApplication sharedApplication] terminateWithStatus:128 + number];
}

@end

///////////////////////////////////////////////////////////////////////////////
// HELP

static NXString *const HELP = @"help";

// Writes a line to standard output
static void write_line(NXString *line) {
  NXStream *stream = [NXStream standardOutput];
  [stream writeString:line];
  [stream writeString:@"\n"];
}

///////////////////////////////////////////////////////////////////////////////
// MAIN

// Parses the command line, with --help added unless there's one already. Returns
// the flags' values, or nil with a status to return.
static NXMap *parse(NXEnvironment *environment, NXArray *flags, int *status) {
  NXArray *all = [NXArray array];
  BOOL hasHelp = NO;
  for (id flag in flags) {
    if (object_isKindOfClass(flag, [NXArgument class]) &&
        [[(NXArgument *)flag name] isEqual:HELP]) {
      hasHelp = YES;
    }
    if (![all appendObject:flag]) {
      *status = STATUS_FAILED;
      return nil;
    }
  }
  if (!hasHelp && ![all appendObject:[NXArgument argumentWithName:HELP short:@"h"]]) {
    *status = STATUS_FAILED;
    return nil;
  }

  NXString *error = nil;
  NXMap *values = [environment parseFlags:all error:&error];
  if (values == nil) {
    write_line([NXString stringWithFormat:@"%@: %@", [environment name], error]);
    *status = STATUS_USAGE;
    return nil;
  }
  if (!hasHelp && [[values objectForKey:HELP] boolValue]) {
    write_line([NXString stringWithFormat:@"Usage: %@ [flags]", [environment name]]);
    [environment writeUsageToStream:[NXStream standardOutput] flags:all];
    *status = 0;
    return nil;
  }
  if (!hasHelp) {
    [values removeObjectForKey:HELP];
  }
  return values;
}

// The delegate class's flags, if it has them
static NXArray *flags_of(Class delegateClass) {
  SEL selector = @selector(commandLineFlags);
  if (!class_respondsToSelector(object_getClass(delegateClass), selector)) {
    return nil;
  }
  void (*imp)(void) = (void (*)(void))objc_msg_lookup(delegateClass, selector);
  return ((NXArray * (*)(id, SEL)) imp)(delegateClass, selector);
}

int NXApplicationMain(int argc, char **argv, NXApplicationFeatures features,
                      Class delegateClass) {
#if defined(SYSTEM_NAME_PICO)
  // A Pico has no command line, and main() isn't given one
  argc = 0;
  argv = NULL;
#endif
  sys_stdio_t stdio = sys_stdio_none;
  if (features & NXApplicationFeatureStdioRTT) {
    stdio = sys_stdio_rtt;
  } else if (features & NXApplicationFeatureStdioUSB) {
    stdio = sys_stdio_usb;
  }
  sys_init(argc, argv, 0, stdio);
  NXAutoreleasePool *pool = [[NXAutoreleasePool alloc] init];
  if (pool == nil) {
    sys_panicf("NXApplicationMain out of memory");
  }
  NXApplication *application = [NXApplication sharedApplication];
  int status = STATUS_FAILED;

  // The delegate's class, which conforms to the protocol
  id delegate = nil;
  if (delegateClass == Nil ||
      !class_conformsTo(delegateClass, (objc_protocol_t *)@protocol(NXApplicationDelegate))) {
    write_line(@"NXApplicationMain: the delegate isn't an NXApplicationDelegate");
  } else {
    // The command line
    NXEnvironment *environment = [NXEnvironment environmentWithArgc:argc argv:argv];
    NXMap *values =
        environment == nil ? nil : parse(environment, flags_of(delegateClass), &status);
    if (values != nil) {
      delegate = [[delegateClass alloc] init];
      if (delegate == nil) {
        write_line(@"NXApplicationMain: the delegate couldn't be made");
      } else {
        [application setEnvironment:environment flags:values];
      }
    }
  }

  if (delegate != nil) {
    [application setDelegate:delegate];
    [application setWorkers:(features & NXApplicationFeatureMulticore) ? 0 : 1];

    // The hardware, which the run loop polls, and which feeds the watchdog
    hw_init();
    [application setHardware:YES];
    hw_watchdog_t *watchdog = NULL;
    if (features & NXApplicationFeatureWatchdog) {
      watchdog = hw_watchdog_init();
      if (watchdog != NULL) {
        hw_watchdog_enable(watchdog, true);
      } else {
        NXDebug(@"NXApplicationMain: there's no watchdog");
      }
    }
    NXSignalSource *signals = nil;
    if (features & NXApplicationFeatureSignals) {
      signals = [[NXSignalSource alloc] init];
      if (signals == nil || ![application attachEventSource:signals]) {
        NXDebug(@"NXApplicationMain: signals can't be handled");
      }
    }

    status = [application run];

    if (signals != nil) {
      [application detachEventSource:signals];
      [signals release];
    }
    if (watchdog != NULL) {
      hw_watchdog_enable(watchdog, false);
      hw_watchdog_deinit(watchdog);
    }
    [application setHardware:NO];
    hw_exit();
    [application setDelegate:nil];
    [delegate release];
  }

  [application setEnvironment:nil flags:nil];
  [pool release];
  sys_exit();
  return status;
}
