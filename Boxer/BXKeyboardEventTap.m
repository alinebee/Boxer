/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <AppKit/AppKit.h> //For NSApp
#import <Carbon/Carbon.h> //For keycodes
#import <IOKit/hidsystem/ev_keymap.h> //For media key codes

#import "BXKeyboardEventTap.h"
#import "BXContinuousThread.h"


@interface BXKeyboardEventTap ()

//The thread on which our tap is running.
@property (retain) BXContinuousThread *tapThread;

//Our CGEventTap callback. Receives the BXKeyboardEventTap instance as the userInfo parameter,
//and passes handling directly on to it. 
static CGEventRef _handleEventFromTap(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo);

//Actually does the work of handling the event. Checks
- (CGEventRef) _handleEvent: (CGEventRef)event
                     ofType: (CGEventType)type
                  fromProxy: (CGEventTapProxy)proxy;

//Executes _runTap in a separate continuous thread.
- (void) _startTapping;

//Cancels the tapping thread and waits for it to finish.
- (void) _stopTapping;

//Runs continuously on tapThread. Creates an event tap and pumps
//tapThread's run loop, listening to the tap until the thread is cancelled.
- (void) _runTap;

@end


@implementation BXKeyboardEventTap
@synthesize enabled = _enabled;
@synthesize tapThread = _tapThread;
@synthesize delegate = _delegate;

- (id) init
{
    if ((self = [super init]))
    {
        NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
        [center addObserver: self
                   selector: @selector(applicationDidBecomeActive:)
                       name: NSApplicationDidBecomeActiveNotification
                     object: NSApp];
    }
    return self;
}

- (void) applicationDidBecomeActive: (NSNotification *)notification
{
    //Listen for when Boxer becomes the active application and re-check
    //the availability of the accessibility API at this point.
    //If the API is available, attempt to reestablish a tap if we're
    //enabled and don't already have one (which means it failed when
    //we tried it the last time.)
    [self willChangeValueForKey: @"canTapEvents"];
    if (![self isTapping] && [self isEnabled] && [self canTapEvents])
    {
        [self _startTapping];
    }
    [self didChangeValueForKey: @"canTapEvents"];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [self unbind: @"enabled"];
    
    [self _stopTapping];
    [self setTapThread: nil], [_tapThread release];
    
    [super dealloc];
}

- (void) setEnabled: (BOOL)flag
{
    if (_enabled != flag)
    {
        _enabled = flag;
        
        if (flag) [self _startTapping];
        else [self _stopTapping];
    }
}

- (BOOL) canTapEvents
{
    return (AXAPIEnabled() || AXIsProcessTrusted());
}

- (BOOL) isTapping
{
    return [[self tapThread] isExecuting];
}

- (void) _startTapping
{
    if (![self isTapping])
    {
        BXContinuousThread *thread = [[BXContinuousThread alloc] initWithTarget: self
                                                                       selector: @selector(_runTap)
                                                                         object: nil];
        
        [thread start];
        [self setTapThread: thread];
        [thread release];
    }
}

- (void) _stopTapping
{
    if ([self isTapping])
    {
        [[self tapThread] cancel];
        [[self tapThread] waitUntilFinished];
        [self setTapThread: nil];
    }
}

- (void) _runTap
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    //Create the event tap, and keep a reference to it as an instance variable
    //so that we can access it from our callback if needed.
    //This will fail and return NULL if Boxer does not have permission to tap
    //keyboard events.
    _tap = CGEventTapCreate(kCGSessionEventTap,
                            kCGHeadInsertEventTap,
                            kCGEventTapOptionDefault,
                            CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(NX_SYSDEFINED),
                            _handleEventFromTap,
                            self);
        
    if (_tap != NULL)
    {
        //Create a source on the thread's run loop so that we'll receive messages
        //from the tap when an event comes in.
        CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _tap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
        
        //Run this thread's run loop until we're told to stop, processing event-tap
        //callbacks and other messages on this thread.
        [(BXContinuousThread *)[NSThread currentThread] runUntilCancelled];
        
        //Clean up the event tap and source after ourselves.
        CFMachPortInvalidate(_tap);
        CFRunLoopSourceInvalidate(source);
        
        CFRelease(source);
        CFRelease(_tap);
        
        _tap = NULL;
    }
    
    [pool drain];
}

- (CGEventRef) _handleEvent: (CGEventRef)event
                     ofType: (CGEventType)type
                  fromProxy: (CGEventTapProxy)proxy
{
    //If we're not enabled or we have no way of validating the events, give up early
    if (!self.enabled || !self.delegate)
    {
        return event;
    }
    
    BOOL shouldCapture = NO;
    switch (type)
    {
        case kCGEventKeyDown:
        case kCGEventKeyUp:
        case NX_SYSDEFINED:
        {
            //First try and make this into a cocoa event
            NSEvent *cocoaEvent = nil;
            @try
            {
                cocoaEvent = [NSEvent eventWithCGEvent: event];
            }
            @catch (NSException *exception) {
                //If the event could not be converted into a cocoa event, give up
            }
            
            if (cocoaEvent)
            {
                if (type == NX_SYSDEFINED)
                {
                    shouldCapture = [self.delegate eventTap: self shouldCaptureSystemDefinedEvent: cocoaEvent];
                }
                else
                {
                    shouldCapture = [self.delegate eventTap: self shouldCaptureKeyEvent: cocoaEvent];
                }
            }
            
            break;
        }
        
        case kCGEventTapDisabledByTimeout:
        {
            //Re-enable the event tap if it has been disabled after a timeout.
            //(This may occur if our thread has been blocked for some reason.)
            CGEventTapEnable(_tap, YES);
            break;
        }
    }
    
    if (shouldCapture)
    {
        ProcessSerialNumber PSN;
        OSErr error = GetCurrentProcess(&PSN);
        if (error == noErr)
        {
            CGEventPostToPSN(&PSN, event);
            
            //Returning NULL cancels the original event
            return NULL;
        }
    }
    
    return event;
}

static CGEventRef _handleEventFromTap(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo)
{
    CGEventRef returnedEvent = event;
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    BXKeyboardEventTap *tap = (BXKeyboardEventTap *)userInfo;
    if (tap)
    {
        returnedEvent = [tap _handleEvent: event ofType: type fromProxy: proxy];
    }
    [pool drain];
    
    return returnedEvent;
}

@end
