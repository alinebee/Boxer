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
