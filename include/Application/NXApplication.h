/**
 * @file NXApplication.h
 * @brief Defines the NXApplication class, the application which runs a run loop.
 */
#pragma once
#include "NXEventSource.h"
#include "NXRunLoop.h"
#include <stdint.h>

/**
 * @brief What an application tells its delegate. Each method is optional.
 * @ingroup Application
 *
 * \headerfile NXApplication.h Application/Application.h
 */
@protocol NXApplicationDelegate
@optional


/**
 * @brief Called on worker 0 when the application starts. Events can be posted from here,
 * and none are dispatched, on any worker, until it returns.
 */
- (void)applicationDidStart:(NXApplication *)application;

/**
 * @brief Called on the thread which ran the application, once it has been terminated,
 * every event which was posted has been dispatched, and every worker has finished.
 */
- (void)applicationWillTerminate:(NXApplication *)application;

/**
 * @brief Returns the NXArgument flags which can be given on the command line, for
 * NXApplicationMain, which calls it on the delegate's class once the system has started.
 */
+ (NXArray *)commandLineFlags;

@end

/**
 * @brief The application: one for the program, which runs a run loop until it's
 * terminated.
 * @ingroup Application
 *
 * \code
 * int main(void) {
 *   [[NXApplication sharedApplication] setDelegate:delegate];
 *   return [NXApplication run];
 * }
 * \endcode
 *
 * \headerfile NXApplication.h Application/Application.h
 */
@interface NXApplication : NXObject <NXRunLoopDelegate> {
@private
  NXRunLoop *_runLoop;                    ///< Its run loop
  id<NXApplicationDelegate> _delegate;    ///< Not retained
  uint8_t _workers;                       ///< 0 for every core
  NXArray *_sources;                      ///< Event sources which are attached
  void *_hid;                             ///< picofuse's HID, while it runs, or NULL
  NXEnvironment *_environment;            ///< From NXApplicationMain, or nil
  NXMap *_flags;                          ///< The flags' values, from NXApplicationMain
  BOOL _hardware;                         ///< YES to poll picofuse's hardware
}

/**
 * @brief Returns the application, which is made the first time, and never deallocated.
 */
+ (NXApplication *)sharedApplication;

/**
 * @brief Runs the shared application, as -run does.
 */
+ (int)run;

/**
 * @brief Runs the application's run loop, until it's terminated. The thread which calls
 * this is worker 0.
 * @return The status it was terminated with, or -1 if it couldn't run.
 */
- (int)run;

/**
 * @brief Returns the application's run loop, to post events to.
 */
- (NXRunLoop *)runLoop;

/**
 * @brief Returns the command line and the system, from NXApplicationMain, or nil if it
 * wasn't started with it.
 */
- (NXEnvironment *)environment;

/**
 * @brief Returns the value of every flag given to NXApplicationMain, keyed by its long
 * name, or nil if it wasn't started with it.
 */
- (NXMap *)flags;

/**
 * @brief Returns the number of workers, which is 0 for one on every core.
 */
- (uint8_t)workers;

/**
 * @brief Sets the number of workers, before it runs: 0 for one on every core, or 1, the
 * default, to dispatch every event on the thread which runs it.
 */
- (void)setWorkers:(uint8_t)workers;

/**
 * @brief Returns the delegate, which isn't retained.
 */
- (id<NXApplicationDelegate>)delegate;

/**
 * @brief Sets the delegate, which isn't retained.
 */
- (void)setDelegate:(id<NXApplicationDelegate>)delegate;

/**
 * @brief Terminates it: once the events which have been posted are dispatched, run
 * returns a status.
 */
- (void)terminateWithStatus:(int)status;

/**
 * @brief Attaches an event source, such as a timer, which is retained until it's
 * detached. It starts producing events when the application runs, or straight away if
 * it's running, and stops when the application stops, starting again if it runs again.
 * If it can't start when the application runs, such as when there's no HID timer left,
 * it's detached.
 * @return YES, or NO if it's attached already, it isn't one of the Application
 * framework's sources, or it couldn't start.
 */
- (BOOL)attachEventSource:(id<NXEventSource>)source;

/**
 * @brief Detaches an event source, which stops producing events. Those it produced which
 * haven't been handled yet aren't.
 */
- (void)detachEventSource:(id<NXEventSource>)source;

@end

/**
 * @brief The features NXApplicationMain starts, which can be combined.
 * @ingroup Application
 */
typedef enum {
  /// None
  NXApplicationFeatureNone = 0,
  /// A worker on every core, rather than one
  NXApplicationFeatureMulticore = (1 << 0),
  /// The watchdog, where there's one, which the run loop feeds as it runs
  NXApplicationFeatureWatchdog = (1 << 1),
  /// TERM, INT and QUIT terminate it, with 128 + the signal's number
  NXApplicationFeatureSignals = (1 << 2),
  /// Standard input and output over SEGGER RTT
  NXApplicationFeatureStdioRTT = (1 << 3),
  /// Standard input and output over USB
  NXApplicationFeatureStdioUSB = (1 << 4),
} NXApplicationFeatures;

/**
 * @brief Starts the system, parses the command line, and runs the shared application
 * with a delegate, until it's terminated. Call it from main() and return what it
 * returns.
 * @ingroup Application
 * @param argc The number of arguments, from main(), which is ignored on a Pico.
 * @param argv The arguments, from main(), which are ignored on a Pico.
 * @param features The features to start.
 * @param delegateClass The class of the delegate, which conforms to
 * NXApplicationDelegate, and is made with alloc and init. Its flags are from
 * +commandLineFlags, to which --help, -h is added, which writes usage.
 * @return The status it was terminated with, 0 after --help, 2 if the command line
 * doesn't parse, or 1 if the delegate can't be made.
 *
 * \code
 * @implementation Controller
 * + (NXArray *)commandLineFlags {
 *   return [NXArray arrayWithObjects:[NXArgument argumentWithName:@"verbose" short:@"v"], nil];
 * }
 * @end
 *
 * int main(int argc, char *argv[]) {
 *   return NXApplicationMain(argc, argv,
 *       NXApplicationFeatureWatchdog | NXApplicationFeatureSignals, [Controller class]);
 * }
 * \endcode
 */
int NXApplicationMain(int argc, char **argv, NXApplicationFeatures features,
                      Class delegateClass);
