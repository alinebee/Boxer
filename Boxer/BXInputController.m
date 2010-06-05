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


#pragma mark -
#pragma mark Constants for configuring behaviour

//The number of seconds it takes for the cursor to fade out after entering the window.
//Cursor animation is flickery so a small duration helps mask this.
const NSTimeInterval BXCursorFadeDuration = 0.4;

//The framerate at which to animate the cursor fade.
//15fps is as fast as is really noticeable.
const float BXCursorFadeFrameRate = 15.0;

//If the cursor is warped less than this distance (relative to a 0.0->1.0 square canvas) then
//the warp will be ignored. Because cursor warping introduces a slight input delay, we use this
//tolerance to ignore small warps.
const CGFloat BXCursorWarpTolerance = 0.1;

const float BXMouseLockSoundVolume = 0.5;


//Flags for which mouse buttons we are currently faking (for Ctrl- and Opt-clicking.)
//Note that while these are ORed together, there will currently only ever be one of them active at a time.
enum {
	BXNoSimulatedButtons			= 0,
	BXSimulatedButtonRight			= 1,
	BXSimulatedButtonMiddle			= 2,
	BXSimulatedButtonLeftAndRight	= 4,
};


@interface BXInputController (BXInputControllerInternals)

//Returns whether we should have control of the mouse cursor state.
//This is true if the mouse is within the view, the window is key,
//and mouse input is in use by the DOS program.
- (BOOL) _controlsCursor;

//Converts a 0.0-1.0 relative canvas offset to a point on screen.
- (NSPoint) _pointOnScreen: (NSPoint)canvasPoint;

//Converts a point on screen to a 0.0-1.0 relative canvas offset.
- (NSPoint) _pointInCanvas: (NSPoint)screenPoint;

//Performs the fiddly internal work of locking/unlocking the mouse.
- (void) _applyMouseLockState: (BOOL)lock;

//Responds to the emulator moving the mouse cursor,
//either in response to our own signals or of its own accord.
- (void) _emulatorCursorMovedToPointInCanvas: (NSPoint)point;

//Warps the OS X cursor to the specified point on our virtual mouse canvas.
//Used when locking and unlocking the mouse and when DOS warps the mouse.
- (void) _syncOSXCursorToPointInCanvas: (NSPoint)point;

@end


@implementation BXInputController
@synthesize mouseLocked, mouseActive;

#pragma mark -
#pragma mark Initialization and cleanup

- (void) awakeFromNib
{	
	//DOSBox-triggered cursor warp distances which fit within this deadzone will be ignored
	//to prevent needless input delays. q.v. _emulatorCursorMovedToPointInCanvas:
	cursorWarpDeadzone = NSInsetRect(NSZeroRect, -BXCursorWarpTolerance, -BXCursorWarpTolerance);
	
	//The extent of our relative mouse canvas. Mouse coordinates passed to DOSBox will be
	//relative to this canvas and clamped to fit within it. q.v. mouseMoved:
	canvasBounds = NSMakeRect(0.0, 0.0, 1.0, 1.0);
	
	//Used for constraining where the mouse cursor will appear when we unlock the mouse.
	//This is inset slightly from canvasBounds, because a cursor that appears right at the
	//very edge of the window looks dumb. q.v. _applyMouseLockState:
	visibleCanvasBounds = NSMakeRect(0.01, 0.01, 0.98, 0.98);
	
	
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
	cursorFade = [[BXCursorFadeAnimation alloc] initWithDuration: BXCursorFadeDuration
												  animationCurve: NSAnimationEaseIn];
	[cursorFade setDelegate: self];
	[cursorFade setOriginalCursor: [NSCursor arrowCursor]];
	[cursorFade setAnimationBlockingMode: NSAnimationNonblocking];
	[cursorFade setFrameRate: BXCursorFadeFrameRate];
}

- (void) dealloc
{
	[cursorFade stopAnimation];
	[cursorFade release], cursorFade = nil;
	
	[super dealloc];
	
	NSLog(@"BXInputController dealloc");
}


