/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXRenderView is an NSOpenGLView subclass which displays DOSBox's rendered output.
//It relies on a BXRenderer object to do the actual drawing: telling it to draw when needed,
//and notifying it of changes to the viewport dimensions.

#import <Cocoa/Cocoa.h>

@class BXRenderer;
@interface BXRenderView : NSOpenGLView
{
	BXRenderer *renderer;
	IBOutlet NSViewController *delegate;
}
@property (retain) BXRenderer *renderer;

//Render the view's badged grey background; this shows through when there is no renderer yet.
- (void) drawBackgroundInRect: (NSRect) dirtyRect;
@end