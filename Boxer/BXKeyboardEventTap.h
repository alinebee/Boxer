/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Foundation/Foundation.h>

typedef enum {
    BXKeyboardEventTapNotTapping,
    BXKeyboardEventTapTappingSystemEventsOnly,
    BXKeyboardEventTapTappingAllKeyboardEvents,
} BXKeyboardEventTapStatus;

@class ADBContinuousThread;
@protocol BXKeyboardEventTapDelegate;

/// Manages a low-level event tap that captures keyboard events, giving Boxer the ability to respond to them
/// (and potentially swallow them) before they reach the system and trigger system-wide hotkey functions.
@interface BXKeyboardEventTap : NSObject
{
    ADBContinuousThread *_tapThread;
    CFMachPortRef _tap;
    CFRunLoopSourceRef _source;
    BOOL _enabled;
    BOOL _usesDedicatedThread;
    BXKeyboardEventTapStatus _status;
    
    __unsafe_unretained id <BXKeyboardEventTapDelegate> _delegate;
}

/// The delegate whom we will ask for event-capture decisions.
@property (assign) id <BXKeyboardEventTapDelegate> delegate;

/// Whether the event tap should capture system hotkeys and media keys.
/// Toggling this will attach/detach the event tap.
@property (assign, nonatomic, getter=isEnabled) BOOL enabled;

/// The current status of the event tap. See BXKeyboardEventTapStatus constants.
@property (readonly) BXKeyboardEventTapStatus status;

/// Whether our tap is able to capture keyup/keydown events, which require special accessibiity privileges.
/// In OS X 10.8 and below, this will be YES if the accessibility API is enabled: i.e. "Enable access for assistive devices" is turned on.
/// In OS X 10.9 and above, this will be YES if Boxer has been given accessibility control in the Security & Privacy preferences pane.
/// @note Even if this returns NO, the event tap may still be able to attach: in which case it will only catch media key events
/// and not all keyboard events.
@property (readonly, nonatomic) BOOL canCaptureKeyEvents;

/// Whether the event tap should run on a separate thread or the main thread.
/// A separate thread prevents input lag in other apps when the main thread is busy.
/// Changing this while a tap is in progress will stop and restart the tap.
@property (assign, nonatomic) BOOL usesDedicatedThread;

@end


/// A protocol for responding to delegate messages sent by a BXKeyboardEventTap instance.
@protocol BXKeyboardEventTapDelegate <NSObject>

/// Called when a BXKeyboardEventTap instance receives a keyup or keydown event,
/// before the event reaches the default OS X handler for dispatch.
/// @param tap      The BXKeyboardEventTap instance that received the key event.
/// @param event    The NSKeyUp/NSKeyDown event received by the tap.
/// @return YES if the event tap should swallow the without passing it on to the system.
/// @return NO if the event tap should let the event reach the system unmolested.
/// @note This may be called on a thread other than the main thread.
- (BOOL) eventTap: (BXKeyboardEventTap *)tap shouldCaptureKeyEvent: (NSEvent *)event;

/// Called when a BXKeyboardEventTap instance receives a system-defined event,
/// before the event reaches the default OS X handler for dispatch.
/// @param tap      The BXKeyboardEventTap instance that received the system-defined event.
/// @param event    The event received by the tap. The event will be of type NX_SYSDEFINED,
///                 and it is the responsibility of the delegate to parse the event's data.
/// @return YES if the event tap should swallow the without passing it on to the system.
/// @return NO if the event tap should let the event reach the system unmolested.
/// @note This may be called on a thread other than the main thread.
- (BOOL) eventTap: (BXKeyboardEventTap *)tap shouldCaptureSystemDefinedEvent: (NSEvent *)event;

@end
