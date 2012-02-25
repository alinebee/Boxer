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
#import "BXAppController.h"
#import "BXSession.h"
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

//Returns whether the specified keyup/down event represents an OS X hotkey we want to intercept.
- (BOOL) _isHotKeyEvent: (CGEventRef)event;

//Returns whether the specified system-defined event represents an OS X media key.
- (BOOL) _isMediaKeyEvent: (CGEventRef)event;

//Returns whether we should bother suppressing the specified hotkey event. Will return YES
//if we're the active application and the key window is an active (not paused) DOS session,
//NO otherwise.
- (BOOL) _shouldCaptureHotKeyEvent: (CGEventRef)event;

//Returns whether we should capture the specified media key.
- (BOOL) _shouldCaptureMediaKeyEvent: (CGEventRef)event;

@end


@implementation BXKeyboardEventTap
@synthesize enabled = _enabled;
@synthesize tapThread = _tapThread;

- (void) awakeFromNib
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [self bind: @"enabled"
      toObject: defaults
   withKeyPath: @"suppressSystemHotkeys"
       options: nil];
    
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver: self
               selector: @selector(applicationDidBecomeActive:)
                   name: NSApplicationDidBecomeActiveNotification
                 object: NSApp];
    
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

- (BOOL) _isMediaKeyEvent: (CGEventRef)event
{
    //System-defined hotkey events need a little more deciphering than other kotkey events,
    //and it's easier to do this with the NSEvent API.
    //Adapted from https://github.com/nevyn/SPMediaKeyTap/blob/master/SPMediaKeyTap.m
    NSEvent *cocoaEvent;
    @try
    {
        cocoaEvent = [NSEvent eventWithCGEvent: event];
    }
    //If the event could not be converted into an NSEvent, we can't manage it anyway.
    @catch (NSException * e) { return NO; }
    
    //Event was not of the correct subtype to be a media key event.
    if (cocoaEvent.subtype != 8)
        return NO;
    
    int keyCode = (cocoaEvent.data1 & 0xFFFF0000) >> 16;
    
    switch(keyCode)
    {
        case NX_KEYTYPE_PLAY:
        case NX_KEYTYPE_FAST:
        case NX_KEYTYPE_REWIND:
            return YES;
            break;
        default:
            return NO;
    }
}

//TODO: move this logic off to the current DOS session
- (BOOL) _isHotKeyEvent: (CGEventRef)event
{
    int64_t keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    
    switch(keyCode)
    {
        case kVK_UpArrow:
        case kVK_DownArrow:
        case kVK_LeftArrow:
        case kVK_RightArrow:
        case kVK_F1:
        case kVK_F2:
        case kVK_F3:
        case kVK_F4:
        case kVK_F5:
        case kVK_F6:
        case kVK_F7:
        case kVK_F8:
        case kVK_F9:
        case kVK_F10:
        case kVK_F11:
        case kVK_F12:
            return YES;
            break;
        default:
            return NO;
    }
}

- (BOOL) _shouldCaptureHotKeyEvent: (CGEventRef)event
{
    if (![self isEnabled]) return NO;
    if (![NSApp isActive]) return NO;
    
    BOOL retVal = NO;
    
    //Allow hotkeys to be captured as long as the key window is an active DOS session.
    //TODO: pass this decision to the application delegate itself.
    @synchronized([NSApp delegate])
    {
        id document = [[NSApp delegate] documentForWindow: [NSApp keyWindow]];
        @synchronized(document)
        {
            if ([document respondsToSelector: @selector(programIsActive)] && [document programIsActive])
                retVal = YES;
        }
    }
    return retVal;
}

- (BOOL) _shouldCaptureMediaKeyEvent: (CGEventRef)event
{
    if (![self isEnabled]) return NO;
    if (![NSApp isActive]) return NO;
    
    BOOL retVal = NO;
    
    //Allow media keys to be captured as long as the current DOS session is running (even if it is at the DOS prompt).
    //TODO: pass this decision to the application delegate itself.
    @synchronized([NSApp delegate])
    {
        BXSession *currentSession = [[NSApp delegate] currentSession];
        @synchronized(currentSession)
        {
            if (currentSession.isEmulating)
                retVal = YES;
        }
    }
    return retVal;
}

- (CGEventRef) _handleEvent: (CGEventRef)event
                     ofType: (CGEventType)type
                  fromProxy: (CGEventTapProxy)proxy
{
    BOOL shouldCapture = NO;
    switch (type)
    {
        case kCGEventKeyDown:
        case kCGEventKeyUp:
        {
            //If this is a hotkey event we want to handle ourselves,
            //post it directly to our application and don't let it
            //go through the regular OS X event dispatch.
            if ([self _isHotKeyEvent: event] && [self _shouldCaptureHotKeyEvent: event])
                shouldCapture = YES;
            break;
        }
        case NX_SYSDEFINED:
        {
            if ([self _isMediaKeyEvent: event] && [self _shouldCaptureMediaKeyEvent: event])
                shouldCapture = YES;
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
    
    BXKeyboardEventTap *tap = (BXKeyboardEventTap *)userInfo;
    if (tap)
    {
        returnedEvent = [tap _handleEvent: event ofType: type fromProxy: proxy];
    }
    
    return returnedEvent;
}

@end
