/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXRenderViewController.h"
#import "BXAppController.h"

@implementation BXRenderViewController
@synthesize hiddenCursor, mouseLocked, mouseActive;


/* General helper methods */
/* ---------------------- */

- (BOOL) mouseInView
{
	if ([[self view] isInFullScreenMode]) return YES;
	
	NSView *view = [self view];
	NSPoint mouseLocation = [[view window] mouseLocationOutsideOfEventStream];
	NSPoint relativePoint = [view convertPoint: mouseLocation fromView: nil];
	return [view mouse: relativePoint inRect: [view bounds]];
}


/* Initialization and destruction */
/* ------------------------------ */

- (void) awakeFromNib
{
	//Add a cursor region to our view so that we can track mouse events
	NSTrackingAreaOptions options = NSTrackingMouseEnteredAndExited | NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect | NSTrackingAssumeInside;
	
	NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect: NSZeroRect
																options: options
																  owner: self
															   userInfo: nil];
	[[self view] addTrackingArea: trackingArea];
	[trackingArea release];
}

- (void) dealloc
{
	[self setHiddenCursor: nil], [hiddenCursor release];
	[super dealloc];
}


/* Mouse cursor handling */
/* --------------------- */

- (void) setMouseActive: (BOOL)active
{
	[self willChangeValueForKey: @"mouseActive"];
	mouseActive = active;
	[self cursorUpdate: nil];
	[self didChangeValueForKey: @"mouseActive"];
}


- (NSCursor *)hiddenCursor
{
	//If we don't have a hidden cursor yet, generate it now
	if (!hiddenCursor)
	{
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
	return hiddenCursor;
}

- (void) cursorUpdate: (NSEvent *)theEvent
{
	if ([self mouseActive] && [self mouseInView])
	{
		[[self hiddenCursor] set];
	}
}

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


/* Mouse locking */
/* ------------- */

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

- (BOOL) validateMenuItem: (NSMenuItem *)theItem
{
	SEL theAction = [theItem action];
	if (theAction == @selector(toggleMouseLocked:))
	{
		[theItem setState: [self mouseLocked]];
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
	//([NSCursor hide] seems to stack)
	BOOL cursorVisible = CGCursorIsVisible();
	
	if		(cursorVisible && lock)		[NSCursor hide];
	else if (!cursorVisible && !lock)	[NSCursor unhide];
	
	[self didChangeValueForKey: @"mouseLocked"];
}

@end