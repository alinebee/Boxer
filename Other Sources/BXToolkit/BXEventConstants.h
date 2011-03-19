/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXEventConstants (re)defines some useful constants for handling NSEvents.


//These correspond to NSEvent's mouse button numbers
enum {
	BXMouseButtonLeft	= 0,
	BXMouseButtonRight	= 1,
	BXMouseButtonMiddle	= 2
};

//These correspond to NSEvent's pressedMouseButton masks
enum {
	BXNoMouseButtonsMask	= 0,
	BXMouseButtonLeftMask	= 1U << BXMouseButtonLeft,
	BXMouseButtonRightMask	= 1U << BXMouseButtonRight,
	BXMouseButtonMiddleMask	= 1U << BXMouseButtonMiddle,
	
	BXMouseButtonLeftAndRightMask = BXMouseButtonLeftMask | BXMouseButtonRightMask
};

//Modifier flag constants for left- and right-side modifier keys, copied from IOKit/IOLLEvent.h.
//Allows us to distinguish these for sending keypresses for modifier keys.
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
