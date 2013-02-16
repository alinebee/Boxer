/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXInputControllerPrivate.h"
#import "BXBaseAppController.h"
#import "BXSession.h"
#import "BXJoystickController.h"
#import "BXJoypadController.h"
#import "ADBGeometry.h"
#import "BXCursorFadeAnimation.h"
#import "BXDOSWindowController.h"
#import "BXGLRenderingView.h"
#import "BXDOSWindow.h"
#import "ADBForwardCompatibility.h"
#import "ADBAppKitVersionHelpers.h"
#import "NSWindow+ADBWindowDimensions.h"

#import "BXEventConstants.h"

#import "BXEmulator.h"
#import "BXEmulatedMouse.h"
#import "BXEmulatedKeyboard.h"
#import "BXEmulatedJoystick.h"

#import "BXBezelController.h"

//For text input services notification names
#import <Carbon/Carbon.h>


@implementation BXInputController
@synthesize mouseLocked = _mouseLocked;
@synthesize mouseActive = _mouseActive;
@synthesize trackMouseWhileUnlocked = _trackMouseWhileUnlocked;
@synthesize simulatedNumpadActive = _simulatedNumpadActive;
@synthesize mouseSensitivity = _mouseSensitivity;
@synthesize availableJoystickTypes = _availableJoystickTypes;
@synthesize controllerProfiles = _controllerProfiles;
@synthesize cursorFade = _cursorFade;


#pragma mark -
#pragma mark Initialization and cleanup

- (void) awakeFromNib
{	
	//Initialize the controller profile map to an empty dictionary
	self.controllerProfiles = [NSMutableDictionary dictionaryWithCapacity: 1];
	
	//Initialize mouse sensitivity and tracking options to a suitable default
	_mouseSensitivity = 1.0f;
	_trackMouseWhileUnlocked = YES;
	
	//DOSBox-triggered cursor warp distances which fit within this deadzone will be ignored
	//to prevent needless input delays. q.v. _emulatedCursorMovedToPointInCanvas:
	_cursorWarpDeadzone = NSInsetRect(NSZeroRect, -BXCursorWarpTolerance, -BXCursorWarpTolerance);
	
	//The extent of our relative mouse canvas. Mouse coordinates passed to DOSBox will be
	//relative to this canvas and clamped to fit within it. q.v. mouseMoved:
	_canvasBounds = NSMakeRect(0.0f, 0.0f, 1.0f, 1.0f);
	
	//Used for constraining where the mouse cursor will appear when we unlock the mouse.
	//This is inset slightly from canvasBounds, because a cursor that appears right at the
	//very edge of the window looks dumb. q.v. _applyMouseLockState:
	_visibleCanvasBounds = NSMakeRect(0.01f, 0.01f, 0.98f, 0.98f);
	
	
	//Insert ourselves into the responder chain as our view's next responder
	self.nextResponder = self.view.nextResponder;
    self.view.nextResponder = self;
    
	//Tell the view to accept touch events
    self.view.acceptsTouchEvents = YES;
         
	//Set up a cursor region in the view for mouse handling
	NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited | NSTrackingEnabledDuringMouseDrag | NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect | NSTrackingAssumeInside;
	
	NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect: NSZeroRect
																options: options
																  owner: self
															   userInfo: nil];
	
	[self.view addTrackingArea: trackingArea];
	[trackingArea release];
	 
	
	//Set up our cursor fade animation
	self.cursorFade = [[[BXCursorFadeAnimation alloc] initWithDuration: BXCursorFadeDuration
                                                        animationCurve: NSAnimationEaseIn] autorelease];
    
    self.cursorFade.delegate = self;
    self.cursorFade.originalCursor = [NSCursor arrowCursor];
    self.cursorFade.animationBlockingMode = NSAnimationNonblocking;
    self.cursorFade.frameRate = BXCursorFadeFrameRate;
}

- (void) dealloc
{
    //Tidy up our view's responder chain.
    self.view.nextResponder = self.nextResponder;
    
	[self.cursorFade stopAnimation];
    
    self.cursorFade = nil;
    self.controllerProfiles = nil;
    self.availableJoystickTypes = nil;
    
	[super dealloc];
}

- (BXSession *)representedObject
{
	return (BXSession *)[super representedObject];
}

