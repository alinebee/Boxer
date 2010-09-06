/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXAppController is Boxer's NSApp delegate and document controller. It controls application launch
//behaviour, shared resources and user defaults, and handles non-window-specific UI functions.
//This controller is instantiated in MainMenu.xib.

#import <Cocoa/Cocoa.h>

@class BXSession;

enum {
	BXStartUpWithNothing		= 0,
	BXStartUpWithWelcomePanel	= 1,
	BXStartUpWithGamesFolder	= 2
};


@interface BXAppController : NSDocumentController
{
	BXSession *currentSession;
	NSString *gamesFolderPath;
}
//The currently-active DOS session. Changes whenever a new session opens.
@property (retain, nonatomic) BXSession *currentSession;

//The path where we store Boxer's games, stored internally as an alias to allow the folder to be moved.
//Will be nil if no path has been chosen or the alias could not be resolved.
@property (copy, nonatomic) NSString *gamesFolderPath;

//The icon of the games folder path. This is used for UIs that need to display the games folder.
@property (readonly, nonatomic) NSImage *gamesFolderIcon;

//The game folder path from 0.8x versions of Boxer (stored as an alias at ~/Library/Preferences/Boxer/Default Folder).
//Will be nil if no path was stored by an older version of Boxer, or if the alias could not be resolved.
@property (readonly, nonatomic) NSString *oldGamesFolderPath;

//The 'emergency' path at which to store new gameboxes, used when the games folder cannot be found
//and we don't have the chance to ask the user for a new one. This is currently set to the user's Desktop.
@property (readonly, nonatomic) NSString *fallbackGamesFolderPath;

//Whether to apply our fancy games-shelf appearance to the games folder each time we open it.
//Setting this to NO will immediately remove all effects from the games folder.
//The value for this property is persisted in user defaults.
@property (assign, nonatomic) BOOL appliesShelfAppearanceToGamesFolder;


//Called at class initialization time to initialize Boxer's own user defaults.
+ (void) setupDefaults;

#pragma mark -
#pragma mark UTIs

+ (NSSet *) executableTypes;		//DOS executable UTIs
+ (NSSet *) hddVolumeTypes;			//UTIs that should be mounted as DOS hard drives
+ (NSSet *) cdVolumeTypes;			//UTIs that should be mounted as DOS CD-ROM drives
+ (NSSet *) floppyVolumeTypes;		//UTIs that should be mounted as DOS floppy drives
+ (NSSet *) mountableFolderTypes;	//All mountable folder UTIs supported by Boxer
+ (NSSet *) mountableImageTypes;	//All mountable disk-image UTIs supported by Boxer
+ (NSSet *) mountableTypes;			//All mountable UTIs supported by Boxer


#pragma mark -
#pragma mark Opening documents

//A special method for creating a new untitled import session.
//Mirrors the behaviour of openUntitledDocumentAndDisplay:error:
- (id) openImportSessionAndDisplay: (BOOL)displayDocument error: (NSError **)outError;


#pragma mark -
#pragma mark Games folder handling

//Apply our custom shelf appearance to the specified path.
//If switchMode is YES, the folder's Finder window will be switched to icon mode.
- (void) applyShelfAppearanceToPath: (NSString *)path switchToShelfMode: (BOOL)switchMode;


#pragma mark -
#pragma mark Managing application audio

//Returns whether we should play sounds for UI events.
//(Currently this is based on OS X's system settings, rather than our own preference.)
- (BOOL) shouldPlayUISounds;

//If UI sounds are enabled, play the sound matching the specified name at the specified volume.
- (void) playUISoundWithName: (NSString *)soundName atVolume: (float)volume;


#pragma mark -
#pragma mark UI actions

- (IBAction) orderFrontWelcomePanel: (id)sender;		//Display the welcome panel.
- (IBAction) hideWelcomePanel: (id)sender;				//Close the welcome panel.
- (IBAction) orderFrontImportGamePanel: (id)sender;		//Display the game import panel.

- (IBAction) orderFrontAboutPanel:	(id)sender;			//Display Boxer's About panel.
- (IBAction) orderFrontPreferencesPanel: (id)sender;	//Display Boxer's preferences panel. 
- (IBAction) toggleInspectorPanel: (id)sender;			//Display/hide Boxer's inspector HUD panel.

//Set/get whether the inspector panel is currently open
- (void) setInspectorPanelShown: (BOOL)show;
- (BOOL) inspectorPanelShown;

//The URLs and email addresses for the following actions are configured in the Info.plist file.

- (IBAction) showWebsite:			(id)sender;	//Open the Boxer website in the default browser. 
- (IBAction) showDonationPage:		(id)sender;	//Open the Boxer donations page in the default browser.
- (IBAction) showPerianDownloadPage:(id)sender;	//Open the Perian website in the default browser.
- (IBAction) sendEmail:				(id)sender;	//Open a new email to Boxer's contact email address.

- (IBAction) revealInFinder: (id)sender;			//Reveal the sender's represented object in a new Finder window.
- (IBAction) openInDefaultApplication: (id)sender;	//Open the sender's represented object with its default app.
- (IBAction) revealGamesFolder: (id)sender;			//Reveal our games folder in Finder.


//Reveal the specified path (or its parent folder, in the case of files) in a new Finder window.
- (void) revealPath: (NSString *)filePath;

//Open the specified URL from the specified Info.plist key. Used internally by UI actions.
- (void) openURLFromKey:(NSString *)infoKey;
//Open the specified search-engine URL from the specified Info.plist key, using the specified search parameters.
- (void) searchURLFromKey: (NSString *)infoKey withSearchString: (NSString *)search;
//Open a new email to the address given by the specified Info.plist key, with the specified subject line.
- (void) sendEmailFromKey:(NSString *)infoKey withSubject: (NSString *)subject;


#pragma mark -
#pragma mark Event-related functions

//Return the NSWindow located at the specified point.
//TODO: this should probably be an NSApplication category instead.
- (NSWindow *) windowAtPoint: (NSPoint)screenPoint;

@end
