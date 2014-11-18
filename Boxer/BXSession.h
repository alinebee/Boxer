/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXSession is an NSDocument subclass which encapsulates a single DOS emulation session.
//It manages an underlying BXEmulator (configuring, starting and stopping it), reads and writes
//the gamebox for the session (if any), and creates the various window controllers for the session.

//BXSession is extended by separate categories that encapsulate different aspects of functionality
//(mostly for controlling the emulator.)

#import <Cocoa/Cocoa.h>
//For suppressing display sleep
#import <IOKit/pwr_mgt/IOPMLib.h>

#import "BXEmulatorDelegate.h"
#import "BXGameProfile.h"
#import "ADBUndoExtensions.h"


#pragma mark - Notifications

//Notifications sent by DOS windows when certain custom UI events occur. The notification object
//in these cases is BXSession and not the window controller, window or view responsible for the UI event.
extern NSString * const BXSessionWillEnterFullScreenNotification;
extern NSString * const BXSessionDidEnterFullScreenNotification;
extern NSString * const BXSessionWillExitFullScreenNotification;
extern NSString * const BXSessionDidExitFullScreenNotification;

extern NSString * const BXSessionDidLockMouseNotification;
extern NSString * const BXSessionDidUnlockMouseNotification;

//Intended to be posted by any part of Boxer that takes over the run loop for a significant time.
//Listened for by BXSession, which will take steps to suspend the emulation and pause audio output.
extern NSString * const BXWillBeginInterruptionNotification;
extern NSString * const BXDidFinishInterruptionNotification;


#pragma mark - Game settings .plist keys

extern NSString * const BXGameboxSettingsKeyFormat;
extern NSString * const BXGameboxSettingsNameKey;
extern NSString * const BXGameboxSettingsProfileKey;
extern NSString * const BXGameboxSettingsProfileVersionKey;
extern NSString * const BXGameboxSettingsLastLocationKey;
extern NSString * const BXGameboxSettingsShowProgramPanelKey;
extern NSString * const BXGameboxSettingsStartUpInFullScreenKey;
extern NSString * const BXGameboxSettingsShowLaunchPanelKey;
extern NSString * const BXGameboxSettingsAlwaysShowLaunchPanelKey;

extern NSString * const BXGameboxSettingsLastProgramPathKey;
extern NSString * const BXGameboxSettingsLastProgramLaunchArgumentsKey;

extern NSString * const BXGameboxSettingsDrivesKey;

//Whether to skip the default/previous program when next launching this gamebox.
//This flag will be cleared on the next startup.
extern NSString * const BXGameboxSettingsShowLaunchPanelKey;

//Used by openURLInDOS: to decide what to do after the requested program exits or the directory has been changed.
typedef NS_ENUM(NSInteger, BXSessionProgramCompletionBehavior) {
    BXSessionProgramCompletionBehaviorDoNothing,    //Do not change the currently displayed view at all.
    BXSessionProgramCompletionBehaviorAuto,         //If the DOS view was visible when the opening the URL, stay at the DOS prompt;
                                                    //Otherwise, show the program launcher.
    BXSessionShowDOSPromptOnCompletion,             //Show the DOS prompt once the operation completes.
    BXSessionShowDOSPromptOnCompletionIfDirectory,  //If the URL was a directory, show it at the DOS prompt;
                                                    //Otherwise, behave like BXSessionProgramCompletionBehaviorAuto.
    BXSessionShowLauncherOnCompletion,              //Show the program launcher panel if available.
    BXSessionCloseOnCompletion,                     //Close the DOS session altogether.
};


#pragma mark - Interface

@class BXEmulator;
@class BXGamebox;
@class BXDOSWindowController;
@class BXPrintStatusPanelController;
@class BXDocumentationPanelController;

@interface BXSession : NSDocument <BXEmulatorDelegate, ADBUndoDelegate>
{	
	BXEmulator *_emulator;
	BXGamebox *_gamebox;
	BXGameProfile *_gameProfile;
	NSMutableDictionary *_gameSettings;
    NSMutableArray *_mutableRecentPrograms;
	
	NSMutableDictionary *_drives;
	NSMutableDictionary *_executableURLs;
    
    NSImage *_cachedIcon;
	
	BXDOSWindowController *_DOSWindowController;
	
	NSURL *_targetURL;
    NSString *_targetArguments;
    
    NSURL *_launchedProgramURL;
    NSString *_launchedProgramArguments;
    
	NSURL *_temporaryFolderURL;
	
	BOOL _hasStarted;
	BOOL _hasConfigured;
	BOOL _hasLaunched;
    BOOL _hasFinishedStartupProcess;
	BOOL _isClosing;
	BOOL _emulating;
	
	BOOL _paused;
	BOOL _autoPaused;
	BOOL _interrupted;
	BOOL _suspended;
    
    BOOL _canOpenURLs;
	
	BOOL _userSkippedDefaultProgram;
    BOOL _waitingForFastForwardRelease;
    
    BXSessionProgramCompletionBehavior _programCompletionBehavior;
	
	NSOperationQueue *_importQueue;
    NSOperationQueue *_scanQueue;
    
    IOPMAssertionID _displaySleepAssertionID;
    
    //Used by BXAudioControls
    NSMutableSet *_MT32MessagesReceived;
    
    BXPrintStatusPanelController *_printStatusController;
    
    BXDocumentationPanelController *_documentationPanelController;
}


#pragma mark - Properties

//The main window controller, responsible for the BXDOSWindow that displays this session.
@property (retain, nonatomic) BXDOSWindowController *DOSWindowController;

//The underlying emulator process for this session. This is created during [BXSession start].
@property (retain, nonatomic) BXEmulator *emulator;

