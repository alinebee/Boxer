/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXBridge is SDL's interface onto Boxer, and provides SDL with data about the Boxer session
//on a need-to-know basis.

#import <Cocoa/Cocoa.h>

@interface BXBridge : NSObject

+ (BXBridge *)bridge;

- (id) windowController;
- (NSWindow *) window;
- (NSView *) view;
- (NSOpenGLContext *) openGLContext;

- (BOOL) handleKeyboardEvent: (NSEvent *)event;

- (void) prepareViewForFullscreen;
- (void) prepareViewForFrame: (NSRect)frame;
- (void) prepareOpenGLContextWithFormat: (NSOpenGLPixelFormat *)format;
- (void) prepareOpenGLContextForTeardown;

@end