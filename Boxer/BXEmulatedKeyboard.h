/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Foundation/Foundation.h>
#import "keyboard.h"


/// How long keyPressed: should pretend to hold the specified key down before releasing.
#define BXKeyPressDurationDefault 0.25

/// How long typeCharacters should wait in between bursts of simulated typing.
/// This needs to be high enough that we don't overload a DOS program's own keyboard handling.
#define BXTypingBurstIntervalDefault 1.0

/// How long to wait after finishing a batch of simulated typing, before returning the keyboard state to normal.
#define BXTypingCleanupDelay 0.5

/// When simulating typing, this many slots will be reserved in the emulated keyboard buffer to avoid flooding.
#define BXTypingKeyboardBufferReserve 3

typedef KBD_KEYS BXDOSKeyCode;

/// \c BXEmulatedKeyboard represents the DOS PC's keyboard hardware, and offers an API for sending
/// emulated key events and setting keyboard layout.
@interface BXEmulatedKeyboard : NSObject
{
	BOOL _capsLockEnabled;
	BOOL _numLockEnabled;
    BOOL _scrollLockEnabled;
    NSUInteger _pressedKeys[KBD_LAST];
    
    /// Whether to re-enable capslock and the active layout
    /// once a simulated typing session is finished.
    BOOL _enableActiveLayoutAfterTyping;
    BOOL _enableCapslockAfterTyping;
    
	NSString *_preferredLayout;
    
    __unsafe_unretained NSTimer *_pendingKeypresses;
}

/// NOTE: these are only readwrite for the sake of BXCoalface.
/// They should not be modified by code outside BXEmulator.
@property (assign) BOOL capsLockEnabled;
@property (assign) BOOL numLockEnabled;
@property (assign) BOOL scrollLockEnabled;

/// The DOS keyboard layout that is currently in use.
@property (copy, nonatomic) NSString *activeLayout;

/// Whether to map keyboard input through the active keyboard layout.
/// If NO, input will be mapped according to a standard US keyboard layout instead.
@property (assign, nonatomic) BOOL usesActiveLayout;

/// The DOS keyboard layout that will be applied once emulation has started up.
/// Set whenever activeLayout is changed.
@property (copy) NSString *preferredLayout;

/// Returns \c YES if the emulated keyboard buffer is full, meaning further key events will be ignored.
@property (readonly) BOOL keyboardBufferFull;

/// Whether we are currently typing text into the keyboard. Will be \c YES while the input from
/// \c typeCharacters: is being processed.
@property (readonly) BOOL isTyping;


#pragma mark -
#pragma mark Keyboard input

/// Press the specified key.
- (void) keyDown: (BXDOSKeyCode)key;
/// Release the specified key.
- (void) keyUp: (BXDOSKeyCode)key;

/// Release all currently-pressed keys, as if the user took their hands off the keyboard.
- (void) clearInput;

/// Release all current presses of the specified key, regardless of how many times \c keyDown:
/// has been called on it.
- (void) clearKey: (BXDOSKeyCode)key;

/// Imitate the key being pressed and then released after the default/specified duration.
- (void) keyPressed: (BXDOSKeyCode)key;
- (void) keyPressed: (BXDOSKeyCode)key forDuration: (NSTimeInterval)duration;

/// Returns whether the specified key is currently pressed.
- (BOOL) keyIsDown: (BXDOSKeyCode)key;

/// Simulate typing the specified characters into the keyboard.
/// To avoid flooding the keyboard buffer, characters will be sent
/// in bursts with the specified interval between bursts.
- (void) typeCharacters: (NSString *)characters burstInterval: (NSTimeInterval)interval;
- (void) typeCharacters: (NSString *)characters;

/// Cancel any pending keydown events and empty the queue.
- (void) cancelTyping;



#pragma mark -
#pragma mark 

/// The default DOS keyboard layout that should be used if no more specific one can be found.
+ (NSString *)defaultKeyboardLayout;

@end