- (void) setRepresentedObject: (BXSession *)session
{
	BXSession *previousSession = self.representedObject;
	if (session != previousSession)
	{
		BXJoystickController *joystickController = [[NSApp delegate] joystickController];
        BXJoypadController *joypadController = [[NSApp delegate] joypadController];
		
		if (previousSession)
		{
			[self unbind: @"mouseSensitivity"];
			[self unbind: @"trackMouseWhileUnlocked"];
			[self unbind: @"mouseActive"];
			
			[previousSession removeObserver: self forKeyPath: @"paused"];
			[previousSession removeObserver: self forKeyPath: @"autoPaused"];
			[previousSession removeObserver: self forKeyPath: @"emulator.mouse.position"];
			[previousSession removeObserver: self forKeyPath: @"emulator.keyboard.numLockEnabled"];
			[previousSession removeObserver: self forKeyPath: @"emulator.joystick"];
			[previousSession removeObserver: self forKeyPath: @"emulator.joystickSupport"];
			
			[joystickController removeObserver: self forKeyPath: @"joystickDevices"];
			[joypadController removeObserver: self forKeyPath: @"hasJoypadDevices"];
			
            CFNotificationCenterRef cfCenter = CFNotificationCenterGetDistributedCenter();
            CFNotificationCenterRemoveObserver(cfCenter, (__bridge const void *)(self), kTISNotifySelectedKeyboardInputSourceChanged, NULL);
			
			[self didResignKey];
		}
		
		[super setRepresentedObject: session];
		
		if (session)
		{
			NSDictionary *trackingOptions = [NSDictionary dictionaryWithObject: [NSNumber numberWithBool: YES]
																		forKey: NSNullPlaceholderBindingOption];
			[self bind: @"trackMouseWhileUnlocked" toObject: session
		   withKeyPath: @"gameSettings.trackMouseWhileUnlocked"
			   options: trackingOptions];
			
			NSDictionary *sensitivityOptions = [NSDictionary dictionaryWithObject: [NSNumber numberWithFloat: 1.0f]
																		   forKey: NSNullPlaceholderBindingOption];
			[self bind: @"mouseSensitivity" toObject: session
		   withKeyPath: @"gameSettings.mouseSensitivity"
			   options: sensitivityOptions];
			
			[self bind: @"mouseActive" toObject: session
		   withKeyPath: @"emulator.mouse.active"
			   options: nil];
			
			[session addObserver: self
					  forKeyPath: @"paused"
						 options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
						 context: nil];
			
			[session addObserver: self
					  forKeyPath: @"autoPaused"
						 options: NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
						 context: nil];
			
			[session addObserver: self
					  forKeyPath: @"emulator.mouse.position"
						 options: NSKeyValueObservingOptionInitial
						 context: nil];
            
			[session addObserver: self
					  forKeyPath: @"emulator.keyboard.numLockEnabled"
						 options: 0
						 context: nil];
			
			[joystickController addObserver: self
								 forKeyPath: @"joystickDevices"
									options: NSKeyValueObservingOptionInitial
									context: nil];
            
			[joypadController addObserver: self
                               forKeyPath: @"hasJoypadDevices"
                                  options: NSKeyValueObservingOptionInitial
                                  context: nil];
			
			[session addObserver: self
					  forKeyPath: @"emulator.joystick"
						 options: NSKeyValueObservingOptionInitial
						 context: nil];
            
			[session addObserver: self
					  forKeyPath: @"emulator.joystickSupport"
						 options: NSKeyValueObservingOptionInitial
						 context: nil];
			
            
			//Listen for changes to the keyboard input method
            CFNotificationCenterRef cfCenter = CFNotificationCenterGetDistributedCenter();
            CFNotificationCenterAddObserver(cfCenter, (__bridge const void *)(self), &_inputSourceChanged,
                                            kTISNotifySelectedKeyboardInputSourceChanged, NULL,
                                            CFNotificationSuspensionBehaviorCoalesce);
            
            //Sync the current keyboard layout.
            [self _syncKeyboardLayout];
            
            //Sync the current state of the input methods.
			[self didBecomeKey];
		}
	}
}

- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{
	//Ignore mouse position updates if we know we were the ones that moved the mouse
	if (!_updatingMousePosition && [keyPath isEqualToString: @"emulator.mouse.position"])
	{
		NSPoint mousePosition = self.emulatedMouse.position;
		//Ensure we're synced to the OS X cursor whenever the emulator's mouse position changes
		[self _emulatedCursorMovedToPointInCanvas: mousePosition];
	}
	
    //Show a notification whenever the numlock state is toggled.
    else if ([keyPath isEqualToString: @"emulator.keyboard.numLockEnabled"])
    {
        [self _notifyNumlockState];
    }
    
	//Tweak: we used to observe just the @suspended key, but that meant we'd resign key
	//and unlock the mouse whenever Boxer interrupted the emulator for UI stuff like window resizing.
	else if ([keyPath isEqualToString: @"paused"] || [keyPath isEqualToString: @"autoPaused"])
	{
		BOOL wasPaused	= [[change objectForKey: NSKeyValueChangeOldKey] boolValue];
		BOOL isPaused	= [[change objectForKey: NSKeyValueChangeNewKey] boolValue];
		
		if (wasPaused != isPaused)
		{
			if (isPaused) [self didResignKey];
			else [self didBecomeKey];
		}
	}
	
	else if ([keyPath isEqualToString: @"emulator.joystick"])
    {
        //Regenerate HID controller profiles for the newly connected joystick
        [self _syncControllerProfiles];
    }
    
	else if ([keyPath isEqualToString: @"emulator.joystickSupport"])
	{
        //Ensure that the connected joystick and available joystick types are
        //appropriate for the emulator's joystick support level
        [self _syncAvailableJoystickTypes];
		[self _syncJoystickType];
	}
    
    else if ([keyPath isEqualToString: @"joystickDevices"])
    {
        BXEmulator *emulator = self.representedObject.emulator;
        id oldJoystick = emulator.joystick;
        
        //Connect a joystick if none was available before
		[self _syncJoystickType];
        
        //Regenerate controller profiles for the specified joystick
        //The controller profiles may have already been synced as a result
        //of a joystick being added/removed by syncJoystickType above,
        //so only do this if the joystick didn't change
        //FIXME: ugh, move this logic to BXJoystickInput
        BOOL joystickChanged = (oldJoystick != emulator.joystick);
        if (!joystickChanged) [self _syncControllerProfiles];
        
        //Let the Inspector UI know to switch from the connect-a-controller panel
        [self willChangeValueForKey: @"controllersAvailable"];
        [self didChangeValueForKey: @"controllersAvailable"];
    }
    
    else if ([keyPath isEqualToString: @"hasJoypadDevices"])
    {
        //Connect a joystick if none was available before
		[self _syncJoystickType];
        
        //Let the Inspector UI know to switch from the connect-a-controller panel
        [self willChangeValueForKey: @"controllersAvailable"];
        [self didChangeValueForKey: @"controllersAvailable"];
	}		 
}


