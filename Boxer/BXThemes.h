/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXThemes defines custom UI themes for BGHUDAppKit to customise the appearance of UI elements.
//These are used in Boxer's inspector panel and elsewhere.

#import <Cocoa/Cocoa.h>
#import <BGHUDAppKit/BGHUDAppKit.h>

//Adds a soft text shadow behind labels and button text.
@interface BXShadowedTextTheme : BGGradientTheme
- (NSShadow *) textShadow;
@end

//Adds a soft shadow around text.
@interface BXBlueprintTheme : BGGradientTheme
- (NSShadow *) textShadow;
- (NSColor *) textColor;
@end

//Adds translucency to helper text
@interface BXBlueprintHelpText : BXBlueprintTheme
- (NSColor *) textColor;
@end

//Applies a light gray text colour for help text in HUD-style panels, along with a text shadow.
@interface BXHelpTextTheme : BXShadowedTextTheme
- (NSColor *) textColor;
@end

//Makes selection highlights blue-tinted instead of grey.
@interface BXBlueTheme : BXShadowedTextTheme
- (NSGradient *) highlightGradient;
- (NSGradient *) pushedGradient;
- (NSGradient *) highlightComplexGradient;
- (NSGradient *) pushedComplexGradient;
- (NSGradient *) highlightKnobColor;
- (NSShadow *) focusRing;
@end

//Makes borders more subtle for the darker background of the welcome panel.
@interface BXWelcomeTheme : BXBlueTheme
- (NSColor *) strokeColor;

@end