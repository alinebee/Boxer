/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXBaseAppController.h"

enum {
	BXStartUpWithNothing		= 0,
	BXStartUpWithWelcomePanel	= 1,
	BXStartUpWithGamesFolder	= 2,
    BXStartUpWithDOSPrompt      = 3
};

@class BXInspectorController;

/// \c BXAppController is Boxer's NSApp delegate and document controller. It controls application launch
/// behaviour, shared resources and user defaults, and handles non-window-specific UI functions.
/// This controller is instantiated in MainMenu.xib.
@interface BXAppController : BXBaseAppController
{
	NSURL *_gamesFolderURL;
}

/// Returns YES if there are other Boxer processes currently running, no otherwise.
+ (BOOL) otherBoxersActive;

/// A reference to the app's shared inspector panel controller, used for UI bindings.
@property (weak, readonly, nonatomic) BXInspectorController *inspectorController;

#pragma mark -
#pragma mark Opening documents

/// A special method for creating a new untitled import session.
/// This follows the same method signature as @c NSDocument @c -openUntitledDocumentAndDisplay:error:.
- (id) openImportSessionAndDisplay: (BOOL)displayDocument error: (NSError **)outError;

/// Opens an import window to import the specified URL.
/// This follows the same method signature as @c NSDocument @c -openDocumentWithContentsOfURL:display:error:.
- (id) openImportSessionWithContentsOfURL: (NSURL *)URL
								  display: (BOOL)display
									error: (NSError **)outError;


#pragma mark - UI actions

/// Relaunches the application, restoring any previous session after relaunching.
- (IBAction) relaunch: (id)sender;

/// Displays the About panel.
- (IBAction) orderFrontAboutPanel: (id)sender;

/// Displays the welcome panel.
- (IBAction) orderFrontWelcomePanel: (id)sender;

/// Display the welcome panel with a spin transition.
/// @note Spin transitions are unsupported on OS X 10.7 and above,
/// and this method will behave identically to @c orderFrontWelcomePanel:.
- (IBAction) orderFrontWelcomePanelWithTransition: (id)sender;

/// Dismisses the welcome panel if it is visible.
- (IBAction) hideWelcomePanel: (id)sender;

/// Displays the game import window.
- (IBAction) orderFrontImportGamePanel: (id)sender;

/// Displays the preferences window.
- (IBAction) orderFrontPreferencesPanel: (id)sender;

/// Displays the session inspector panel.
/// @note Has no effect if no session is active.
- (IBAction) orderFrontInspectorPanel: (id)sender;

/// Shows the inspector panel if it is hidden, or hides the inspector panel if it was visible.
/// @note Has no effect if no session is active.
- (IBAction) toggleInspectorPanel: (id)sender;

/// Displays the session inspector panel and shows the gamebox tab.
/// @note Has no effect if no session is active.
- (IBAction) showGamePanel:		(id)sender;

/// Displays the session inspector panel and shows the CPU tab.
/// @note Has no effect if no session is active.
- (IBAction) showCPUPanel:		(id)sender;

/// Displays the session inspector panel and shows the Drives tab.
/// @note Has no effect if no session is active.
- (IBAction) showDrivesPanel:	(id)sender;

/// Displays the session inspector panel and shows the Mouse tab.
/// @note Has no effect if no session is active.
- (IBAction) showMousePanel:	(id)sender;

//Display the add-a-new-drive panel for the current session.
- (IBAction) showMountPanel: (id)sender;


/// Opens the Boxer website in the default browser.
- (IBAction) showWebsite:			(id)sender;

/// Opens Boxer's donations page in the default browser.
- (IBAction) showDonationPage:		(id)sender;

/// Opens the Joypad website in the default browser.
- (IBAction) showJoypadDownloadPage:(id)sender;

/// Opens Boxer's issue tracker in the default browser, ready to create a new issue.
- (IBAction) showBugReportPage:		(id)sender;

/// Opens a new email to Boxer's contact email address in the default email client.
- (IBAction) sendEmail:				(id)sender;

/// Reveals the location of the current session in a new Finder window.
- (IBAction) revealCurrentSession: (id)sender;

@end