#pragma mark -
#pragma mark Cursor and event state handling

- (BOOL) mouseInView
{
	if (self.mouseLocked) return YES;
	
    NSPoint locationOnScreen = [NSEvent mouseLocation];
    BXDOSWindow *window = (BXDOSWindow *)self.view.window;
    
    //Check if that point is over our window to begin with and there are no interposing windows.
    if ([NSWindow windowAtPoint: locationOnScreen] != window)
        return NO;
    
    //If it is, check if the mouse is inside our actual DOS view.
    NSPoint locationInWindow = [window convertScreenToBase: locationOnScreen];
    NSPoint locationInView = [self.view convertPoint: locationInWindow fromView: nil];
    
    if (![self.view mouse: locationInView inRect: self.view.bounds])
        return NO;
    
    //Also check whether the mouse is over a hotzone that will trigger the menu
    //bar or dock (mainly an issue in fullscreen mode.)
    //FIXME: at least in 10.7 this doesn't seem to pick up on the dock hotzone
    //at the bottom of the screen.
    if (!NSPointInRect(locationOnScreen, window.screen.visibleFrame))
        return NO;

    //If we got this far, then yippee! the mouse is over the view and has nothing in the way.
    return YES;
}

- (void) cursorUpdate: (NSEvent *)theEvent
{
    //IMPLEMENTATION NOTE: changes to the statusbar segmented control appear
    //to trigger spurious cursor updates which should be ignored.
    //TODO: find a better heuristic for detecting such cursor updates,
    //and figure out why they're being generated in the first place.
    BOOL isSpuriousUpdate = (theEvent != nil) && (theEvent.timestamp == 0);
    if (isSpuriousUpdate) return;
    
    //If we have control of the mouse cursor and we aren't fading it out yet,
    //start doing so now.
	if ([self _controlsCursor])
	{
        if (!self.cursorFade.isAnimating)
		{
			//If the cursor fade was interrupted, make it restart from the beginning
            //rather than where it left off last time.
			self.cursorFade.currentProgress = 0.0f;
        	[self.cursorFade startAnimation];
		}
	}
    //Otherwise, restore the opaque cursor.
	else
	{
		[self.cursorFade stopAnimation];
        [[NSCursor arrowCursor] set];
	}
}

- (float) animation: (NSAnimation *)animation valueForProgress: (NSAnimationProgress)progress
{
    //Start fading only halfway through the animation.
    float fadeDelay = 0.5f;
    float curve = 0.9f;
    
    float easedValue = powf(progress, 2 * curve);
    
    return easedValue;
    
    return fadeDelay + (easedValue * (1.0f - fadeDelay));
}

- (BOOL) animationShouldChangeCursor: (BXCursorFadeAnimation *)animation
{
	//If the mouse is still inside the view, let the cursor change proceed
	if ([self _controlsCursor]) return YES;
	//If the mouse has left the view, cancel the animation and don't change the cursor
	else
	{
		if (animation.isAnimating) [animation stopAnimation];
		return NO;
	}
}

- (void) didResignKey
{
    [self setMouseLocked: NO force: YES];
    
    [self.emulatedKeyboard clearInput];
	[self.emulatedMouse clearInput];
	[self.emulatedJoystick clearInput];
	
	_simulatedMouseButtons = BXNoMouseButtonsMask;
	_threeFingerTapStarted = 0;
    
    //Clear our record of which keys were fn-modified
    memset(&_modifiedKeys, NO, sizeof(_modifiedKeys));
}

- (void) didBecomeKey
{
    //Account for any changes to key modifier flags while we didn't have keyboard focus.
	//IMPLEMENTATION NOTE: CGEventSourceFlagsState returns the currently active modifiers
	//outside of the event stream. It works the same as the 10.6-only NSEvent +modifierFlags,
	//but is available on 10.5 and (unlike +modifierFlags) it also includes side-specific Shift,
    //Ctrl and Alt flags.
	CGEventFlags currentModifiers = CGEventSourceFlagsState(kCGEventSourceStateCombinedSessionState);
	[self _syncModifierFlags: (NSUInteger)currentModifiers];
	
	//Also sync the cursor state while we're at it, in case the cursor was already over the window.
	[self cursorUpdate: nil];
}

void _inputSourceChanged(CFNotificationCenterRef center,
                         void *observer,
                         CFStringRef name,
                         const void *object,
                         CFDictionaryRef userInfo)
{
    [(__bridge BXInputController *)observer performSelectorOnMainThread: @selector(_syncKeyboardLayout)
                                                    withObject: nil
                                                 waitUntilDone: NO];
}


#pragma mark -
#pragma mark Mouse focus and locking 

- (void) setMouseLocked: (BOOL)lock force: (BOOL)force
{
    [self willChangeValueForKey: @"mouseLocked"];
    
	//Don't continue if we're already in the right lock state
	if (lock != self.mouseLocked)
    {
        if (!lock || force || self.canLockMouse)
        {
            [self _applyMouseLockState: lock];
            _mouseLocked = lock;
            
            [self.representedObject didToggleMouseLocked];
        }
    }
	
    [self didChangeValueForKey: @"mouseLocked"];
}

- (void) setMouseLocked: (BOOL)lock
{
    [self setMouseLocked: lock force: NO];
}

