/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDOSView is an NSOpenGLView subclass which displays DOSBox's rendered output.
//It relies on a BXRenderer object to do the actual drawing: telling it to draw when needed,
//and notifying it of changes to the viewport dimensions.

#import <Cocoa/Cocoa.h>

@class BXRenderingLayer;
@class BXFrameRateCounterLayer;
@class BXFrameBuffer;


@protocol BXDOSView

- (void) updateWithFrame: (BXFrameBuffer *)frame;

@end

@interface BXDOSLayerView : NSView <BXDOSView>
{
	BXRenderingLayer *renderingLayer;
	BXFrameRateCounterLayer *frameRateLayer;
}
@property (retain) BXRenderingLayer *renderingLayer;
@property (retain) BXFrameRateCounterLayer *frameRateLayer;

//Tell the rendering layer to draw the specified frame
- (void) updateWithFrame: (BXFrameBuffer *)frame;

//Render the view's badged grey background; this shows through when there is no renderer yet.
- (void) drawBackgroundInRect: (NSRect) dirtyRect;

//Toggle the frame rate display on/off
- (IBAction) toggleFrameRate: (id) sender;
@end