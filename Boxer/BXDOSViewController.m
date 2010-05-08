/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDOSViewController.h"
#import "BXSessionWindowController.h"
#import "BXInputHandler.h"
#import "BXEmulator.h"
#import "BXAppController.h"
#import "BXGeometry.h"


@implementation BXDOSViewController
@synthesize windowController;
@synthesize mouseLocked, mouseActive, hiddenCursor;


#pragma mark -
#pragma mark Helper accessors

- (BXEmulator *) emulator
{
	return [[self windowController] emulator];
}


#pragma mark -
#pragma mark Initialization and cleanup

- (void) awakeFromNib
{
	//Initialize the mouse position to the centre of the DOS view,
	//in case we lock the mouse before receiving a mouseMoved event.
	lastMousePosition = NSMakePoint(0.5, 0.5);
	
	//Insert ourselves into the responder chain as the view's next responder
	[self setNextResponder: [[self view] nextResponder]];
	[[self view] setNextResponder: self];
	 
	//Set up cursor region for mouse handling
	NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited | NSTrackingEnabledDuringMouseDrag | NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect | NSTrackingAssumeInside;
	
	NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect: NSZeroRect
																options: options
																  owner: self
															   userInfo: nil];
	
	[[self view] addTrackingArea: trackingArea];
	[trackingArea release];	
	 
	//Create our hidden cursor
	 
	NSCursor *arrowCursor	= [NSCursor arrowCursor];
	NSImage *arrowImage		= [arrowCursor image];
	NSImage *blankImage		= [[NSImage alloc] initWithSize: [arrowImage size]];
	 
	//Use a faded cursor instead of an entirely blank one.
	//This is disabled for now because it looks quite distracting.
	 
	/*
	[blankImage lockFocus];
	[arrowImage drawAtPoint: NSZeroPoint fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 0.25];
	[blankImage unlockFocus];
	*/
	 
	NSCursor *blankCursor = [[NSCursor alloc] initWithImage: blankImage hotSpot: [arrowCursor hotSpot]];
	[self setHiddenCursor: blankCursor];
	[blankImage release];
	[blankCursor release];
}

- (void) dealloc
{
	[self setHiddenCursor: nil], [hiddenCursor release];
	[super dealloc];
}

	
#pragma mark -
#pragma mark Cursor handling

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


#pragma mark -
#pragma mark Event responding

- (void) didResignKey
{
	[self setMouseLocked: NO];
	[[[self emulator] inputHandler] lostFocus];
}

- (void) cursorUpdate: (NSEvent *)theEvent
{
	//TODO: figure out why cursor is getting reset when the view changes dimensions
	if ([self mouseActive] && [self mouseInView])
	{
		[[self hiddenCursor] set];
	}

}

- (void) mouseDown: (NSEvent *)theEvent
{
	//Cmd-left-click toggles mouse-locking
	if ([theEvent modifierFlags] & NSCommandKeyMask) [self toggleMouseLocked: self];
	
	//Otherwise, pass the click on as-is
	else [super mouseDown: theEvent];
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
	
	if (discardNextMouseDelta)
	{
		//If we have just warped the mouse, the delta will be the difference between the
		//original and warped mouse positions. We want to discard this initial delta.
		relativeDelta = NSZeroPoint;
		discardNextMouseDelta = NO;
	}
	else
	{
		//We invert the delta to be consistent with AppKit's bottom-left screen origin.
		relativeDelta = NSMakePoint([theEvent deltaX] / width,
									-[theEvent deltaY] / height);		
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
	
	[[[self emulator] inputHandler] mouseMovedToPoint: relativePosition
											 byAmount: relativeDelta
											 onCanvas: canvas
										  whileLocked: [self mouseLocked]];
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

- (void) keyDown: (NSEvent *)theEvent
{
	//Pressing ESC while in fullscreen mode and not running a program will exit fullscreen mode. 	
	if ([[theEvent charactersIgnoringModifiers] isEqualToString: @"\e"] &&
		[[self view] isInFullScreenMode] &&
		![[self emulator] isRunningProcess])
	{
		[[self windowController] exitFullScreen: self];
	}
	
	//Otherwise, send the event onwards
	else [[self nextResponder] keyDown: theEvent];
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
	
	mouseLocked = lock;
	
	[self _applyMouseLockState];
	
	[self didChangeValueForKey: @"mouseLocked"];
}

- (void) _syncOSXCursorToPointInCanvas: (NSPoint)point
{
	NSRect canvas = [[self view] bounds];
	NSPoint pointInView = NSMakePoint(point.x * canvas.size.width,
									  point.y * canvas.size.height);
	
	NSPoint pointOnScreen = [[[self view] window] convertBaseToScreen: [[self view] convertPointToBase: pointInView]];
	CGPoint cgPointOnScreen	= NSPointToCGPoint(pointOnScreen);
	
	//Correct for CG's top-left origin, since the result of convertBaseToScreen: will use 
	NSRect screenFrame = [[[[self view] window] screen] frame];
	cgPointOnScreen.y = screenFrame.size.height - screenFrame.origin.y - cgPointOnScreen.y;
	
	CGWarpMouseCursorPosition(cgPointOnScreen);
	
	//Warping the mouse won't generate a mouseMoved event, but it will mess up the delta on the 
	//next mouseMoved event to reflect the distance the mouse was warped. This flag instructs our
	//mouseMoved: handler to ignore the delta from the warp.
	discardNextMouseDelta = YES;
}

- (void) _applyMouseLockState
{
	BOOL lock = [self mouseLocked];
	
	//Ensure we don't "over-hide" the cursor if it's already hidden
	//(since [NSCursor hide] stacks)
	BOOL cursorVisible = CGCursorIsVisible();
	
	if		(cursorVisible && lock)		[NSCursor hide];
	else if (!cursorVisible && !lock)	[NSCursor unhide];
	
	//Associate/disassociate the mouse and the OS X cursor
	CGAssociateMouseAndMouseCursorPosition(!lock);
	
	//Warp the cursor to the equivalent position of the DOS cursor within the view.
	//This gives a smooth user transition from locked to unlocked mode, and ensures
	//that when we lock the mouse it will always be over the window (so that clicks
	//don't go astray).
	
	NSPoint newMousePosition = lastMousePosition;
	
	//Tweak: when unlocking the mouse, inset it slightly from the edges of the canvas,
	//as having the mouse exactly flush with the window edge looks ugly.
	if (!lock) newMousePosition = clampPointToRect(newMousePosition, NSMakeRect(0.01, 0.01, 0.98, 0.98));
	
	[self _syncOSXCursorToPointInCanvas: newMousePosition];
}

@end