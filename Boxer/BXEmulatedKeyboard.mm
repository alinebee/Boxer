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

//Called after a delay by keyPressed: to release the specified key
- (void) _releaseKeyWithCode: (NSNumber *)key;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXEmulatedKeyboard
@synthesize capsLockEnabled, numLockEnabled, scrollLockEnabled, preferredLayout;

+ (NSTimeInterval) defaultKeypressDuration { return 0.25; }


#pragma mark -
#pragma mark Initialization and deallocation

- (id) init
{
	if ((self = [super init]))
	{
		self.preferredLayout = [[self class] defaultKeyboardLayout];
	}
	return self;
}

- (void) dealloc
{
    self.preferredLayout = nil;
    
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

//FIXME: the US layout has a bug in codepage 858, whereby the E will remain lowercase when capslock is on.
//This bug goes away after switching from another layout back to US, so it may be at the DOSBox level.
+ (NSString *) defaultKeyboardLayout { return @"us"; }

- (void) setActiveLayout: (NSString *)layout
{
    if (![layout isEqualToString: self.activeLayout])
    {
        const char *layoutName;
        if (!layout || layout.length < 2) layoutName = "none";
        //Strip off any codepage number from the string and sanitise it to lowercase.
        else layoutName = [[layout substringToIndex: 2].lowercaseString cStringUsingEncoding: BXDirectStringEncoding];
        
        //IMPLEMENTATION NOTE: we can only safely swap layouts to one that's supported
        //by the current codepage. If the current codepage does not support the specified
        //layout, we would need to load up another codepage, which is too complex and brittle
        //to do while another program may be running.
        //TODO: if we're at the DOS prompt anyway, then run KEYB to let it handle such cases.
        if (boxer_keyboardLayoutSupported(layoutName))
        {   
            Bit32s codepage = -1;
            DOS_SwitchKeyboardLayout(layoutName, codepage);
        }
        
        //Whether we can apply it or not, mark this as our preferred layout so that
        //DOSBox will apply it during startup.
        self.preferredLayout = layout;
    }
}

- (NSString *)activeLayout
{
    if (boxer_keyboardLayoutLoaded())
    {
        const char *loadedName = DOS_GetLoadedLayout();
        
        if (loadedName)
        {
            return [NSString stringWithCString: loadedName encoding: BXDirectStringEncoding];
        }
        else
        {
            //The name of the "none" keyboard layout will be reported as NULL by DOSBox.
            return nil;
        }
    }
    //If the keyboard has not been initialized yet, return the layout we'll apply once DOSBox finishes initializing.
    else
    {
        return self.preferredLayout;
    }
}

- (BOOL) usesActiveLayout
{
    return boxer_keyboardLayoutActive();
}

- (void) setUsesActiveLayout: (BOOL)usesActiveLayout
{
    boxer_setKeyboardLayoutActive(usesActiveLayout);
}

@end
