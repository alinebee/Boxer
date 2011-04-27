/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXEmulatedMouse.h"

#import "config.h"
#import "video.h"
#import "mouse.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXEmulatedMouse ()
@property (readwrite, assign) NSUInteger pressedButtons;

- (void) setButton: (BXMouseButton)button toState: (BOOL)pressed;
- (void) releaseButton: (NSNumber *)button;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXEmulatedMouse
@synthesize active, position, pressedButtons;

- (id) init
{
	if ((self = [super init]))
	{
		active			= NO;
		position		= NSMakePoint(0.5f, 0.5f);
		pressedButtons	= BXNoMouseButtonsMask;
	}
	return self;
}

#pragma mark -
#pragma mark Controlling response state

- (void) clearInput
{
	[self buttonUp: BXMouseButtonLeft];
	[self buttonUp: BXMouseButtonRight];
	[self buttonUp: BXMouseButtonMiddle];
}

- (void) setActive: (BOOL)flag
{
	if (active != flag)
	{
		//If mouse support is disabled while we still have mouse buttons pressed,
		//then release those buttons before continuing.
		if (!flag) [self clearInput];
		
		active = flag;
	}
}

- (void) movedTo: (NSPoint)point
			  by: (NSPoint)delta
		onCanvas: (NSRect)canvas
	 whileLocked: (BOOL)locked
{
	if ([self isActive])
	{
		//In DOSBox land, absolute position is from 0.0 to 1.0 but delta is in raw pixels,
		//for some silly reason.
		//TODO: try making this relative to the DOS driver's max mouse position instead.
		NSPoint canvasDelta = NSMakePoint(delta.x * canvas.size.width,
										  delta.y * canvas.size.height);
		
		Mouse_CursorMoved(canvasDelta.x,
						  canvasDelta.y,
						  point.x,
						  point.y,
						  locked);
	}
}

- (void) setButton: (BXMouseButton)button
		   toState: (BOOL)pressed
{
	//Ignore button presses while we're inactive
	if (![self isActive]) return;
	
	NSUInteger buttonMask = 1U << button;
	
	if ([self buttonIsDown: button] != pressed)
	{
		if (pressed)
		{
			Mouse_ButtonPressed(button);
			[self setPressedButtons: pressedButtons | buttonMask];
		}
		else
		{
			Mouse_ButtonReleased(button);
			[self setPressedButtons: pressedButtons & ~buttonMask];
		}
	}
}

- (void) buttonDown: (BXMouseButton)button
{
	[self setButton: button toState: YES];
}

- (void) buttonUp: (BXMouseButton)button
{
	[self setButton: button toState: NO];
}

- (BOOL) buttonIsDown: (BXMouseButton)button
{
	NSUInteger buttonMask = 1U << button;
	
	return (pressedButtons & buttonMask) == buttonMask;
}


- (void) buttonPressed: (BXMouseButton)button
{
	[self buttonPressed: button forDuration: BXMouseButtonPressDurationDefault];
}

- (void) buttonPressed: (BXMouseButton)button forDuration: (NSTimeInterval)duration
{
	[self buttonDown: button];
	
	[self performSelector: @selector(releaseButton:)
			   withObject: [NSNumber numberWithUnsignedInteger: button]
			   afterDelay: duration];
}

- (void) releaseButton: (NSNumber *)button
{
	[self buttonUp: [button unsignedIntegerValue]];
}

@end
