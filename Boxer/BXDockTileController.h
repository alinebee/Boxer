/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXDockTileController is a standalone class that listens for changes to the active DOS session
//and changes the Boxer dock icon to match the current session's gamebox icon (if any).
//This class is instantiated in MainMenu.xib.

#import <Cocoa/Cocoa.h>

@class BXSession;

@interface BXDockTileController : NSObject

//Returns appropriate cover art for the specified session:
// - If the session has a gamebox with an icon, this will return the gamebox's icon;
// - If the session has a gamebox with no icon, this will generate and return bootleg cover art
//   based on the gamebox's name;
// - If the session is not gamebox-based, this will return nil.
- (NSImage *) coverArtForSession: (BXSession *)session;

//Called whenever the current session or its icon changes.
//This calls iconForSession: with the current session and sets NSApplication's icon to the result.
- (void) syncIconWithActiveSession;
@end