- (void) setMouseActive: (BOOL)active
{
	if (active != _mouseActive)
	{
		_mouseActive = active;
        //Update the mouse cursor, in case the mouse became active while the cursor was already
        //over the window.
		[self cursorUpdate: nil];
		
		//Release the mouse lock when DOS stops using the mouse, unless we're in fullscreen mode
		if (!active && !self.windowController.window.isFullScreen)
            self.mouseLocked = NO;
    }
}

- (void) setTrackMouseWhileUnlocked: (BOOL)track
{	
	if (_trackMouseWhileUnlocked != track)
	{
		_trackMouseWhileUnlocked = track;
	
		//If we're disabling tracking, and the mouse is currently unlocked,
		//then warp the mouse to the center of the window as if we had just unlocked it.
		
		//Disabled for now because this makes the mouse jumpy and unpredictable.
		/*
		if (!track && ![self mouseLocked])
			[self _syncEmulatedCursorToPointInCanvas: NSMakePoint(0.5f, 0.5f)];
		*/
	}
}

- (BOOL) trackMouseWhileUnlocked
{
	//Tweak: when in fullscreen mode, ignore the current mouse-tracking setting.
	return _trackMouseWhileUnlocked && !self.windowController.window.isFullScreen;
}

- (BOOL) canLockMouse
{
	if (![NSApp isActive]) return NO;
	
	if (!self.view.window.isKeyWindow) return NO;
	
    //Always allow the mouse to be locked in fullscreen mode, even when the mouse is not active.
	return (self.mouseActive || self.windowController.window.isFullScreen);
}


#pragma mark -
#pragma mark Interface actions

- (IBAction) toggleMouseLocked: (id)sender
{
	BOOL lock;
	BOOL wasLocked = self.mouseLocked;
	
	if ([sender respondsToSelector: @selector(boolValue)]) lock = [sender boolValue];
	else lock = !wasLocked;
	
    //BOOL mouseWasInside = self.mouseInView;
    
    self.mouseLocked = lock;
    
	//If the mouse state was actually toggled, play a sound to commemorate the occasion
	if (self.mouseLocked != wasLocked)
	{
		NSString *lockSoundName	= (wasLocked) ? @"LockOpening" : @"LockClosing";
		[[NSApp delegate] playUISoundWithName: lockSoundName atVolume: BXMouseLockSoundVolume];
        
        //Also do a little ripple animation where the mouse cursor was.
        //Disabled for now because it's kinda sucky.
        /*
        if (mouseWasInside)
        {
            NSPoint previousMouseLocation = self.view.window.mouseLocationOutsideOfEventStream;
            BXGLRenderingView *renderView = (BXGLRenderingView *)self.windowController.renderingView;
            NSPoint rippleLocation = [renderView convertPoint: previousMouseLocation fromView: nil];
            [renderView showRippleAtPoint: rippleLocation reverse: wasLocked];
        }
         */
	}
}

- (IBAction) toggleSimulatedNumpad: (id)sender
{
    BOOL simulating = self.simulatedNumpadActive;
    self.simulatedNumpadActive = !simulating;
    
    if (self.simulatedNumpadActive)
        [[BXBezelController controller] showNumpadActiveBezel];
    else
        [[BXBezelController controller] showNumpadInactiveBezel];
}

- (IBAction) toggleTrackMouseWhileUnlocked: (id)sender
{
	BOOL currentlyTracking = self.trackMouseWhileUnlocked;
    self.trackMouseWhileUnlocked = !currentlyTracking;
}

- (BOOL) validateMenuItem: (NSMenuItem *)menuItem
{
	SEL theAction = menuItem.action;
	
	if (theAction == @selector(toggleMouseLocked:))
	{
        menuItem.state = self.mouseLocked;
        return self.canLockMouse;
	}
	else if (theAction == @selector(toggleTrackMouseWhileUnlocked:))
	{
        menuItem.state = self.trackMouseWhileUnlocked;
        return YES;
		return YES;
	}
	else if (theAction == @selector(toggleSimulatedNumpad:))
	{
        menuItem.state = self.simulatedNumpadActive;
        return YES;
	}
    else if (theAction == @selector(sendNumLock:))
    {
        menuItem.state = self.emulatedKeyboard.numLockEnabled;
        return YES;
    }
    else if (theAction == @selector(sendScrollLock:))
    {
        menuItem.state = self.emulatedKeyboard.scrollLockEnabled;
        return YES;
    }
	return YES;
}


#pragma mark -
#pragma mark Mouse events

