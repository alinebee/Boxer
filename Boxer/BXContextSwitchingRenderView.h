/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXContextSwitchingRenderView is a test variant of BXRenderView to see whether manually creating
//a new fullscreen OpenGL context offers faster or less buggy rendering than maintaining the existing
//context when switching to fullscreen.

#import <Cocoa/Cocoa.h>
#import "BXRenderView.h"

@class BXRenderer;
@interface BXContextSwitchingRenderView : BXRenderView
{
	NSOpenGLContext *windowedContext;	//Used to retain the former windowed context during fullscreen
}
@property (retain) NSOpenGLContext *windowedContext;
@end