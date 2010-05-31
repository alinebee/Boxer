/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXInputController.h"
#import "BXEventConstants.h"
#import "BXInputHandler.h"
#import "BXEmulator.h"
#import "BXAppController.h"
#import "BXGeometry.h"
#import "BXCursorFadeAnimation.h"

//If the cursor is warped less than this distance (relative to a 0.0->1.0 square canvas) then
//the warp will be ignored. Because cursor warping introduces a slight input delay, we use this
//tolerance to ignore small warps.
const CGFloat BXCursorWarpTolerance = 0.1;

//Flags for which mouse buttons we are currently faking (for Ctrl- and Opt-clicking.)
//Note that while these are ORed together, there will currently only ever be one of them active at a time.
enum {
	BXNoSimulatedButtons			= 0,
	BXSimulatedButtonRight			= 1,
	BXSimulatedButtonMiddle			= 2,
	BXSimulatedButtonLeftAndRight	= 4,
};


@interface BXInputController (BXInputControllerInternals)

//Warp the OS X cursor to the specified point on our virtual mouse canvas.
//Used when locking and unlocking the mouse.
- (void) _syncOSXCursorToPointInCanvas: (NSPoint)point;

//Convert a relative 0.0-1.0 canvas offset to a point on screen.
- (NSPoint) _pointOnScreen: (NSPoint)canvasPoint;

//Does the fiddly internal work of locking/unlocking the mouse.
- (void) _applyMouseLockState: (BOOL)lock;

//Returns whether we should have control of the mouse cursor state.
- (BOOL) _controlsCursor;

@end


@implementation BXInputController
@synthesize mouseLocked, mouseActive;

#pragma mark -
#pragma mark Initialization and cleanup

- (void) awakeFromNib
{
	//Initialize the mouse position to the centre of the DOS view,
	//in case we lock the mouse before receiving a mouseMoved event.
	lastMousePosition = NSMakePoint(0.5, 0.5);
	
	//DOSBox-triggered cursor warp distances which fit within this deadzone will be ignored
	//to prevent needless input delays.
	cursorWarpDeadzone = NSInsetRect(NSZeroRect, -BXCursorWarpTolerance, -BXCursorWarpTolerance);
	
	//Insert ourselves into the responder chain as our view's next responder
	[self setNextResponder: [[self view] nextResponder]];
	[[self view] setNextResponder: self];
	
	//Set up a cursor region in the view for mouse handling
	NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited | NSTrackingEnabledDuringMouseDrag | NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect | NSTrackingAssumeInside;
	
	NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect: NSZeroRect
																options: options
																  owner: self
															   userInfo: nil];
	
	[[self view] addTrackingArea: trackingArea];
	[trackingArea release];	
	 
	
	//Set up our cursor fade animation
	cursorFade = [[BXCursorFadeAnimation alloc] initWithDuration: 0.5
												  animationCurve: NSAnimationEaseIn];
	[cursorFade setDelegate: self];
	[cursorFade setOriginalCursor: [NSCursor arrowCursor]];
	[cursorFade setAnimationBlockingMode: NSAnimationNonblocking];
	[cursorFade setFrameRate: 15.0];
}

- (void) dealloc
{
	[cursorFade stopAnimation];
	[cursorFade release], cursorFade = nil;
	
	[super dealloc];
}


- (void) setRepresentedObject: (BXInputHandler *)representedObject
{
	if (![representedObject isEqualTo: [self representedObject]])
	{
		if ([self representedObject])
		{
			[self unbind: @"mouseActive"];
			[representedObject removeObserver: self forKeyPath: @"mousePosition"];
		}
		
		[super setRepresentedObject: representedObject];
		
		if (representedObject)
		{
			[self bind: @"mouseActive" toObject: representedObject withKeyPath: @"mouseActive" options: nil];
			[representedObject addObserver: self forKeyPath: @"mousePosition" options: 0 context: nil];
		}
	}
}

- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{
	//Ignore mouse position updates while we are moving the mouse ourselves.
	if (!updatingMousePosition && [keyPath isEqualToString: @"mousePosition"])
	{
		NSPoint position = [object mousePosition];
		
		//If the mouse is locked, update the last known position to match DOSBox's and leave it at that.
		if ([self mouseLocked]) lastMousePosition = position;
		
		//Otherwise if we have control of the mouse, warp the OS X mouse cursor to match DOSBox's.
		else if ([self _controlsCursor])
		{
			//Because the warp would result in a slight but noticeable input delay,
			//we ignore it if the difference between the two points is negligible.
			NSPoint distance = NSMakePoint(lastMousePosition.x - position.x,
										   lastMousePosition.y - position.y);
			
			if (!NSPointInRect(distance, cursorWarpDeadzone)) [self _syncOSXCursorToPointInCanvas: position];
		}
	}
}

	
#pragma mark -
#pragma mark Cursor and event state handling

- (BOOL) mouseInView
{
	if ([[self view] isInFullScreenMode] || [self mouseLocked]) return YES;
	
	NSPoint mouseLocation = [[[self view] window] mouseLocationOutsideOfEventStream];
	NSPoint pointInView = [[self view] convertPoint: mouseLocation fromView: nil];
	return [[self view] mouse: pointInView inRect: [[self view] bounds]];
}

- (void) setMouseActive: (BOOL)active
{
	[self willChangeValueForKey: @"mouseActive"];
	mouseActive = active;
	[self cursorUpdate: nil];
	[self didChangeValueForKey: @"mouseActive"];
}

- (void) cursorUpdate: (NSEvent *)theEvent
{
	if ([self _controlsCursor])
	{
		if (![cursorFade isAnimating])
		{
			//Make the cursor fade from the beginning rather than where it left off
			[cursorFade setCurrentProgress: 0.0];
			[cursorFade startAnimation];
		}
	}
	else
	{
		[cursorFade stopAnimation];
	}
}

- (BOOL) animationShouldChangeCursor: (BXCursorFadeAnimation *)animation
{
	//If the mouse is still inside the view, let the cursor change proceed
	if ([self _controlsCursor]) return YES;
	//If the mouse has left the view, cancel the animation and don't change the cursor
	else
	{
		if ([animation isAnimating]) [animation stopAnimation];
		return NO;
	}
}

- (BOOL) _controlsCursor
{
	return [self mouseActive] && [[[self view] window] isKeyWindow] && [self mouseInView];
}


- (void) didResignKey
{
	[self setMouseLocked: NO];
	[[self representedObject] lostFocus];
}

#pragma mark -
#pragma mark Mouse events

- (void) mouseDown: (NSEvent *)theEvent
{
	id inputHandler = [self representedObject];
	
	NSUInteger modifiers = [theEvent modifierFlags];
	BOOL optModified	= (modifiers & NSAlternateKeyMask) > 0;
	BOOL ctrlModified	= (modifiers & NSControlKeyMask) > 0;
	BOOL cmdModified	= (modifiers & NSCommandKeyMask) > 0;

	//Cmd-clicking toggles mouse-locking
	if (cmdModified) [self toggleMouseLocked: self];
	
	//Ctrl-Opt-clicking simulates a simultaneous left- and right-click
	//(for those rare games that need it, like Syndicate)
	else if (optModified && ctrlModified)
	{
		simulatedMouseButtons |= BXSimulatedButtonLeftAndRight;
		[inputHandler mouseButtonPressed: OSXMouseButtonLeft withModifiers: modifiers];
		[inputHandler mouseButtonPressed: OSXMouseButtonRight withModifiers: modifiers];
	}
	
	//Ctrl-clicking simulates a right mouse-click
	else if (ctrlModified)
	{
		simulatedMouseButtons |= BXSimulatedButtonRight;
		[inputHandler mouseButtonPressed: OSXMouseButtonRight withModifiers: modifiers];
	}
	
	//Opt-clicking simulates a middle mouse-click
	else if (optModified)
	{
		simulatedMouseButtons |= BXSimulatedButtonMiddle;
		[inputHandler mouseButtonPressed: OSXMouseButtonMiddle withModifiers: modifiers];
	}
	
	//Otherwise, pass the left click on as-is
	else [inputHandler mouseButtonPressed: OSXMouseButtonLeft withModifiers: modifiers];
}

- (void) rightMouseDown: (NSEvent *)theEvent
{
	[[self representedObject] mouseButtonPressed: OSXMouseButtonRight withModifiers: [theEvent modifierFlags]];
}

