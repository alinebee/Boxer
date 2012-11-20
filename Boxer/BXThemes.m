/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXThemes.h"
#import "NSShadow+BXShadowExtensions.h"


@implementation BGTheme (BXThemeExtensions)

+ (void) registerWithName: (NSString *)name
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    if (!name) name = NSStringFromClass(self);
    BGTheme *theme = [[self alloc] init];
    [[BGThemeManager keyedManager] setTheme: theme
                                     forKey: name];
    [theme release];
    [pool drain];
}

- (NSShadow *) sliderTrackInnerShadow
{
    return nil;
}

- (NSShadow *) sliderTrackShadow
{
    return nil;
}

- (NSShadow *) sliderKnobShadow
{
    return self.dropShadow;
}

- (NSColor *) sliderTrackStrokeColor
{
    return self.strokeColor;
}

- (NSColor *) disabledSliderTrackStrokeColor
{
    return self.disabledStrokeColor;
}

- (NSColor *) sliderKnobStrokeColor
{
    return self.strokeColor;
}

- (NSColor *) disabledSliderKnobStrokeColor
{
    return self.disabledStrokeColor;
}


- (NSGradient *) imageFill
{
    return [[[NSGradient alloc] initWithStartingColor: self.textColor endingColor: self.textColor] autorelease];
}
- (NSShadow *) imageDropShadow  { return self.dropShadow; }
- (NSShadow *) imageInnerShadow { return nil; }

- (NSGradient *) selectedImageFill      { return self.imageFill; }
- (NSShadow *) selectedImageDropShadow  { return self.imageDropShadow; }
- (NSShadow *) selectedImageInnerShadow { return self.imageInnerShadow; }

- (NSGradient *) highlightedImageFill      { return self.imageFill; }
- (NSShadow *) highlightedImageDropShadow  { return self.imageDropShadow; }
- (NSShadow *) highlightedImageInnerShadow { return self.imageInnerShadow; }

- (NSGradient *) pushedImageFill      { return self.highlightedImageFill; }
- (NSShadow *) pushedImageDropShadow  { return self.highlightedImageDropShadow; }
- (NSShadow *) pushedImageInnerShadow { return self.highlightedImageInnerShadow; }

- (NSGradient *) disabledImageFill
{
    return [[[NSGradient alloc] initWithStartingColor: self.disabledTextColor endingColor: self.disabledTextColor] autorelease];
}
- (NSShadow *) disabledImageDropShadow  { return self.imageDropShadow; }
- (NSShadow *) disabledImageInnerShadow { return self.imageInnerShadow; }

@end


@implementation BXBaseTheme
@end

@implementation BXBlueprintTheme

+ (void) load
{
    [self registerWithName: nil];
}

- (NSShadow *) textShadow
{
    return [NSShadow shadowWithBlurRadius: 3.0f
                                   offset: NSZeroSize
                                    color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.75f]];
}

- (NSColor *) textColor
{
	return [NSColor whiteColor];
}

@end

@implementation BXBlueprintHelpTextTheme

+ (void) load
{
    [self registerWithName: nil];
}

- (NSColor *) textColor
{
	return [NSColor colorWithCalibratedRed: 0.67f green: 0.86f blue: 0.93f alpha: 1.0f];
}
@end



@implementation BXHUDTheme

+ (void) load
{
    [self registerWithName: nil];
}

- (NSShadow *) dropShadow
{
    return [NSShadow shadowWithBlurRadius: 2
                                   offset: NSMakeSize(0, -1)
                                    color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.75f]];
}
- (NSShadow *) textShadow
{
    return [NSShadow shadowWithBlurRadius: 2
                                   offset: NSMakeSize(0, -1)
                                    color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.66f]];
}

- (NSColor *) textColor
{
    return [NSColor whiteColor];
}

- (NSColor *) disabledTextColor
{
    return [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.5f];
}

