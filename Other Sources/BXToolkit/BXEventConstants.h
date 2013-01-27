/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXEventConstants (re)defines some useful constants for handling NSEvents.

#import <Cocoa/Cocoa.h>

//A sufficiently large number that exceeds the highest virtual keycode.
//Used as the arbitrary length for arrays of key mappings.
#define BXMaxSystemKeyCode 256

//These correspond to NSEvent's mouse button numbers
typedef enum {
	BXMouseButtonLeft	= 0,
	BXMouseButtonRight	= 1,
	BXMouseButtonMiddle	= 2,
    BXMouseButtonMax    = 3
} BXMouseButton;


//These correspond to NSEvent's pressedMouseButton masks
enum {
	BXNoMouseButtonsMask	= 0,
	BXMouseButtonLeftMask	= 1U << BXMouseButtonLeft,
	BXMouseButtonRightMask	= 1U << BXMouseButtonRight,
	BXMouseButtonMiddleMask	= 1U << BXMouseButtonMiddle,
	
	BXMouseButtonLeftAndRightMask = BXMouseButtonLeftMask | BXMouseButtonRightMask
};

typedef NSUInteger BXMouseButtonMask;


//Modifier flag constants for left- and right-side modifier keys, copied from IOKit/IOLLEvent.h.
//Allows us to distinguish these for sending keypresses for modifier keys.

//IMPLEMENTATION NOTE: these are combined with their respective device-independent modifier masks,
//to ensure that modifier flags we compare against do actually represent a key event of that type:
//this avoids collisions with other unrelated device-dependent flags.
enum {
	BXLeftControlKeyMask	= 0x00000001 | NSControlKeyMask,
	BXLeftShiftKeyMask		= 0x00000002 | NSShiftKeyMask,
	BXRightShiftKeyMask		= 0x00000004 | NSShiftKeyMask,
	BXLeftCommandKeyMask	= 0x00000008 | NSCommandKeyMask,
	BXRightCommandKeyMask	= 0x00000010 | NSCommandKeyMask,
	BXLeftAlternateKeyMask	= 0x00000020 | NSAlternateKeyMask,
	BXRightAlternateKeyMask	= 0x00000040 | NSAlternateKeyMask,
	BXRightControlKeyMask	= 0x00002000 | NSControlKeyMask
};
