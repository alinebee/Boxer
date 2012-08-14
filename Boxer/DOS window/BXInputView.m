/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXInputView.h"
#import "BXGeometry.h"
#import "NSView+BXDrawing.h"
#import "NSShadow+BXShadowExtensions.h"


@implementation BXInputView

- (BOOL) acceptsFirstResponder
{
	return YES;
}

//Prevent ourselves from relinquishing first-responder status to other elements in the window,
//which could otherwise happen if the user has toggled "Full Keyboard Access" mode in the
//System Keyboard Preferences.
//FIXME: this is rather a blunt instrument and there are cases where it would be desirable
//to allow keyboard focus to move to other elements. Instead of refusing to resign, we should
//pass the decision upstream to BXInputController (which deserves a delegate relationship.)
- (BOOL) resignFirstResponder
{
    return self.isHiddenOrHasHiddenAncestor;
}

//Use flipped coordinates to make input handling easier
- (BOOL) isFlipped
{
	return YES;
}

//Pass on various events that would otherwise be eaten by the default NSView implementation
- (void) rightMouseDown: (NSEvent *)theEvent
{
	[self.nextResponder rightMouseDown: theEvent];
}

@end
