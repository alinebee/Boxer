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
	return [NSColor lightGrayColor];
}
@end

/*
@implementation BXIconButtonTheme
- (CGFloat) alphaValue			{ return 1.0; }
- (CGFloat) disabledAlphaValue	{ return 0.6; }
@end
*/