- (void) mouseDown: (NSEvent *)theEvent
{
	//Unpause whenever the view is clicked on
	[self.representedObject resume: self];
	
	//Only respond to clicks if we're locked or tracking mouse input while unlocked
	if ([self _controlsCursorWhileMouseInside])
	{
		NSUInteger modifiers = theEvent.modifierFlags;
		
        //Cmd-clicking toggles mouse-locking and causes the actual click to be ignored.
		if ((modifiers & NSCommandKeyMask) == NSCommandKeyMask)
		{
			[self toggleMouseLocked: self];
		}
        else
        {
            //Check if our right-mouse-button/both-mouse-button shortcut modifiers are being
            //pressed: if so, simulate the appropriate kind of mouse click.
            NSDictionary *gameSettings = self.representedObject.gameSettings;
            
            NSUInteger rightButtonModifierMask = [[gameSettings objectForKey: @"mouseButtonModifierRight"] unsignedIntegerValue];
            NSUInteger bothButtonsModifierMask = [[gameSettings objectForKey: @"mouseButtonModifierBoth"] unsignedIntegerValue];
                    
            //Check if our both-buttons-at-once modifiers are being pressed.
            if (bothButtonsModifierMask > 0 && (modifiers & bothButtonsModifierMask) == bothButtonsModifierMask)
            {
                _simulatedMouseButtons |= BXMouseButtonLeftAndRightMask;
                [self.emulatedMouse buttonDown: BXMouseButtonLeft];
                [self.emulatedMouse buttonDown: BXMouseButtonRight];
            }
            
            //Check if our right-button modifiers are being pressed.
            else if (rightButtonModifierMask > 0 && (modifiers & rightButtonModifierMask) == rightButtonModifierMask)
            {
                _simulatedMouseButtons |= BXMouseButtonRightMask;
                [self.emulatedMouse buttonDown: BXMouseButtonRight];
            }
            
            //Otherwise, pass the left click on to the emulator as-is.
            else
            {
                [self.emulatedMouse buttonDown: BXMouseButtonLeft];   
            }
        }
	}
	
	//A single click on the window will lock the mouse if unlocked-tracking is disabled or we're in fullscreen mode
	else if (!self.trackMouseWhileUnlocked)
	{
		[self toggleMouseLocked: self];
	}
	
	//Otherwise, let the mouse event pass on unmolested
	else
	{
		[super mouseDown: theEvent];
	}
}

- (void) rightMouseDown: (NSEvent *)theEvent
{
	//Unpause whenever the view is clicked on
	[self.representedObject resume: self];
	
	if ([self _controlsCursorWhileMouseInside])
	{
        //Check if the both-mouse-button shortcut modifier is being pressed:
        //if so, simulate both buttons being clicked instead of just the right one.
        NSUInteger currentModifiers = theEvent.modifierFlags;
        NSDictionary *gameSettings = self.representedObject.gameSettings;
        NSUInteger bothButtonsModifierMask = [[gameSettings objectForKey: @"mouseButtonModifierBoth"] unsignedIntegerValue];
        
        if (bothButtonsModifierMask > 0 && (currentModifiers & bothButtonsModifierMask) == bothButtonsModifierMask)
        {
            _simulatedMouseButtons |= BXMouseButtonLeftAndRightMask;
            [self.emulatedMouse buttonDown: BXMouseButtonLeft];
            [self.emulatedMouse buttonDown: BXMouseButtonRight];
        }
        else
        {
            [self.emulatedMouse buttonDown: BXMouseButtonRight];
        }
	}
	else
	{
		[super rightMouseDown: theEvent];
	}
}

- (void) otherMouseDown: (NSEvent *)theEvent
{
	//Unpause whenever the view is clicked on
	[self.representedObject resume: self];
	
	if ([self _controlsCursorWhileMouseInside] && theEvent.buttonNumber == BXMouseButtonMiddle)
	{
		[self.emulatedMouse buttonDown: BXMouseButtonMiddle];
	}
	else
	{
		[super otherMouseDown: theEvent];
	}
}

- (void) _syncSimulatedMouseButtons: (NSUInteger)currentModifiers
{
    //Because we can't reliably detect mouse button states from arbitrary NSEvents,
    //we retrieve their current value independent of the current event.
    BOOL leftButtonDown     = CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonLeft);
    BOOL rightButtonDown    = CGEventSourceButtonState(kCGEventSourceStateCombinedSessionState, kCGMouseButtonRight);
    
    //Check whether the both-mouse-buttons keyboard modifier has been pressed
    //or released while a mouse button is down, and update the simulated mouse
    //buttons accordingly.
    if (leftButtonDown || rightButtonDown)
    {
        NSDictionary *gameSettings = self.representedObject.gameSettings;
        NSUInteger bothButtonsModifierMask = [[gameSettings objectForKey: @"mouseButtonModifierBoth"] unsignedIntegerValue];
        
        BOOL isSimulatingBothButtons = (_simulatedMouseButtons & BXMouseButtonLeftAndRightMask) == BXMouseButtonLeftAndRightMask;
        BOOL isPressingBothButtonsShortcut = bothButtonsModifierMask > 0 && ((currentModifiers & bothButtonsModifierMask) == bothButtonsModifierMask);
        
        //The user has released the both-buttons shortcut: release whichever mouse button
        //was previously being simulated, while leaving the original mouse button pressed.
        if (isSimulatingBothButtons && !isPressingBothButtonsShortcut)
        {
            //If the user was pressing the right button originally, release the simulated left button;
            //otherwise, release the right button.
            if (rightButtonDown)
            {
                [self.emulatedMouse buttonUp: BXMouseButtonLeft];
                _simulatedMouseButtons &= ~BXMouseButtonLeftMask;
            }
            else
            {
                [self.emulatedMouse buttonUp: BXMouseButtonRight];
                _simulatedMouseButtons &= ~BXMouseButtonRightMask;
            }
        }
        //The user has pressed the both-buttons shortcut: simulate the other mouse button being pressed
        //along with whichever one was already pressed.
        else if (!isSimulatingBothButtons && isPressingBothButtonsShortcut)
        {
            [self.emulatedMouse buttonDown: BXMouseButtonLeft];
            [self.emulatedMouse buttonDown: BXMouseButtonRight];
            
            _simulatedMouseButtons |= BXMouseButtonLeftAndRightMask;
        }
    }
}

