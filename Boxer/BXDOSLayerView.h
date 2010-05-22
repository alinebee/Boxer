/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDOSLayerView is a layer-backed implementation of the BXFrameRenderingView protocol.
//It uses a CAOpenGLLayer subclass for displaying frame content, and unlike BXDOSGLView
//it can display other views or layers over the top of this content.

//This layer-based drawing approach is not currently used as it has significant unresolved
//performance problems compared to BXDOSGLView.

#import "BXFrameRenderingView.h"

@class BXRenderingLayer;
@class BXFrameRateCounterLayer;

@interface BXDOSLayerView : NSView <BXFrameRenderingView>
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