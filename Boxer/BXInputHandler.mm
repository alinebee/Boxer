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
#import "joystick.h"


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
@synthesize joystickType;

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

- (void) releaseJoystickInput
{
	//Reset the joystick state to default values
	[self joystickPOVSwitchChangedToDirection: BXDOSFlightstickPOVCentered];
	
	JOYSTICK_Move_X(0, 0.0f);
	JOYSTICK_Move_Y(0, 0.0f);
	JOYSTICK_Button(0, 0, NO);
	JOYSTICK_Button(0, 1, NO);
	
	JOYSTICK_Move_X(1, 0.0f);
	JOYSTICK_Move_Y(1, 0.0f);
	JOYSTICK_Button(1, 0, NO);
	JOYSTICK_Button(1, 1, NO);
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

- (void) setJoystickType: (BXDOSJoystickType)type
{
	if ([self joystickType] != type)
	{
		joystickType = type;
	
		[self releaseJoystickInput];
		
		switch (type)
		{
			case BXCHFlightstickPro:
			case BXThrustmasterFCS:
			case BX4AxisJoystick:
				JOYSTICK_Enable(0, YES);
				JOYSTICK_Enable(1, YES);
				break;
			
			case BX2AxisJoystick:
				JOYSTICK_Enable(0, YES);
				JOYSTICK_Enable(1, NO);
				break;
				
			default:
				JOYSTICK_Enable(0, NO);
				JOYSTICK_Enable(1, NO);
		}
	}
}

#pragma mark -
#pragma mark Joystick handling

- (void) _joystickButton: (BXDOSJoystickButton)button
				 pressed: (BOOL)pressed
{
	//The CH Flightstick Pro could only represent one button-press at a time,
	//so unset all the other buttons before setting this one
	if (pressed && [self joystickType] == BXCHFlightstickPro)
	{
		JOYSTICK_Button(0, 0, NO);
		JOYSTICK_Button(0, 1, NO);
		JOYSTICK_Button(1, 0, NO);
		JOYSTICK_Button(1, 1, NO);
	}
	
	//TODO: if CH Flightstick Pro is used, release all other buttons
	switch (button)
	{
		case BXDOSJoystickButton1:
			JOYSTICK_Button(0, 0, pressed);
			break;
			
		case BXDOSJoystickButton2:
			JOYSTICK_Button(0, 1, pressed);
			break;
			
		case BXDOSJoystick2Button1: //Also BXDOSJoystickButton3
			JOYSTICK_Button(1, 0, pressed);
			break;
			
		case BXDOSJoystick2Button2: //Also BXDOSJoystickButton4
			JOYSTICK_Button(1, 1, pressed);
			break;
		
		//TODO: add emulation for CH F-16 Combat Stick buttons 5-6
	}
}

- (void) joystickButtonPressed: (BXDOSJoystickButton)button
{
	[self _joystickButton: button pressed: YES];
}

- (void) joystickButtonReleased: (BXDOSJoystickButton)button
{
	[self _joystickButton: button pressed: NO];
}

- (void) joystickAxisChanged: (BXDOSJoystickAxis)axis toPosition: (float)position
{
	switch (axis)
	{
		case BXDOSJoystickAxisX:
			return JOYSTICK_Move_X(0, position);
		
		case BXDOSJoystickAxisY:
			return JOYSTICK_Move_Y(0, position);
			
		case BXDOSJoystick2AxisX:
			return JOYSTICK_Move_X(1, position);
			
		case BXDOSJoystick2AxisY:
			return JOYSTICK_Move_Y(1, position);
	}
}

- (void) joystickAxisChanged: (BXDOSJoystickAxis)axis byAmount: (float)delta
{
	float currentPosition;
	BOOL isY;
	NSUInteger joyNum;
	
	switch (axis)
	{
		case BXDOSJoystickAxisX:
			currentPosition = JOYSTICK_GetMove_X(0);
			joyNum = 0;
			isY = NO;
			break;
		
		case BXDOSJoystickAxisY:
			currentPosition = JOYSTICK_GetMove_Y(0);
			joyNum = 0;
			isY = YES;
			break;
			
		case BXDOSJoystick2AxisX:
			currentPosition = JOYSTICK_GetMove_X(1);
			joyNum = 1;
			isY = NO;
			break;
			
		case BXDOSJoystick2AxisY:
			currentPosition = JOYSTICK_GetMove_Y(1);
			joyNum = 1;
			isY = YES;
			break;
		
		default:
			return;
	}
	
	//Apply the delta and clamp the result to fit within -1.0 to +1.0
	float newPosition = currentPosition + delta;
	newPosition = fmaxf(fminf(newPosition, 1.0f), -1.0f);
	
	NSLog(@"Axis %i changed by: %f (now %f)", axis, delta, newPosition);
	
	if (isY) JOYSTICK_Move_Y(joyNum, newPosition);
	else	 JOYSTICK_Move_X(joyNum, newPosition);
	
}

//TODO: add support for hat 2 on CH F-16 Combat Stick
- (void) joystickPOVSwitchChangedToDirection: (BXDOSFlightstickPOVDirection)direction
{
	if ([self joystickType] == BXCHFlightstickPro)
	{
		//Bitflags according to:
		//http://www.epanorama.net/documents/joystick/pc_special.html#chflightpro
		char flags = 0;
		switch (direction)
		{
			case BXDOSFlightstickPOVNorth:
				flags = 1 | 2 | 4 | 8;
				break;
				
			case BXDOSFlightstickPOVEast:
				flags = 1 | 2 | 8;
				break;
			
			case BXDOSFlightstickPOVSouth:
				flags = 1 | 2 | 4;
				break;
				
			case BXDOSFlightstickPOVWest:
				flags = 1 | 2;
				break;
		}
		
		JOYSTICK_Button(0, 0, flags & 1);
		JOYSTICK_Button(0, 1, flags & 2);
		JOYSTICK_Button(1, 0, flags & 4);
		JOYSTICK_Button(1, 1, flags & 8);
	}
	//TODO: Thrustmaster FCS hat handling (which uses stick 2 Y axis)
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