- (void) mouseUp: (NSEvent *)theEvent
{
	if ([self _controlsCursorWhileMouseInside])
	{
		if (_simulatedMouseButtons != BXNoMouseButtonsMask)
		{
			if ((_simulatedMouseButtons & BXMouseButtonLeftMask) == BXMouseButtonLeftMask)
				[self.emulatedMouse buttonUp: BXMouseButtonLeft];
			
			if ((_simulatedMouseButtons & BXMouseButtonRightMask) == BXMouseButtonRightMask)
				[self.emulatedMouse buttonUp: BXMouseButtonRight];
			
			if ((_simulatedMouseButtons & BXMouseButtonMiddleMask) == BXMouseButtonMiddleMask)
				[self.emulatedMouse buttonUp: BXMouseButtonMiddle];
			
			_simulatedMouseButtons = BXNoMouseButtonsMask;
		}
		//Pass the mouse release as-is to our input handler
		else [self.emulatedMouse buttonUp: BXMouseButtonLeft];
	}
	else
	{
		[super mouseUp: theEvent];
	}
}

- (void) rightMouseUp: (NSEvent *)theEvent
{
	if ([self _controlsCursorWhileMouseInside])
	{
		if (_simulatedMouseButtons != BXNoMouseButtonsMask)
		{
			if ((_simulatedMouseButtons & BXMouseButtonLeftMask) == BXMouseButtonLeftMask)
				[self.emulatedMouse buttonUp: BXMouseButtonLeft];
			
			if ((_simulatedMouseButtons & BXMouseButtonRightMask) == BXMouseButtonRightMask)
				[self.emulatedMouse buttonUp: BXMouseButtonRight];
			
			if ((_simulatedMouseButtons & BXMouseButtonMiddleMask) == BXMouseButtonMiddleMask)
				[self.emulatedMouse buttonUp: BXMouseButtonMiddle];
			
			_simulatedMouseButtons = BXNoMouseButtonsMask;
		}
        else
        {
            [self.emulatedMouse buttonUp: BXMouseButtonRight];
        }
	}
	else
	{
		[super rightMouseUp: theEvent];
	}

}

- (void) otherMouseUp: (NSEvent *)theEvent
{
	//Only pay attention to the middle mouse button; all others can do as they will
	if (theEvent.buttonNumber == BXMouseButtonMiddle && [self _controlsCursorWhileMouseInside])
	{
		[self.emulatedMouse buttonUp: BXMouseButtonMiddle];
	}		
	else
	{
		[super otherMouseUp: theEvent];
	}
}

//Work out mouse motion relative to the view's canvas, passing on the current position
//and movement delta to the emulator's input handler.
//We represent position and delta as as a fraction of the canvas rather than as a fixed unit
//position, so that they stay consistent when the view size changes.
- (void) mouseMoved: (NSEvent *)theEvent
{
	//Only apply mouse movement if we're locked or we're accepting unlocked mouse input
	if ([self _controlsCursorWhileMouseInside])
	{
		NSRect canvas = self.view.bounds;
		CGFloat width = canvas.size.width;
		CGFloat height = canvas.size.height;
		
		NSPoint locationOnCanvas, delta;

		//Make the delta relative to the canvas
		delta = NSMakePoint(theEvent.deltaX / width,
							theEvent.deltaY / height);		
		
		//If we have just warped the mouse, the delta above will include the distance warped
		//as well as the actual distance moved in this mouse event: so, we subtract the warp.
		if (!NSEqualPoints(_distanceWarped, NSZeroPoint))
		{
			delta.x -= _distanceWarped.x;
			delta.y -= _distanceWarped.y;
		}
		
		if (!self.mouseLocked)
		{
			NSPoint locationInView	= [self.view convertPoint: theEvent.locationInWindow
                                                    fromView: nil];
			locationOnCanvas = NSMakePoint(locationInView.x / width,
                                           locationInView.y / height);

			//Clamp the position to within the canvas.
			locationOnCanvas = clampPointToRect(locationOnCanvas, _canvasBounds);
		}
		else
		{
			//While the mouse is locked, OS X won't update the absolute cursor position and
			//DOSBox won't pay attention to the absolute cursor position either, so we don't
			//bother calculating it.
			locationOnCanvas = NSZeroPoint;
			
			//While the mouse is locked, we apply our mouse sensitivity to the delta.
			delta.x *= self.mouseSensitivity;
			delta.y *= self.mouseSensitivity;
		}
		
		//Ensures we ignore any cursor-moved notifications from the emulator as a result of this call.
		_updatingMousePosition = YES;
		
		[self.emulatedMouse movedTo: locationOnCanvas
                                 by: delta
                           onCanvas: canvas
                        whileLocked: self.mouseLocked];
		
		//Resume paying attention to mouse position updates.
		_updatingMousePosition = NO;
	}
	else
	{
		[super mouseMoved: theEvent];
	}
	
	//Always reset our internal warp tracking after every mouse movement event,
	//even if the event is not handled.
	_distanceWarped = NSZeroPoint;
}

//Treat drag events as simple mouse movement
- (void) mouseDragged: (NSEvent *)theEvent		{ [self mouseMoved: theEvent]; }
- (void) rightMouseDragged: (NSEvent *)theEvent	{ return [self mouseDragged: theEvent]; }
- (void) otherMouseDragged: (NSEvent *)theEvent	{ return [self mouseDragged: theEvent]; }


- (void) mouseExited: (NSEvent *)theEvent
{
	[self willChangeValueForKey: @"mouseInView"];
	//Force a cursor update at this point: OS X 10.7 won't do so itself
    //if the mouse leaves the tracking area by moving into a floating panel.
	[super mouseExited: theEvent];
    [self cursorUpdate: theEvent];
    [self didChangeValueForKey: @"mouseInView"];
    
    //If the mouse leaves the view while we're locked, unlock it immediately:
    //this will happen if the user activates Exposé or the Cmd-Tab bar.
    //TWEAK: 10.6 seems to spuriously trigger this during fullscreen transitions.
    //For now, we ignore it on 10.6, but we need to look into the root cause.
    if (isRunningOnLionOrAbove())
        self.mouseLocked = NO;
}

