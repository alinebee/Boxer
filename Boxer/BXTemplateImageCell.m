/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXTemplateImageCell.h"
#import "BXGeometry.h"
#import "NSShadow+BXShadowExtensions.h"

@implementation BXTemplateImageCell
@synthesize imageColor, imageShadow;

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
	[self setImageColor: nil], [imageColor release];
	[self setImageShadow: nil], [imageShadow release];
	
	[super dealloc];
}

- (NSRect) imageRectForBounds: (NSRect)theRect
{
    NSRect imageRect = [super imageRectForBounds: theRect];
    if ([self imageShadow])
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
		NSImage *templateImage = [[self image] copy];
		
        NSRect drawRegion = NSIntegralRect([self imageRectForBounds: cellFrame]);
        
        NSSize imageSize = [templateImage size];
        
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
        
		//First resize the image to the intended size and fill it with the foreground colour
		[templateImage setSize: scaledFrame.size];
		[templateImage lockFocus];
			[[self imageColor] set];
			NSRectFillUsingOperation(NSMakeRect(0.0f, 0.0f, scaledFrame.size.width, scaledFrame.size.height), NSCompositeSourceAtop);
		[templateImage unlockFocus];
		
		//Then render the matted image into the final context along with the drop shadow
		[NSGraphicsContext saveGraphicsState];
			[[self imageShadow] set];
			[templateImage drawInRect: scaledFrame
                             fromRect: NSZeroRect
                            operation: NSCompositeSourceOver
                             fraction: 1.0f];
		[NSGraphicsContext restoreGraphicsState];
		[templateImage release];
	}
	else
	{
		[super drawInteriorWithFrame: cellFrame inView: controlView];
	}
}

@end

@implementation BXHUDImageCell

- (void) awakeFromNib
{
	if (![self imageColor])
	{
		[self setImageColor: [NSColor whiteColor]];
	}
	
	if (![self imageShadow])
	{
		NSShadow *theShadow = [[NSShadow alloc] init];
		
		[theShadow setShadowBlurRadius: 3.0f];
		[theShadow setShadowOffset: NSMakeSize(0.0f, -1.0f)];
		
		[self setImageShadow: theShadow];
		[theShadow release];
	}
}

@end