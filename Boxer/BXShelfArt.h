/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>


/// \c BXShelfArt generates tiled shelf artwork for Finder folders. It can return an NSImage resource
/// suitable for saving as a file, or draw the art directly into the current graphics context.
@interface BXShelfArt : NSObject

/// The original image we will render into tiled shelf art.
@property (strong) NSImage *sourceImage;

#pragma mark -
#pragma mark Initialization and teardown

/// Default initializer: returns a BXShelfArt object initialized with the specified source image.
- (instancetype) initWithSourceImage: (NSImage *)image;


#pragma mark -
#pragma mark Rendering methods

/// Draws the source image tiled into the specified frame in the current graphics context.
- (void) drawInRect: (NSRect)frame;

/// Returns a new NSImage containing the source image tiled to fill the logical unit size.
- (NSImage *) tiledImageWithSize: (NSSize)size;

/// Returns a new NSImage containing the source image tiled to fill the specific device pixel size.
- (NSImage *) tiledImageWithPixelSize: (NSSize)pixelSize;

@end