- (void) mouseEntered: (NSEvent *)theEvent
{
	[self willChangeValueForKey: @"mouseInView"];
	[super mouseEntered: theEvent];
    [self cursorUpdate: theEvent];
	[self didChangeValueForKey: @"mouseInView"];
}


#pragma mark -
#pragma mark Touch events

- (void) touchesBeganWithEvent: (NSEvent *)theEvent
{	
	if ([self _controlsCursorWhileMouseInside])
	{
		NSSet *touches = [theEvent touchesMatchingPhase: NSTouchPhaseTouching
												 inView: self.view];
		
		//As soon as the user has placed three fingers onto the touch surface,
		//start tracking for the release to detect this as a three-finger tap gesture.
		if (touches.count == 3)
		{
			_threeFingerTapStarted = [NSDate timeIntervalSinceReferenceDate];
		}
		//If the user puts down more fingers, then cancel the gesture.
		else
		{
			_threeFingerTapStarted = 0;
		}
	}
}

- (void) touchesEndedWithEvent: (NSEvent *)theEvent
{
	if (_threeFingerTapStarted && [self _controlsCursorWhileMouseInside])
	{
		//If the touch has gone on for too long to treat as a tap,
		//then cancel the gesture.
		if (([NSDate timeIntervalSinceReferenceDate] - _threeFingerTapStarted) > BXTapDurationThreshold)
		{
			_threeFingerTapStarted = 0;
		}
		else
		{
			NSSet *touches = [theEvent touchesMatchingPhase: NSTouchPhaseTouching
													 inView: self.view];
			
			//If all fingers have now been lifted from the surface,
			//then treat this as a proper triple-tap gesture.
			if (touches.count == 0)
			{	
				//Unpause when triple-tapping
				[self.representedObject resume: self];
			
				[self.emulatedMouse buttonPressed: BXMouseButtonLeft];
				[self.emulatedMouse buttonPressed: BXMouseButtonRight];
				
				_threeFingerTapStarted = 0;
			}
		}
	}
}

- (void) swipeWithEvent: (NSEvent *)theEvent
{
	//The swipe event is a three-finger gesture based on movement and so may conflict with our own.
	//(We listen for this instead of for the touchesMovedWithEvent: message because it means we don't
	//have to bother calculating movement deltas.)
	_threeFingerTapStarted = 0;
}

- (void) touchesCancelledWithEvent: (NSEvent *)theEvent
{
	_threeFingerTapStarted = 0;
}


#pragma mark -
#pragma mark Private methods

- (BXDOSWindowController *) windowController	{ return self.representedObject.DOSWindowController; }
- (BXEmulatedMouse *)emulatedMouse				{ return self.representedObject.emulator.mouse; }
- (BXEmulatedKeyboard *)emulatedKeyboard		{ return self.representedObject.emulator.keyboard; }
- (id <BXEmulatedJoystick>)emulatedJoystick     { return self.representedObject.emulator.joystick; }


- (BOOL) _controlsCursor
{
	if (![self _controlsCursorWhileMouseInside]) return NO;
	
	if (!self.view.window.isKeyWindow) return NO;
	
	return self.mouseInView;
}

- (BOOL) _controlsCursorWhileMouseInside
{
    //Don't mess with the mouse cursor the emulator is paused or the program doesn't use the mouse.
	if (!self.mouseActive) return NO;
	if (self.representedObject.isSuspended) return NO;
	
	return (self.mouseLocked || self.trackMouseWhileUnlocked);
}

- (NSPoint) _pointOnScreen: (NSPoint)canvasPoint
{
	NSRect canvas = self.view.bounds;
	NSPoint pointInView = NSMakePoint(canvasPoint.x * canvas.size.width,
									  canvasPoint.y * canvas.size.height);
	
	NSPoint pointInWindow = [self.view convertPoint: pointInView toView: nil];
	NSPoint pointOnScreen = [self.view.window convertBaseToScreen: pointInWindow];
	
	return pointOnScreen;
}

- (NSPoint) _pointInCanvas: (NSPoint)screenPoint
{
	NSPoint pointInWindow	= [self.view.window convertScreenToBase: screenPoint];
	NSPoint pointInView		= [self.view convertPoint: pointInWindow fromView: nil];
	
	NSRect canvas = self.view.bounds;
	NSPoint pointInCanvas = NSMakePoint(pointInView.x / canvas.size.width,
										pointInView.y / canvas.size.height);
	
	return pointInCanvas;	
}