- (void) otherMouseDown: (NSEvent *)theEvent
{
	if ([theEvent buttonNumber] == OSXMouseButtonMiddle)
		[[self representedObject] mouseButtonPressed: OSXMouseButtonMiddle withModifiers: [theEvent modifierFlags]];
	else [super otherMouseDown: theEvent];
}

- (void) mouseUp: (NSEvent *)theEvent
{
	id inputHandler = [self representedObject];
	NSUInteger modifiers = [theEvent modifierFlags];

	if (simulatedMouseButtons)
	{
		if (simulatedMouseButtons & BXSimulatedButtonLeftAndRight)
		{
			[inputHandler mouseButtonReleased: OSXMouseButtonLeft withModifiers: modifiers];
			[inputHandler mouseButtonReleased: OSXMouseButtonRight withModifiers: modifiers];
		}
		if (simulatedMouseButtons & BXSimulatedButtonRight)
			[inputHandler mouseButtonReleased: OSXMouseButtonRight withModifiers: modifiers];
		if (simulatedMouseButtons & BXSimulatedButtonMiddle)
			[inputHandler mouseButtonReleased: OSXMouseButtonMiddle withModifiers: modifiers];
		
		simulatedMouseButtons = BXNoSimulatedButtons;
	}
	//Pass the mouse release as-is to our input handler
	else [inputHandler mouseButtonReleased: OSXMouseButtonLeft withModifiers: modifiers];
}


//Work out mouse motion relative to the DOS viewport canvas, passing on the current position
//and last movement delta to the emulator's input handler.
//We represent position and delta as as a fraction of the canvas rather than as a fixed unit
//position, so that they stay consistent when the view size changes.
- (void) mouseMoved: (NSEvent *)theEvent
{
	NSRect canvas = [[self view] bounds];
	CGFloat width = canvas.size.width;
	CGFloat height = canvas.size.height;
	
	NSPoint relativePosition, relativeDelta;

	relativeDelta = NSMakePoint([theEvent deltaX] / width,
								[theEvent deltaY] / height);		
	
	
	//If we have just warped the mouse, the delta above will include the distance warped
	//as well as the actual distance moved in this mouse event: so, we subtract the warp.
	if (!NSEqualPoints(distanceWarped, NSZeroPoint))
	{
		relativeDelta.x -= distanceWarped.x;
		relativeDelta.y -= distanceWarped.y;
		distanceWarped = NSZeroPoint;
	}
	
	if ([self mouseLocked])
	{
		//While we're mouselocked and the cursor is disassociated,
		//we can't get an absolute mouse position, so we have to calculate
		//it using the delta from the last known position.
		relativePosition.x = lastMousePosition.x + relativeDelta.x;
		relativePosition.y = lastMousePosition.y + relativeDelta.y;
	}
	else
	{
		NSPoint pointInView	= [[self view] convertPoint: [theEvent locationInWindow] fromView: nil];
		relativePosition	= NSMakePoint(pointInView.x / width,
										  pointInView.y / height);
	}
	
	//Clamp the position to within the canvas.
	relativePosition = clampPointToRect(relativePosition, NSMakeRect(0.0, 0.0, 1.0, 1.0));
	
	//Record the position for next time.
	lastMousePosition = relativePosition;
	
	//Ignore DOSBox-generated mouse position updates generated by this call
	//FIXME: ewwwww.
	updatingMousePosition = YES;
	[[self representedObject] mouseMovedToPoint: relativePosition
									   byAmount: relativeDelta
									   onCanvas: canvas
									whileLocked: [self mouseLocked]];
	//Resume paying attention to mouse position updates
	updatingMousePosition = NO;
}

//Treat drag events as simple mouse movement
- (void) mouseDragged: (NSEvent *)theEvent		{ [self mouseMoved: theEvent]; }
- (void) rightMouseDragged: (NSEvent *)theEvent	{ return [self mouseDragged: theEvent]; }
- (void) otherMouseDragged: (NSEvent *)theEvent	{ return [self mouseDragged: theEvent]; }


