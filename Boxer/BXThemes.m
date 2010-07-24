/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
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
	return [NSColor lightGrayColor];
}
@end

@implementation BXBlueTheme

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

/*
@implementation BXIconButtonTheme
- (CGFloat) alphaValue			{ return 1.0; }
- (CGFloat) disabledAlphaValue	{ return 0.6; }
@end
*/
