//
//  BXInputController+BXKeyboardInput.m
//  Boxer
//
//  Created by Alun Bestor on 26/04/2011.
//  Copyright 2011 Alun Bestor and contributors. All rights reserved.
//

#import "BXInputControllerPrivate.h"
#import "BXEventConstants.h"
#import "BXDOSWindow.h"

#import <Carbon/Carbon.h> //For keycodes


@implementation BXInputController (BXKeyboardInput)

+ (NSString *) keyboardLayoutForCurrentInputMethod
{
	TISInputSourceRef keyboardRef	= TISCopyCurrentKeyboardLayoutInputSource();
	NSString *inputSourceID			= (NSString *)TISGetInputSourceProperty(keyboardRef, kTISPropertyInputSourceID);
	CFRelease(keyboardRef);
	
	return [self keyboardLayoutForInputSourceID: inputSourceID];
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
	static NSDictionary *mappings = nil;
	
	if (!mappings)
	{
		NSString *dictionaryPath = [[NSBundle mainBundle] pathForResource: @"KeyboardLayouts" ofType: @"plist"];
		
		if (dictionaryPath)
			mappings = [[NSDictionary alloc] initWithContentsOfFile: dictionaryPath];
	}

	return mappings;
}


#pragma mark -
#pragma mark Key events

- (void) keyDown: (NSEvent *)theEvent
{
	//If the keypress was command-modified, don't pass it on to the emulator as it indicates
	//a failed key equivalent.
	//(This is consistent with how other OS X apps with textinput handle Cmd-keypresses.)
	if ([theEvent modifierFlags] & NSCommandKeyMask)
	{
		[super keyDown: theEvent];
	}
	
	//Pressing ESC while in fullscreen mode and not running a program will exit fullscreen mode.
	else if ([[theEvent charactersIgnoringModifiers] isEqualToString: @"\e"] &&
		[[[self _windowController] window] isFullScreen] &&
		[[[self representedObject] emulator] isAtPrompt])
	{
		[NSApp sendAction: @selector(exitFullScreen:) to: nil from: self];
	}
	
    //Ignore repeated key events, as the emulation implements its own key-repeating.
	else if ([theEvent isARepeat])
    {
        return;
    }
    
    //Otherwise, pass the keypress on to the emulated keyboard hardware.
    else
	{
		//Unpause the emulation whenever a key is sent to DOS.
		[[self representedObject] resume: self];
        
        //Check the separate key-mapping layer for numpad simulation for this key, if:
        //- There's a program running AND
        //- The numpad simulation toggle is off and the user is holding down the Fn key OR
        //- The numpad simulation toggle is on and the user is *not* holding down the Fn key
        BOOL programIsRunning = ![[[self representedObject] emulator] isAtPrompt];
        BOOL fnModified = ([theEvent modifierFlags] & NSFunctionKeyMask) == NSFunctionKeyMask;
        BOOL simulateNumpad = programIsRunning && ([self simulatedNumpadActive] != fnModified);
        
        CGKeyCode OSXKeyCode = [theEvent keyCode];
        BXDOSKeyCode dosKeyCode = KBD_NONE;
        
        //Check if we have a different key mapping for this key when simulating a numpad.
        if (simulateNumpad)
        {
            dosKeyCode = [self _simulatedNumpadKeyCodeForSystemKeyCode: OSXKeyCode];
            if (dosKeyCode != KBD_NONE)
                modifiedKeys[OSXKeyCode] = YES;
        }
        
        //If there's no numpad-simulation key equivalent, just go with the regular mapping
        if (dosKeyCode == KBD_NONE)
            dosKeyCode = [self _DOSKeyCodeForSystemKeyCode: OSXKeyCode];
        
        if (dosKeyCode != KBD_NONE)
            [[self _emulatedKeyboard] keyDown: dosKeyCode];
	}
}

