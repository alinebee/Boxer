/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXThemes defines custom UI themes for BGHUDAppKit to customise the appearance of UI elements.
//These are used in Boxer's inspector panel and elsewhere.

#import <Cocoa/Cocoa.h>
#import <BGHUDAppKit/BGHUDAppKit.h>

//Adds convenience methods used by all Boxer themes.
@interface BXBaseTheme : BGGradientTheme
//Registers the theme class with the theme manager,
//keyed under the specific name.
//If name is nil, the classname will be used.
+ (void) registerWithName: (NSString *)name;
@end

//Adds a soft shadow around text.
@interface BXBlueprintTheme : BXBaseTheme
- (NSShadow *) textShadow;
- (NSColor *) textColor;
@end

//Adds translucency to helper text
@interface BXBlueprintHelpTextTheme : BXBlueprintTheme
- (NSColor *) textColor;
@end

//Makes selection highlights blue-tinted instead of grey.
@interface BXBlueTheme : BXBaseTheme
- (NSGradient *) highlightGradient;
- (NSGradient *) pushedGradient;
- (NSGradient *) highlightComplexGradient;
- (NSGradient *) pushedComplexGradient;
- (NSGradient *) highlightKnobColor;
- (NSShadow *) focusRing;
@end
