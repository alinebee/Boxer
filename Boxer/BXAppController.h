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


//Not defined in NSApplication until 10.6 (whoopeeeeeee)
#ifndef NSAppKitVersionNumber10_5
#define NSAppKitVersionNumber10_5 949
#endif 


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
	BOOL hasFinishedLaunching;
	
	NSOperationQueue *generalQueue;
}
//The currently-active DOS session. Changes whenever a new session opens.
@property (retain, nonatomic) BXSession *currentSession;

//A general operation queue for non-session-specific operations.
@property (retain, readonly) NSOperationQueue *generalQueue;


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

//Open an import session to import the specified URL.
- (id) openImportSessionWithContentsOfURL: (NSURL *)url
								  display: (BOOL)display
									error: (NSError **)outError;


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
//Display the welcome panel with a flip animation (used only at startup).
- (IBAction) orderFrontWelcomePanelWithFlip: (id)sender;
- (IBAction) orderFrontFirstRunPanel: (id)sender;		//Display the first-run panel.
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


//Reveal the specified path (or its parent folder, in the case of files) in a new Finder window.
//Returns NO if the file at the path did not exist or could not be opened, YES otherwise.
- (BOOL) revealPath: (NSString *)filePath;

//Open the specified URL from the specified Info.plist key. Used internally by UI actions.
- (void) openURLFromKey:(NSString *)infoKey;
//Open the specified search-engine URL from the specified Info.plist key, using the specified search parameters.
- (void) searchURLFromKey: (NSString *)infoKey withSearchString: (NSString *)search;
//Open a new email to the address given by the specified Info.plist key, with the specified subject line.
- (void) sendEmailFromKey:(NSString *)infoKey withSubject: (NSString *)subject;


#pragma mark -
#pragma mark Miscellaneous helpers

//Return the NSWindow located at the specified point.
//TODO: this should probably be an NSApplication category instead.
- (NSWindow *) windowAtPoint: (NSPoint)screenPoint;

//Returns whether is running on 10.5 Leopard.
//This is used to trigger certain bugfixes and adjusts the art we use.
+ (BOOL) isRunningOnLeopard;

@end
