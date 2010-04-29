/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//The BXInput category extends BXEmulator to add methods for getting keyboard, mouse and joystick
//input into a form that DOSBox can cope with.

#import "BXEmulator.h"
#import <SDL/SDL.h>

enum {
	DOSBoxMouseButtonLeft	= 0,
	DOSBoxMouseButtonMiddle	= 1,
	DOSBoxMouseButtonRight	= 2
};


@interface BXEmulator (BXInput)

//Handling keyboard layout
//------------------------

//Returns a dictionary mapping OSX InputServices input method names to DOS keyboard layout codes. 
+ (NSDictionary *)keyboardLayoutMappings;

//Returns the DOS keyboard layout code for the currently-active input method in OS X.
//Returns nil if no appropriate layout could be found.
+ (NSString *)keyboardLayoutForCurrentInputMethod;

//The default DOS keyboard layout that should be used if no more specific one can be found.
+ (NSString *)defaultKeyboardLayout;


//Triggering events
//-----------------

- (void) sendTab;
- (void) sendDelete;
- (void) sendSpace;
- (void) sendEnter;
- (void) sendF1;
- (void) sendF2;
- (void) sendF3;
- (void) sendF4;
- (void) sendF5;
- (void) sendF6;
- (void) sendF7;
- (void) sendF8;
- (void) sendF9;
- (void) sendF10;

//Accepts a string of characters, and deals with how best to paste it into DOS.
//Returns YES if the string was handled, NO otherwise.
- (BOOL) handlePastedString: (NSString *)pastedString;

//Returns YES if Boxer can paste the specified string, no otherwise.
//In practice, this just returns whether Boxer is at the commandline or not.
- (BOOL) canAcceptPastedString: (NSString *)pastedString;

- (void) handleSDLMouseMovement: (SDL_MouseMotionEvent *)event;
- (void) handleSDLMouseButton: (SDL_MouseButtonEvent *)event;

@end