- (void) keyUp: (NSEvent *)theEvent
{
    CGKeyCode OSXKeyCode = [theEvent keyCode];
    
    //If this key was modified to a different mapping when it was was originally pressed,
    //then release its modified mapping too (e.g. numpad simulation).
    if (modifiedKeys[OSXKeyCode])
    {
        BXDOSKeyCode modifiedKeyCode = [self _simulatedNumpadKeyCodeForSystemKeyCode: OSXKeyCode];
        if (modifiedKeyCode != KBD_NONE)
            [[self _emulatedKeyboard] keyUp: modifiedKeyCode];
        
        modifiedKeys[OSXKeyCode] = NO;
    }
    
    //Release the regular key mapping in any case.
    BXDOSKeyCode dosKeyCode = [self _DOSKeyCodeForSystemKeyCode: OSXKeyCode];
    if (dosKeyCode != KBD_NONE)
        [[self _emulatedKeyboard] keyUp: dosKeyCode];
}

- (void) flagsChanged: (NSEvent *)theEvent
{
	[self _syncModifierFlags: [theEvent modifierFlags]];
    
    //Cmd-key tweak: in 10.7 at least, we won't receive keyUp: events for any key while
    //Cmd is being held down. To prevent keys getting stuck, we immediately release any
    //keys that were down when Cmd is first pressed.
    if (([theEvent modifierFlags] & NSCommandKeyMask) == NSCommandKeyMask)
    {
        [[self _emulatedKeyboard] clearInput];
    }
}


#pragma mark -
#pragma mark Simulating keyboard events

- (IBAction) sendF1:	(id)sender	{ [[self _emulatedKeyboard] keyPressed: KBD_f1]; }
- (IBAction) sendF2:	(id)sender	{ [[self _emulatedKeyboard] keyPressed: KBD_f2]; }
- (IBAction) sendF3:	(id)sender	{ [[self _emulatedKeyboard] keyPressed: KBD_f3]; }
- (IBAction) sendF4:	(id)sender	{ [[self _emulatedKeyboard] keyPressed: KBD_f4]; }
- (IBAction) sendF5:	(id)sender	{ [[self _emulatedKeyboard] keyPressed: KBD_f5]; }
- (IBAction) sendF6:	(id)sender	{ [[self _emulatedKeyboard] keyPressed: KBD_f6]; }
- (IBAction) sendF7:	(id)sender	{ [[self _emulatedKeyboard] keyPressed: KBD_f7]; }
- (IBAction) sendF8:	(id)sender	{ [[self _emulatedKeyboard] keyPressed: KBD_f8]; }
- (IBAction) sendF9:	(id)sender	{ [[self _emulatedKeyboard] keyPressed: KBD_f9]; }
- (IBAction) sendF10:	(id)sender	{ [[self _emulatedKeyboard] keyPressed: KBD_f10]; }
- (IBAction) sendF11:	(id)sender	{ [[self _emulatedKeyboard] keyPressed: KBD_f11]; }
- (IBAction) sendF12:	(id)sender	{ [[self _emulatedKeyboard] keyPressed: KBD_f12]; }

- (IBAction) sendHome:		(id)sender { [[self _emulatedKeyboard] keyPressed: KBD_home]; }
- (IBAction) sendEnd:		(id)sender { [[self _emulatedKeyboard] keyPressed: KBD_end]; }
- (IBAction) sendPageUp:	(id)sender { [[self _emulatedKeyboard] keyPressed: KBD_pageup]; }
- (IBAction) sendPageDown:	(id)sender { [[self _emulatedKeyboard] keyPressed: KBD_pagedown]; }

- (IBAction) sendInsert:	(id)sender { [[self _emulatedKeyboard] keyPressed: KBD_insert]; }
- (IBAction) sendDelete:	(id)sender { [[self _emulatedKeyboard] keyPressed: KBD_delete]; }
- (IBAction) sendPause:		(id)sender { [[self _emulatedKeyboard] keyPressed: KBD_pause]; }
//TODO: should we be sending a key combo here?
- (IBAction) sendBreak:		(id)sender { [[self _emulatedKeyboard] keyPressed: KBD_pause]; }

- (IBAction) sendNumLock:		(id)sender { [[self _emulatedKeyboard] keyPressed: KBD_numlock]; }
- (IBAction) sendScrollLock:	(id)sender { [[self _emulatedKeyboard] keyPressed: KBD_scrolllock]; }
- (IBAction) sendPrintScreen:	(id)sender { [[self _emulatedKeyboard] keyPressed: KBD_printscreen]; }


