/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXTemplateImageCell.h"
#import "BXGeometry.h"
#import "NSShadow+BXShadowExtensions.h"
#import "NSImage+BXImageEffects.h"


@implementation BXTemplateImageCell
@synthesize imageColor, disabledImageColor, imageShadow;

- (void) dealloc
{
	[self setImageColor: nil],          [imageColor release];
	[self setDisabledImageColor: nil],  [disabledImageColor release];
	[self setImageShadow: nil],         [imageShadow release];
	
	[super dealloc];
}

- (NSRect) imageRectForBounds: (NSRect)theRect
{
    NSRect imageRect = [super imageRectForBounds: theRect];
    if ([self imageShadow] && [[self image] isTemplate])
    {
        //If we have a shadow set, then constrain the image region to accomodate the shadow
        imageRect = [[self imageShadow] insetRectForShadow: imageRect
                                                   flipped: [[self controlView] isFlipped]];
    }
    return imageRect;
}

- (void) drawInteriorWithFrame: (NSRect)cellFrame inView: (NSView *)controlView
{	
	//Apply our foreground colour and shadow when drawing any template image
	if ([[self image] isTemplate])
	{
		NSRect imageRegion = NSIntegralRect([self imageRectForBounds: cellFrame]);
        
        NSRect imageRect = [[self image] imageRectAlignedInRect: imageRegion
                                                     alignment: [self imageAlignment]
                                                       scaling: [self imageScaling]];
        
        imageRect = NSIntegralRect(imageRect);
        
        NSColor *color = ([self isEnabled]) ? [self imageColor] : [self disabledImageColor];
        
        //Use the template image as a mask to create a new image composed entirely of one color.
        NSImage *maskedImage = [[self image] imageFilledWithColor: color
                                                           atSize: imageRect.size];
		
		//Then, render the single-color image into the final context along with the drop shadow
		[NSGraphicsContext saveGraphicsState];
			[[self imageShadow] set];
			[maskedImage drawInRect: imageRect
                           fromRect: NSZeroRect
                          operation: NSCompositeSourceOver
                           fraction: 1.0f
                     respectFlipped: YES];
		[NSGraphicsContext restoreGraphicsState];
	}
	else
	{
		[super drawInteriorWithFrame: cellFrame inView: controlView];
	}
}

@end

@implementation BXHUDImageCell

- (NSColor *) imageColor
{
    if (!imageColor) imageColor = [[NSColor whiteColor] retain];
    return imageColor;
}

- (NSColor *) disabledImageColor
{
    if (!disabledImageColor) disabledImageColor = [[NSColor colorWithCalibratedWhite: 1.0f alpha: 0.5f] retain];
    return disabledImageColor;
}

- (NSShadow *) imageShadow
{
    if (!imageShadow)
    {
        imageShadow = [[NSShadow alloc] init];
		
		[imageShadow setShadowBlurRadius: 3.0f];
		[imageShadow setShadowOffset: NSMakeSize(0.0f, -1.0f)];
    }
    return imageShadow;
}

@end