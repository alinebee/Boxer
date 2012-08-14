/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXThemedButtonCell.h"

@interface BXLaunchPanelButton : NSButton
@end

//Provides the custom appearance and mouseover behaviour for launch buttons.
@interface BXLaunchPanelButtonCell : BXThemedButtonCell
{
    BOOL _mouseIsInside;
}
@end

//Cleans up button behaviour for a button that only displays an image,
//for which we do not want to show any highlight effects.
@interface BXLaunchPanelLogoCell : NSButtonCell
@end