- (NSGradient *) normalGradient
{
	NSColor *baseColor      = [NSColor colorWithCalibratedWhite: 0.15f alpha: 0.75f];
	
	NSColor *topColor		= [baseColor highlightWithLevel: 0.15f];
	NSColor *midColor1		= [baseColor highlightWithLevel: 0.05f];
	NSColor *midColor2		= baseColor;
	NSColor *bottomColor	= [baseColor shadowWithLevel: 0.4f];
	
	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
							topColor,		0.0f,
							midColor1,		0.5f,
							midColor2,		0.5f,
							bottomColor,	1.0f,
							nil];
	
	return [gradient autorelease];
}

- (NSGradient *) highlightGradient
{
	NSColor *selectionColor	= [[NSColor alternateSelectedControlColor] colorWithAlphaComponent: [self alphaValue]];
	
	NSColor *topColor		= [selectionColor highlightWithLevel: 0.25f];
	NSColor *midColor1		= [selectionColor highlightWithLevel: 0.1f];
	NSColor *midColor2		= selectionColor;
	NSColor *bottomColor	= [selectionColor shadowWithLevel: 0.4f];
	
	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
							topColor,		0.0f,
							midColor1,		0.5f,
							midColor2,		0.5f,
							bottomColor,	1.0f,
							nil];
	
	return [gradient autorelease];
}


- (NSGradient *) knobColor
{
	//Use solid colours to avoid the track showing through
	NSColor *baseColor      = [NSColor colorWithCalibratedWhite: 0.15f alpha: 1.0f];
	
	NSColor *topColor		= [baseColor highlightWithLevel: 0.15f];
	NSColor *midColor1		= [baseColor highlightWithLevel: 0.05f];
	NSColor *midColor2		= baseColor;
	NSColor *bottomColor	= [baseColor shadowWithLevel: 0.4f];
	
	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
							topColor,		0.0f,
							midColor1,		0.4f,
							midColor2,		0.4f,
							bottomColor,	1.0f,
							nil];
	
	return [gradient autorelease];
}

- (NSGradient *) highlightKnobColor
{
	//Use solid colours to avoid the track showing through
	NSColor *selectionColor	= [[NSColor alternateSelectedControlColor] shadowWithLevel: 0.25f];
	
	NSColor *topColor		= [selectionColor highlightWithLevel: 0.25f];
	NSColor *midColor1		= [selectionColor highlightWithLevel: 0.1f];
	NSColor *midColor2		= selectionColor;
	NSColor *bottomColor	= [selectionColor shadowWithLevel: 0.4f];
	
	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
							topColor,		0.0f,
							midColor1,		0.4f,
							midColor2,		0.4f,
							bottomColor,	1.0f,
							nil];
	
	return [gradient autorelease];
}

- (NSColor *) sliderTrackColor
{
    return [NSColor colorWithCalibratedWhite: 0 alpha: 0.1f];
}

- (NSGradient *) pushedGradient
{
	return [self highlightGradient];
}

- (NSGradient *) highlightComplexGradient
{
	return [self highlightGradient];
}

- (NSGradient *) pushedComplexGradient
{
	return [self pushedGradient];
}


- (NSShadow *) focusRing
{
    return [NSShadow shadowWithBlurRadius: 2.0f
                                   offset: NSZeroSize
                                    color: [NSColor keyboardFocusIndicatorColor]];
}

- (NSColor *) strokeColor
{
    return [NSColor colorWithCalibratedRed: 0.8f green: 0.85f blue: 0.9f alpha: 0.33f];
}

@end


@implementation BXIndentedTheme

+ (void) load
{
    [self registerWithName: nil];
}

- (NSShadow *) textShadow	{ return self.dropShadow; }

- (NSShadow *) dropShadow
{
    return [NSShadow shadowWithBlurRadius: 1.0f
                                   offset: NSMakeSize(0, -1.0f)
                                    color: [NSColor colorWithCalibratedWhite: 1 alpha: 1.0f]];
}

