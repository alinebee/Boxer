/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXInputHandler.h"
#import "BXEmulator.h"

#import <Carbon/Carbon.h>	//For OSX keycode constants
#import <SDL/SDL.h>			//For SDL keycode constants
#import "config.h"
#import "video.h"
#import "mouse.h"
#import "joystick.h"

//How long in seconds to 'hold down' a fake keypress before releasing it.
//This gives games enough time to register that the key has been pressed.
#define BXFakeKeypressReleaseDelay 0.25

#define BXUnknownScancode 0


//Declared in mapper.cpp
void MAPPER_CheckEvent(SDL_Event *event);
void MAPPER_LosingFocus();


#pragma mark -
#pragma mark Private method declarations

@interface BXInputHandler ()
@property (readwrite, assign) NSUInteger pressedMouseButtons;

//Simple performSelector:withObject:afterDelay: wrappers, used by
//sendKeypressWithCode:, sendKeypressWithSDLKey: and mouseButtonClicked:
//for releasing their respective keys/buttons after a brief delay.
- (void) _releaseKey: (NSArray *)args;
- (void) _releaseSDLKey: (NSArray *)args;
- (void) _releaseButton: (NSArray *)args;

//Generates and returns an SDL key event with the specified parameters.
+ (SDL_Event) _SDLKeyEventForKeyCode: (CGKeyCode)keyCode
							 pressed: (BOOL)pressed
						   modifiers: (NSUInteger)modifierFlags;

//Generates and returns an SDL key event for the specified SDL key code,
//rather than OS X key code. Uses 0 as the device scancode.
+ (SDL_Event) _SDLKeyEventForSDLKey: (SDLKey)sdlKeyCode
							pressed: (BOOL)pressed
						  modifiers: (NSUInteger)modifierFlags;

//Returns the SDL key constant corresponding to the specified OS X virtual keycode.
+ (SDLKey) _convertToSDLKeyCode: (CGKeyCode)keyCode;	

//Returns the appropriate SDL modifier bitmask for the specified NSEvent modifier flags.
+ (SDLMod) _convertToSDLModifiers: (NSUInteger)modifierFlags;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXInputHandler
@synthesize emulator;
@synthesize mouseActive, pressedMouseButtons;
@synthesize mousePosition;
@synthesize capsLockEnabled, numLockEnabled;
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

- (void) releaseKeyboardInput
{
	MAPPER_LosingFocus();
}

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
			   afterDelay: BXFakeKeypressReleaseDelay];
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
#pragma mark Key handling

- (void) sendKeyEventWithCode: (unsigned short)keyCode
					  pressed: (BOOL)pressed
					modifiers: (NSUInteger)modifierFlags
{
	if ([[self emulator] isExecuting])
	{
		SDL_Event keyEvent = [[self class] _SDLKeyEventForKeyCode: keyCode
														  pressed: pressed
														modifiers: modifierFlags];
		
		MAPPER_CheckEvent(&keyEvent);
	}
}

- (void) sendKeypressWithCode: (unsigned short)keyCode modifiers: (NSUInteger)modifierFlags
{	
	[self sendKeyEventWithCode: keyCode
					   pressed: YES
					 modifiers: modifierFlags];
	
	//Release the key after a brief delay
	[self performSelector: @selector(_releaseKey:)
			   withObject: [NSArray arrayWithObjects:
							[NSNumber numberWithUnsignedInteger: keyCode],
							[NSNumber numberWithUnsignedInteger: modifierFlags],
							nil]
			   afterDelay: BXFakeKeypressReleaseDelay];
}


- (void) sendKeyEventWithSDLKey: (SDLKey)sdlKeyCode
						pressed: (BOOL)pressed
					  modifiers: (NSUInteger)modifierFlags
{
	if ([[self emulator] isExecuting])
	{		
		SDL_Event keyEvent = [[self class] _SDLKeyEventForSDLKey: sdlKeyCode
														 pressed: pressed
													   modifiers: modifierFlags];
		
		MAPPER_CheckEvent(&keyEvent);
	}
}

