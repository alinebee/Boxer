/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXInputHandler.h"
#import "BXEmulator.h"

#import "BXEventConstants.h"
#import <AppKit/AppKit.h>	//For NSApp; remove this dependency ASAP
#import <Carbon/Carbon.h>	//For OSX keycode constants
#import <SDL/SDL.h>			//For SDL keycode constants
#import "config.h"
#import "video.h"
#import "mouse.h"

//How long in seconds to 'hold down' a fake keypress before releasing it.
//This gives games enough time to register that the key has been pressed.
#define BXFakeKeypressReleaseDelay 0.25

#define BXUnknownScancode 0


//Declared in mapper.cpp
void MAPPER_CheckEvent(SDL_Event *event);
void MAPPER_LosingFocus();


@interface BXInputHandler ()

//Simple performSelector:withObject:afterDelay: wrappers, used by
//sendKeypressWithCode: and sendKeypressWithSDLKey: for releasing
//their fake key events after a brief delay.
- (void) _releaseKey: (NSArray *)args;
- (void) _releaseSDLKey: (NSArray *)args;

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


@implementation BXInputHandler
@synthesize emulator;
@synthesize mouseActive;
@synthesize mousePosition;

- (id) init
{
	if ((self = [super init]))
	{
		mousePosition	= NSMakePoint(0.5f, 0.5f);
		mouseActive		= NO;
	}
	return self;
}

#pragma mark -
#pragma mark Controlling response state

- (void) lostFocus
{
	//Release all DOSBox events when we lose focus
	MAPPER_LosingFocus();
}

- (BOOL) capsLockEnabled
{
	return ([[NSApp currentEvent] modifierFlags] & NSAlphaShiftKeyMask);
}


#pragma mark -
#pragma mark Mouse handling

- (void) mouseButtonPressed: (NSInteger)button withModifiers: (NSUInteger) modifierFlags
{
	//Happily, DOSBox's mouse button numbering corresponds exactly to OSX's
	if ([[self emulator] isExecuting]) Mouse_ButtonPressed(button);
}


- (void) mouseButtonReleased: (NSInteger)button withModifiers: (NSUInteger) modifierFlags
{
	//Happily, DOSBox's mouse button numbering corresponds exactly to OSX's
	if ([[self emulator] isExecuting]) Mouse_ButtonReleased(button);
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

- (NSString *)keyboardLayoutForCurrentInputMethod
{
	TISInputSourceRef keyboardRef	= TISCopyCurrentKeyboardLayoutInputSource();
	NSString *inputSourceID			= (NSString *)TISGetInputSourceProperty(keyboardRef, kTISPropertyInputSourceID);
	CFRelease(keyboardRef);
	
	NSString *layout	= [[[self class] keyboardLayoutMappings] objectForKey: inputSourceID];
	if (!layout) layout	= [[self class] defaultKeyboardLayout];
	return layout;
}

+ (NSDictionary *)keyboardLayoutMappings
{
	//Note: these are not exact matches, and the ones marked with ?? are purely speculative.
	//DOSBox doesn't even natively support all of them.
	//This is a disgusting solution, and will be the first against the wall when the Unicode
	//revolution comes. 
	
	static NSDictionary *mappings = nil;
	if (!mappings) mappings = [[NSDictionary alloc] initWithObjectsAndKeys:
							   @"be",	@"com.apple.keylayout.Belgian",
							   
							   @"bg",	@"com.apple.keylayout.Bulgarian",				
							   @"bg",	@"com.apple.keylayout.Bulgarian-Phonetic",	//??
							   
							   @"br",	@"com.apple.keylayout.Brazilian",
							   
							   @"us",	@"com.apple.keylayout.Canadian",
							   @"ca",	@"com.apple.keylayout.Canadian-CSA",
							   
							   //Note: DOS cz layout is QWERTY, not QWERTZ like the standard Mac Czech layout
							   @"cz",	@"com.apple.keylayout.Czech",
							   @"cz",	@"com.apple.keylayout.Czech-QWERTY",
							   
							   @"de",	@"com.apple.keylayout.Austrian",
							   @"de",	@"com.apple.keylayout.German",
							   
							   @"dk",	@"com.apple.keylayout.Danish",
							   
							   @"dv",	@"com.apple.keylayout.DVORAK-QWERTYCMD",
							   @"dv",	@"com.apple.keylayout.Dvorak",
							   
							   @"es",	@"com.apple.keylayout.Spanish",
							   @"es",	@"com.apple.keylayout.Spanish-ISO",
							   
							   @"fi",	@"com.apple.keylayout.Finnish",
							   @"fi",	@"com.apple.keylayout.FinnishExtended",
							   @"fi",	@"com.apple.keylayout.FinnishSami-PC",		//??
							   
							   //There should be different DOS mappings for French and French Numerical
							   @"fr",	@"com.apple.keylayout.French",
							   @"fr",	@"com.apple.keylayout.French-numerical",
							   
							   @"gk",	@"com.apple.keylayout.Greek",
							   @"gk",	@"com.apple.keylayout.GreekPolytonic",		//??
							   
							   @"hu",	@"com.apple.keylayout.Hungarian",
							   
							   @"is",	@"com.apple.keylayout.Icelandic",
							   
							   @"it",	@"com.apple.keylayout.Italian",
							   @"it",	@"com.apple.keylayout.Italian-Pro",			//??
							   
							   @"nl",	@"com.apple.keylayout.Dutch",
							   
							   @"no",	@"com.apple.keylayout.Norwegian",
							   @"no",	@"com.apple.keylayout.NorwegianExtended",
							   @"no",	@"com.apple.keylayout.NorwegianSami-PC",	//??
							   
							   @"pl",	@"com.apple.keylayout.Polish",
							   @"pl",	@"com.apple.keylayout.PolishPro",			//??
							   
							   @"po",	@"com.apple.keylayout.Portuguese",
							   
							   @"ru",	@"com.apple.keylayout.Russian",				//??
							   @"ru",	@"com.apple.keylayout.Russian-Phonetic",	//??
							   @"ru",	@"com.apple.keylayout.RussianWin",			//??
							   
							   @"sf",	@"com.apple.keylayout.SwissFrench",
							   @"sg",	@"com.apple.keylayout.SwissGerman",
							   
							   @"sv",	@"com.apple.keylayout.Swedish",
							   @"sv",	@"com.apple.keylayout.Swedish-Pro",
							   @"sv",	@"com.apple.keylayout.SwedishSami-PC",		//??
							   
							   @"uk",	@"com.apple.keylayout.British",
							   @"uk",	@"com.apple.keylayout.Irish",				//??
							   @"uk",	@"com.apple.keylayout.IrishExtended",		//??
							   @"uk",	@"com.apple.keylayout.Welsh",				//??
							   
							   @"us",	@"com.apple.keylayout.Australian",
							   @"us",	@"com.apple.keylayout.Hawaiian",			//??
							   @"us",	@"com.apple.keylayout.US",
							   @"us",	@"com.apple.keylayout.USExtended",
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
	
	//Override for transposed kVK_ISO_Section on ISO keyboards
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
