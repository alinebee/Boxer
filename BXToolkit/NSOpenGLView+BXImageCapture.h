/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXImageCapture category extends NSOpenGLView to allow it to cache to an NSBitmapImageRep.
//This reimplements existing, but on NSOpenGLView nonfunctional, methods from NSView.

#import <Cocoa/Cocoa.h>

@interface NSOpenGLView (BXImageCapture)
- (NSBitmapImageRep *) bitmapImageRepForCachingDisplayInRect: (NSRect)theRect;

- (void) cacheDisplayInRect:	(NSRect)theRect
			toBitmapImageRep:	(NSBitmapImageRep *)rep;
@end

@interface NSBitmapImageRep (BXFlipper)
//Flips a bitmap vertically to go to/from a flipped coordinate system.
//Used by BXImageCapture to correct the coordinates of a bitmap captured from OpenGL (which uses flipped coordinates.)
- (void) flip;
@end