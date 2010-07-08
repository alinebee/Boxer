/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXThemes defines custom UI themes for BGHUDAppKit to customise the appearance of UI elements.
//These are used in Boxer's inspector panel and elsewhere.

#import <Cocoa/Cocoa.h>
#import <BGHUDAppKit/BGTheme.h>

//Adds a soft text shadow behind labels and button text.
@interface BXShadowedTextTheme : BGTheme
- (NSShadow *) textShadow;
@end

//Applies a light gray text colour for help text in HUD-style panels, along with a text shadow.
@interface BXHelpTextTheme : BXShadowedTextTheme
- (NSColor *) textColor;
@end

//Currently unused.
/*
@interface BXIconButtonTheme : BXShadowedTextTheme
- (CGFloat) alphaValue;
- (CGFloat) disabledAlphaValue;
@end
*/
