/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXShelfArt.h"

@implementation BXShelfArt

- (id) initWithSourceImage: (NSImage *)image
{
    self = [super init];
	if (self)
	{
        self.sourceImage = image;
	}
	return self;
}

- (void) drawInRect: (NSRect)frame
{
	NSAssert(self.sourceImage != nil, @"[BXShelfArt -drawInRect:] called before source image was set.");
	
	NSColor *tileColor = [NSColor colorWithPatternImage: self.sourceImage];
	NSSize tileSize = self.sourceImage.size;
	
	//Set the phase so that the art is drawn from the top left corner of the frame
	NSUInteger offset = (NSUInteger)frame.size.height % (NSUInteger)tileSize.height;
	
	NSPoint tilePhase = NSMakePoint(frame.origin.x,
									frame.origin.y + (CGFloat)offset);
	
	//Combine with the phase of the inherited graphics context
	NSPoint initialPhase = [NSGraphicsContext currentContext].patternPhase;
	NSPoint combinedPhase = NSMakePoint(tilePhase.x + initialPhase.x,
										tilePhase.y + initialPhase.y);
	
	[NSGraphicsContext saveGraphicsState];
		[[NSGraphicsContext currentContext] setPatternPhase: combinedPhase];
		[tileColor set];
		NSRectFill(frame);
	[NSGraphicsContext restoreGraphicsState];
}

//Returns a new NSImage containing the source image tiled to fill the specified size.
- (NSImage *) tiledImageWithSize: (NSSize)size
{
	NSAssert(self.sourceImage != nil, @"[BXShelfArt -tiledImageWithSize:] called before source image was set.");
	
	NSImage *image = [[NSImage alloc] initWithSize: size];
	NSRect frame = NSMakeRect(0, 0, size.width, size.height);
	
	[image lockFocus];
		[self drawInRect: frame];
	[image unlockFocus];
	
	return image;
}

- (NSImage *) tiledImageWithPixelSize: (NSSize)pixelSize
{
    NSSize logicalSize = pixelSize;
    
    //TODO: ask our drawing context to do the conversion itself
    if ([[NSScreen mainScreen] respondsToSelector: @selector(convertRectFromBacking:)])
    {
        NSRect pixelFrame = NSMakeRect(0, 0, pixelSize.width, pixelSize.height);
        logicalSize = [[NSScreen mainScreen] convertRectFromBacking: pixelFrame].size;
    }
    
    return [self tiledImageWithSize: logicalSize];
}
@end
