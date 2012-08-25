/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBaseAppController.h"
#import "BXKeyboardEventTap.h"

//Dispatches media key events received by the application, which are otherwise unhandled by NSApplication.

#define BXMediaKeyEventSubtype 8

@interface BXBaseAppController (BXHotKeys) <BXKeyboardEventTapDelegate>

- (void) mediaKeyPressed: (NSEvent *)theEvent;

- (void) showHotkeyWarningIfUnavailable;

@end
