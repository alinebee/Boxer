/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDisplayLinkRenderingView is a variant of BXGLRenderingView that syncs to the display's
//refresh rate using CVDisplayLink. This is a test class to see if this provides better vsync
//than BXGLRenderingView.

#import "BXGLRenderingView.h"
#import <QuartzCore/QuartzCore.h>

@interface BXDisplayLinkRenderingView : BXGLRenderingView
{
	CVDisplayLinkRef displayLink;
}

@end
