/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDockTileController is a standalone class that listens for changes to the active DOS session
//and changes the Boxer dock icon to match the current session's gamebox icon (if any).
//This class is instantiated in MainMenu.xib.

#import <Cocoa/Cocoa.h>

@class BXSession;

@interface BXDockTileController : NSObject

//Called whenever the current session or its icon changes.
//This calls coverArtForSession: with the current session and sets NSApplication's icon to the result.
- (void) syncIconWithActiveSession;

@end
