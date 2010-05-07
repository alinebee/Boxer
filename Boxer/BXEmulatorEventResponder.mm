/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXEmulatorEventResponder.h"

#import <Carbon/Carbon.h> //For keycode constants
#import <SDL/SDL.h>
#import "config.h"
#import "video.h"
#import "mouse.h"
#import "sdlmain.h"

//Modifier flag constants for left- and right-side modifier keys, copied from IOKit/IOLLEvent.h.
//Allows us to distinguish these for DOSBox.
enum {
	BXLeftControlKeyMask	= 0x00000001,
	BXLeftShiftKeyMask		= 0x00000002,
	BXRightShiftKeyMask		= 0x00000004,
	BXLeftCommandKeyMask	= 0x00000008,
	BXRightCommandKeyMask	= 0x00000010,
	BXLeftAlternateKeyMask	= 0x00000020,
	BXRightAlternateKeyMask	= 0x00000040,
	BXRightControlKeyMask	= 0x00002000
};

//Declared in mapper.cpp
void MAPPER_CheckEvent(SDL_Event *event);

@implementation BXEmulatorEventResponder

#pragma mark -
#pragma mark Mouse handling

- (void) mouseDown: (NSEvent *)theEvent			{ Mouse_ButtonPressed(DOSBoxMouseButtonLeft); }
- (void) mouseUp: (NSEvent *)theEvent			{ Mouse_ButtonReleased(DOSBoxMouseButtonLeft); }

- (void) rightMouseDown: (NSEvent *)theEvent	{ Mouse_ButtonPressed(DOSBoxMouseButtonRight); }
- (void) rightMouseUp: (NSEvent *)theEvent		{ Mouse_ButtonReleased(DOSBoxMouseButtonRight); }

- (void) otherMouseDown: (NSEvent *)theEvent
{
	if ([theEvent buttonNumber] == 2) Mouse_ButtonPressed(DOSBoxMouseButtonMiddle);
}

- (void) otherMouseUp: (NSEvent *)theEvent
{
	if ([theEvent buttonNumber] == 2) Mouse_ButtonReleased(DOSBoxMouseButtonMiddle);	
}

- (void) mouseMovedToPoint: (NSPoint)point
				  byAmount: (NSPoint)delta
				  onCanvas: (NSRect)canvas
			   whileLocked: (BOOL)locked
{
	CGFloat sensitivity = sdl.mouse.sensitivity / 100.0f;
	
	//In DOSBox land, absolute position is from 0-1 but delta is in raw pixels,
	//for some silly reason.
	NSPoint canvasDelta = NSMakePoint(delta.x * canvas.size.width,
									  delta.y * canvas.size.height);
	
	//point and delta use bottom-left origins to be consistent with AppKit's coordinate system.
	//We need to flip them to match DOSBox's top-left origin coordinate system.
	Mouse_CursorMoved(canvasDelta.x * sensitivity,
					  -canvasDelta.y * sensitivity,
					  point.x * sensitivity,
					  (1 - point.y) * sensitivity,
					  NO);
}
		 
		 
#pragma mark -
#pragma mark Key handling

- (void) keyUp: (NSEvent *)theEvent
{
	SDL_Event keyEvent = [[self class] _SDLKeyEventForKeyCode: [theEvent keyCode]
													  pressed: NO
												withModifiers: [theEvent modifierFlags]];
	
	MAPPER_CheckEvent(&keyEvent);
}

- (void) keyDown: (NSEvent *)theEvent
{
	SDL_Event keyEvent = [[self class] _SDLKeyEventForKeyCode: [theEvent keyCode]
													  pressed: YES
												withModifiers: [theEvent modifierFlags]];
	
	MAPPER_CheckEvent(&keyEvent);
}

//Convert flag changes into proper key events
- (void) flagsChanged: (NSEvent *)theEvent
{
	//We can determine which modifier key was involved by its key code,
	//but we can't determine from the event whether it was pressed or released.
	//So, we check whether the corresponding modifier flag is active or not.
	NSUInteger flag;
	
	switch([theEvent keyCode])
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
	
	SDL_Event keyEvent = [[self class] _SDLKeyEventForKeyCode: [theEvent keyCode]
													  pressed: ([theEvent modifierFlags] & flag)
												withModifiers: [theEvent modifierFlags]];

	//Special-case for CapsLock, which is a toggle: we get here only when the button is pressed,
	//not when it is released. Thus, we have to assume it is always pressed and then released immediately.
	//FIXME: this isn't responding in DOSBox. Why?
	if (flag == NSAlphaShiftKeyMask)
	{
		keyEvent.type = SDL_KEYDOWN;
		keyEvent.key.state = SDL_PRESSED;
		
		MAPPER_CheckEvent(&keyEvent);
		
		keyEvent.type = SDL_KEYUP;
		keyEvent.key.state = SDL_RELEASED;
		
		MAPPER_CheckEvent(&keyEvent);
	}
	else MAPPER_CheckEvent(&keyEvent);
}

@end


@implementation BXEmulatorEventResponder (BXEmulatorEventResponderInternals)

//"Private-but-not-quite" - exposed here for coalface functions
- (SDLMod) currentSDLModifiers
{
	return [[self class] _convertToSDLModifiers: [[NSApp currentEvent] modifierFlags]];
}

+ (SDL_Event) _SDLKeyEventForKeyCode: (CGKeyCode)keyCode
							 pressed: (BOOL)pressed
					   withModifiers: (NSUInteger)modifierFlags
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
	
	if (keyCode < KEYMAP_SIZE) return map[keyCode];
	//Just in case
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