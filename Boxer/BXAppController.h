/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXAppController is Boxer's NSApp delegate and document controller. It controls application launch
//behaviour, shared resources and user defaults, and handles non-window-specific UI functions.
//This controller is instantiated in MainMenu.xib.

#import <Cocoa/Cocoa.h>



@class BXSession;
@class BXJoystickController;
@class BXJoypadController;
@class BXMIDIDeviceMonitor;
@class BXKeyboardEventTap;

enum {
	BXStartUpWithNothing		= 0,
	BXStartUpWithWelcomePanel	= 1,
	BXStartUpWithGamesFolder	= 2
};


@interface BXAppController : NSDocumentController
{
	BXSession *currentSession;
	NSString *gamesFolderPath;
	BOOL hasSuppressedSpacesShortcuts;
	
	NSOperationQueue *generalQueue;
	
    BXJoystickController *joystickController;
    BXJoypadController *joypadController;
    BXKeyboardEventTap *hotkeySuppressionTap;
	
    BXMIDIDeviceMonitor *MIDIDeviceMonitor;
}

//The currently-active DOS session. Changes whenever a new session opens.
@property (retain) BXSession *currentSession;

//App-wide controllers for HID joystick input and JoyPad app input.
@property (retain, nonatomic) IBOutlet BXJoystickController *joystickController;
@property (retain, nonatomic) IBOutlet BXJoypadController *joypadController;
@property (retain, nonatomic) BXMIDIDeviceMonitor *MIDIDeviceMonitor;
@property (retain, nonatomic) BXKeyboardEventTap *hotkeySuppressionTap;

//A general operation queue for non-session-specific operations.
@property (retain, readonly) NSOperationQueue *generalQueue;

//An array of open BXSession documents.
//This is [NSDocumentController documents] filtered to just BXSession subclasses.
@property (readonly, nonatomic) NSArray *sessions;


//Returns YES if there are other Boxer processes currently running, no otherwise.
+ (BOOL) otherBoxersActive;

//The application version and internal build number
+ (NSString *) localizedVersion;
+ (NSString *) buildNumber;


#pragma mark -
#pragma mark UTIs

+ (NSSet *) executableTypes;		//DOS executable UTIs
+ (NSSet *) hddVolumeTypes;			//UTIs that should be mounted as DOS hard drives
+ (NSSet *) cdVolumeTypes;			//UTIs that should be mounted as DOS CD-ROM drives
+ (NSSet *) floppyVolumeTypes;		//UTIs that should be mounted as DOS floppy drives
+ (NSSet *) mountableFolderTypes;	//All mountable folder UTIs supported by Boxer
+ (NSSet *) mountableImageTypes;	//All mountable disk-image UTIs supported by Boxer
+ (NSSet *) OSXMountableImageTypes; //All disk-image UTIs that OSX's hdiutil can mount
+ (NSSet *) mountableTypes;			//All mountable UTIs supported by Boxer


#pragma mark -
#pragma mark Initialization and teardown

//Called at class initialization time to initialize Boxer's own user defaults.
+ (void) setupDefaults;


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

//Whether emulated audio is muted. Persisted across all sessions in user defaults.
@property (assign, nonatomic) BOOL muted;
//The master volume for emulated audio. Persisted across all sessions in user defaults.
@property (assign, nonatomic) float masterVolume; 

//The master volume as it will affect played sounds and appear in volume indicators.
//Will be 0 while muted, regardless of the master volume currently set.
//Changing this will change the master volume and mute/unmute sound.
@property (assign, nonatomic) float effectiveVolume;

//If UI sounds are enabled, play the sound matching the specified name
//at the specified volume, with the specified optional delay.
- (void) playUISoundWithName: (NSString *)soundName atVolume: (float)volume;
- (void) playUISoundWithName: (NSString *)soundName atVolume: (float)volume afterDelay: (NSTimeInterval)delay;

//Toggle mute on/off.
- (IBAction) toggleMuted: (id)sender;

//Increment/decrement the master volume. These will also unmute the sound.
- (IBAction) incrementVolume: (id)sender;
- (IBAction) decrementVolume: (id)sender;


#pragma mark -
#pragma mark UI actions

- (IBAction) orderFrontWelcomePanel: (id)sender;		//Display the welcome panel.
- (IBAction) orderFrontWelcomePanelWithTransition: (id)sender;
- (IBAction) orderFrontFirstRunPanel: (id)sender;		//Display the first-run panel.
- (IBAction) orderFrontFirstRunPanelWithTransition: (id)sender;

- (IBAction) hideWelcomePanel: (id)sender;				//Close the welcome panel.
- (IBAction) orderFrontImportGamePanel: (id)sender;		//Display the game import panel.

- (IBAction) orderFrontAboutPanel:	(id)sender;			//Display Boxer's About panel.
- (IBAction) orderFrontPreferencesPanel: (id)sender;	//Display Boxer's preferences panel.
- (IBAction) orderFrontInspectorPanel: (id)sender;		//Display Boxer's inspector HUD panel.
- (IBAction) toggleInspectorPanel: (id)sender;			//Display/hide Boxer's inspector HUD panel.

//Display the relevant panels of the Inspector.
- (IBAction) showGamePanel:		(id)sender;
- (IBAction) showCPUPanel:		(id)sender;
- (IBAction) showDrivesPanel:	(id)sender;
- (IBAction) showMousePanel:	(id)sender;

//The URLs and email addresses for the following actions are configured in the Info.plist file.

- (IBAction) showWebsite:			(id)sender;	//Open the Boxer website in the default browser. 
- (IBAction) showDonationPage:		(id)sender;	//Open the Boxer donations page in the default browser.
- (IBAction) showPerianDownloadPage:(id)sender;	//Open the Perian website in the default browser.
- (IBAction) showJoypadDownloadPage:(id)sender;	//Open the Joypad website in the default browser.
- (IBAction) showBugReportPage:		(id)sender;	//Open Boxer's issue reporting page in the default browser. 
- (IBAction) sendEmail:				(id)sender;	//Open a new email to Boxer's contact email address.
- (IBAction) showUniversalAccessPrefsPane: (id)sender; //Open the Universal Access pane in OS X System Preferences.

- (IBAction) revealInFinder: (id)sender;			//Reveal the sender's represented object in a new Finder window.
- (IBAction) openInDefaultApplication: (id)sender;	//Open the sender's represented object with its default app.

//Reveal the path of the current session in a new Finder window.
- (IBAction) revealCurrentSessionPath: (id)sender;

//Reveal the specified path (or its parent folder, in the case of files) in a new Finder window.
//Returns NO if the file at the path did not exist or could not be opened, YES otherwise.
- (BOOL) revealPath: (NSString *)filePath;

//Open the specified help anchor in the Boxer help.
- (void) showHelpAnchor: (NSString *)anchor;

//Open the specified URL from the specified Info.plist key. Used internally by UI actions.
- (void) openURLFromKey:(NSString *)infoKey;
//Open the specified search-engine URL from the specified Info.plist key, using the specified search parameters.
- (void) searchURLFromKey: (NSString *)infoKey withSearchString: (NSString *)search;
//Open a new email to the address given by the specified Info.plist key, with the specified subject line.
- (void) sendEmailFromKey:(NSString *)infoKey withSubject: (NSString *)subject;

@end
