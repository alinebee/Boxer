/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSessionWindow.h"
#import "BXSessionWindowController.h"

@implementation BXSessionWindow

//Overridden to make our required controller type explicit
- (BXSessionWindowController *) windowController
{
	return (BXSessionWindowController *)[super windowController];
}

//Adjust reported content/frame sizes to account for statusbar and program panel
//This is used to keep content resizing proportional to the shape of the render view, not the shape of the window
- (NSRect) contentRectForFrameRect:(NSRect)windowFrame
{
	NSRect rect = [super contentRectForFrameRect: windowFrame];
	NSView *container	= [[self windowController] viewContainer];

	CGFloat sizeAdjustment	= [container frame].origin.y;
	rect.size.height		-= sizeAdjustment;
	rect.origin.y			+= sizeAdjustment;

	return rect;
}

- (NSRect) frameRectForContentRect: (NSRect)windowContent
{
	NSRect rect = [super frameRectForContentRect: windowContent];
	NSView *container	= [[self windowController] viewContainer];

	CGFloat sizeAdjustment	= [container frame].origin.y;
	rect.size.height		+= sizeAdjustment;
	rect.origin.y			-= sizeAdjustment;
	
	return rect;
}

//Disable constraining if our window controller is taking matters into its own hands 
- (NSRect)constrainFrameRect:(NSRect)frameRect toScreen:(NSScreen *)screen
{
	if ([[self windowController] resizingProgrammatically]) return frameRect;
	else return [super constrainFrameRect: frameRect toScreen: screen];
}
@end