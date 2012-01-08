/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXGLRenderingView is an NSOpenGLView subclass which displays DOSBox's rendered output.
//It manages a BXRenderer object to do the actual drawing, passing it new frames to draw
//and notifying it of changes to the view dimensions.

#import "BXFrameRenderingView.h"

@class BXRenderer;
@interface BXGLRenderingView : NSOpenGLView <BXFrameRenderingView>
{
	BXRenderer *renderer;
}
@property (retain, nonatomic) BXRenderer *renderer;

@end