#pragma mark -
#pragma mark Private methods

- (void) _syncModifierFlags: (NSUInteger)newModifiers
{
	//IMPLEMENTATION NOTE: this method used to check the keyCode of the event to determine which
	//modifier key was just toggled. This worked fine for single keypresses, but could miss keys
	//when multiple modifier keys were pressed or released, causing 'stuck' keys.
	//The new implementation correctly handles multiple keys and can also be used to synchronise
	//modifier-key states whenever we regain keyboard focus.
	
	if (newModifiers != lastModifiers)
	{
#define NUM_FLAGS 7
		
		//Map flags to their corresponding keycodes, because NSDictionaries are so tedious to write
		NSUInteger flags[NUM_FLAGS] = {
			BXLeftControlKeyMask,
			BXLeftAlternateKeyMask,
			BXLeftShiftKeyMask,
			BXRightControlKeyMask,
			BXRightAlternateKeyMask,
			BXRightShiftKeyMask,
			NSAlphaShiftKeyMask
		};
		BXDOSKeyCode keyCodes[NUM_FLAGS] = {
			KBD_leftctrl,
			KBD_leftalt,
			KBD_leftshift,
			KBD_rightctrl,
			KBD_rightalt,
			KBD_rightshift,
			KBD_capslock
		};
		
		NSUInteger i;
		for (i=0; i<NUM_FLAGS; i++)
		{
			NSUInteger flag			= flags[i];
			BXDOSKeyCode keyCode	= keyCodes[i];
			  
			BOOL isPressed	= (newModifiers & flag) == flag;
			BOOL wasPressed	= (lastModifiers & flag) == flag;
			
			//If this flag has been toggled, then post a new keyboard event
			//IMPLEMENTATION NOTE: we used to XOR newModifiers and lastModifiers together
			//and just check if the flag appeared in that, but that was incorrectly ignoring
			//events when both the left and right version of a key were pressed at the same time.
			if (isPressed != wasPressed)
			{
				BXEmulatedKeyboard *keyboard = [self _emulatedKeyboard];
				
				//Special handling for capslock key: whenever the flag is toggled,
				//act like the key was pressed and then released shortly after.
				//(We never receive receive actual keyup events for this key.)
				if (flag == NSAlphaShiftKeyMask)
				{
					[keyboard keyPressed: keyCode];
				}
				else if (isPressed)
				{
					[keyboard keyDown: keyCode];
				}
				else
				{
					[keyboard keyUp: keyCode];
				}
			}
		}
		lastModifiers = newModifiers;
	}
}

