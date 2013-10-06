/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <AppKit/AppKit.h> //For NSApp
#import <Carbon/Carbon.h> //For keycodes
#import <IOKit/hidsystem/ev_keymap.h> //For media key codes

#import "BXKeyboardEventTap.h"
#import "ADBContinuousThread.h"


@interface BXKeyboardEventTap ()

//The dedicated thread on which our tap runs.
@property (retain) ADBContinuousThread *tapThread;

//Our CGEventTap callback. Receives the BXKeyboardEventTap instance as the userInfo parameter,
//and passes handling directly on to it. 
static CGEventRef _handleEventFromTap(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo);

//Actually does the work of handling the event. Checks
- (CGEventRef) _handleEvent: (CGEventRef)event
                     ofType: (CGEventType)type
                  fromProxy: (CGEventTapProxy)proxy;

//Creates an event tap, and starts up a dedicated thread to monitor it (if usesDedicatedThread is YES)
//or adds it to the main thread (if usesDedicatedThread is NO).
- (void) _startTapping;

//Removes the tap and any dedicated thread we were running it on.
- (void) _stopTapping;

//Runs continuously on tapThread, listening to the tap until _stopTapping is called and the thread is cancelled.
- (void) _runTapInDedicatedThread;

@end


@implementation BXKeyboardEventTap
@synthesize enabled = _enabled;
@synthesize usesDedicatedThread = _usesDedicatedThread;
@synthesize tapThread = _tapThread;
@synthesize delegate = _delegate;

- (id) init
{
    self = [super init];
    if (self)
    {
        self.usesDedicatedThread = NO;
        
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
    [self willChangeValueForKey: @"canCaptureKeyEvents"];
    if (!self.isTapping && self.isEnabled && self.canCaptureKeyEvents)
    {
        [self _startTapping];
    }
    [self didChangeValueForKey: @"canCaptureKeyEvents"];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    
    [self _stopTapping];
    self.tapThread = nil;
    
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

- (void) setUsesDedicatedThread: (BOOL)usesDedicatedThread
{
    if (usesDedicatedThread != self.usesDedicatedThread)
    {
        BOOL wasTapping = self.isTapping;
        if (wasTapping)
        {
            [self _stopTapping];
        }
        
        _usesDedicatedThread = usesDedicatedThread;
        
        if (wasTapping)
        {
            [self _startTapping];
        }
    }
}

- (BOOL) canCaptureKeyEvents
{
    return (AXAPIEnabled() || AXIsProcessTrusted());
}

- (BOOL) isTapping
{
    return _tap != NULL;
}

- (void) _startTapping
{
    if (!self.isTapping)
    {
        //Create the event tap, and keep a reference to it as an instance variable
        //so that we can access it from our callback if needed.
        //This will fail and return NULL if Boxer does not have permission to tap
        //keyboard events.
        CGEventMask eventTypes = CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(NX_SYSDEFINED);
        _tap = CGEventTapCreate(kCGSessionEventTap,
                                kCGHeadInsertEventTap,
                                kCGEventTapOptionDefault,
                                eventTypes,
                                _handleEventFromTap,
                                (__bridge void *)self);
        
        if (_tap)
        {
            _source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _tap, 0);
            
            //Decide whether to run the tap on a dedicated thread or on the main thread.
            if (self.usesDedicatedThread)
            {
#ifdef BOXER_DEBUG
                NSLog(@"Installing event tap on dedicated thread.");
#endif
                //_runTapInDedicatedThread will handle adding and removing the source
                //on its own run loop.
                self.tapThread = [[[ADBContinuousThread alloc] initWithTarget: self
                                                                    selector: @selector(_runTapInDedicatedThread)
                                                                      object: nil] autorelease];
                
                [self.tapThread start];
            }
            else
            {
#ifdef BOXER_DEBUG
                NSLog(@"Installing event tap on main thread.");
#endif
                CFRunLoopAddSource(CFRunLoopGetMain(), _source, kCFRunLoopCommonModes);
            }
        }
    }
}

- (void) _stopTapping
{
    if (self.isTapping)
    {
        if (self.usesDedicatedThread && self.tapThread)
        {
            [self.tapThread cancel];
            [self.tapThread waitUntilFinished];
            self.tapThread = nil;
        }
        else
        {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), _source, kCFRunLoopCommonModes);
        }
        
        //Clean up the event tap and source after ourselves.
        CFMachPortInvalidate(_tap);
        CFRunLoopSourceInvalidate(_source);
        
        CFRelease(_source);
        CFRelease(_tap);
        
        _tap = NULL;
        _source = NULL;
    }
}

- (void) _runTapInDedicatedThread
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    if (_source != NULL)
    {
        CFRetain(_source);
        
        //Create a source on the thread's run loop so that we'll receive messages
        //from the tap when an event comes in.
        CFRunLoopAddSource(CFRunLoopGetCurrent(), _source, kCFRunLoopCommonModes);
        
        //Run this thread's run loop until we're told to stop, processing event-tap
        //callbacks and other messages on this thread.
        [(ADBContinuousThread *)[NSThread currentThread] runUntilCancelled];
        
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _source, kCFRunLoopCommonModes);
        
        CFRelease(_source);
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
    
    switch (type)
    {
        case kCGEventKeyDown:
        case kCGEventKeyUp:
        case NX_SYSDEFINED:
        {
            BOOL shouldCapture = NO;
            
            //First try and make this into a cocoa event
            NSEvent *cocoaEvent = nil;
            @try
            {
                cocoaEvent = [NSEvent eventWithCGEvent: event];
            }
            @catch (NSException *exception) 
            {
#ifdef BOXER_DEBUG
                //If the event could not be converted into a cocoa event, give up
                CFStringRef eventDesc = CFCopyDescription(event);
                NSLog(@"Could not convert CGEvent: %@", (__bridge NSString *)eventDesc);
                CFRelease(eventDesc);
#endif
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
            
            if (shouldCapture)
            {
                [NSApp postEvent: cocoaEvent atStart: YES];
                
                //This approach ought to be closer to the normal behaviour
                //of the event dispatch mechanism, but seems to result
                //in key events occasionally getting lost, causing stuck keys.
                //So we go with a more explicit NSEvent-based dispatch instead.
                /*
                 ProcessSerialNumber PSN;
                 OSErr error = GetCurrentProcess(&PSN);
                 if (error == noErr)
                 {
                 CGEventPostToPSN(&PSN, event);
                 
                 //Returning NULL cancels the original event
                 return NULL;
                 }
                 */
                
                //Returning NULL cancels the original event
                return NULL;
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
            
        case kCGEventTapDisabledByUserInput:
        {
            //Re-enable the event tap if it has been disabled after a timeout.
            //(This may occur if our thread has been blocked for some reason.)
            CGEventTapEnable(_tap, YES);
            break;
        }
    }
    
    return event;
}

static CGEventRef _handleEventFromTap(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo)
{
    CGEventRef returnedEvent = event;
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    BXKeyboardEventTap *tap = (__bridge BXKeyboardEventTap *)userInfo;
    if (tap)
    {
        returnedEvent = [tap _handleEvent: event ofType: type fromProxy: proxy];
    }
    [pool drain];
    
    return returnedEvent;
}

@end
