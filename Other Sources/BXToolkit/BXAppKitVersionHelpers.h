/* 
 Boxer is copyright 2012 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//Functions for checking which version of AppKit we're running on.

#import <Cocoa/Cocoa.h>


//Not defined in AppKit until 10.6 (whoopeeeeeee)
#ifndef NSAppKitVersionNumber10_5
#define NSAppKitVersionNumber10_5 949
#endif 

#ifndef NSAppKitVersionNumber10_6
#define NSAppKitVersionNumber10_6 1038
#endif

#ifndef NSAppKitVersionNumber10_7
#define NSAppKitVersionNumber10_7 1110
#endif

BOOL isRunningOnLeopard();
BOOL isRunningOnSnowLeopard();
BOOL isRunningOnSnowLeopardOrAbove();
BOOL isRunningOnLionOrAbove();