- (void) mouseExited: (NSEvent *)theEvent
{
	[self willChangeValueForKey: @"mouseInView"];
	[super mouseExited: theEvent];
	[self didChangeValueForKey: @"mouseInView"];
}

- (void) mouseEntered: (NSEvent *)theEvent
{
	[self willChangeValueForKey: @"mouseInView"];
	[super mouseEntered: theEvent];
	[self didChangeValueForKey: @"mouseInView"];
}

#pragma mark -
#pragma mark Key events

- (void) keyDown: (NSEvent *)theEvent
{
	//Pressing ESC while in fullscreen mode and not running a program will exit fullscreen mode. 	
	if ([[theEvent charactersIgnoringModifiers] isEqualToString: @"\e"] &&
		[[self view] isInFullScreenMode] &&
		![[[self representedObject] emulator] isRunningProcess])
	{
		[NSApp sendAction: @selector(exitFullScreen:) to: nil from: self];
	}
	
	//If the keypress was command-modified, don't pass it on to the emulator as it indicates
	//a failed key equivalent.
	//(This is consistent with how other OS X apps with textinput handle Cmd-keypresses.)
	else if ([theEvent modifierFlags] & NSCommandKeyMask)
		[super keyDown: theEvent];
	
	//Otherwise, pass the keypress on to our input handler.
	else [[self representedObject] sendKeyEventWithCode: [theEvent keyCode]
												pressed: YES
										  withModifiers: [theEvent modifierFlags]];
}

- (void) keyUp: (NSEvent *)theEvent
{
	//If the keypress was command-modified, don't pass it on to the emulator as it indicates
	//a failed key equivalent.
	//(This is consistent with how other OS X apps with textinput handle Cmd-keypresses.)
	if ([theEvent modifierFlags] & NSCommandKeyMask)
		[super keyUp: theEvent];
	
	[[self representedObject] sendKeyEventWithCode: [theEvent keyCode]
										   pressed: NO withModifiers:
	 [theEvent modifierFlags]];
}

//Convert flag changes into proper key events
- (void) flagsChanged: (NSEvent *)theEvent
{
	unsigned short keyCode	= [theEvent keyCode];
	NSUInteger modifiers	= [theEvent modifierFlags];
	NSUInteger flag;
	
	//We can determine which modifier key was involved by its key code,
	//but we can't determine from the event whether it was pressed or released.
	//So, we check whether the corresponding modifier flag is active or not.	
	switch (keyCode)
	{
		case kVK_Control:		flag = BXLeftControlKeyMask;	break;
		case kVK_Option:		flag = BXLeftAlternateKeyMask;	break;
		case kVK_Shift:			flag = BXLeftShiftKeyMask;		break;
			
		case kVK_RightControl:	flag = BXRightControlKeyMask;	break;
		case kVK_RightOption:	flag = BXRightAlternateKeyMask;	break;
		case kVK_RightShift:	flag = BXRightShiftKeyMask;		break;
			
		case kVK_CapsLock:		flag = NSAlphaShiftKeyMask;		break;
			
		default:
			//Ignore all other modifier types
			return;
	}
	
	BOOL pressed = (modifiers & flag) == flag;
	
	//Implementation note: you might think that CapsLock has to be handled differently since
	//it's a toggle. However, DOSBox expects a keydown event when CapsLock is toggled on,
	//and a keyup event when CapsLock is toggled off, so this default behaviour is fine.
	
	[[self representedObject] sendKeyEventWithCode: keyCode
										   pressed: pressed
									 withModifiers: modifiers];
}




#pragma mark -
#pragma mark Mouse focus and locking 
	 
	 
- (IBAction) toggleMouseLocked: (id)sender
{
	BOOL wasLocked = [self mouseLocked];
	[self setMouseLocked: !wasLocked];
	
	//If the mouse state was actually toggled, play a sound to commemorate the occasion
	if ([self mouseLocked] != wasLocked)
	{
		NSString *lockSoundName	= (wasLocked) ? @"LockOpening" : @"LockClosing";
		[[NSApp delegate] playUISoundWithName: lockSoundName atVolume: 0.5f];
	}
}

- (BOOL) validateMenuItem: (NSMenuItem *)menuItem
{
	SEL theAction = [menuItem action];
	
	if (theAction == @selector(toggleMouseLocked:))
	{
		[menuItem setState: [self mouseLocked]];
		return [self mouseActive];
	}
	return YES;
}
	 