- (void) setRepresentedObject: (BXInputHandler *)representedObject
{
	if (representedObject != [self representedObject])
	{
		if ([self representedObject])
		{
			[self unbind: @"mouseActive"];
			[[self representedObject] removeObserver: self forKeyPath: @"mousePosition"];
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
	//This is the only value we're observing, so don't bother checking the key path
	[self _emulatorCursorMovedToPointInCanvas: [object mousePosition]];
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
	//Release the mouse lock when the game stops using the mouse
	if (!active) [self setMouseLocked: NO];
	
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

- (void) rightMouseUp:(NSEvent *)theEvent
{
	[[self representedObject] mouseButtonReleased: OSXMouseButtonRight withModifiers: [theEvent modifierFlags]];
}

- (void) otherMouseUp:(NSEvent *)theEvent
{
	if ([theEvent buttonNumber] == OSXMouseButtonMiddle)
		[[self representedObject] mouseButtonReleased: OSXMouseButtonMiddle withModifiers: [theEvent modifierFlags]];
	else [super otherMouseDown: theEvent];
}

//Work out mouse motion relative to the view's canvas, passing on the current position
//and movement delta to the emulator's input handler.
//We represent position and delta as as a fraction of the canvas rather than as a fixed unit
//position, so that they stay consistent when the view size changes.
- (void) mouseMoved: (NSEvent *)theEvent
{	
	NSRect canvas = [[self view] bounds];
	CGFloat width = canvas.size.width;
	CGFloat height = canvas.size.height;
	
	NSPoint pointOnCanvas, delta;

	//Make the delta relative to the canvas
	delta = NSMakePoint([theEvent deltaX] / width,
						[theEvent deltaY] / height);		
	
	//If we have just warped the mouse, the delta above will include the distance warped
	//as well as the actual distance moved in this mouse event: so, we subtract the warp.
	if (!NSEqualPoints(distanceWarped, NSZeroPoint))
	{
		delta.x -= distanceWarped.x;
		delta.y -= distanceWarped.y;
		distanceWarped = NSZeroPoint;
	}
	
	if (![self mouseLocked])
	{
		NSPoint pointInView	= [[self view] convertPoint: [theEvent locationInWindow]
											   fromView: nil];
		pointOnCanvas = NSMakePoint(pointInView.x / width,
									pointInView.y / height);

		//Clamp the position to within the canvas.
		pointOnCanvas = clampPointToRect(pointOnCanvas, canvasBounds);
	}
	else
	{
		//While the mouse is locked, OS X won't update the absolute cursor position and
		//DOSBox won't pay attention to the absolute cursor position either, so we don't
		//bother calculating it.
		pointOnCanvas = NSZeroPoint;
	}
	
	//Tells _emulatorCursorMovedToPointInCanvas: not to warp the mouse cursor based on
	//DOSBox mouse position updates from this call.
	updatingMousePosition = YES;
	
	[[self representedObject] mouseMovedToPoint: pointOnCanvas
									   byAmount: delta
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
		[[NSApp delegate] playUISoundWithName: lockSoundName atVolume: BXMouseLockSoundVolume];
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
@end


#pragma mark -
#pragma mark Internal methods

@implementation BXInputController (BXInputControllerInternals)

- (BOOL) _controlsCursor
{
	return [self mouseActive] && [[[self view] window] isKeyWindow] && [self mouseInView];
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

- (NSPoint) _pointInCanvas: (NSPoint)screenPoint
{
	NSPoint pointInWindow	= [[[self view] window] convertScreenToBase: screenPoint];
	NSPoint pointInView		= [[self view] convertPoint: pointInWindow fromView: nil];
	
	NSRect canvas = [[self view] bounds];
	NSPoint pointInCanvas = NSMakePoint(pointInView.x / canvas.size.width,
										pointInView.y / canvas.size.height);
	
	return pointInCanvas;	
}

- (void) _applyMouseLockState: (BOOL)lock
{
	//Ensure we don't "over-hide" the cursor if it's already hidden
	//(since [NSCursor hide] stacks)
	BOOL cursorVisible = CGCursorIsVisible();
	
	if		(cursorVisible && lock)		[NSCursor hide];
	else if (!cursorVisible && !lock)	[NSCursor unhide];
	
	//Reset any custom faded cursor to the default arrow cursor.
	[[NSCursor arrowCursor] set];
	
	//Associate/disassociate the mouse and the OS X cursor
	CGAssociateMouseAndMouseCursorPosition(!lock);
	
	if (lock)
	{
		//If we're locking the mouse and the cursor is outside of the view,
		//then warp it to the center of the DOS view.
		//This prevents mouse clicks from going to other windows.
		//(We avoid warping if the mouse is already over the view,
		//as this would cause an input delay.)
		if (![self mouseInView]) [self _syncOSXCursorToPointInCanvas: NSMakePoint(0.5, 0.5)];
	}
	else
	{
		//If we're unlocking the mouse, then sync the OS X mouse cursor
		//to wherever DOSBox's cursor is located within the view.
		NSPoint mousePosition = [[self representedObject] mousePosition];
		
		//Constrain the cursor position to slightly inset within the view:
		//This ensures the mouse doesn't appear outside the view or right
		//at the view's edge, which looks ugly.
		mousePosition = clampPointToRect(mousePosition, visibleCanvasBounds);
		
		[self _syncOSXCursorToPointInCanvas: mousePosition];
	}
}

- (void) _emulatorCursorMovedToPointInCanvas: (NSPoint)pointInCanvas
{	
	//If the mouse warped of its own accord, and we have control of the cursor,
	//then sync the OS X mouse cursor to match DOSBox's.
	//(We only bother doing this if the mouse is unlocked; there's no point doing
	//otherwise, since we'll sync the cursors when we unlock.)
	if (!updatingMousePosition && ![self mouseLocked] && [self _controlsCursor])
	{
		//Don't sync if the mouse was warped to the 0, 0 point:
		//This indicates a game testing the extents of the mouse canvas.
		if (NSEqualPoints(pointInCanvas, NSZeroPoint)) return;
		
		//Don't sync if the mouse was warped outside the canvas:
		//This would place the mouse cursor beyond the confines of the window.
		if (!NSPointInRect(pointInCanvas, canvasBounds)) return;
		
		//Because syncing the OS X cursor causes a slight but noticeable input delay,
		//we check how far it moved and ignore small distances.
		NSPoint oldPointInCanvas = [self _pointInCanvas: [NSEvent mouseLocation]];
		NSPoint distance = deltaFromPointToPoint(oldPointInCanvas, pointInCanvas);

		if (!NSPointInRect(distance, cursorWarpDeadzone))
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
	distanceWarped = deltaFromPointToPoint(oldPointInCanvas, pointInCanvas);
	
	
	CGPoint cgPointOnScreen = NSPointToCGPoint(pointOnScreen);
	//Flip the coordinates to compensate for AppKit's bottom-left screen origin
	NSRect screenFrame = [[[[self view] window] screen] frame];
	cgPointOnScreen.y = screenFrame.origin.y + screenFrame.size.height - cgPointOnScreen.y;
	
	//TODO: check that this behaves correctly across multiple displays.
	CGWarpMouseCursorPosition(cgPointOnScreen);
}

@end