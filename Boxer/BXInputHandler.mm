/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXInputHandler.h"
#import "BXEmulator.h"

#import "config.h"
#import "video.h"
#import "mouse.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXInputHandler ()
@property (readwrite, assign) NSUInteger pressedMouseButtons;

- (void) _releaseButton: (NSArray *)args;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXInputHandler
@synthesize emulator;
@synthesize mouseActive, pressedMouseButtons;
@synthesize mousePosition;

- (id) init
{
	if ((self = [super init]))
	{
		mousePosition	= NSMakePoint(0.5f, 0.5f);
		mouseActive		= NO;
		pressedMouseButtons = BXNoMouseButtonsMask;
	}
	return self;
}

#pragma mark -
#pragma mark Controlling response state

- (void) releaseMouseInput
{
	if (pressedMouseButtons != BXNoMouseButtonsMask)
	{
		[self mouseButtonReleased: BXMouseButtonLeft withModifiers: 0];
		[self mouseButtonReleased: BXMouseButtonRight withModifiers: 0];
		[self mouseButtonReleased: BXMouseButtonMiddle withModifiers: 0];
	}
}


- (BOOL) mouseActive
{
	//Ignore whether the program has actually asked for the mouse,
	//and just assume that every program needs it. This fixes games
	//that use the mouse but don't advertise that fact.
	return ![emulator isAtPrompt];
}

- (void) setMouseActive: (BOOL)flag
{
	if (mouseActive != flag)
	{
		mouseActive = flag;
		
		//If mouse support is disabled while we still have mouse buttons pressed, then release those buttons
		if (!mouseActive && pressedMouseButtons != BXNoMouseButtonsMask)
		{
			[self mouseButtonReleased: BXMouseButtonLeft withModifiers: 0];
			[self mouseButtonReleased: BXMouseButtonRight withModifiers: 0];
			[self mouseButtonReleased: BXMouseButtonMiddle withModifiers: 0];
		}
	}
}


#pragma mark -
#pragma mark Mouse handling

- (void) mouseButtonPressed: (BXMouseButton)button
			  withModifiers: (NSUInteger) modifierFlags
{
	NSUInteger buttonMask = 1U << button;
	
	//Only press the button if it's not already pressed, to avoid duplicate events confusing DOS games.
	if ([[self emulator] isExecuting] && !([self pressedMouseButtons] & buttonMask))
	{
		Mouse_ButtonPressed(button);
		[self setPressedMouseButtons: pressedMouseButtons | buttonMask];
	}
}

- (void) mouseButtonReleased: (BXMouseButton)button
			   withModifiers: (NSUInteger)modifierFlags
{
	NSUInteger buttonMask = 1U << button;
	
	//Likewise, only release the button if it was actually pressed.
	if ([[self emulator] isExecuting] && ([self pressedMouseButtons] & buttonMask))
	{
		Mouse_ButtonReleased(button);
		[self setPressedMouseButtons: pressedMouseButtons & ~buttonMask];
	}
}

- (void) mouseButtonClicked: (BXMouseButton)button
			  withModifiers: (NSUInteger)modifierFlags
{
	[self mouseButtonPressed: button withModifiers: modifierFlags];
	
	//Release the button after a brief delay
	[self performSelector: @selector(_releaseButton:)
			   withObject: [NSArray arrayWithObjects:
							[NSNumber numberWithUnsignedInteger: button],
							[NSNumber numberWithUnsignedInteger: modifierFlags],
							nil]
			   afterDelay: 0.25];
}

- (void) mouseMovedToPoint: (NSPoint)point
				  byAmount: (NSPoint)delta
				  onCanvas: (NSRect)canvas
			   whileLocked: (BOOL)locked
{
	if ([[self emulator] isExecuting])
	{
		//In DOSBox land, absolute position is from 0-1 but delta is in raw pixels, for some silly reason.
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


#pragma mark -
#pragma mark Internal methods

- (void) _releaseButton: (NSArray *)args
{
	NSUInteger button			= [[args objectAtIndex: 0] unsignedIntegerValue];
	NSUInteger modifierFlags	= [[args objectAtIndex: 1] unsignedIntegerValue];
	
	[self mouseButtonReleased: button withModifiers: modifierFlags];
}

@end