- (void) setMouseLocked: (BOOL)lock
{
	//Don't continue if we're already in the right lock state
	if (lock == [self mouseLocked]) return;
	
	//Don't allow the mouse to be unlocked while in fullscreen mode
	if (!lock && [[self view] isInFullScreenMode]) return;
	
	//Don't allow the mouse to be locked if the game hasn't indicated mouse support
	//Tweak: unless we're in fullscreen mode, in which case we only really do it
	//to hide the mouse cursor.
	if (lock && ![self mouseActive] && ![[self view] isInFullScreenMode]) return;
	
	
	//If we got this far, go ahead!
	[self willChangeValueForKey: @"mouseLocked"];
	
	//When locking, always ensure the application and DOS window are active.
	if (lock)
	{
		[NSApp activateIgnoringOtherApps: YES];
		[[[self view] window] makeKeyAndOrderFront: self];
	}
	
	[self _applyMouseLockState: lock];
	
	mouseLocked = lock;
	
	[self didChangeValueForKey: @"mouseLocked"];
}

- (void) _syncOSXCursorToPointInCanvas: (NSPoint)point
{
	NSPoint oldPointOnScreen = [NSEvent mouseLocation];
	NSPoint newPointOnScreen = [self _pointOnScreen: point];
	
	CGPoint cgPointOnScreen	= NSPointToCGPoint(newPointOnScreen);
	
	//Correct for CG's top-left origin, since _pointOnScreen will return AppKit-style coordinates.
	NSRect screenFrame = [[[[self view] window] screen] frame];
	cgPointOnScreen.y = screenFrame.size.height - screenFrame.origin.y - cgPointOnScreen.y;
	
	CGWarpMouseCursorPosition(cgPointOnScreen);
	
	//Warping the mouse won't generate a mouseMoved event, but it will mess up the delta on the 
	//next mouseMoved event to reflect the distance the mouse was warped. So, we determine how
	//far the mouse was warped, and subtract that from the next mouse delta calculation.
	NSRect canvas = [[self view] bounds];
	distanceWarped = NSMakePoint((newPointOnScreen.x - oldPointOnScreen.x) / canvas.size.width,
								 -(newPointOnScreen.y - oldPointOnScreen.y) / canvas.size.height);
}

- (NSPoint) _pointOnScreen: (NSPoint)canvasPoint
{
	NSRect canvas = [[self view] bounds];
	NSPoint pointInView = NSMakePoint(canvasPoint.x * canvas.size.width,
									  canvasPoint.y * canvas.size.height);
	
	NSPoint pointInWindow = [[self view] convertPoint: pointInView toView: nil];
	NSPoint pointOnScreen = [[[self view] window] convertBaseToScreen: pointInWindow];
	
	return pointOnScreen;
}

- (void) _applyMouseLockState: (BOOL)lock
{	
	//Ensure we don't "over-hide" the cursor if it's already hidden
	//(since [NSCursor hide] stacks)
	BOOL cursorVisible = CGCursorIsVisible();
	
	if		(cursorVisible && lock)		[NSCursor hide];
	else if (!cursorVisible && !lock)	[NSCursor unhide];
	
	//Associate/disassociate the mouse and the OS X cursor
	CGAssociateMouseAndMouseCursorPosition(!lock);
	
	//If we're unlocking, or the mouse isn't over the window when we lock, then
	//warp the cursor to the equivalent position of the DOS cursor within the view.
	//This gives a smooth transition from locked to unlocked mode, and ensures that
	//when we lock the mouse it will always be over the window so that clicks don't
	//go astray.
	if (!lock || ![self mouseInView])
	{
		NSPoint newMousePosition = lastMousePosition;
		
		//Tweak: when unlocking the mouse, inset it slightly from the edges of the canvas,
		//as having the mouse exactly flush with the window edge looks ugly.
		if (!lock) newMousePosition = clampPointToRect(newMousePosition, NSMakeRect(0.01, 0.01, 0.98, 0.98));
		
		[self _syncOSXCursorToPointInCanvas: newMousePosition];
		
		lastMousePosition = newMousePosition;
	}
}

@end