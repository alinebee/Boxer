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

/// The dedicated thread on which our tap runs. Only used if @c usesDedicatedThread is YES.
@property (retain) ADBContinuousThread *tapThread;

//Overridden to be read-write.
@property (readwrite, getter=isTapping) BXKeyboardEventTapStatus status;
@property (readwrite) BOOL restartNeeded;

///Our CGEventTap callback. Receives the BXKeyboardEventTap instance as the userInfo parameter, and passes handling directly on to it.
static CGEventRef _handleEventFromTap(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo);

/// Receives keyboard and system events and asks our delegate whether to let them go through
/// or swallow them whole.
- (CGEventRef) _handleEvent: (CGEventRef)event
                     ofType: (CGEventType)type
                  fromProxy: (CGEventTapProxy)proxy;

/// Creates an event tap, and starts up a dedicated thread to monitor it (if @c usesDedicatedThread is YES)
/// or adds it to the main thread (if @c usesDedicatedThread is NO).
- (void) _startTapping;

/// Removes the tap and cancels any dedicated thread we were running it on.
- (void) _stopTapping;

/// Runs continuously on tapThread, listening to the tap until _stopTapping is called and the thread is cancelled.
- (void) _runTapInDedicatedThread;

/// Attempts to find our current tap in @c CGGetTapList() and checks what event types it was actually permitted to listen to.
- (BXKeyboardEventTapStatus) _reportedStatusOfEventTap;

@end


@implementation BXKeyboardEventTap
@synthesize enabled = _enabled;
@synthesize usesDedicatedThread = _usesDedicatedThread;
@synthesize tapThread = _tapThread;
@synthesize delegate = _delegate;
@synthesize status = _status;
@synthesize restartNeeded = _restartNeeded;

- (id) init
{
    self = [super init];
    if (self)
    {
        self.usesDedicatedThread = NO;
    }
    return self;
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
        
        if (flag)
            [self _startTapping];
        else
            [self _stopTapping];
    }
}

- (void) setUsesDedicatedThread: (BOOL)usesDedicatedThread
{
    if (usesDedicatedThread != self.usesDedicatedThread)
    {
        BOOL wasTapping = self.status != BXKeyboardEventTapNotTapping;
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

+ (BOOL) canCaptureKeyEvents
{
    return AXAPIEnabled() || AXIsProcessTrusted();
}

- (BXKeyboardEventTapStatus) _reportedStatusOfEventTap
{
    NSUInteger i, numTaps = 0;
    CGGetEventTapList(0, NULL, &numTaps);
    
    BXKeyboardEventTapStatus status = BXKeyboardEventTapNotTapping;
    if (numTaps > 0)
    {
        CGEventTapInformation *taps = malloc(sizeof(CGEventTapInformation) * numTaps);
        CGGetEventTapList(numTaps, taps, &numTaps);
        
        pid_t processID = [NSProcessInfo processInfo].processIdentifier;
        for (i=0; i<numTaps; i++)
        {
            CGEventTapInformation tap = taps[i];
            
            //FIXME: this assumes our process only has a single tap going at once.
            //Unfortunately we have no other way to determine if this tap is our own or not.
            if (tap.tappingProcess == processID)
            {
                CGEventMask keyEvents = CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventKeyDown);
                CGEventMask systemEvents = CGEventMaskBit(NX_SYSDEFINED);
                
                if ((tap.eventsOfInterest & keyEvents) == keyEvents)
                {
                    status = BXKeyboardEventTapTappingAllKeyboardEvents;
                }
                else if ((tap.eventsOfInterest & systemEvents) == systemEvents)
                {
                    status = BXKeyboardEventTapTappingSystemEventsOnly;
                }
                else
                {
                    status = BXKeyboardEventTapNotTapping;
                }
                
                break;
            }
        }
        free(taps);
    }
    
    return status;
}

- (BOOL) _installEventTapOnCurrentThread
{
    @synchronized(self)
    {
        //Captures keyup and keydown events. We use this for intercepting OS X hotkeys.
        CGEventMask keyEvents = CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventKeyDown);
        
        //Captures system-defined events. We use this for intercepting media keys.
        CGEventMask systemEvents = CGEventMaskBit(NX_SYSDEFINED);
        
        _tap = CGEventTapCreate(kCGSessionEventTap, 
                                kCGHeadInsertEventTap,
                                kCGEventTapOptionDefault,
                                keyEvents | systemEvents,
                                _handleEventFromTap,
                                (__bridge void *)self);
        
        if (_tap)
        {
            _source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _tap, 0);
            CFRunLoopAddSource(CFRunLoopGetCurrent(), _source, kCFRunLoopCommonModes);
            
            //CGEventTapCreate will silently disable event capture for keyup/keydown events if we don't have permission to tap them.
            //However, the tap may still be installed and only capturing system events: so we need to check what events it's actually
            //tapping.
            BXKeyboardEventTapStatus reportedStatus = [self _reportedStatusOfEventTap];
            switch (reportedStatus)
            {
                case BXKeyboardEventTapTappingAllKeyboardEvents:
                    NSLog(@"Event tap created and tapping all keyboard events.");
                    self.status = reportedStatus;
                    self.restartNeeded = NO;
                    return YES;
                case BXKeyboardEventTapTappingSystemEventsOnly:
                    NSLog(@"Event tap created but tapping system events only.");
                    self.status = reportedStatus;
                    return YES;
                case BXKeyboardEventTapNotTapping:
                case BXKeyboardEventTapInstalling: //Will never be returned by _reportedStatusOfEventTap, but included anyway to suppress compiler warnings.
                    NSLog(@"Event tap created but could not capture any relevant events: discarding.");
                    [self _removeEventTapFromCurrentThread];
                    self.status = reportedStatus;
                    return NO;
            }
        }
        else
        {
            NSLog(@"Event tap could not be created");
            self.status = BXKeyboardEventTapNotTapping;
            return NO;
        }
    }
}