- (void) _applyMouseLockState: (BOOL)lock
{	
	if (lock)
	{
        //Hide the mouse cursor when locking, if it's currently visible.
        //Checking CGCursorIsVisible() ensures we don't "over-hide"
        //the cursor if it's already hidden, since [NSCursor hide] stacks
        //and we have no way of knowing the current stack depth.
        if (CGCursorIsVisible()) [NSCursor hide];
        
        //Disassociate the mouse and the OS X cursor. This prevents the OS X cursor
        //from moving as long as the mouse is locked (which prevents it leaving the
        //confines of the window, which is what we want to avoid.)
        //FIXME: this is ignored by tablet devices on OS X 10.6 and below, which means
        //the cursor can leave the window and inadvertently click on other applications.
        CGAssociateMouseAndMouseCursorPosition(NO);
        
		//If the cursor is outside of the view when we lock the mouse,
		//then warp it to the center of the DOS view.
		//This prevents mouse clicks from going to other windows.
		//(We avoid warping if the mouse is already over the view,
        //as this would cause an input delay.)
		if (!self.mouseInView)
            [self _syncOSXCursorToPointInCanvas: NSMakePoint(0.5f, 0.5f)];
		
		//Warp the DOS mouse cursor to the previous location of the OS X cursor upon locking.
		//Disabled for now, because this gives poor results in games with relative mouse positioning
        //and so makes the mouse behaviour feel jumpy and unpredictable.
        /*
		if (![self trackMouseWhileUnlocked])
		{
			NSPoint mouseLocation = [NSEvent mouseLocation];
			NSPoint canvasLocation = [self _pointInCanvas: mouseLocation];
			
			[self _syncEmulatedCursorToPointInCanvas: canvasLocation];
		}
         */
	}
	else
	{
        //Restore the regular mouse cursor if it was previously faded-out.
        [[NSCursor arrowCursor] set];
        
        //Allow the OS X cursor to update its position in response to mouse
        //movement again.
        CGAssociateMouseAndMouseCursorPosition(YES);
        
		//If we're unlocking the mouse, then sync the OS X mouse cursor
		//to wherever DOSBox's cursor is located within the view.
		NSPoint mousePosition = self.emulatedMouse.position;
		
		//Constrain the cursor position to slightly inset within the view:
		//This ensures the mouse doesn't appear outside the view or right
		//at the view's edge, which looks ugly.
		mousePosition = clampPointToRect(mousePosition, _visibleCanvasBounds);
		
		[self _syncOSXCursorToPointInCanvas: mousePosition];
		
		
		//If we don't track the mouse while unlocked, then also tell DOSBox
		//to warp the mouse to the center of the canvas; this will prevent
		//the leftover position from latently causing unintended input
		//(such as scrolling or turning).
		
		//Disabled for now because this makes the mouse jumpy and unpredictable.
		/*
		if (![self trackMouseWhileUnlocked])
		{
			[self _syncEmulatedCursorToPointInCanvas: NSMakePoint(0.5f, 0.5f)];
		}
		 */
        
        //Unhide the mouse cursor once we're unlocked.
        //IMPLEMENTATION NOTE: we used to check CGCursorIsVisible when unhiding,
        //as with hiding, but this broke with Cmd-Tabbing and there's no danger
        //of "over-unhiding" anyway.
        [NSCursor unhide];
	}
}

- (void) _emulatedCursorMovedToPointInCanvas: (NSPoint)pointInCanvas
{	
	//If the mouse warped of its own accord, and we have control of the cursor,
	//then sync the OS X mouse cursor to match DOSBox's.
	//(We only bother doing this if the mouse is unlocked; there's no point doing
	//otherwise, since we'll sync the cursors when we unlock.)
	if (!_updatingMousePosition && !self.mouseLocked && [self _controlsCursor])
	{
		//Don't sync if the mouse was warped to the 0, 0 point:
		//This indicates a game testing the extents of the mouse canvas.
		if (NSEqualPoints(pointInCanvas, NSZeroPoint)) return;
		
		//Don't sync if the mouse was warped outside the canvas:
		//This would place the mouse cursor beyond the confines of the window.
		if (!NSPointInRect(pointInCanvas, _canvasBounds)) return;
		
		//Because syncing the OS X cursor causes a slight but noticeable input delay,
		//we check how far it moved and ignore small distances.
		NSPoint oldPointInCanvas = [self _pointInCanvas: [NSEvent mouseLocation]];
		NSPoint distance = deltaFromPointToPoint(oldPointInCanvas, pointInCanvas);

		if (!NSPointInRect(distance, _cursorWarpDeadzone))
			[self _syncOSXCursorToPointInCanvas: pointInCanvas];
	}
}

- (void) _syncOSXCursorToPointInCanvas: (NSPoint)pointInCanvas
{
	NSPoint oldPointOnScreen	= [NSEvent mouseLocation];
	NSPoint pointOnScreen		= [self _pointOnScreen: pointInCanvas];
	
	//Warping the mouse won't generate a mouseMoved event, but it will mess up the delta on the 
	//next mouseMoved event to reflect the distance the mouse was warped. So, we determine how
	//far the mouse was warped, and will subtract that from the next mouse delta calculation.
	NSPoint oldPointInCanvas = [self _pointInCanvas: oldPointOnScreen];
	_distanceWarped = deltaFromPointToPoint(oldPointInCanvas, pointInCanvas);
	
	
	CGPoint cgPointOnScreen = NSPointToCGPoint(pointOnScreen);
	//Flip the coordinates to compensate for AppKit's bottom-left screen origin
	NSRect screenFrame = self.view.window.screen.frame;
	cgPointOnScreen.y = screenFrame.origin.y + screenFrame.size.height - cgPointOnScreen.y;
	
	//TODO: check that this behaves correctly across multiple displays.
	CGWarpMouseCursorPosition(cgPointOnScreen);
}

- (void) _syncEmulatedCursorToPointInCanvas: (NSPoint)pointInCanvas
{
	NSPoint mousePosition = self.emulatedMouse.position;
	NSPoint delta = deltaFromPointToPoint(mousePosition, pointInCanvas);
	[self.emulatedMouse movedTo: pointInCanvas
                             by: delta
                       onCanvas: self.view.bounds
                    whileLocked: NO];
}
@end
