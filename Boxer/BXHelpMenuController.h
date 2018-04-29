/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

@class BXSession;

/// \c BXHelpMenuController manages the Boxer Help menu and its actions. When a DOS session is active,
/// it populates the help menu with documentation files found within the session's gamebox (if any)
/// and links to look up the game on Mobygames or Replacementdocs.
/// This controller is instantiated in MainMenu.xib.
@interface BXHelpMenuController : NSObject
@property (strong, nonatomic) IBOutlet NSMenuItem *mobygamesItem;
@property (strong, nonatomic) IBOutlet NSMenuItem *replacementDocsItem;
@property (strong, nonatomic) IBOutlet NSMenuItem *helpLinksDivider;
@property (strong, nonatomic) IBOutlet NSMenuItem *documentationDivider;

/// The array of sort descriptors we use to order documentation in the doc list.
/// These are ordered by extension and then by filename.
+ (NSArray<NSSortDescriptor*> *) documentationSortCriteria;

/// Returns the localised display strings used to label the "Find [current game] on Mobygames"
/// and "Find [current game] on ReplacementDocs" menu items.
+ (NSString *) mobygamesMenuTitleForSession: (BXSession *)session;
+ (NSString *) replacementDocsMenuTitleForSession: (BXSession *)session;

/// Displays Boxer's main help. Currently this opens the Boxer online User Guide in the default browser. 
- (IBAction) showHelp: (id)sender;

/// Opens a search for the current game on the Mobygames/ReplacementDocs website in the default browser.
/// If no game can be determined for the active session, opens the homepage of the appropriate website.
- (IBAction) showGameAtMobygames: (id)sender;
- (IBAction) showGameAtReplacementDocs: (id)sender;

/// Opens the URL corresponding to the specified menu item.
- (IBAction) openLinkFromMenuItem: (NSMenuItem *)sender;
- (IBAction) openDocumentFromMenuItem: (NSMenuItem *)sender;

@end