- (void) sendKeypressWithSDLKey: (SDLKey)sdlKeyCode
					  modifiers: (NSUInteger)modifierFlags 
{
	[self sendKeyEventWithSDLKey: sdlKeyCode
						 pressed: YES
					   modifiers: modifierFlags];
	
	//Release the key after a brief delay
	[self performSelector: @selector(_releaseSDLKey:)
			   withObject: [NSArray arrayWithObjects:
							[NSNumber numberWithInteger: sdlKeyCode],
							[NSNumber numberWithUnsignedInteger: modifierFlags],
							nil]
			   afterDelay: BXFakeKeypressReleaseDelay];
}


#pragma mark -
#pragma mark Keyboard layout methods

- (NSString *) keyboardLayoutForCurrentInputMethod
{
	TISInputSourceRef keyboardRef	= TISCopyCurrentKeyboardLayoutInputSource();
	NSString *inputSourceID			= (NSString *)TISGetInputSourceProperty(keyboardRef, kTISPropertyInputSourceID);
	CFRelease(keyboardRef);
	
	NSString *layout	= [[self class] keyboardLayoutForInputSourceID: inputSourceID];
	if (!layout) layout	= [[self class] defaultKeyboardLayout];
	return layout;
}


+ (NSString *) keyboardLayoutForInputSourceID: (NSString *)inputSourceID
{
	//Input source IDs are a reverse-DNS string in the form com.companyname.layout.layoutName.
	//To avoid false negatives, we only look at the last part of this string.
	NSString *layoutName = [[inputSourceID componentsSeparatedByString: @"."] lastObject];
	if (layoutName)
	{
		return [[self keyboardLayoutMappings] objectForKey: layoutName];
	}
	else return nil;
}

+ (NSDictionary *) keyboardLayoutMappings
{
	//Note: these are not exact matches, and the ones marked with ?? are purely speculative.
	static NSDictionary *mappings = nil;
	if (!mappings) mappings = [[NSDictionary alloc] initWithObjectsAndKeys:
							   @"be",	@"Belgian",
							   
							   @"bg",	@"Bulgarian",				
							   @"bg",	@"Bulgarian-Phonetic",	//??
							   
							   @"br",	@"Brazilian",
							   
							   @"us",	@"Canadian",
							   @"ca",	@"Canadian-CSA",
							   
							   //Note: DOS cz layout is QWERTY, not QWERTZ like the standard Mac Czech layout
							   @"cz",	@"Czech",
							   @"cz",	@"Czech-QWERTY",
							   
							   @"de",	@"Austrian",
							   @"de",	@"German",
							   
							   @"dk",	@"Danish",
							   
							   @"dv",	@"DVORAK-QWERTYCMD",
							   @"dv",	@"Dvorak",
							   
							   @"es",	@"Spanish",
							   @"es",	@"Spanish-ISO",
							   
							   @"fi",	@"Finnish",
							   @"fi",	@"FinnishExtended",
							   @"fi",	@"FinnishSami-PC",		//??
							   
							   //There should be different DOS mappings for French and French Numerical
							   @"fr",	@"French",
							   @"fr",	@"French-numerical",
							   
							   @"gk",	@"Greek",
							   @"gk",	@"GreekPolytonic",		//??
							   
							   @"hu",	@"Hungarian",
							   
							   @"is",	@"Icelandic",
							   
							   @"it",	@"Italian",
							   @"it",	@"Italian-Pro",			//??
							   
							   @"nl",	@"Dutch",
							   
							   @"no",	@"Norwegian",
							   @"no",	@"NorwegianExtended",
							   @"no",	@"NorwegianSami-PC",	//??
							   
							   @"pl",	@"Polish",
							   @"pl",	@"PolishPro",			//??
							   
							   @"po",	@"Portuguese",
							   
							   @"ru",	@"Russian",				//??
							   @"ru",	@"Russian-Phonetic",	//??
							   @"ru",	@"RussianWin",			//??
							   
							   @"sf",	@"SwissFrench",
							   @"sg",	@"SwissGerman",
							   
							   @"sv",	@"Swedish",
							   @"sv",	@"Swedish-Pro",
							   @"sv",	@"SwedishSami-PC",		//??
							   
							   @"uk",	@"British",
							   @"uk",	@"Irish",				//??
							   @"uk",	@"IrishExtended",		//??
							   @"uk",	@"Welsh",				//??
							   
							   @"us",	@"Australian",
							   @"us",	@"Hawaiian",			//??
							   @"us",	@"US",
							   @"us",	@"USExtended",
							   nil];
	return mappings;
}

