/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <AppKit/AppKit.h>

@class BXSession;
@class BXJoystickController;
@class BXJoypadController;
@class BXMIDIDeviceMonitor;
@class BXKeyboardEventTap;

/// A base class for application delegates, that centralises functionality that is shared between
/// the standard and standalone app controller subclasses. It is not intended to be instantiated directly.
@interface BXBaseAppController : NSDocumentController <NSApplicationDelegate, NSAlertDelegate>

#pragma mark - Properties

/// The currently-active DOS session. Changes whenever a new session opens.
@property (retain) BXSession *currentSession;

/// An array of open @c BXSession documents.
/// This is equivalent to @c [NSDocumentController documents] filtered to contain just @c BXSession instances.
@property (readonly, nonatomic) NSArray<BXSession*> *sessions;


#pragma mark App-wide controllers

/// Responds to incoming HID controller events from gamepads and joysticks, and dispatches them the current DOS session.
@property (retain, nonatomic) IBOutlet BXJoystickController *joystickController;

/// Responds to incoming JoyPad controller events and dispatches them to the current DOS session.
@property (retain, nonatomic) IBOutlet BXJoypadController *joypadController;

/// Monitors the connected MIDI devices, and scans newly-connected devices to see if they're MT-32 units.
@property (retain, nonatomic) BXMIDIDeviceMonitor *MIDIDeviceMonitor;

/// A general operation queue for non-session-specific operations.
@property (retain, readonly) NSOperationQueue *generalQueue;


#pragma mark Application volume settings

/// Whether emulated audio is muted. Persisted across all sessions in user defaults.
@property (assign, nonatomic) BOOL muted;

/// The master volume for emulated audio. Persisted across all sessions in user defaults.
@property (assign, nonatomic) float masterVolume; 

/// The master volume as it will affect played sounds and appear in volume indicators.
/// Will be 0 while @c muted is YES, regardless of the @c masterVolume currently set.
/// Changing this will change the @c masterVolume and @c muted.
@property (assign, nonatomic) float effectiveVolume;


#pragma mark - Methods

#pragma mark Application metadata

/// A human-readable representation of the application version. This is only used for display to the user.
+ (NSString *) localizedVersion;

/// The internal build number. This is the version number actually used for version comparison checks and the like.
+ (NSString *) buildNumber;

/// The localized name of the application.
+ (NSString *) appName;

/// The bundle identifier of the application.
+ (NSString *) appIdentifier;

/// Whether this is a standalone app bundled with a gamebox.
/// Returns @c NO by default; overridden by @c BXStandaloneAppController.
@property (readonly, getter=isStandaloneGameBundle) BOOL standaloneGameBundle;

/// Whether the app should hide all potential branding.
/// Returns @c NO by default; overridden by @c BXStandaloneAppController.
@property (readonly, getter=isUnbrandedGameBundle) BOOL unbrandedGameBundle;


#pragma mark Application audio

/// Returns whether we should play sounds for UI events. This checks OS X's own user defaults
/// for whether the user has enabled "Play user interface sound effects" in OS X's Sound Preferences.
- (BOOL) shouldPlayUISounds;

/// If UI sounds are enabled, play the sound matching the specified name  at the specified volume.
/// @param soundName    The resource name of the sound effect to play.
/// @param volume       The relative volume at which to play the sound,
///                     where 0.0 is silent and 1.0 is full volume.
- (void) playUISoundWithName: (NSString *)soundName
                    atVolume: (float)volume;

/// If UI sounds are enabled, play the sound matching the specified name  at the specified volume at the specified delay.
/// @param soundName    The resource name of the sound effect to play.
/// @param volume       The relative volume at which to play the sound,
///                     where 0.0 is silent and 1.0 is full volume.
/// @param delay        The delay in seconds before playing the sound.
- (void) playUISoundWithName: (NSString *)soundName
                    atVolume: (float)volume
                  afterDelay: (NSTimeInterval)delay;

/// Toggles mute on/off.
- (IBAction) toggleMuted: (id)sender;

/// Increments the master volume until it reaches maximum. This will also unmute the sound.
- (IBAction) incrementVolume: (id)sender;

/// Decrements the master volume until it reaches minimum. This will also unmute the sound.
- (IBAction) decrementVolume: (id)sender;

/// Sets the volume to its minimum level. This will also unmute the sound.
- (IBAction) minimizeVolume: (id)sender;

/// Sets the volume to its maximum level. This will also unmute the sound.
- (IBAction) maximizeVolume: (id)sender;



#pragma mark Application lifecycle

/// Relaunch the application, restoring its previous state if possible.
/// @note This must be implemented by subclasses: the default implementation will raise a not-implemented exception.
- (IBAction) relaunch: (id)sender;


#pragma mark Misc UI actions

/// Open the specified URLs in Boxer's preferred application(s) for each.
/// @param URLs             An array of URLs to open. Boxer will open each one in Boxer's preferred application,
///                         which will usually be the OS X default application for that filetype.
/// @param launchOptions    The options which NSWorkspace should use when opening the URLs.
/// @see BXFileTypes  @c -bundleIdentifierForApplicationToOpenURL:
- (BOOL) openURLsInPreferredApplications: (NSArray<NSURL*> *)URLs
                                 options: (NSWorkspaceLaunchOptions)launchOptions;

/// Reveal and select the specified URLs in Finder.
/// @param URLs The URLs to reveal in Finder. URLs located in the same folder will be shown in the same Finder window.
- (BOOL) revealURLsInFinder: (NSArray<NSURL*> *)URLs;

/// Open the specified help anchor in Boxer's help.
/// @param anchor   The name of the help anchor to open. This is assumed to be in Boxer's own helpbook.
- (void) showHelpAnchor: (NSString *)anchor;

/// Open the URL contained in the specified @c Info.plist key. Used internally by UI actions.
/// @param infoKey  The Info.plist key containing the URL to open.
- (void) openURLFromKey: (NSString *)infoKey;

/// Open the URL contained in the specified @c Info.plist key, substituting the specified search parameters for its placeholders.
/// @param infoKey  The Info.plist key containing the search URL to open.
///                 This URL is expected to contain a single string substitution placeholder.
/// @param search   The search string to search for. This will be URL-encoded automatically and substituted into the URL.
- (void) searchURLFromKey: (NSString *)infoKey
         withSearchString: (NSString *)search;

/// Open a new email addressed to the email address in a specified @c Info.plist key.
/// @param infoKey  The Info.plist key containing the email address to send to.
/// @param subject  The subject line for the email. This will be encoded automatically.
- (void) sendEmailFromKey: (NSString *)infoKey
              withSubject: (NSString *)subject;

@end


/// Top-level methods for reporting fatal errors to Boxer's error reporting page.
@interface BXBaseAppController (BXErrorReporting)

/// Opens an issue tracker page for a new issue, prefilling with optional issue data.
/// @param title    If provided, the title field of the issue form will be prefilled with this string.
/// @param body     If provided, the content field of the issue form will be prefilled with this string.
- (void) reportIssueWithTitle: (NSString *)title
                         body: (NSString *)body;

/// Opens an issue tracker page prefilled with the details of the specified error.
/// @param error    The error whose details should be prefilled into the issue form.
/// @param session  The session that triggered the error. Details of the session will be included in the issue text.
- (void) reportIssueForError: (NSError *)error
                   inSession: (BXSession *)session;

@end
