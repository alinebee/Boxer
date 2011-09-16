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

+ (NSPoint) anchorForAlignment: (NSImageAlignment)alignment
{
    switch (alignment)
    {
        case NSImageAlignCenter:
            return NSMakePoint(0.5f, 0.5f);
        
        case NSImageAlignBottom:
            return NSMakePoint(0.5f, 0.0f);
            
        case NSImageAlignTop:
            return NSMakePoint(0.5f, 1.0f);
            
        case NSImageAlignLeft:
            return NSMakePoint(0.0f, 0.5f);
            
        case NSImageAlignRight:
            return NSMakePoint(1.0f, 0.5f);
            
        case NSImageAlignBottomLeft:
            return NSMakePoint(0.0f, 0.0f);
            
        case NSImageAlignBottomRight:
            return NSMakePoint(1.0f, 0.0f);
            
        case NSImageAlignTopLeft:
            return NSMakePoint(0.0f, 1.0f);
            
        case NSImageAlignTopRight:
            return NSMakePoint(1.0f, 1.0f);
            
        default: //Should never happen, but hey
            return NSZeroPoint;
    }
}

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
        imageRect = [[self imageShadow] insetRectForShadow: imageRect];
    }
    return imageRect;
}

- (void) drawInteriorWithFrame: (NSRect)cellFrame inView: (NSView *)controlView
{	
	//Apply our foreground colour and shadow when drawing any template image
	if ([[self image] isTemplate])
	{
		NSRect drawRegion = NSIntegralRect([self imageRectForBounds: cellFrame]);
        NSSize imageSize = [[self image] size];
        
        NSPoint anchor = [[self class] anchorForAlignment: [self imageAlignment]];
        
        NSRect imageFrame = NSMakeRect(0.0f, 0.0f, imageSize.width, imageSize.height);
        
        NSRect scaledFrame;
        
        switch ([self imageScaling])
        {
            case NSImageScaleProportionallyDown:
                scaledFrame = constrainToRect(imageFrame, drawRegion, anchor);
                break;
            case NSImageScaleProportionallyUpOrDown:
                scaledFrame = fitInRect(imageFrame, drawRegion, anchor);
                break;
            case NSImageScaleAxesIndependently:
                scaledFrame = drawRegion;
                break;
            case NSImageScaleNone:
            default:
                scaledFrame = alignInRectWithAnchor(imageFrame, drawRegion, anchor);
                break;
        }
        
		scaledFrame = NSIntegralRect(scaledFrame);
        
        NSColor *color = ([self isEnabled]) ? [self imageColor] : [self disabledImageColor];
        
        //Use the template image as a mask to create a new image composed entirely of one color.
        NSImage *maskedImage = [[self image] maskedImageWithColor: color
                                                           atSize: scaledFrame.size];
		
		//Then, render the single-color image into the final context along with the drop shadow
		[NSGraphicsContext saveGraphicsState];
			[[self imageShadow] set];
			[maskedImage drawInRect: scaledFrame
                           fromRect: NSZeroRect
                          operation: NSCompositeSourceOver
                           fraction: 1.0f];
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