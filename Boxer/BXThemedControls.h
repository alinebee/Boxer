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


//BGHUDAppKit control subclasses hardcoded to use BXBlueTheme.

@interface BXHUDLabel : BGHUDLabel
@end

@interface BXHUDButtonCell : BGHUDButtonCell
@end

@interface BXHUDCheckboxCell : BXHUDButtonCell
@end

@interface BXHUDSliderCell : BGHUDSliderCell
@end

@interface BXHUDPopUpButtonCell : BGHUDPopUpButtonCell
@end

//BGHUDAppKit control subclasses hardcoded to use BXBlueprintTheme
//and BXBlueprintHelpTextTheme.

@interface BXBlueprintLabel : BXHUDLabel
@end

@interface BXBlueprintHelpTextLabel : BXHUDLabel
@end


