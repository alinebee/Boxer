/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Carbon/Carbon.h>
#import "BXEmulator+BXInput.h"
#import "BXRenderer.h"

#import "config.h"
#import "video.h"
#import "mouse.h"
#import "sdlmain.h"

@implementation BXEmulator (BXInput)
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
							   
							   //There should be different mappings for Canadian vs French-Canadian
							   @"ca",	@"com.apple.keylayout.Canadian",
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

+ (NSString *)keyboardLayoutForCurrentInputMethod
{
	TISInputSourceRef keyboardRef	= TISCopyCurrentKeyboardLayoutInputSource();
	NSString *inputSourceID			= (NSString *)TISGetInputSourceProperty(keyboardRef, kTISPropertyInputSourceID);
	CFRelease(keyboardRef);
	
	return [[self keyboardLayoutMappings] objectForKey: inputSourceID];
}

+ (NSString *)defaultKeyboardLayout	{ return @"us"; }


//Triggering events
//-----------------

//This currently uses SDL keycodes directly, because it's less work than trying to munge NSEvents
- (void) _simulateKeypress: (SDLKey)sdlKey withKeyCode: (unsigned short)keyCode
{
	SDL_KeyboardEvent keyDown, keyUp;
	SDL_keysym key;
	
	key.scancode = keyCode;
	key.unicode  = 0;
	key.sym      = sdlKey;
	key.mod      = KMOD_NONE; //Todo: apply the appropriate modifiers
	
	keyDown.type = SDL_KEYDOWN;
	keyDown.state = SDL_PRESSED;
	keyDown.keysym = key;
	
	keyUp.type = SDL_KEYUP;
	keyUp.state = SDL_RELEASED;
	keyUp.keysym = key;
	
	SDL_PushEvent((SDL_Event *)&keyDown);
	SDL_PushEvent((SDL_Event *)&keyUp);
}

- (void) sendTab	{ return [self _simulateKeypress: SDLK_TAB withKeyCode: kVK_Tab]; }
- (void) sendDelete	{ return [self _simulateKeypress: SDLK_DELETE withKeyCode: kVK_Delete]; }
- (void) sendSpace	{ return [self _simulateKeypress: SDLK_SPACE withKeyCode: kVK_Space]; }
- (void) sendEnter	{ return [self _simulateKeypress: SDLK_RETURN withKeyCode: kVK_Return]; }
- (void) sendF1		{ return [self _simulateKeypress: SDLK_F1	withKeyCode: kVK_F1]; }
- (void) sendF2		{ return [self _simulateKeypress: SDLK_F2	withKeyCode: kVK_F2]; }
- (void) sendF3		{ return [self _simulateKeypress: SDLK_F3	withKeyCode: kVK_F3]; }
- (void) sendF4		{ return [self _simulateKeypress: SDLK_F4	withKeyCode: kVK_F4]; }
- (void) sendF5		{ return [self _simulateKeypress: SDLK_F5	withKeyCode: kVK_F5]; }
- (void) sendF6		{ return [self _simulateKeypress: SDLK_F6	withKeyCode: kVK_F6]; }
- (void) sendF7		{ return [self _simulateKeypress: SDLK_F7	withKeyCode: kVK_F7]; }
- (void) sendF8		{ return [self _simulateKeypress: SDLK_F8	withKeyCode: kVK_F8]; }
- (void) sendF9		{ return [self _simulateKeypress: SDLK_F9	withKeyCode: kVK_F9]; }
- (void) sendF10	{ return [self _simulateKeypress: SDLK_F10	withKeyCode: kVK_F10]; }


- (BOOL) handlePastedString: (NSString *)pastedString
{
	if ([self isAtPrompt])
	{
		//Split string into separate lines, which will be pasted one by one as commands
		NSArray *lines = [pastedString componentsSeparatedByCharactersInSet: [NSCharacterSet newlineCharacterSet]];
		NSUInteger i, numLines = [lines count];
		for (i = 0; i < numLines; i++)
		{
			//Remove whitespace from each line
			NSString *cleanedString = [[lines objectAtIndex: i]
									   stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
			
			if ([cleanedString length])
			{
				//Execute each line immediately, except for the last one, which we leave in case the user wants to modify it
				if (i < numLines - 1) cleanedString = [cleanedString stringByAppendingString: @"\n"]; 
				[[self commandQueue] addObject: cleanedString];
			}
		}
		return YES;
	}
	return NO;
}

- (BOOL) canAcceptPastedString: (NSString *)pastedString
{
	//Disabled-for-1.0: Disable paste and drag-drop of text for now, as there are too many bugs for it to be a releasable feature.
	return NO;
	//return [self isAtPrompt];
}

+ (NSSet *) keyPathsForValuesAffectingMouseActive	{ return [NSSet setWithObject: @"isRunningProcess"]; }

- (BOOL) mouseActive
{
	//The mouse active state is not reset by DOSBox when a game exits.
	return mouseActive && [self isRunningProcess];
}



- (void) handleSDLMouseMovement: (SDL_MouseMotionEvent *)motion
{
	NSRect viewport = [[self renderer] viewport];
	CGFloat sensitivity = sdl.mouse.sensitivity / 100.0f;
	
	NSPoint relativeMotion		= NSMakePoint(motion->xrel, motion->yrel);
	NSPoint absolutePosition	= NSMakePoint((motion->x - viewport.origin.x) / (viewport.size.width - 1),
											  (motion->y - viewport.origin.y) / (viewport.size.height - 1)); 
	
	
	Mouse_CursorMoved(relativeMotion.x * sensitivity,
					  relativeMotion.y * sensitivity,
					  absolutePosition.x * sensitivity,
					  absolutePosition.y * sensitivity,
					  [self mouseLocked]);
}

- (void) handleSDLMouseButton: (SDL_MouseButtonEvent *)event
{
	/*
	NSInteger button;
	
	//Convert SDL button constants to DOSBox button constants
	switch (event->button)
	{
		case SDL_BUTTON_LEFT:	button = DOSBoxMouseButtonLeft; break;
		case SDL_BUTTON_RIGHT:	button = DOSBoxMouseButtonRight; break;
		case SDL_BUTTON_MIDDLE:	button = DOSBoxMouseButtonMiddle; break;
		default:
			//Ignore buttons we don't recognise
			return;
	}
	
	if (event->state == SDL_PRESSED)
	{
		//If the mouse was clicked while Cmd was held down, lock/unlock the mouse and discard the event
		if ([[NSApp currentEvent] modifierFlags] & NSCommandKeyMask)
		{
			BXSession *session = [self delegate];
			[NSApp sendAction: @selector(toggleMouseLocked:) to: nil from: self];
			return;
		}
		else Mouse_ButtonPressed(button);
	}
	else if (event->state == SDL_RELEASED)
	{
		Mouse_ButtonReleased(button);	
	}
	 */
}

@end