/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXShelfArt generates tiled shelf artwork for Finder folders. It can return an NSImage resource
//suitable for saving as a file, or draw the art directly into the current graphics context.

#import <Cocoa/Cocoa.h>


@interface BXShelfArt : NSObject
{
	NSImage *sourceImage;
}
//The original image we will render into tiled shelf art
@property (retain) NSImage *sourceImage;

#pragma mark -
#pragma mark Initialization and teardown

//Default initializer: returns a BXShelfArt object initialized with the specified source image.
- (id) initWithSourceImage: (NSImage *)image;


#pragma mark -
#pragma mark Rendering methods

//Draws the source image tiled into the specified frame in the current graphics context.
- (void) drawInRect: (NSRect)frame;

//Returns a new NSImage containing the source image tiled to fill the specified size.
- (NSImage *)tiledImageWithSize: (NSSize)size;

@end