- (NSColor *) textColor
{
    return [NSColor colorWithCalibratedWhite: 0.25f alpha: 1];
}

- (NSColor *) disabledTextColor
{
    return [NSColor grayColor];
}

- (NSColor *) strokeColor
{
    return [NSColor colorWithCalibratedWhite: 0 alpha: 0.25f];
}

- (NSColor *) disabledStrokeColor
{
    return [NSColor colorWithCalibratedWhite: 0 alpha: 0.1f];
}


- (NSGradient *) normalGradient
{
    NSColor *baseColor = [NSColor lightGrayColor];
    
    NSColor *topColor		= [baseColor highlightWithLevel: 0.2f];
	NSColor *midColor		= baseColor;
	NSColor *bottomColor	= [baseColor shadowWithLevel: 0.2f];
	
	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
							topColor,		0.0f,
							midColor,		0.5f,
							bottomColor,	1.0f,
							nil];
    
    return [gradient autorelease];
}

- (NSGradient *) normalComplexGradient
{
    return [self normalGradient];
}

- (NSGradient *) highlightGradient
{
	NSColor *selectionColor	= [[NSColor alternateSelectedControlColor] colorWithAlphaComponent: 1];
	
	NSColor *topColor		= [selectionColor highlightWithLevel: 0.3f];
	NSColor *midColor1		= [selectionColor highlightWithLevel: 0.05f];
	NSColor *midColor2		= selectionColor;
	NSColor *bottomColor	= [selectionColor shadowWithLevel: 0.1f];
	
	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
							topColor,		0.0f,
							midColor1,		0.5f,
							midColor2,		0.5f,
							bottomColor,	1.0f,
							nil];
	
	return [gradient autorelease];
}

- (NSGradient *) pushedGradient
{
	return [self highlightGradient];
}

- (NSGradient *) highlightComplexGradient
{
	return [self highlightGradient];
}

- (NSGradient *) pushedComplexGradient
{
	return [self pushedGradient];
}

- (NSGradient *) knobColor
{
    NSColor *baseColor = [NSColor colorWithCalibratedWhite: 0.75f alpha: 1.0f];
    
    NSColor *topColor		= [baseColor highlightWithLevel: 0.3f];
	NSColor *midColor		= baseColor;
	NSColor *bottomColor	= [baseColor shadowWithLevel: 0.1f];
	
	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
							topColor,		0.0f,
							midColor,		0.5f,
							bottomColor,	1.0f,
							nil];
    
    return [gradient autorelease];
}

- (NSGradient *) disabledKnobColor
{
    NSColor *baseColor = [NSColor colorWithCalibratedWhite: 0.9f alpha: 1.0f];
    
    NSColor *topColor		= [baseColor highlightWithLevel: 0.3f];
	NSColor *midColor		= baseColor;
	NSColor *bottomColor	= [baseColor shadowWithLevel: 0.1f];
	
	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
							topColor,		0.0f,
							midColor,		0.5f,
							bottomColor,	1.0f,
							nil];
    
    return [gradient autorelease];
}

- (NSGradient *) highlightKnobColor
{
    return self.highlightGradient;
}

- (NSColor *) sliderTrackColor
{
    return [NSColor colorWithCalibratedWhite: 0 alpha: 0.2f];
}

- (NSColor *) disabledSliderTrackColor
{
    return [NSColor colorWithCalibratedWhite: 0 alpha: 0.1f];
}

- (NSShadow *) sliderTrackShadow
{
    return self.dropShadow;
}

- (NSShadow *) sliderTrackInnerShadow
{
    return [NSShadow shadowWithBlurRadius: 3.0f
                                   offset: NSMakeSize(0, -1.0f)
                                    color: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.5f]];
}

- (NSShadow *) sliderKnobShadow
{
    return [NSShadow shadowWithBlurRadius: 2.0f
                                   offset: NSMakeSize(0, -1.0f)
                                    color: [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.5f]];
}