+ (NSString *)defaultKeyboardLayout	{ return @"us"; }


#pragma mark -
#pragma mark Internal methods

- (void) _releaseKey: (NSArray *)args
{
	unsigned short keyCode		= (unsigned short)[[args objectAtIndex: 0] unsignedIntegerValue];
	NSUInteger modifierFlags	= [[args objectAtIndex: 1] unsignedIntegerValue];
	
	[self sendKeyEventWithCode: keyCode pressed: NO modifiers: modifierFlags];
}

- (void) _releaseSDLKey: (NSArray *)args
{
	SDLKey sdlKeyCode			= (SDLKey)[[args objectAtIndex: 0] integerValue];
	NSUInteger modifierFlags	= [[args objectAtIndex: 1] unsignedIntegerValue];
	
	[self sendKeyEventWithSDLKey: sdlKeyCode pressed: NO modifiers: modifierFlags];
}

- (void) _releaseButton: (NSArray *)args
{
	NSUInteger button			= [[args objectAtIndex: 0] unsignedIntegerValue];
	NSUInteger modifierFlags	= [[args objectAtIndex: 1] unsignedIntegerValue];
	
	[self mouseButtonReleased: button withModifiers: modifierFlags];
}


+ (SDL_Event) _SDLKeyEventForSDLKey: (SDLKey)sdlKeyCode
							pressed: (BOOL)pressed
						  modifiers: (NSUInteger)modifierFlags
{	
    SDL_Event keyEvent;
	keyEvent.type		= (pressed) ? SDL_KEYDOWN : SDL_KEYUP;
	keyEvent.key.state	= (pressed) ? SDL_PRESSED : SDL_RELEASED;
	
	keyEvent.key.keysym.scancode = BXUnknownScancode;
	keyEvent.key.keysym.sym	= sdlKeyCode;
	keyEvent.key.keysym.mod	= [self _convertToSDLModifiers: modifierFlags];
	
	return keyEvent;
}

+ (SDL_Event) _SDLKeyEventForKeyCode: (CGKeyCode)keyCode
							 pressed: (BOOL)pressed
						   modifiers: (NSUInteger)modifierFlags
{
	
    SDL_Event keyEvent;
	keyEvent.type		= (pressed) ? SDL_KEYDOWN : SDL_KEYUP;
	keyEvent.key.state	= (pressed) ? SDL_PRESSED : SDL_RELEASED;
	
	keyEvent.key.keysym.scancode = keyCode;
	keyEvent.key.keysym.sym	= [self _convertToSDLKeyCode: keyCode];
	keyEvent.key.keysym.mod	= [self _convertToSDLModifiers: modifierFlags];
	
	return keyEvent;
}

