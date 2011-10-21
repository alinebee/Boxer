/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXHUDControls defines a set of simple NSControl and NSCell subclasses
//for use in HUD-style translucent black windows.

#import <BGHUDAppKit/BGHUDAppKit.h>
#import "BXScroller.h"
#import "BXTemplateImageCell.h"
#import "BXHUDSegmentedCell.h"


//BGHUDAppKit control subclasses hardcoded to use BXBlueTheme.
//These are for use in XCode 4+, which does not support the IB
//plugin that BGHUDAppKit relies on for defining themes.

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

//BGHUDAppKit control subclasses hardcoded to use BXBlueprintTheme and BXBlueprintHelpTextTheme.

@interface BXBlueprintLabel : BXHUDLabel
@end

@interface BXBlueprintHelpTextLabel : BXHUDLabel
@end


//A custom view used for drawing a rounded translucent bezel background.
@interface BXBezelView: NSView
@end
