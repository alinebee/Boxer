/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXBridge.h"

@implementation BXBridge

+ (BXBridge *) bridge
{
	static BXBridge *bridge = nil;
	if (bridge == nil) bridge = [[BXBridge alloc] init];
	return bridge;
}

- (id) windowController
{
	return [[[NSApp delegate] currentSession] mainWindowController];
}

- (NSWindow *) window
{
	return [[self windowController] SDLWindow];
}

- (NSView *) view
{
	return [[self windowController] renderView];
}

- (NSOpenGLContext *) openGLContext
{
	return [[self windowController] SDLOpenGLContext];
}

- (BOOL) handleKeyboardEvent: (NSEvent *)event
{
	return [[self windowController] handleSDLKeyboardEvent: event];
}

- (void) prepareViewForFullscreen
{
	[[self windowController] prepareSDLViewForFullscreen];
}

- (void) prepareViewForFrame: (NSRect)frame
{
	[[self windowController] prepareSDLViewForFrame: frame];
}

- (void) prepareOpenGLContextWithFormat: (NSOpenGLPixelFormat *)format
{
	[[self windowController] prepareSDLOpenGLContextWithFormat: format];
}

- (void) prepareOpenGLContextForTeardown
{
	[[self windowController] prepareSDLOpenGLContextForTeardown];
}
@end