+ (SDLKey) _convertToSDLKeyCode: (CGKeyCode)keyCode
{
#define KEYMAP_SIZE 256
	static SDLKey map[KEYMAP_SIZE];
	static BOOL mapGenerated = NO;
	if (!mapGenerated)
	{
		NSUInteger i;
		//Clear all of the keymap entries first
		for (i=0; i < KEYMAP_SIZE; i++)
			map[i] = SDLK_UNKNOWN;
		
		map[kVK_F1] = SDLK_F1;
		map[kVK_F2] = SDLK_F2;
		map[kVK_F3] = SDLK_F3;
		map[kVK_F4] = SDLK_F4;
		map[kVK_F5] = SDLK_F5;
		map[kVK_F6] = SDLK_F6;
		map[kVK_F7] = SDLK_F7;
		map[kVK_F8] = SDLK_F8;
		map[kVK_F9] = SDLK_F9;
		map[kVK_F10] = SDLK_F10;
		map[kVK_F11] = SDLK_F11;
		map[kVK_F12] = SDLK_F12;
		map[kVK_F13] = SDLK_F13;
		map[kVK_F14] = SDLK_F14;
		map[kVK_F15] = SDLK_F15;		
		
		map[kVK_ANSI_1] = SDLK_1;
		map[kVK_ANSI_2] = SDLK_2;
		map[kVK_ANSI_3] = SDLK_3;
		map[kVK_ANSI_4] = SDLK_4;
		map[kVK_ANSI_5] = SDLK_5;
		map[kVK_ANSI_6] = SDLK_6;
		map[kVK_ANSI_7] = SDLK_7;
		map[kVK_ANSI_8] = SDLK_8;
		map[kVK_ANSI_9] = SDLK_9;
		map[kVK_ANSI_0] = SDLK_0;
		
		map[kVK_ANSI_Q] = SDLK_q;
		map[kVK_ANSI_W] = SDLK_w;
		map[kVK_ANSI_E] = SDLK_e;
		map[kVK_ANSI_R] = SDLK_r;
		map[kVK_ANSI_T] = SDLK_t;
		map[kVK_ANSI_Y] = SDLK_y;
		map[kVK_ANSI_U] = SDLK_u;
		map[kVK_ANSI_I] = SDLK_i;
		map[kVK_ANSI_O] = SDLK_o;
		map[kVK_ANSI_P] = SDLK_p;
		
		map[kVK_ANSI_A] = SDLK_a;
		map[kVK_ANSI_S] = SDLK_s;
		map[kVK_ANSI_D] = SDLK_d;
		map[kVK_ANSI_F] = SDLK_f;
		map[kVK_ANSI_G] = SDLK_g;
		map[kVK_ANSI_H] = SDLK_h;
		map[kVK_ANSI_J] = SDLK_j;
		map[kVK_ANSI_K] = SDLK_k;
		map[kVK_ANSI_L] = SDLK_l;
		
		map[kVK_ANSI_Z] = SDLK_z;
		map[kVK_ANSI_X] = SDLK_x;
		map[kVK_ANSI_C] = SDLK_c;
		map[kVK_ANSI_V] = SDLK_v;
		map[kVK_ANSI_B] = SDLK_b;
		map[kVK_ANSI_N] = SDLK_n;
		map[kVK_ANSI_M] = SDLK_m;
		
		map[kVK_ANSI_Keypad1] = SDLK_KP1;
		map[kVK_ANSI_Keypad2] = SDLK_KP2;
		map[kVK_ANSI_Keypad3] = SDLK_KP3;
		map[kVK_ANSI_Keypad4] = SDLK_KP4;
		map[kVK_ANSI_Keypad5] = SDLK_KP5;
		map[kVK_ANSI_Keypad6] = SDLK_KP6;
		map[kVK_ANSI_Keypad7] = SDLK_KP7;
		map[kVK_ANSI_Keypad8] = SDLK_KP8;
		map[kVK_ANSI_Keypad9] = SDLK_KP9;
		map[kVK_ANSI_Keypad0] = SDLK_KP0;
		map[kVK_ANSI_KeypadDecimal] = SDLK_KP_PERIOD;
		
		map[kVK_ANSI_KeypadPlus] = SDLK_KP_PLUS;
		map[kVK_ANSI_KeypadMinus] = SDLK_KP_MINUS;
		map[kVK_ANSI_KeypadEquals] = SDLK_KP_EQUALS;
		map[kVK_ANSI_KeypadDivide] = SDLK_KP_DIVIDE;
		map[kVK_ANSI_KeypadMultiply] = SDLK_KP_MULTIPLY;
		map[kVK_ANSI_KeypadEnter] = SDLK_KP_ENTER;
		
		map[kVK_Escape] = SDLK_ESCAPE;
		map[kVK_CapsLock] = SDLK_CAPSLOCK;
		map[kVK_Tab] = SDLK_TAB;
		map[kVK_Delete] = SDLK_BACKSPACE;
		map[kVK_ForwardDelete] = SDLK_DELETE;
		map[kVK_Return] = SDLK_RETURN;
		map[kVK_Space] = SDLK_SPACE;
		
		map[kVK_Home] = SDLK_HOME;
		map[kVK_End] = SDLK_END;
		map[kVK_PageUp] = SDLK_PAGEUP;
		map[kVK_PageDown] = SDLK_PAGEDOWN;
		
		map[kVK_UpArrow] = SDLK_UP;
		map[kVK_LeftArrow] = SDLK_LEFT;
		map[kVK_DownArrow] = SDLK_DOWN;
		map[kVK_RightArrow] = SDLK_RIGHT;
		
		map[kVK_Shift] = SDLK_LSHIFT;
		map[kVK_Control] = SDLK_LCTRL;
		map[kVK_Option] = SDLK_LALT;
		
		map[kVK_RightControl] = SDLK_RCTRL;
		map[kVK_RightOption] = SDLK_RALT;
		map[kVK_RightShift] = SDLK_RSHIFT;
		
		map[kVK_ANSI_Minus] = SDLK_MINUS;
		map[kVK_ANSI_Equal] = SDLK_EQUALS;
		
		map[kVK_ANSI_LeftBracket] = SDLK_LEFTBRACKET;
		map[kVK_ANSI_RightBracket] = SDLK_RIGHTBRACKET;
		map[kVK_ANSI_Backslash] = SDLK_BACKSLASH;
		
		map[kVK_ANSI_Grave] = SDLK_BACKQUOTE;
		map[kVK_ANSI_Semicolon] = SDLK_SEMICOLON;
		map[kVK_ANSI_Quote] = SDLK_QUOTE;
		map[kVK_ANSI_Comma] = SDLK_COMMA;
		map[kVK_ANSI_Period] = SDLK_PERIOD;
		map[kVK_ANSI_Slash] = SDLK_SLASH;
		map[kVK_ISO_Section] = SDLK_WORLD_0;
		
		mapGenerated = YES;
	}
	
	//Correction for transposed kVK_ISO_Section/kVK_ANSI_Grave on ISO keyboards
	if ((keyCode == kVK_ISO_Section || keyCode == kVK_ANSI_Grave) && KBGetLayoutType(LMGetKbdType()) == kKeyboardISO)
	{
		return (keyCode == kVK_ISO_Section) ? SDLK_BACKQUOTE : SDLK_WORLD_0;
	}
	
	else if (keyCode < KEYMAP_SIZE) return map[keyCode];
	else return SDLK_UNKNOWN;
}

