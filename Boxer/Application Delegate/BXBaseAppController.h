/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXBaseAppController centralises functionality shared between the standard and
//standalone app controller subclasses. It is not intended to be instantiated directly.

#import <AppKit/AppKit.h>

@class BXSession;
@class BXJoystickController;
@class BXJoypadController;
@class BXMIDIDeviceMonitor;
@class BXKeyboardEventTap;

@interface BXBaseAppController : NSDocumentController <NSApplicationDelegate>
{
	BXSession *_currentSession;
	NSOperationQueue *_generalQueue;
	
    BXJoystickController *_joystickController;
    BXJoypadController *_joypadController;
    BXKeyboardEventTap *_hotkeySuppressionTap;
	
    BXMIDIDeviceMonitor *_MIDIDeviceMonitor;
    
    BOOL _relaunching;
}

#pragma mark -
#pragma mark Properties

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


//Whether emulated audio is muted. Persisted across all sessions in user defaults.
@property (assign, nonatomic) BOOL muted;
//The master volume for emulated audio. Persisted across all sessions in user defaults.
@property (assign, nonatomic) float masterVolume; 

//The master volume as it will affect played sounds and appear in volume indicators.
//Will be 0 while muted, regardless of the master volume currently set.
//Changing this will change the master volume and mute/unmute sound.
@property (assign, nonatomic) float effectiveVolume;


#pragma mark -
#pragma mark Class helper methods

//The application version, internal build number and application title.
+ (NSString *) localizedVersion;
+ (NSString *) buildNumber;
+ (NSString *) appName;
+ (NSString *) appIdentifier;

//Whether this is a standalone app bundled with a game.
//Returns NO by default; overridden by BXStandaloneAppController.
- (BOOL) isStandaloneGameBundle;

//Whether the app should hide all potential branding.
//Returns NO by default; overridden by BXStandaloneAppController.
- (BOOL) isUnbrandedGameBundle;

#pragma mark -
#pragma mark Initialization

//Load/create the user defaults for the application. Called from +initialize.
+ (void) prepareUserDefaults;

//Create common value transformers used throughout the application. Called from +initialize.
+ (void) prepareValueTransformers;


#pragma mark -
#pragma mark Responding to changes in application mode

//Set the application UI to the appropriate mode for the current session's
//fullscreen and mouse-locked status.
- (void) syncApplicationPresentationMode;

//Register for notifications about the mode changes below.
- (void) registerApplicationModeObservers;

- (void) sessionDidUnlockMouse: (NSNotification *)notification;
- (void) sessionDidLockMouse: (NSNotification *)notification;

- (void) sessionWillEnterFullScreenMode: (NSNotification *)notification;
- (void) sessionDidEnterFullScreenMode: (NSNotification *)notification;
- (void) sessionWillExitFullScreenMode: (NSNotification *)notification;
- (void) sessionDidExitFullScreenMode: (NSNotification *)notification;


#pragma mark -
#pragma mark Managing application audio

//Returns whether we should play sounds for UI events.
//(Currently this is based on OS X's system settings, rather than our own preference.)
- (BOOL) shouldPlayUISounds;

//If UI sounds are enabled, play the sound matching the specified name
//at the specified volume, with the specified optional delay.
- (void) playUISoundWithName: (NSString *)soundName atVolume: (float)volume;
- (void) playUISoundWithName: (NSString *)soundName atVolume: (float)volume afterDelay: (NSTimeInterval)delay;

//Toggle mute on/off.
- (IBAction) toggleMuted: (id)sender;

//Increment/decrement the master volume. These will also unmute the sound.
- (IBAction) incrementVolume: (id)sender;
- (IBAction) decrementVolume: (id)sender;

//Set the volume to minimum/maximum.
- (IBAction) minimizeVolume: (id)sender;
- (IBAction) maximizeVolume: (id)sender;


#pragma mark -
#pragma mark Misc UI actions

//Reveal the sender's represented object in a new Finder window.
- (IBAction) revealInFinder: (id)sender;

//Open the sender's represented object with its default app.
- (IBAction) openInDefaultApplication: (id)sender;

//Open the specified URLs in Boxer's preferred application(s) for each.
- (BOOL) openURLsInPreferredApplications: (NSArray *)URLs
                                 options: (NSWorkspaceLaunchOptions)launchOptions;

//Reveal the specified path (or its parent folder, in the case of files) in a new Finder window.
//Returns NO if the file at the path did not exist or could not be opened, YES otherwise.
- (BOOL) revealPath: (NSString *)filePath;

//Open the specified help anchor in the Boxer help.
- (void) showHelpAnchor: (NSString *)anchor;

//Open the specified URL from the specified Info.plist key. Used internally by UI actions.
- (void) openURLFromKey: (NSString *)infoKey;

//Open the specified search-engine URL from the specified Info.plist key, using the specified search parameters.
- (void) searchURLFromKey: (NSString *)infoKey
         withSearchString: (NSString *)search;

//Open a new email to the address given by the specified Info.plist key, with the specified subject line.
- (void) sendEmailFromKey: (NSString *)infoKey
              withSubject: (NSString *)subject;

@end


@interface BXBaseAppController (BXErrorReporting)

//Opens an issue tracker page for a new issue, prefilling the issue with the specified title and body text (if provided).
- (void) reportIssueWithTitle: (NSString *)title
                         body: (NSString *)body;

//Opens an issue tracker page prefilled with the details of the specified error.
- (void) reportIssueForError: (NSError *)error
                   inSession: (BXSession *)session;

@end