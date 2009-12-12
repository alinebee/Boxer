/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXHelpMenuController manages the Boxer Help menu and its actions. When a DOS session is active,
//it populates the help menu with documentation files found within the session's gamebox (if any)
//and links to look up the game on Mobygames or Replacementdocs.
//This controller is instantiated in MainMenu.xib.

#import <Cocoa/Cocoa.h>

@class BXSession;

@interface BXHelpMenuController : NSObject
{
	BOOL populated;
	NSArray *documentation;
	BXSession *docSession;
	IBOutlet NSMenuItem *mobygamesItem;
	IBOutlet NSMenuItem *replacementDocsItem;
}
//File paths of documentation in the active session's gamebox, sorted by filetype and then alphabetically.
@property (retain) NSArray *documentation;

//Returns the localised display strings used to label the "Find [current game] on Mobygames"
//and "Find [current game] on ReplacementDocs" menu items.
- (NSString *)mobygamesMenuTitle;
- (NSString *)replacementDocsMenuTitle;

//Displays Boxer's main help. Currently this opens the Boxer online User Guide in the default browser. 
- (IBAction) showHelp: (id)sender;

//Opens a search for the current game on the Mobygames/ReplacementDocs website in the default browser.
//If no game can be determined for the active session, opens the homepage of the appropriate website.
- (IBAction) showGameAtMobygames: (id)sender;
- (IBAction) showGameAtReplacementDocs: (id)sender;

//Used internally to populate the help menu with items for the paths in BXHelpMenuController documentaiton.
//While this can be called manually to add to the menu, any such items you add will be deleted when the active
//session changes and the menu is repopulated. So, don't do it.
- (NSMenuItem *) addItemForDocument: (NSDictionary *)docPath toMenu: (NSMenu *)menu;
@end
