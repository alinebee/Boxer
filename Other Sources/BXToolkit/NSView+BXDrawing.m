/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "NSView+BXDrawing.h"
#import "BXGeometry.h"

@implementation NSView (BXDrawing)

- (NSPoint) offsetFromWindowOrigin
{
	NSPoint offset = NSZeroPoint;
	NSView *offsetParent = self;
	do
	{
		offset = pointWithDelta(offset, [offsetParent frame].origin);
	}
	while ((offsetParent = [offsetParent superview]));
	
	return offset;
}
@end