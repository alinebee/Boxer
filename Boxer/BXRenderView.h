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

@class BXRenderingLayer;
@class BXFrameRateCounterLayer;

@interface BXRenderView : NSView
{
	BXRenderingLayer *renderingLayer;
	BXFrameRateCounterLayer *frameRateLayer;
}
@property (retain) BXRenderingLayer *renderingLayer;
@property (retain) BXFrameRateCounterLayer *frameRateLayer;

//Render the view's badged grey background; this shows through when there is no renderer yet.
- (void) drawBackgroundInRect: (NSRect) dirtyRect;

//Toggle the frame rate display on/off
- (IBAction) toggleFrameRate: (id) sender;
@end