/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <AppKit/AppKit.h> //For NSApp
#import <Carbon/Carbon.h> //For keycodes
#import "BXKeyboardEventTap.h"
#import "BXAppController.h"
#import "BXSession.h"


@interface BXKeyboardEventTap ()

static CGEventRef _handleEventFromTap(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo);

- (CGEventRef) _handleEvent: (CGEventRef)event
                     ofType: (CGEventType)type
                  fromProxy: (CGEventTapProxy)proxy;

- (BOOL) _installTap;
- (void) _removeTap;

- (BOOL) _shouldHandleEvents;

@end


@implementation BXKeyboardEventTap
@synthesize enabled = _enabled;

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
    if (!_tap && [self isEnabled] && [self canTapEvents])
    {
        [self _installTap];
    }
    [self didChangeValueForKey: @"canTapEvents"];
}

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver: self];
    [self unbind: @"enabled"];
    
    [self _removeTap];
    [super dealloc];
}

- (void) setEnabled: (BOOL)flag
{
    if (_enabled != flag)
    {
        _enabled = flag;
        if (flag) [self _installTap];
        else [self _removeTap];
    }
}

- (BOOL) canTapEvents
{
    return (AXAPIEnabled() || AXIsProcessTrusted());
}

- (BOOL) _installTap
{
    if (!_tap)
    {
        _tap = CGEventTapCreate(kCGSessionEventTap,
                                kCGHeadInsertEventTap,
                                kCGEventTapOptionDefault,
                                CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventKeyDown),
                                _handleEventFromTap,
                                self);
        
        if (_tap)
        {
            CFRunLoopSourceRef source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _tap, 0);
            //Install the source on the main run loop, where events are normally processed.
            CFRunLoopAddSource(CFRunLoopGetMain(), source, kCFRunLoopCommonModes);
            //Adding the source to the run loop will retain it, so we can ditch our own reference.
            CFRelease(source);
        }
        
    }
    
    //TODO: populate an error if the tap failed.
    return (_tap != NULL);
}


- (void) _removeTap
{
    if (_tap)
    {
        
        CFMachPortInvalidate(_tap);
        CFRelease(_tap);
        _tap = NULL;
    }
}

- (BOOL) _shouldHandleEvents
{
    if (![self isEnabled]) return NO;
    if (![NSApp isActive]) return NO;
    
    if (![[[NSApp delegate] currentSession] programIsActive]) return NO;
    
    return YES;
}

- (CGEventRef) _handleEvent: (CGEventRef)event
                     ofType: (CGEventType)type
                  fromProxy: (CGEventTapProxy)proxy
{
    if ([self _shouldHandleEvents]) switch (type)
    {
        case kCGEventKeyDown:
        case kCGEventKeyUp:
        {
            int64_t keyCode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
            
            BOOL intercept;
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
                    intercept = YES;
                    break;
                default:
                    intercept = NO;
            }
            
            //If this is an event we want to handle ourselves,
            //post it directly to our application and don't let
            //it go through the regular OS X event dispatch.
            if (intercept)
            {
                NSEvent *keyboardEvent = [NSEvent eventWithCGEvent: event];
                [NSApp postEvent: keyboardEvent atStart: YES];
                return NULL;
            }
            break;
        }
        
        case kCGEventTapDisabledByTimeout:
        {
            //Re-enable the event tap if it has been disabled after a timeout.
            //(This may occur if our main thread is blocked for too long.)
            CGEventTapEnable(_tap, YES);
            break;
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
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        returnedEvent = [tap _handleEvent: event ofType: type fromProxy: proxy];
        [pool drain];
    }
    
    return returnedEvent;
}

@end
