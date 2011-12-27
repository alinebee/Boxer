/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXEmulatedKeyboard.h"


#pragma mark -
#pragma mark Private method declarations

@interface BXEmulatedKeyboard ()

//Called after a delay by keyPressed: to release the specified key
- (void) _releaseKeyWithCode: (NSNumber *)key;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXEmulatedKeyboard
@synthesize capsLockEnabled, numLockEnabled, activeLayout;

+ (NSString *) defaultKeyboardLayout { return @"us"; }

+ (NSTimeInterval) defaultKeypressDuration { return 0.25; }


#pragma mark -
#pragma mark Initialization and deallocation

- (id) init
{
	if ((self = [super init]))
	{
		[self setActiveLayout: [[self class] defaultKeyboardLayout]];
	}
	return self;
}

- (void) dealloc
{
	[self setActiveLayout: nil], [activeLayout release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark Keyboard input

- (void) keyDown: (BXDOSKeyCode)key
{   
    //If this key is not already pressed, tell the emulator the key has been pressed.
	if (!pressedKeys[key])
	{
		KEYBOARD_AddKey(key, YES);
		
		if		(key == KBD_capslock)	[self setCapsLockEnabled: !capsLockEnabled];
		else if	(key == KBD_numlock)	[self setNumLockEnabled: !numLockEnabled];
	}
    pressedKeys[key]++;
}

- (void) keyUp: (BXDOSKeyCode)key
{
	if (pressedKeys[key])
	{
        //FIXME: we should just decrement the number of times the key has been pressed
        //instead of clearing it altogether. However, we're still running into problems
        //with arrowkeys, where we miss a keyUp: event from OS X and the key stays pressed.
        //This should be changed back once those problems have been located and fixed.
        
		//pressedKeys[key]--;
        pressedKeys[key] = 0;
        
        //If this was the last press of this key,
        //tell the emulator to finally release the key.
        if (!pressedKeys[key])
            KEYBOARD_AddKey(key, NO);
	}
}

- (BOOL) keyIsDown: (BXDOSKeyCode)key
{
	return pressedKeys[key] > 0;
}

- (void) keyPressed: (BXDOSKeyCode)key
{
	[self keyPressed: key forDuration: BXKeyPressDurationDefault];
}

- (void) keyPressed: (BXDOSKeyCode)key forDuration: (NSTimeInterval)duration
{
	[self keyDown: key];
	
	[self performSelector: @selector(_releaseKeyWithCode:)
			   withObject: [NSNumber numberWithUnsignedShort: key]
			   afterDelay: duration];
}
	 
- (void) _releaseKeyWithCode: (NSNumber *)key
{
	[self keyUp: [key unsignedShortValue]];
}

- (void) clearInput
{
	BXDOSKeyCode key;
	for (key=KBD_NONE; key<KBD_LAST; key++)
    {
        [self clearKey: key];
    }
}

- (void) clearKey: (BXDOSKeyCode)key
{
    if (pressedKeys[key])
    {
        //Ensure that no matter how many ways the key is being held down,
        //it will always be released by this keyUp:.
        pressedKeys[key] = 1;
        [self keyUp: key];
    }
}
	 
@end
