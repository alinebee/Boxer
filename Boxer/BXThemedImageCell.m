/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXThemedImageCell.h"
#import "ADBGeometry.h"
#import "NSShadow+ADBShadowExtensions.h"
#import "NSImage+ADBImageEffects.h"
#import "BXThemes.h"


@interface BXThemedImageCell ()

@property (readonly, nonatomic) NSGradient *_fillForCurrentState;
@property (readonly, nonatomic) NSShadow *_dropShadowForCurrentState;
@property (readonly, nonatomic) NSShadow *_innerShadowForCurrentState;

@end

@implementation BXThemedImageCell
@synthesize themeKey = _themeKey;
@synthesize highlighted = _highlighted;


#pragma mark - Default theme handling

- (id) initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder: coder];
    if (self)
    {
        if (![coder containsValueForKey: @"themeKey"])
            self.themeKey = [self.class defaultThemeKey];
    }
    return self;
}

- (void) dealloc
{
    self.themeKey = nil;
	[super dealloc];
}

- (void) setThemeKey: (NSString *)key
{
    if (![key isEqual: self.themeKey])
    {
        [_themeKey release];
        _themeKey = [key copy];
        
        [self.controlView setNeedsDisplay: YES];
    }
}

- (NSGradient *) _fillForCurrentState
{
    if (self.isHighlighted)
        return self.themeForKey.highlightedImageFill;
    
    if (!self.isEnabled)
        return self.themeForKey.disabledImageFill;
    
    return self.themeForKey.imageFill;
}

- (NSShadow *) _innerShadowForCurrentState
{
    if (self.isHighlighted)
        return self.themeForKey.highlightedImageInnerShadow;
    
    if (!self.isEnabled)
        return self.themeForKey.disabledImageInnerShadow;
    
    return self.themeForKey.imageInnerShadow;
}

- (NSShadow *) _dropShadowForCurrentState
{
    if (self.isHighlighted)
        return self.themeForKey.highlightedImageDropShadow;
    
    if (!self.isEnabled)
        return self.themeForKey.disabledImageDropShadow;
    
    return self.themeForKey.imageDropShadow;
}

- (NSRect) imageRectForBounds: (NSRect)theRect
{
    NSRect imageRect = [super imageRectForBounds: theRect];
    
    NSShadow *dropShadow = self._dropShadowForCurrentState;
    if (self.image.isTemplate && dropShadow != nil)
    {
        //If we have a shadow set, then constrain the image region to accomodate the shadow
        imageRect = [dropShadow insetRectForShadow: imageRect
                                           flipped: self.controlView.isFlipped];
    }
    return imageRect;
}

- (void) drawInteriorWithFrame: (NSRect)cellFrame inView: (NSView *)controlView
{
	//Apply our foreground colour and shadow when drawing any template image
	if (self.image.isTemplate)
	{
		NSRect imageRegion = [self imageRectForBounds: cellFrame];
        NSRect imageRect = [self.image imageRectAlignedInRect: imageRegion
                                                    alignment: self.imageAlignment
                                                      scaling: self.imageScaling];
        
        //IMPLEMENTATION NOTE: we used to use NSIntegralRect for this, but that would always
        //expand the rectangle rather than rounding down where appropriate. That was occasionally
        //causing images to get stretched if they used NSImageScaleProportionallyDown.
        imageRect = NSMakeRect(round(imageRect.origin.x),
                               round(imageRect.origin.y),
                               round(imageRect.size.width),
                               round(imageRect.size.height));
        
        [NSGraphicsContext saveGraphicsState];
            [self.image drawInRect: imageRect
                      withGradient: self._fillForCurrentState
                        dropShadow: self._dropShadowForCurrentState
                       innerShadow: self._innerShadowForCurrentState
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

+ (NSString *) defaultThemeKey
{
    return @"BXHUDTheme";
}

@end



@implementation BXIndentedImageCell

+ (NSString *) defaultThemeKey
{
    return @"BXIndentedTheme";
}

@end