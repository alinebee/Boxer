/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXAlert is a base class for self-contained NSAlert sheets that act as their own delegates.
//Boxer subclasses this for various alerts whose logic is too basic to warrant offloading
//to a separate controller.

#import <Cocoa/Cocoa.h>

@interface BXAlert : NSAlert

//Returns a non-retained BXAlert instance.
+ (id) alert;

//Set the alert's icon to the represented icon of the specified window.
//Returns YES if the window had a specific icon, NO otherwise (in which case the alert will use
//the normal application icon instead.)
- (BOOL) adoptIconFromWindow: (NSWindow *)window;

@end
