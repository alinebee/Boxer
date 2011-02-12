/* 
 Boxer is copyright 2010-2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXScriptedPreferences exposes a scripting API for messing with Boxer's application preferences.
//Currently, this only includes a shortcut to the global preferences window.

#import <Cocoa/Cocoa.h>

@interface BXScriptedPreferences : NSObject

//Boxer’s global preferences window.
@property (readonly) NSWindow *window;

//The singleton for this class.
+ (BXScriptedPreferences *) sharedPreferences;

@end