- (void) _removeEventTapFromCurrentThread
{
    @synchronized(self)
    {
        if (_source)
        {
            CFRunLoopSourceInvalidate(_source);
            CFRelease(_source);
            _source = NULL;
        }
        
        if (_tap)
        {
            CFMachPortInvalidate(_tap);
            CFRelease(_tap);
            _tap = NULL;
        }
        
        self.status = BXKeyboardEventTapNotTapping;
    }
}

- (void) refreshEventTap
{
    if (self.isEnabled)
    {
        [self _stopTapping];
        [self _startTapping];
    }
}

- (void) _startTapping
{
    if (self.status == BXKeyboardEventTapNotTapping)
    {
        self.status = BXKeyboardEventTapInstalling;
        if (self.usesDedicatedThread)
        {
            NSLog(@"Installing event tap on dedicated thread.");
            self.tapThread = [[[ADBContinuousThread alloc] initWithTarget: self
                                                                 selector: @selector(_runTapInDedicatedThread)
                                                                   object: nil] autorelease];
            
            [self.tapThread start];
        }
        else
        {
            NSLog(@"Installing event tap on main thread.");
            [self _installEventTapOnCurrentThread];
            [self.delegate eventTapDidFinishAttaching: self];
        }
    }
}

- (void) _runTapInDedicatedThread
{
    @autoreleasepool {
    
    BOOL installed = [self _installEventTapOnCurrentThread];
    [self.delegate eventTapDidFinishAttaching: self];
    
    if (installed)
    {
        //Run this thread's run loop until we're told to stop: processing event-tap
        //callbacks and other messages on this thread.
        [(ADBContinuousThread *)[NSThread currentThread] runUntilCancelled];
        
        //Clean up the tap once the thread is cancelled
        [self _removeEventTapFromCurrentThread];
    }
    
    }
}

- (void) _stopTapping
{
    if (self.status != BXKeyboardEventTapNotTapping)
    {
        if (self.usesDedicatedThread && self.tapThread)
        {
            //The thread will clean itself up
            [self.tapThread cancel];
            [self.tapThread waitUntilFinished];
            self.tapThread = nil;
        }
        else
        {
            [self _removeEventTapFromCurrentThread];
        }
    }
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
    
    @autoreleasepool {
    BXKeyboardEventTap *tap = (__bridge BXKeyboardEventTap *)userInfo;
    if (tap)
    {
        returnedEvent = [tap _handleEvent: event ofType: type fromProxy: proxy];
    }
    }
    
    return returnedEvent;
}

@end