- (BXDOSKeyCode) _DOSKeyCodeForSystemKeyCode: (CGKeyCode)keyCode
{
	static BXDOSKeyCode map[BXMaxSystemKeyCode];
	static BOOL mapGenerated = NO;
	if (!mapGenerated)
	{
        memset(&map, KBD_NONE, sizeof(map));
		
		map[kVK_F1] = KBD_f1;
		map[kVK_F2] = KBD_f2;
		map[kVK_F3] = KBD_f3;
		map[kVK_F4] = KBD_f4;
		map[kVK_F5] = KBD_f5;
		map[kVK_F6] = KBD_f6;
		map[kVK_F7] = KBD_f7;
		map[kVK_F8] = KBD_f8;
		map[kVK_F9] = KBD_f9;
		map[kVK_F10] = KBD_f10;
		map[kVK_F11] = KBD_f11;
		map[kVK_F12] = KBD_f12;
		
		//NOTE: these keys don't exist on a Mac keyboard, but F13-15 on a full-size
        //Mac keyboard correspond to the physical locations of the keys on a PC keyboard
		map[kVK_F13] = KBD_printscreen;
		map[kVK_F14] = KBD_scrolllock;
		map[kVK_F15] = KBD_pause;
		
		map[kVK_ANSI_1] = KBD_1;
		map[kVK_ANSI_2] = KBD_2;
		map[kVK_ANSI_3] = KBD_3;
		map[kVK_ANSI_4] = KBD_4;
		map[kVK_ANSI_5] = KBD_5;
		map[kVK_ANSI_6] = KBD_6;
		map[kVK_ANSI_7] = KBD_7;
		map[kVK_ANSI_8] = KBD_8;
		map[kVK_ANSI_9] = KBD_9;
		map[kVK_ANSI_0] = KBD_0;
		
		map[kVK_ANSI_Q] = KBD_q;
		map[kVK_ANSI_W] = KBD_w;
		map[kVK_ANSI_E] = KBD_e;
		map[kVK_ANSI_R] = KBD_r;
		map[kVK_ANSI_T] = KBD_t;
		map[kVK_ANSI_Y] = KBD_y;
		map[kVK_ANSI_U] = KBD_u;
		map[kVK_ANSI_I] = KBD_i;
		map[kVK_ANSI_O] = KBD_o;
		map[kVK_ANSI_P] = KBD_p;
		
		map[kVK_ANSI_A] = KBD_a;
		map[kVK_ANSI_S] = KBD_s;
		map[kVK_ANSI_D] = KBD_d;
		map[kVK_ANSI_F] = KBD_f;
		map[kVK_ANSI_G] = KBD_g;
		map[kVK_ANSI_H] = KBD_h;
		map[kVK_ANSI_J] = KBD_j;
		map[kVK_ANSI_K] = KBD_k;
		map[kVK_ANSI_L] = KBD_l;
		
		map[kVK_ANSI_Z] = KBD_z;
		map[kVK_ANSI_X] = KBD_x;
		map[kVK_ANSI_C] = KBD_c;
		map[kVK_ANSI_V] = KBD_v;
		map[kVK_ANSI_B] = KBD_b;
		map[kVK_ANSI_N] = KBD_n;
		map[kVK_ANSI_M] = KBD_m;
		
		map[kVK_ANSI_Keypad1] = KBD_kp1;
		map[kVK_ANSI_Keypad2] = KBD_kp2;
		map[kVK_ANSI_Keypad3] = KBD_kp3;
		map[kVK_ANSI_Keypad4] = KBD_kp4;
		map[kVK_ANSI_Keypad5] = KBD_kp5;
		map[kVK_ANSI_Keypad6] = KBD_kp6;
		map[kVK_ANSI_Keypad7] = KBD_kp7;
		map[kVK_ANSI_Keypad8] = KBD_kp8;
		map[kVK_ANSI_Keypad9] = KBD_kp9;
		map[kVK_ANSI_Keypad0] = KBD_kp0;
		map[kVK_ANSI_KeypadDecimal] = KBD_kpperiod;
		
		map[kVK_ANSI_KeypadPlus] = KBD_kpplus;
		map[kVK_ANSI_KeypadMinus] = KBD_kpminus;
		//NOTE: PC keyboards have no equals key on the keypad, so this triggers a regular equals.
		map[kVK_ANSI_KeypadEquals] = KBD_equals;
		map[kVK_ANSI_KeypadDivide] = KBD_kpdivide;
		map[kVK_ANSI_KeypadMultiply] = KBD_kpmultiply;
		map[kVK_ANSI_KeypadEnter] = KBD_kpenter;
		//NOTE: Clear key is in the same physical location as Numlock on a PC keyboard.
		map[kVK_ANSI_KeypadClear] = KBD_numlock;
		
		map[kVK_Escape] = KBD_esc;
		map[kVK_CapsLock] = KBD_capslock;
		map[kVK_Tab] = KBD_tab;
		map[kVK_Delete] = KBD_backspace;
		map[kVK_ForwardDelete] = KBD_delete;
        //NOTE: Mac keyboards have no insert key, but Ins keys on connected PC keyboards are
        //treated as help keys by OS X.
        map[kVK_Help] = KBD_insert;
		map[kVK_Return] = KBD_enter;
		map[kVK_Space] = KBD_space;
		
		map[kVK_Home] = KBD_home;
		map[kVK_End] = KBD_end;
		map[kVK_PageUp] = KBD_pageup;
		map[kVK_PageDown] = KBD_pagedown;
		
		map[kVK_UpArrow] = KBD_up;
		map[kVK_LeftArrow] = KBD_left;
		map[kVK_DownArrow] = KBD_down;
		map[kVK_RightArrow] = KBD_right;
		
		map[kVK_Shift] = KBD_leftshift;
		map[kVK_Control] = KBD_leftctrl;
		map[kVK_Option] = KBD_leftalt;
		
		map[kVK_RightControl] = KBD_rightctrl;
		map[kVK_RightOption] = KBD_rightalt;
		map[kVK_RightShift] = KBD_rightshift;
		
		map[kVK_ANSI_Minus] = KBD_minus;
		map[kVK_ANSI_Equal] = KBD_equals;
		
		map[kVK_ANSI_LeftBracket] = KBD_leftbracket;
		map[kVK_ANSI_RightBracket] = KBD_rightbracket;
		map[kVK_ANSI_Backslash] = KBD_backslash;
		
		map[kVK_ANSI_Grave] = KBD_grave;
		map[kVK_ANSI_Semicolon] = KBD_semicolon;
		map[kVK_ANSI_Quote] = KBD_quote;
		map[kVK_ANSI_Comma] = KBD_comma;
		map[kVK_ANSI_Period] = KBD_period;
		map[kVK_ANSI_Slash] = KBD_slash;
		map[kVK_ISO_Section] = KBD_extra_lt_gt;
		
		mapGenerated = YES;
	}
    
    //Early return if key code is beyond the range of our mappings anyway.
    if (keyCode > BXMaxSystemKeyCode)
        return KBD_NONE;
	
	//Correction for transposed kVK_ISO_Section/kVK_ANSI_Grave on ISO keyboards.
	if ((keyCode == kVK_ISO_Section || keyCode == kVK_ANSI_Grave) && KBGetLayoutType(LMGetKbdType()) == kKeyboardISO)
	{
        if (keyCode == kVK_ISO_Section) keyCode = kVK_ANSI_Grave;
        else keyCode = kVK_ISO_Section;
	}
	
	return map[keyCode];
}

