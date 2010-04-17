/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXContextSwitchingRenderView.h"
#import "BXRenderer.h"

@implementation BXContextSwitchingRenderView
@synthesize windowedContext;

- (void) dealloc
{
	[self setWindowedContext: nil], [windowedContext release];
	[super dealloc];
}

- (BOOL) enterFullScreenMode: (NSScreen *)screen withOptions: (NSDictionary *)options
{
	if ([super enterFullScreenMode: screen withOptions: options])
	{
		[self setWindowedContext: [self openGLContext]];
		
		CGDirectDisplayID screenID = [[[screen deviceDescription] valueForKey: @"NSScreenNumber"] integerValue];
		NSOpenGLPixelFormatAttribute attrs[] = {
			NSOpenGLPFAFullScreen,
			NSOpenGLPFAScreenMask, CGDisplayIDToOpenGLDisplayMask(screenID),
			NSOpenGLPFAColorSize, 32,
			NSOpenGLPFADoubleBuffer,
			NSOpenGLPFAAccelerated,
			0
		};
		
		NSOpenGLPixelFormat *pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attrs];
		
		NSOpenGLContext *fullScreenContext = [[NSOpenGLContext alloc] initWithFormat: pixelFormat shareContext: [self windowedContext]];
		
		[self setOpenGLContext: fullScreenContext];
		[fullScreenContext setView: self];
		[fullScreenContext makeCurrentContext];
		[fullScreenContext setFullScreen];
		[self setNeedsDisplay: YES];
		
		[pixelFormat release];
		[fullScreenContext release];	
		
		//[self setNeedsDisplay: YES];
		return YES;
	}
	else
	{
		return NO;
	}
}

- (void) exitFullScreenModeWithOptions: (NSDictionary *)options
{
	//[self clearGLContext];
	[super exitFullScreenModeWithOptions: options];
	[self setOpenGLContext: [self windowedContext]];
	[[self openGLContext] setView: self];
	[[self openGLContext] makeCurrentContext];
	[self setNeedsDisplay: YES];
}
@end