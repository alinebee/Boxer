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

@interface BXAppController : NSDocumentController
{
	NSOperationQueue *emulationQueue;
	BXSession *currentSession;
}
@property (readonly) NSOperationQueue *emulationQueue;	//Currently unused
@property (retain) BXSession *currentSession;			//The currently-active DOS session


//Called at class initialization time to initialize Boxer's own user defaults.
+ (void) setupDefaults;


//UI-related functionality
//------------------------

//Returns whether we should play sounds for UI events.
//(Currently this is based on OS X's system settings, rather than our own preference.)
- (BOOL) shouldPlayUISounds;

//If UI sounds are enabled, play the sound matching the specified name at the specified volume.
- (void) playUISoundWithName: (NSString *)soundName atVolume: (float)volume;


//UI actions
//----------

- (IBAction) orderFrontAboutPanel:	(id)sender;	//Display the Boxer About window.


//The URLs and email addresses for the following actions are configured in the Info.plist file.

- (IBAction) showWebsite:			(id)sender;	//Open the Boxer website in the default browser. 
- (IBAction) showDonationPage:		(id)sender;	//Open the Boxer donations page in the default browser.
- (IBAction) showPerianDownloadPage:(id)sender;	//Open the Perian website in the default browser.
- (IBAction) sendEmail:				(id)sender;	//Open a new email to Boxer's contact email address.

- (IBAction) revealInFinder: (id)sender;			//Reveal the sender's represented object in a new Finder window.
- (IBAction) openInDefaultApplication: (id)sender;	//Open the sender's represented object with its default app.


//Reveal the specified path (or its parent folder, in the case of files) in a new Finder window.
- (void) revealPath: (NSString *)filePath;

//Open the specified URL from the specified Info.plist key. Used internally by UI actions.
- (void) openURLFromKey:(NSString *)infoKey;
//Open the specified search-engine URL from the specified Info.plist key, using the specified search parameters.
- (void) searchURLFromKey: (NSString *)infoKey withSearchString: (NSString *)search;
//Open a new email to the address given by the specified Info.plist key, with the specified subject line.
- (void) sendEmailFromKey:(NSString *)infoKey withSubject: (NSString *)subject;


//Event-related functions
//-----------------------

//Return the NSWindow located at the specified point.
//TODO: this should probably be an NSApplication category instead.
- (NSWindow *) windowAtPoint: (NSPoint)screenPoint;
@end