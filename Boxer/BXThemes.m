/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXThemes.h"

@implementation BXShadowedTextTheme

- (NSShadow *) textShadow	{ return [self dropShadow]; }

@end

@implementation BXHelpTextTheme

- (NSColor *) textColor
{
	return [NSColor whiteColor];
}
@end


@implementation BXBlueprintTheme

- (NSShadow *) textShadow
{
	static NSShadow *textShadow;
	if (!textShadow)
	{
		textShadow = [[NSShadow alloc] init];
		[textShadow setShadowOffset: NSMakeSize(0.0f, 0.0f)];
		[textShadow setShadowBlurRadius: 3.0f];
		[textShadow setShadowColor: [[NSColor blackColor] colorWithAlphaComponent: 0.75f]];
	}
	return textShadow;
}

- (NSColor *) textColor
{
	return [NSColor whiteColor];
}

@end

@implementation BXBlueprintHelpText

- (NSColor *) textColor
{
	return [NSColor colorWithCalibratedRed: 0.67f green: 0.86f blue: 0.93f alpha: 1.0f];
}
@end



@implementation BXBlueTheme

- (NSColor *) disabledTextColor
{
    return [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.5f];
}

- (NSGradient *) highlightGradient
{
	NSColor *selectionColor	= [[NSColor alternateSelectedControlColor] colorWithAlphaComponent: [self alphaValue]];
	
	NSColor *topColor		= [selectionColor highlightWithLevel: 0.3f];
	NSColor *midColor1		= [selectionColor highlightWithLevel: 0.2f];
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

- (NSGradient *) highlightKnobColor
{
	//Use solid colours to avoid the track showing through
	NSColor *selectionColor	= [NSColor alternateSelectedControlColor];
	
	NSColor *topColor		= [selectionColor highlightWithLevel: 0.2f];
	NSColor *midColor1		= [selectionColor highlightWithLevel: 0.1f];
	NSColor *midColor2		= [selectionColor shadowWithLevel: 0.2f];
	NSColor *bottomColor	= [selectionColor shadowWithLevel: 0.4f];
	
	NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
							topColor,		0.0f,
							midColor1,		0.5f,
							midColor2,		0.5f,
							bottomColor,	1.0f,
							nil];
	
	return [gradient autorelease];
}

- (NSShadow *) focusRing
{
	NSShadow *glow = [[NSShadow new] autorelease];
	[glow setShadowColor: [NSColor keyboardFocusIndicatorColor]];
	[glow setShadowBlurRadius: 2.0f];
	return glow;
}

@end


@implementation BXWelcomeTheme

- (NSColor *) strokeColor
{
	return [NSColor colorWithCalibratedWhite: 1.0f alpha: 0.33f];
}

@end