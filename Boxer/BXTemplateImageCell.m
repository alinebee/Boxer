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
@synthesize imageFill = _imageFill;
@synthesize disabledImageFill = _disabledImageFill;
@synthesize dropShadow = _dropShadow;
@synthesize innerShadow = _innerShadow;

- (void) awakeFromNib
{
    self.imageFill = [self.class defaultImageFill];
    self.disabledImageFill = [self.class defaultDisabledImageFill];
    self.dropShadow = [self.class defaultDropShadow];
    self.innerShadow = [self.class defaultInnerShadow];
}

- (void) dealloc
{
    self.imageFill = nil;
    self.disabledImageFill = nil;
    self.dropShadow = nil;
    self.innerShadow = nil;
    
	[super dealloc];
}

- (NSRect) imageRectForBounds: (NSRect)theRect
{
    NSRect imageRect = [super imageRectForBounds: theRect];
    if (self.dropShadow && self.image.isTemplate)
    {
        //If we have a shadow set, then constrain the image region to accomodate the shadow
        imageRect = [self.dropShadow insetRectForShadow: imageRect
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
        NSGradient *fill = (self.isEnabled) ? self.imageFill : self.disabledImageFill;
		
        [NSGraphicsContext saveGraphicsState];
		[self.image drawInRect: imageRect withGradient: fill dropShadow: self.dropShadow innerShadow: self.innerShadow];
        [NSGraphicsContext restoreGraphicsState];
	}
	else
	{
		[super drawInteriorWithFrame: cellFrame inView: controlView];
	}
}

- (void) setImageFill: (NSGradient *)imageFill
{
    if (![self.imageFill isEqual: imageFill])
    {
        [_imageFill release];
        _imageFill = [imageFill copy];
        
        [self.controlView setNeedsDisplay: YES];
    }
}

- (void) setDisabledImageFill: (NSGradient *)imageFill
{
    if (![self.disabledImageFill isEqual: imageFill])
    {
        [_disabledImageFill release];
        _disabledImageFill = [imageFill copy];
        
        [self.controlView setNeedsDisplay: YES];
    }
}

- (void) setDropShadow: (NSShadow *)dropShadow
{
    if (![self.dropShadow isEqual: dropShadow])
    {
        [_dropShadow release];
        _dropShadow = [dropShadow copy];
        
        [self.controlView setNeedsDisplay: YES];
    }
}

- (void) setInnerShadow: (NSShadow *)innerShadow
{
    if (![self.innerShadow isEqual: innerShadow])
    {
        [_innerShadow release];
        _innerShadow = [innerShadow copy];
        
        [self.controlView setNeedsDisplay: YES];
    }
}

//Override in subclasses
+ (NSGradient *) defaultImageFill           { return nil; }
+ (NSGradient *) defaultDisabledImageFill   { return nil; }
+ (NSShadow *) defaultDropShadow            { return nil; }
+ (NSShadow *) defaultInnerShadow           { return nil; }

@end

@implementation BXHUDImageCell

+ (NSGradient *) defaultImageFill
{
    return [[[NSGradient alloc] initWithStartingColor: [NSColor whiteColor]
                                          endingColor: [NSColor whiteColor]] autorelease];
}

+ (NSGradient *) defaultDisabledImageFill
{
    return [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 1 alpha: 0.5]
                                          endingColor: [NSColor colorWithCalibratedWhite: 1 alpha: 0.5]] autorelease];
}

+ (NSShadow *) defaultDropShadow
{
    return [NSShadow shadowWithBlurRadius: 3.0f offset: NSMakeSize(0.0f, -1.0f)];
}

+ (NSShadow *) defaultInnerShadow
{
    return nil;
}

@end



@implementation BXIndentedImageCell

+ (NSGradient *) defaultImageFill
{
    return [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 0 alpha: 0.25]
                                          endingColor: [NSColor colorWithCalibratedWhite: 0 alpha: 0.10]] autorelease];
}

+ (NSGradient *) defaultDisabledImageFill
{
    return [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 0 alpha: 0.15]
                                          endingColor: [NSColor colorWithCalibratedWhite: 0 alpha: 0.05]] autorelease];
}

+ (NSShadow *) defaultDropShadow
{
    return [NSShadow shadowWithBlurRadius: 1.0
                                   offset: NSMakeSize(0, -1)
                                    color: [NSColor colorWithCalibratedWhite: 1 alpha: 1]];
}

+ (NSShadow *) defaultInnerShadow
{
    return [NSShadow shadowWithBlurRadius: 1.25
                                   offset: NSMakeSize(0, -0.25)
                                    color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.5]];
}

@end