+ (SDLMod) _convertToSDLModifiers: (NSUInteger)modifierFlags
{
	//To avoid compilation errors because of the OR operator, we declare
	//this as an integer and then cast it to SDLMod once we're done.
	NSUInteger SDLModifiers = KMOD_NONE;
	
	//This flag doesn't work the way that NumLock works in PC-land, so we shouldn't expose it.
	//if (modifierFlags & NSNumericPadKeyMask)		SDLModifiers |= KMOD_NUM;
	
	if (modifierFlags & NSAlphaShiftKeyMask)		SDLModifiers |= KMOD_CAPS;
	if (modifierFlags & BXLeftControlKeyMask)		SDLModifiers |= KMOD_LCTRL;
	if (modifierFlags & BXRightControlKeyMask)		SDLModifiers |= KMOD_RCTRL;
	if (modifierFlags & BXLeftShiftKeyMask)			SDLModifiers |= KMOD_LSHIFT;
	if (modifierFlags & BXRightShiftKeyMask)		SDLModifiers |= KMOD_RSHIFT;
	if (modifierFlags & BXLeftAlternateKeyMask)		SDLModifiers |= KMOD_LALT;
	if (modifierFlags & BXRightAlternateKeyMask)	SDLModifiers |= KMOD_RALT;
	
	return (SDLMod)SDLModifiers;
}

@end
