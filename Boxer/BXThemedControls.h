/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXThemedControls defines a set of simple NSControl and NSCell subclasses
//hardcoded to use our own BGHUDAppKit themes. These are for use in XCode 4+,
//which does not support the IB plugin BGHUDAppKit relies on for assigning themes.

#import <BGHUDAppKit/BGHUDAppKit.h>
#import "BXThemedSegmentedCell.h"
#import "BXThemedPopUpButtonCell.h"
#import "BXThemedButtonCell.h"
#import "BXThemedSliderCell.h"
#import "BXThemedImageCell.h"

//NSControl extension to allow passthroughs to themed cell properties
@interface NSControl (BXThemedControls)

//The theme corresponding to the current theme key.
- (BGTheme *) themeForKey;

//If the control wraps a themed cell, returns the cell's theme key.
//Otherwise returns nil.
- (NSString *) themeKey;

//If the control wraps a themed cell, sets the cell's theme key.
//Otherwise does nothing.
- (void) setThemeKey: (NSString *)themeKey;

@end


//Base classes for our BGHUDAppKit-themed control subclasses.

@interface BXThemedLabel : BGHUDLabel

//The theme corresponding to the current theme key.
@property (readonly, nonatomic) BGTheme *themeForKey;

//The initial theme key for all instances of this cell.
//Returns nil by default: intended to be implemented in subclasses.
+ (NSString *) defaultThemeKey;

@end

@interface BXThemedCheckboxCell : BXThemedButtonCell
@end

@interface BXThemedRadioCell : BXThemedButtonCell
@end


//BGHUDAppKit control subclasses hardcoded to use BXHUDTheme.

@interface BXHUDLabel : BXThemedLabel
@end

@interface BXHUDButtonCell : BXThemedButtonCell
@end

@interface BXHUDCheckboxCell : BXThemedCheckboxCell
@end

@interface BXHUDSliderCell : BXThemedSliderCell
@end

@interface BXHUDSegmentedCell : BXThemedSegmentedCell
@end

@interface BXHUDPopUpButtonCell : BXThemedPopUpButtonCell
@end

//BGHUDAppKit control subclasses hardcoded to use BXBlueprintTheme
//and BXBlueprintHelpTextTheme.

@interface BXBlueprintLabel : BXThemedLabel
@end

@interface BXBlueprintHelpTextLabel : BXThemedLabel
@end

//BGHUDAppKit control subclasses hardcoded to use BXIndentedTheme
//and BXIndentedHelpTextTheme.

@interface BXIndentedLabel : BXThemedLabel
@end

@interface BXIndentedHelpTextLabel : BXIndentedLabel
@end

@interface BXIndentedCheckboxCell : BXThemedCheckboxCell
@end

@interface BXIndentedSliderCell : BXThemedSliderCell
@end

//BGHUDAppKit control subclasses hardcoded to use BXAboutTheme,
//BXAboutDarkTheme and BXAboutLightTheme.
@interface BXAboutLabel : BXThemedLabel
@end

@interface BXAboutDarkLabel : BXThemedLabel
@end

@interface BXAboutLightLabel : BXThemedLabel
@end
