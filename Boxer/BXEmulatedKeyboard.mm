/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXEmulatedKeyboard.h"
#import "BXEmulator.h"
#import "BXCoalface.h"

#pragma mark -
#pragma mark Private method declarations

//Implemented in dos_keyboard_layout.cpp
Bitu DOS_SwitchKeyboardLayout(const char* new_layout, Bit32s& tried_cp);
Bitu DOS_LoadKeyboardLayout(const char * layoutname, Bit32s codepage, const char * codepagefile);
const char* DOS_GetLoadedLayout(void);

@interface BXEmulatedKeyboard ()

@property (copy) NSString *pendingLayout;

//Called after a delay by keyPressed: to release the specified key
- (void) _releaseKeyWithCode: (NSNumber *)key;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXEmulatedKeyboard
@synthesize capsLockEnabled, numLockEnabled, scrollLockEnabled, pendingLayout;

+ (NSTimeInterval) defaultKeypressDuration { return 0.25; }


#pragma mark -
#pragma mark Initialization and deallocation

- (id) init
{
	if ((self = [super init]))
	{
		self.pendingLayout = [[self class] defaultKeyboardLayout];
	}
	return self;
}

- (void) dealloc
{
    self.pendingLayout = nil;
    
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
        else if (key == KBD_scrolllock) [self setScrollLockEnabled: !scrollLockEnabled];
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
	
    if (duration > 0)
    {
        [self performSelector: @selector(_releaseKeyWithCode:)
                   withObject: [NSNumber numberWithUnsignedShort: key]
                   afterDelay: duration];
    }
    //Immediately release the key if the duration was 0.
    //CHECKME: The keydown and keyup events will still appear in the keyboard event queue,
    //but games that poll the current state of the keys may overlook the event.
    else
    {
        [self keyUp: key];
    }
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

- (BOOL) keyboardBufferFull
{
    return boxer_keyboardBufferFull();
}

#pragma mark -
#pragma mark Keyboard layout

+ (NSString *) defaultKeyboardLayout { return @"us"; }

- (void) setActiveLayout: (NSString *)layout
{
    //TODO: support codepage files as well as keycodes?
    
    //We cannot have a null layout, so explicitly force it to the default here.
    if (!layout) layout = [[self class] defaultKeyboardLayout];
    
    //Always sanitise the layout to lowercase.
    layout = layout.lowercaseString;
    
    if (![layout isEqualToString: self.activeLayout])
    {
        if (boxer_keyboardLayoutHasLoaded())
        {
            const char *layoutName = [layout cStringUsingEncoding: BXDirectStringEncoding];
            Bit32s codepage = -1;
            
            DOS_SwitchKeyboardLayout(layoutName, codepage);
            NSLog(@"%s, %i", layoutName, codepage);
        }
        //Whether we can apply it or not, update the pending layout also.
        self.pendingLayout = layout;
    }
}

- (NSString *)activeLayout
{
    if (boxer_keyboardLayoutHasLoaded())
    {
        const char *loadedName = DOS_GetLoadedLayout();
        
        //The name of the default keyboard layout (US) will be reported as NULL by DOSBox.
        if (loadedName)
        {
            return [NSString stringWithCString: loadedName encoding: BXDirectStringEncoding];
        }
        else
        {
            return @"us";
        }
    }
    //If no layout has been loaded yet, return the layout we'll apply once DOSBox finishes initializing.
    else
    {
        return self.pendingLayout;
    }
}
	 
@end
