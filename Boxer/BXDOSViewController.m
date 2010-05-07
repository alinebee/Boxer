/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXDOSViewController.h"
#import "BXSessionWindowController.h"
#import "BXEmulatorEventResponder.h"
#import "BXEmulator.h"
#import "BXAppController.h"


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
	[[[self emulator] eventHandler] lostFocus];
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
//and last movement delta to the emulator's event handler.
- (void) mouseMoved: (NSEvent *)theEvent
{
	NSPoint relativePosition;
	NSPoint relativeDelta;
	NSRect canvas = [[self view] bounds];
	
	if ([self mouseLocked])
	{
		//While we're mouselocked and the cursor is disassociated,
		//we can't get an absolute mouse position, so we have to calculate
		//it using the delta from the last known position. We store this
		//as a 0-1 ratio of the canvas rather than as a fixed unit position,
		//so that it doesn't get muddled up by changes to the view size.
		
		relativeDelta = NSMakePoint([theEvent deltaX] / canvas.size.width,
									-[theEvent deltaY] / canvas.size.height);
		
		relativePosition = lastMousePosition;
		
		//Update the last known position with the new mouse delta
		relativePosition.x += relativeDelta.x;
		relativePosition.y += relativeDelta.y;
	}
	else
	{
		NSPoint pointInView	= [[self view] convertPoint: [theEvent locationInWindow] fromView: nil];
		
		relativeDelta		= NSMakePoint([theEvent deltaX] / canvas.size.width,
										  -[theEvent deltaY] / canvas.size.height);
		relativePosition	= NSMakePoint(pointInView.x / canvas.size.width,
										  pointInView.y / canvas.size.height);
	}
	
	//Clamp the position's axes to within 0.0 and 1.0
	relativePosition.x = fmaxf(fminf(relativePosition.x, 1.0f), 0.0f);
	relativePosition.y = fmaxf(fminf(relativePosition.y, 1.0f), 0.0f);
	
	//Record the position so that we can use it next time
	lastMousePosition = relativePosition;
	
	[[[self emulator] eventHandler] mouseMovedToPoint: relativePosition
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
	if ([[self view] isInFullScreenMode] && !lock) return;
	
	//Don't allow the mouse to be locked if the game hasn't requested mouse locking
	if (![self mouseActive] && lock) return;
	
	
	//If we got this far, go ahead!
	[self willChangeValueForKey: @"mouseLocked"];
	
	mouseLocked = lock;
	
	//Ensure we don't "over-hide" the cursor if it's already hidden
	//(since [NSCursor hide] stacks)
	BOOL cursorVisible = CGCursorIsVisible();
	
	if		(cursorVisible && lock)		[NSCursor hide];
	else if (!cursorVisible && !lock)	[NSCursor unhide];
	
	//Associate/disassociate the mouse and the OS X cursor
	CGAssociateMouseAndMouseCursorPosition(!lock);
	
	//When locking, always ensure the DOS window is key and frontmost.
	if (lock) [[[self view] window] makeKeyAndOrderFront: self];
	
	//Warp the cursor to the equivalent position of the DOS cursor within the view.
	//This gives a smooth user transition from locked to unlocked mode, and ensures
	//that when we lock the mouse it will always be over the window (so that clicks
	//don't go astray).
	[self _syncOSXCursorToPointInCanvas: lastMousePosition];
	
	[self didChangeValueForKey: @"mouseLocked"];
}

- (void) _syncOSXCursorToPointInCanvas: (NSPoint)point
{
	NSRect canvas = [[self view] bounds];
	NSPoint pointInView = NSMakePoint(point.x * canvas.size.width,
									  point.y * canvas.size.height);
	
	NSPoint pointOnScreen = [[[self view] window] convertBaseToScreen: [[self view] convertPointToBase: pointInView]];
	CGPoint cgPointOnScreen	= NSPointToCGPoint(pointOnScreen);
	
	//Correct for CG's top-left origin
	NSRect screenFrame = [[[[self view] window] screen] frame];
	cgPointOnScreen.y = screenFrame.size.height - screenFrame.origin.y - cgPointOnScreen.y;
	CGWarpMouseCursorPosition(cgPointOnScreen);
}

@end