//The print status window, displayed as a sheet while printing is in progress.
@property (retain, nonatomic) BXPrintStatusPanelController *printStatusController;

//The documentation browser, displayed either as a panel or a popover.
@property (retain, nonatomic) BXDocumentationPanelController *documentationPanelController;

//The gamebox for this session. BXSession retrieves bundled drives, configuration files and
//target program from this during emulator configuration.
//Will be nil if an executable file or folder was opened outside of a gamebox.
@property (retain, nonatomic) BXGamebox *gamebox;

//The autodetected game profile for this session. Used for various emulator configuration tasks.
@property (retain, nonatomic) BXGameProfile *gameProfile;

//A general store of configuration settings for this session.
//These are retrieved and stored in the user defaults system, keyed to each gamebox
//(the settings for 'regular' sessions are not stored).
@property (readonly, retain, nonatomic) NSMutableDictionary *gameSettings;

//The logical URL of the executable to launch (or folder to switch to) when the emulator starts,
//and any arguments to pass to that executable.
@property (copy, nonatomic) NSURL *targetURL;
@property (copy, nonatomic) NSString *targetArguments;

//The logical URL of the last program that was launched through user interaction (i.e. from the
//launcher panel or from the DOS prompt), along with any arguments it was launched with.
@property (readonly, copy, nonatomic) NSURL *launchedProgramURL;
@property (readonly, copy, nonatomic) NSString *launchedProgramArguments;

//The logical URL of the currently executing DOS program or batch file if one is running,
//or the current directory at the DOS prompt. This will  be nil if Boxer has no idea where it is.
@property (readonly, nonatomic) NSURL *currentURL;

//A lookup table of all mounted and queued drives, organised by drive letter.
@property (readonly, retain, nonatomic) NSDictionary *drives;

//A lookup table of logical URLs to all known executables on mounted drives, organised by drive letter.
@property (readonly, retain, nonatomic) NSDictionary *executableURLs;

//Whether the emulator is initialized and ready to receive instructions.
@property (readonly, assign, getter=isEmulating) BOOL emulating;

//Whether this session is actively running a program. Will be NO if the emulator
//is suspended, at the DOS prompt, or not currently emulating at all.
@property (readonly, assign) BOOL programIsActive;

//Whether this session can be safely closed without losing data.
@property (readonly, nonatomic) BOOL canCloseSafely;

//Whether this session is currently able to open any URLs via openURLInDOS:error:.
//Will only be YES while the session is idling at the DOS prompt.
@property (readonly, assign) BOOL canOpenURLs;

//Whether this session represents a gamebox.
@property (readonly, nonatomic) BOOL hasGamebox;

//Returns NO if this is a standalone game bundle with only a single launcher
//(in which case the launcher panel is redundant) or if this is a gamebox
//(in which case no launcher panel is appropriate.)
@property (readonly, nonatomic) BOOL allowsLauncherPanel;

//Whether this session is a game import. Returns NO by default; overridden by BXImportSession to return YES.
@property (readonly, nonatomic) BOOL isGameImport;

//The display-ready title for the currently-executing DOS process.
//Will be nil if there is currently no process executing.
@property (readonly, nonatomic) NSString *processDisplayName;

//The icon for this DOS session, which corresponds to the icon of the session's gamebox.
@property (copy, nonatomic) NSImage *representedIcon;


//Whether the emulator is currently suspended for any reason.
@property (readonly, nonatomic, getter=isSuspended)     BOOL suspended;
//Whether the emulator is currently suspended because the user has manually paused the emulation.
@property (assign, nonatomic, getter=isPaused)			BOOL paused;
//Whether the emulator is currently suspended because it has been interrupted by UI events.
@property (readonly, nonatomic, getter=isInterrupted)	BOOL interrupted;
//Whether the emulator is currently suspended because Boxer is in the background.
@property (readonly, nonatomic, getter=isAutoPaused)	BOOL autoPaused;


#pragma mark - Helper class methods

+ (BXGameProfile *) profileForGameAtURL: (NSURL *)URL;

//Generates and returns a new bootleg cover-art image for the specified package,
//using the specified game era. If era is BXUnknownEra, a suitable era will be
//autodetected based on the size and age of the game's files.
+ (NSImage *) bootlegCoverArtForGamebox: (BXGamebox *)gamebox
                             withMedium: (BXReleaseMedium)medium;


#pragma mark - Lifecycle control methods

//Start up the DOS emulator.
//This is currently called automatically by showWindow, meaning that emulation starts
//as soon as the session window appears.
- (void) start;

//Restart the DOS emulator. Currently this involves closing and reopening the document,
//which will usually trigger an application restart.
//If showLaunchPanel is YES, the launch panel will be displayed upon restarting; otherwise
//the session will resume with the previously-running program (if any).
- (void) restartShowingLaunchPanel: (BOOL)showLaunchPanel;

//Shut down the DOS emulator.
- (void) cancel;

//Save our document-specific settings to disk. Called when the document is closed and when
//the application is quit.
- (void) synchronizeSettings;


#pragma mark - Recent programs

///Returns an array of dictionaries recording recently launched DOS programs.
@property (readonly, nonatomic) NSArray *recentPrograms;

//Adds a new program to the recent programs list, specified as a dictionary of keys corresponding
//to BXEmulator's process info dictionaries. See BXEmulator.h for available keys.
//Changes to the recent program list will be persisted into the game info for this session,
//if available.
- (void) noteRecentProgram: (NSDictionary *)programDetails;

//Remove the recent program corresponding to the specified program details.
//(This will match on URL and arguments and ignore other fields.)
- (void) removeRecentProgram: (NSDictionary *)programDetails;

//Empty the recent programs list.
- (void) clearRecentPrograms;

@end