- (BXDOSKeyCode) _simulatedNumpadKeyCodeForSystemKeyCode: (CGKeyCode)keyCode
{
	static BXDOSKeyCode map[BXMaxSystemKeyCode];
	static BOOL mapGenerated = NO;
	if (!mapGenerated)
	{
        memset(&map, KBD_NONE, sizeof(map));
		
        //Disabled for now as it feels too easy to trigger by accident,
        //resulting in confusion and misery.
		//map[kVK_ANSI_6] = KBD_numlock;
        
		map[kVK_ANSI_7] = KBD_kp7;
		map[kVK_ANSI_8] = KBD_kp8;
		map[kVK_ANSI_9] = KBD_kp9;
		map[kVK_ANSI_0] = KBD_kpdivide;
		
		map[kVK_ANSI_U] = KBD_kp4;
		map[kVK_ANSI_I] = KBD_kp5;
		map[kVK_ANSI_O] = KBD_kp6;
		map[kVK_ANSI_P] = KBD_kpmultiply;
		
		map[kVK_ANSI_J] = KBD_kp1;
		map[kVK_ANSI_K] = KBD_kp2;
		map[kVK_ANSI_L] = KBD_kp3;
		map[kVK_ANSI_Semicolon] = KBD_kpminus;
		
		map[kVK_ANSI_M] = KBD_kp0;
		map[kVK_ANSI_Comma] = KBD_kpperiod;
        map[kVK_ANSI_Period] = KBD_kpenter;
        map[kVK_ANSI_Slash] = KBD_kpplus;
		
		mapGenerated = YES;
	}
	
    //Early return if key code is beyond the range of our mappings anyway.
    if (keyCode > BXMaxSystemKeyCode)
        return KBD_NONE;
    
	//Correction for transposed kVK_ISO_Section/kVK_ANSI_Grave on ISO keyboards.
	if ((keyCode == kVK_ISO_Section || keyCode == kVK_ANSI_Grave) && KBGetLayoutType(LMGetKbdType()) == kKeyboardISO)
	{
        if (keyCode == kVK_ISO_Section) keyCode = kVK_ANSI_Grave;
        else keyCode = kVK_ISO_Section;
	}
    
	return map[keyCode];
}

@end