- (NSColor *) sliderKnobStrokeColor
{
    return [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.4f];
}

- (NSColor *) disabledSliderKnobStrokeColor
{
    return [NSColor colorWithCalibratedWhite: 0.0f alpha: 0.25f];
}



- (NSGradient *) imageFill
{
    return [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 0 alpha: 0.33]
                                          endingColor: [NSColor colorWithCalibratedWhite: 0 alpha: 0.10]] autorelease];
}
- (NSShadow *) imageDropShadow
{
    return [NSShadow shadowWithBlurRadius: 1.0
                                   offset: NSMakeSize(0, -1)
                                    color: [NSColor colorWithCalibratedWhite: 1 alpha: 1]];
}
- (NSShadow *) imageInnerShadow
{
    return [NSShadow shadowWithBlurRadius: 1.25
                                   offset: NSMakeSize(0, -0.25)
                                    color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.5]];
}

- (NSGradient *) selectedImageFill
{
    return [[[NSGradient alloc] initWithStartingColor: [NSColor whiteColor]
                                          endingColor: [NSColor whiteColor]] autorelease];
}

- (NSShadow *) selectedImageInnerShadow
{
    return nil;
}

- (NSShadow *) selectedImageDropShadow
{
    return [NSShadow shadowWithBlurRadius: 1.0
                                   offset: NSMakeSize(0, -1)
                                    color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.5]];
}

- (NSGradient *) disabledImageFill
{
    return [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 0 alpha: 0.10]
                                          endingColor: [NSColor colorWithCalibratedWhite: 0 alpha: 0.05]] autorelease];
}
- (NSShadow *) disabledImageInnerShadow
{
    return [NSShadow shadowWithBlurRadius: 1.25
                                   offset: NSMakeSize(0, -0.25)
                                    color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.25]];
}

- (NSGradient *) highlightedImageFill
{
    return [[[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 0 alpha: 0.5]
                                          endingColor: [NSColor colorWithCalibratedWhite: 0 alpha: 0.15]] autorelease];
}
- (NSShadow *) highlightedImageInnerShadow
{
    return [NSShadow shadowWithBlurRadius: 1.25
                                   offset: NSMakeSize(0, -0.25)
                                    color: [NSColor colorWithCalibratedWhite: 0 alpha: 0.6]];
}

@end

@implementation BXIndentedHelpTextTheme

+ (void) load
{
    [self registerWithName: nil];
}

- (NSColor *) textColor
{
    return [NSColor darkGrayColor];
}

@end



@implementation BXAboutTheme

+ (void) load
{
    [self registerWithName: nil];
}

- (NSShadow *) textShadow	{ return [self dropShadow]; }

- (NSShadow *) dropShadow
{
    return [NSShadow shadowWithBlurRadius: 1.0f
                                   offset: NSMakeSize(0, 1.0f)
                                    color: [NSColor colorWithCalibratedWhite: 0 alpha: 1.0f]];
}

- (NSColor *) textColor
{
    return [NSColor colorWithCalibratedWhite: 1 alpha: 0.66f];
}

@end


@implementation BXAboutDarkTheme

+ (void) load
{
    [self registerWithName: nil];
}

- (NSShadow *) dropShadow
{
    return [NSShadow shadowWithBlurRadius: 1.0f
                                   offset: NSMakeSize(0, -1.0f)
                                    color: [NSColor colorWithCalibratedWhite: 1 alpha: 0.4f]];
}

- (NSColor *) textColor
{
    return [NSColor colorWithCalibratedWhite: 0 alpha: 0.9f];
}

@end

@implementation BXAboutLightTheme

+ (void) load
{
    [self registerWithName: nil];
}

- (NSColor *) textColor
{
    return [NSColor colorWithCalibratedWhite: 1 alpha: 0.8f];
}

@end