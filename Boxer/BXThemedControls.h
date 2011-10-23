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

//Base classes for our BGHUDAppKit-themed control subclasses.

@interface BXThemedLabel : BGHUDLabel
@end

@interface BXThemedButtonCell : BGHUDButtonCell
@end

@interface BXThemedCheckboxCell : BXThemedButtonCell
@end

@interface BXThemedRadioCell : BXThemedButtonCell
@end

@interface BXThemedSliderCell : BGHUDSliderCell
@end

@interface BXThemedPopUpButtonCell : BGHUDPopUpButtonCell
@end


//BGHUDAppKit control subclasses hardcoded to use BXBlueTheme.

@interface BXHUDLabel : BXThemedLabel
@end

@interface BXHUDButtonCell : BXThemedButtonCell
@end

@interface BXHUDCheckboxCell : BXThemedCheckboxCell
@end

@interface BXHUDSliderCell : BXThemedSliderCell
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
