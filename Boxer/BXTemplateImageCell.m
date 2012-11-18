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
@synthesize imageColor = _imageColor;
@synthesize disabledImageColor = _disabledImageColor;
@synthesize imageShadow = _imageShadow;
@synthesize innerShadow = _innerShadow;

- (void) dealloc
{
    self.imageColor = nil;
    self.disabledImageColor = nil;
    self.imageShadow = nil;
    self.innerShadow = nil;
	[super dealloc];
}

- (NSRect) imageRectForBounds: (NSRect)theRect
{
    NSRect imageRect = [super imageRectForBounds: theRect];
    if (self.imageShadow && self.image.isTemplate)
    {
        //If we have a shadow set, then constrain the image region to accomodate the shadow
        imageRect = [self.imageShadow insetRectForShadow: imageRect
                                                 flipped: self.controlView.isFlipped];
    }
    return imageRect;
}

- (void) drawInteriorWithFrame: (NSRect)cellFrame inView: (NSView *)controlView
{	
	//Apply our foreground colour and shadow when drawing any template image
	if (self.image.isTemplate)
	{
		NSRect imageRegion = NSIntegralRect([self imageRectForBounds: cellFrame]);
        
        NSRect imageRect = [self.image imageRectAlignedInRect: imageRegion
                                                    alignment: self.imageAlignment
                                                      scaling: self.imageScaling];
        
        imageRect = NSIntegralRect(imageRect);
        
        NSColor *color = (self.isEnabled) ? self.imageColor : self.disabledImageColor;
        
        //Use the template image as a mask to create a new image composed entirely of one color.
        NSImage *maskedImage = [self.image imageFilledWithColor: color
                                                         atSize: imageRect.size];
		
		//Then, render the single-color image into the final context along with the drop shadow
		[NSGraphicsContext saveGraphicsState];
			[self.imageShadow set];
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
    if (!_imageColor) self.imageColor = [NSColor whiteColor];
    return _imageColor;
}

- (NSColor *) disabledImageColor
{
    if (!_disabledImageColor)
        self.disabledImageColor = [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.5f];
    
    return _disabledImageColor;
}

- (NSShadow *) imageShadow
{
    if (!_imageShadow)
    {
        self.imageShadow = [NSShadow shadowWithBlurRadius: 3.0f
                                                   offset: NSMakeSize(0.0f, -1.0f)];
    }
    return _imageShadow;
}

@end



@implementation BXIndentedImageCell

- (void) awakeFromNib
{
    self.imageColor = [NSColor colorWithCalibratedWhite: 0 alpha: 0.25];
    self.imageShadow = [NSShadow shadowWithBlurRadius: 1
                                               offset: NSMakeSize(0, -1)
                                                color: [NSColor colorWithCalibratedWhite: 1 alpha: 1]];
    self.innerShadow = [NSShadow shadowWithBlurRadius: 2
                                               offset: NSMakeSize(0, -0.5)
                                                color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.5]];
}

- (void) drawInteriorWithFrame: (NSRect)cellFrame inView: (NSView *)controlView
{
	//Apply our foreground colour and shadow when drawing any template image
	if (self.image.isTemplate)
	{
		NSRect imageRegion = NSIntegralRect([self imageRectForBounds: cellFrame]);
        
        NSRect imageRect = [self.image imageRectAlignedInRect: imageRegion
                                                    alignment: self.imageAlignment
                                                      scaling: self.imageScaling];
        
        imageRect = NSIntegralRect(imageRect);
        
        NSGradient *gradient = [[[NSGradient alloc] initWithStartingColor: self.imageColor
                                                              endingColor: self.imageColor] autorelease];
		
		[self.image drawInRect: imageRect withGradient: gradient dropShadow: self.imageShadow innerShadow: self.innerShadow];
	}
	else
	{
		[super drawInteriorWithFrame: cellFrame inView: controlView];
	}
}

@end