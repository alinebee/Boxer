/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBaseAppControllerPrivate.h"
#import "BXValueTransformers.h"
#import "ADBAppKitVersionHelpers.h"

#import "BXBaseAppController+BXHotKeys.h"
#import "BXFileTypes.h"

#import "BXMIDIDeviceMonitor.h"
#import "BXKeyboardEventTap.h"
#import "BXBezelController.h"

#import "BXDOSWindowController.h"
#import "BXInputController.h"
#import "BXDOSWindow.h"

#import "BXSession.h"
#import "BXEmulator.h"
#import "BXEmulatorErrors.h"
#import "NSError+ADBErrorHelpers.h"
#import "NSURL+ADBFilesystemHelpers.h"
#import "NSObject+ADBPerformExtensions.h"

#import "ADBUserNotificationDispatcher.h"

/// The number of increments from minimum volume to full volume.
/// Used by @c -incrementMasterVolume: and @c -decrementMasterVolume:
#define BXMasterVolumeNumIncrements 12.0f

/// The amount by which to increase/decrease the volume when it is incremented/decremented.
/// Used by @c -incrementMasterVolume: and @c -decrementMasterVolume:.
#define BXMasterVolumeIncrement (1.0f / BXMasterVolumeNumIncrements)


#pragma mark - Implementation

@implementation BXBaseAppController

@synthesize currentSession = _currentSession;
@synthesize generalQueue = _generalQueue;
@synthesize joystickController = _joystickController;
@synthesize joypadController = _joypadController;
@synthesize MIDIDeviceMonitor = _MIDIDeviceMonitor;
@synthesize hotkeySuppressionTap = _hotkeySuppressionTap;

@synthesize postTerminationHandler = _postTerminationHandler;
@synthesize activeHotkeyAlert = _activeHotkeyAlert;
@synthesize needsRestartForHotkeyCapture = _needsRestartForHotkeyCapture;


#pragma mark - Helper class methods

+ (NSString *) localizedVersion
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
}

+ (NSString *) buildNumber
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: (NSString *)kCFBundleVersionKey];
}

+ (NSString *) appName
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: (NSString *)kCFBundleNameKey];
}

+ (NSString *) appIdentifier
{
    return [NSBundle mainBundle].bundleIdentifier;
}

- (BOOL) isStandaloneGameBundle
{
    return NO;
}

- (BOOL) isUnbrandedGameBundle
{
    return NO;
}

#pragma mark -
#pragma mark Initialization and teardown

+ (void) initialize
{
    if (self == [BXBaseAppController class])
    {
        //Create common value transformers
        [self prepareUserDefaults];
        [self prepareValueTransformers];
    }
}

+ (void) prepareUserDefaults
{
    //We carry a plist of initial values for application preferences
    NSString *defaultsPath	= [[NSBundle mainBundle] pathForResource: @"UserDefaults" ofType: @"plist"];
    NSDictionary *defaults	= [NSDictionary dictionaryWithContentsOfFile: defaultsPath];
    
    [[NSUserDefaults standardUserDefaults] registerDefaults: defaults];
    
}

+ (void) prepareValueTransformers
{
    NSValueTransformer *isEmpty		= [[BXArraySizeTransformer alloc] initWithMinSize: 0 maxSize: 0];
    NSValueTransformer *isNotEmpty	= [[BXArraySizeTransformer alloc] initWithMinSize: 1 maxSize: NSIntegerMax];
    NSValueTransformer *capitalizer	= [[BXCapitalizer alloc] init];
    
    BXIconifiedDisplayPathTransformer *pathTransformer = [[BXIconifiedDisplayPathTransformer alloc]
                                                          initWithJoiner: @" ▸ " maxComponents: 0];
    pathTransformer.missingFileIcon = [NSImage imageNamed: @"gamefolder"];
    pathTransformer.hidesSystemRoots = YES;
    
    NSMutableParagraphStyle *pathStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    pathStyle.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [pathTransformer.textAttributes setObject: pathStyle
                                       forKey: NSParagraphStyleAttributeName];
    [pathStyle release];
    
    [NSValueTransformer setValueTransformer: isEmpty forName: @"BXArrayIsEmpty"];
    [NSValueTransformer setValueTransformer: isNotEmpty forName: @"BXArrayIsNotEmpty"];	
    [NSValueTransformer setValueTransformer: capitalizer forName: @"BXCapitalizedString"];	
    [NSValueTransformer setValueTransformer: pathTransformer forName: @"BXIconifiedGamesFolderPath"];
    
    [isEmpty release];
    [isNotEmpty release];
    [capitalizer release];
    [pathTransformer release];
}

- (id) init
{
	if ((self = [super init]))
	{
		self.generalQueue = [[[NSOperationQueue alloc] init] autorelease];
		[self registerApplicationModeObservers];
	}
	return self;
}

- (void) dealloc
{
	//Remove any notification observers we've registered
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
    self.currentSession = nil;
    self.joystickController = nil;
    self.joypadController = nil;
    self.MIDIDeviceMonitor = nil;
    self.hotkeySuppressionTap = nil;
    self.generalQueue = nil;
    
    self.postTerminationHandler = nil;
    self.activeHotkeyAlert = nil;
	
	[super dealloc];
}


#pragma mark - Application lifecycle

- (void) applicationWillFinishLaunching: (NSNotification *)notification
{
    //Set up our keyboard event tap
    [self prepareHotkeyTap];

    //Start scanning for MIDI devices now
    self.MIDIDeviceMonitor = [[[BXMIDIDeviceMonitor alloc] init] autorelease];
    [self.MIDIDeviceMonitor start];
}

- (void) closeAllDocumentsWithDelegate: (id)delegate
                   didCloseAllSelector: (SEL)didCloseAllSelector
                           contextInfo: (void *)contextInfo
{
    id __block blockSelf = self;
    
    void (^closeHandler)(BOOL) = [^(BOOL didCloseAll) {
        [delegate performSelector: didCloseAllSelector withValues: &blockSelf, &didCloseAll, &contextInfo];
    } copy];
    
    [super closeAllDocumentsWithDelegate: self
                     didCloseAllSelector: @selector(documentController:didCloseAll:contextInfo:)
                             contextInfo: closeHandler];
}

- (void) documentController: (NSDocumentController *)docController
                didCloseAll: (BOOL)didCloseAll
                contextInfo: (void (^)(BOOL))handler
{
    //If the user refused to close one or more documents, clear any post-termination callback we had lined up.
    if (!didCloseAll)
        self.postTerminationHandler = nil;
    
    handler(didCloseAll);
    [handler release];
}

- (void) applicationWillTerminate: (NSNotification *)notification
{
	//Disable our hotkey suppression
    [self.hotkeySuppressionTap unbind: @"enabled"];
    self.hotkeySuppressionTap.enabled = NO;
    
    //Tell the MIDI device scanner to stop
    [self.MIDIDeviceMonitor cancel];
    
    //Tell any remaining documents to close on exit so they can clean up properly and save their state.
	//(NSDocumentController doesn't always do this itself.)
	for (id document in [NSArray arrayWithArray: self.documents])
        [document close];
	
	//Save our preferences to disk before exiting
	[[NSUserDefaults standardUserDefaults] synchronize];
    
	//Tell any operations in our queue to cancel themselves,
    //and let them finish in case they're performing critical operations
	[self.generalQueue cancelAllOperations];
	[self.generalQueue waitUntilAllOperationsAreFinished];
    
    //Remove any lingering notifications that were created by the app.
    [[ADBUserNotificationDispatcher dispatcher] removeAllNotifications];
    
    //Finally, run any post-termination block we've been given.
    if (self.postTerminationHandler)
    {
        self.postTerminationHandler();
        self.postTerminationHandler = nil;
    }
}

- (void) terminateWithHandler: (void (^)())postTerminationHandler
{
    self.postTerminationHandler = postTerminationHandler;
    
    //IMPLEMENTATION NOTE: terminate: will first ask the document controller (i.e. us) to close all documents
    //and will cancel termination if the user cancels from closing any document.
    //- If the user allows all documents to be closed, we'll call the post-termination handler
    //  in applicationWillTerminate:.
    //- If the user cancels from closing all documents, then we clear the post-termination handler
    //  so that it won't be accidentally used if the user later tries to quit normally.
    //  This is done in -documentController:didCloseAll:contextInfo:.
    [NSApp terminate: self];
}

- (IBAction) relaunch: (id)sender
{
    [self doesNotRecognizeSelector: _cmd];
}


#pragma mark - Responding to application mode changes

- (void) registerApplicationModeObservers
{
	//Listen out for UI notifications so that we can coordinate window behaviour
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	
	[center addObserver: self selector: @selector(sessionWillEnterFullScreenMode:)
				   name: BXSessionWillEnterFullScreenNotification
				 object: nil];
    
	[center addObserver: self selector: @selector(sessionDidEnterFullScreenMode:)
				   name: BXSessionDidEnterFullScreenNotification
				 object: nil];
	
	[center addObserver: self selector: @selector(sessionWillExitFullScreenMode:)
				   name: BXSessionWillExitFullScreenNotification
				 object: nil];
    
	[center addObserver: self selector: @selector(sessionDidExitFullScreenMode:)
				   name: BXSessionDidExitFullScreenNotification
				 object: nil];
	
	[center addObserver: self selector: @selector(sessionDidLockMouse:)
				   name: BXSessionDidLockMouseNotification
				 object: nil];
	
	[center addObserver: self selector: @selector(sessionDidUnlockMouse:)
				   name: BXSessionDidUnlockMouseNotification
				 object: nil];
}

- (void) syncApplicationPresentationMode
{
    BOOL suppressProcessSwitching = [[NSUserDefaults standardUserDefaults] boolForKey: @"suppressProcessSwitching"];
    
    BXDOSWindowController *currentController = self.currentSession.DOSWindowController;
    
    NSApplicationPresentationOptions currentOptions = [NSApp presentationOptions], newOptions = currentOptions;
    
    //On SL, we need to manage the fullscreen application state ourselves.
    if (isRunningOnSnowLeopard())
    {
        if ([NSApp isActive] && [(BXDOSWindow *)currentController.window isFullScreen])
        {
            if (currentController.inputController.mouseLocked)
            {
                //When the session is fullscreen and mouse-locked, hide all UI components completely.
                newOptions |= NSApplicationPresentationHideDock | NSApplicationPresentationHideMenuBar | NSApplicationPresentationFullScreen;
                newOptions &= ~(NSApplicationPresentationAutoHideDock | NSApplicationPresentationAutoHideMenuBar);
            }
            else
            {
                //When the session is fullscreen but the mouse is unlocked,
                //show the OS X menu but hide the Dock until it is moused over
                newOptions |= NSApplicationPresentationAutoHideDock | NSApplicationPresentationFullScreen;
                newOptions &= ~(NSApplicationPresentationHideDock | NSApplicationPresentationHideMenuBar | NSApplicationPresentationAutoHideMenuBar);
            }
        }
        else
        {
            //When there is no fullscreen session, show all UI components normally.
            newOptions = NSApplicationPresentationDefault;
        }
    }
    
    //Disable process-switching while the mouse is locked, and enable it again when unlocked.
    if (suppressProcessSwitching && [NSApp isActive] && currentController.inputController.mouseLocked)
    {
        newOptions |= NSApplicationPresentationDisableProcessSwitching;
        
        //The disable process-switching flag requires that the dock be hidden also For Some Reason.
        if (!(newOptions & NSApplicationPresentationAutoHideDock) && !(newOptions & NSApplicationPresentationHideDock))
            newOptions |= NSApplicationPresentationAutoHideDock;
    }
    else
    {
        newOptions &= ~NSApplicationPresentationDisableProcessSwitching;
        
        //We want to unset any auto-hiding we did upstream, but only if we're not in fullscreen and don't have the menu-bar hidden
        //(as these options insist on the dock remaining auto-hidden and will trigger an assertion if they're included.)
        if (!(newOptions & NSApplicationPresentationAutoHideMenuBar) && !(newOptions & NSApplicationPresentationFullScreen))
            newOptions &= ~NSApplicationPresentationAutoHideDock;
    }
    
    if (newOptions != currentOptions)
    {
        @try
        {
            [NSApp setPresentationOptions: newOptions];
        }
        @catch (NSException *exception)
        {
            if ([exception.name isEqualToString: NSInvalidArgumentException])
            {
                NSLog(@"Incompatible presentation options: %@", exception);
            }
            else
            {
                @throw exception;
            }
        }
    }
}

- (void) sessionDidUnlockMouse: (NSNotification *)notification
{
	[self syncApplicationPresentationMode];
}

- (void) sessionDidLockMouse: (NSNotification *)notification
{
	[self syncApplicationPresentationMode];
}

- (void) sessionWillEnterFullScreenMode: (NSNotification *)notification
{
	[self syncApplicationPresentationMode];
}

- (void) sessionDidEnterFullScreenMode: (NSNotification *)notification
{
    [[BXBezelController controller] showFullscreenBezel];
}

- (void) sessionWillExitFullScreenMode: (NSNotification *)notification
{
    //Hide the fullscreen notification if it's still visible
    BXBezelController *bezel = [BXBezelController controller];
    if (bezel.currentBezel == bezel.fullscreenBezel)
        [bezel.window orderOut: self];
}

- (void) sessionDidExitFullScreenMode: (NSNotification *)notification
{
	[self syncApplicationPresentationMode];
}

- (void) applicationDidResignActive: (NSNotification *)notification
{
    [self syncApplicationPresentationMode];
}

- (void) applicationDidBecomeActive: (NSNotification *)notification
{
    [self syncApplicationPresentationMode];
    [self checkHotkeyCaptureAvailability];
}


#pragma mark -
#pragma mark Document management

- (NSArray *) sessions
{
	NSMutableArray *sessions = [NSMutableArray arrayWithCapacity: 1];
	for (id document in self.documents)
	{
		if ([document isKindOfClass: [BXSession class]])
            [sessions addObject: document];
	}
	return sessions;
}

//Store the specified document as the current session
- (void) addDocument: (NSDocument *)theDocument
{
	[super addDocument: theDocument];
	if ([theDocument isKindOfClass: [BXSession class]])
	{
		[self setCurrentSession: (BXSession *)theDocument];
	}
}

- (void) removeDocument: (NSDocument *)theDocument
{	
	//Do whatever we were going to do originally
	[super removeDocument: theDocument];
	
	//Clear the current session
	if (self.currentSession == theDocument) self.currentSession = nil;
}


#pragma mark -
#pragma mark Misc UI actions

- (BOOL) alertShowHelp: (NSAlert *)alert
{
    NSString *helpAnchor = alert.helpAnchor;
    if (helpAnchor)
    {
        [self showHelpAnchor: helpAnchor];
        return YES;
    }
    else
    {
        return NO;
    }
}

- (void) showHelpAnchor: (NSString *)anchor
{
	NSString *bookID = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
	[[NSHelpManager sharedHelpManager] openHelpAnchor: anchor inBook: bookID];
}

- (void) openURLFromKey: (NSString *)infoKey
{
	NSString *URLString = [[NSBundle mainBundle] objectForInfoDictionaryKey: infoKey];
    NSAssert(URLString.length, @"No URL found in Info.plist for key %@", infoKey);
    
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: URLString]];
}

- (void) searchURLFromKey: (NSString *)infoKey withSearchString: (NSString *)search
{
	NSString *siteString = [[NSBundle mainBundle] objectForInfoDictionaryKey: infoKey];
    NSAssert(siteString.length, @"No search URL found in Info.plist for key %@", infoKey);
    
    NSString *encodedSearch = [search stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
    NSString *URLString		= [NSString stringWithFormat: siteString, encodedSearch];
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: URLString]];
}

- (void) sendEmailFromKey: (NSString *)infoKey withSubject:(NSString *)subject
{
	NSString *address = [[NSBundle mainBundle] objectForInfoDictionaryKey: infoKey];
    NSAssert(address.length, @"No email address found in Info.plist for key %@", infoKey);
	if (address.length)
	{
		NSString *encodedSubject	= [subject stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
		NSString *mailtoURLString	= [NSString stringWithFormat: @"mailto:%@?subject=%@", address, encodedSubject];
		[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: mailtoURLString]];
	}
}

- (BOOL) openURLsInPreferredApplications: (NSArray *)URLs
                                 options: (NSWorkspaceLaunchOptions)launchOptions
{
    BOOL openedAnyFiles = NO;
    
    //Go through each URL working out if we want to override the application for any of them.
    //We then group URLs by app so that we can open them all at once with that application
    //(which is tidier and allows e.g. Preview to group the opened documents intelligently).
    NSMutableDictionary *appIdentifiersAndURLs = [[NSMutableDictionary alloc] initWithCapacity: 1];
    
    for (NSURL *URL in URLs)
    {
        id preferredIdentifier = [BXFileTypes bundleIdentifierForApplicationToOpenURL: URL];
        
        //If we'll be opening this URL with the system's default app, group it with other such URLs
        //under a null identifier so we know to use the default handler later.
        if (preferredIdentifier == nil)
            preferredIdentifier = [NSNull null];
        
        NSMutableArray *URLsForApp = [appIdentifiersAndURLs objectForKey: preferredIdentifier];
        if (!URLsForApp)
        {
            URLsForApp = [NSMutableArray arrayWithObject: URL];
            [appIdentifiersAndURLs setObject: URLsForApp forKey: preferredIdentifier];
        }
        else
        {
            [URLsForApp addObject: URL];
        }
    }
    
    //Now that we've grouped all the URLs by the app we want to open them in, go ahead and do the opening
    for (NSString *appIdentifier in appIdentifiersAndURLs)
    {
        NSArray *URLsForApp = [appIdentifiersAndURLs objectForKey: appIdentifier];
        
        //The null identifier is special
        if ([appIdentifier isEqual: [NSNull null]])
            appIdentifier = nil;
        
        BOOL succeeded = [[NSWorkspace sharedWorkspace] openURLs: URLsForApp
                                         withAppBundleIdentifier: appIdentifier
                                                         options: launchOptions
                                  additionalEventParamDescriptor: nil
                                               launchIdentifiers: NULL];
        
        if (succeeded)
            openedAnyFiles = YES;
    }
    
    [appIdentifiersAndURLs release];
    
    return openedAnyFiles;
}

- (BOOL) revealURLsInFinder: (NSArray *)URLs
{
    BOOL revealedAnyFiles = NO;
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    
    //IMPLEMENTATION NOTE: NSWorkspace's activateFileViewerSelectingURLs:
    //refuses to open a window for files that are located *in the root directory
    //of a package*, even though it does properly handle files located deeper within
    //the package. We solve this in two ways:
    //1. If the file in question is a directory, we grab the first file we can find
    //   inside the directory and select that instead.
    //2. If it's not a directory or it's empty, we reveal that URL using NSWorkspace's
    //   older selectFile:inFileViewerRootedAtPath: method instead: this does a better
    //   job with files inside packages, but only takes a single path at a time.
    NSMutableArray *safeURLs = [NSMutableArray arrayWithCapacity: URLs.count];
    for (NSURL *URL in URLs)
    {
        if ([URL checkResourceIsReachableAndReturnError: NULL])
        {
            NSURL *parentURL = [URL URLByDeletingLastPathComponent];
            BOOL parentIsPackage = [[parentURL resourceValueForKey: NSURLIsPackageKey] boolValue];
            if (parentIsPackage)
            {
                if (URL.isDirectory)
                {
                    NSDirectoryEnumerationOptions options = NSDirectoryEnumerationSkipsHiddenFiles | NSDirectoryEnumerationSkipsSubdirectoryDescendants;
                    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL: URL
                                                                             includingPropertiesForKeys: nil
                                                                                                options: options
                                                                                           errorHandler: NULL];
                    
                    NSURL *childURL = enumerator.nextObject;
                    if (childURL)
                    {
                        [safeURLs addObject: childURL];
                        continue;
                    }
                }
                
                revealedAnyFiles = [ws selectFile: URL.path inFileViewerRootedAtPath: parentURL.path] || revealedAnyFiles;
            }
            else
            {
                [safeURLs addObject: URL];
                revealedAnyFiles = YES;
            }
        }
    }
    
    if (safeURLs.count)
        [ws activateFileViewerSelectingURLs: safeURLs];
    
    return revealedAnyFiles;
}


#pragma mark - Managing application audio

//We retrieve OS X's own UI sound setting from their domain
//(hoping this is future-proof - if we can't find it though, we assume it's yes)
- (BOOL) shouldPlayUISounds
{
	NSString *systemSoundDomain	= @"com.apple.systemsound";
	NSString *systemUISoundsKey	= @"com.apple.sound.uiaudio.enabled";
	NSUserDefaults *defaults	= [NSUserDefaults standardUserDefaults];
	[defaults addSuiteNamed: systemSoundDomain];
	
	return ([defaults objectForKey: systemUISoundsKey] == nil || [defaults boolForKey: systemUISoundsKey]);
}

//If UI sounds are enabled, play the sound matching the specified name at the specified volume
- (void) playUISoundWithName: (NSString *)soundName atVolume: (float)volume afterDelay: (NSTimeInterval)delay
{
	if ([self shouldPlayUISounds])
	{
		NSSound *theSound = [NSSound soundNamed: soundName];
		[theSound setVolume: (volume * self.effectiveVolume)];
        
        if (delay > 0)
        {
            [theSound performSelector: @selector(play) withObject: nil afterDelay: delay];
        }
        else
        {
            [theSound play];
        }
	}
}

- (void) playUISoundWithName: (NSString *)soundName atVolume: (float)volume
{
    [self playUISoundWithName: soundName
                     atVolume: volume
                   afterDelay: 0];
}

- (BOOL) muted
{
    return [[NSUserDefaults standardUserDefaults] boolForKey: @"muted"];
}

- (void) setMuted: (BOOL)muted
{
    [[NSUserDefaults standardUserDefaults] setBool: muted forKey: @"muted"];
}

- (float) masterVolume
{
    return [[NSUserDefaults standardUserDefaults] floatForKey: @"masterVolume"];
}

- (void) setMasterVolume: (float)volume
{
    volume = MAX(0.0f, volume);
    volume = MIN(volume, 1.0f);
    [[NSUserDefaults standardUserDefaults] setFloat: volume forKey: @"masterVolume"];
}

+ (NSSet *) keyPathsForValuesAffectingEffectiveVolume
{
    return [NSSet setWithObjects: @"muted", @"masterVolume", nil];
}

- (float) effectiveVolume
{
    if (self.muted) return 0.0f;
    else return self.masterVolume;
}

- (void) setEffectiveVolume: (float)volume
{
    volume = MAX(0.0f, volume);
    volume = MIN(volume, 1.0f);
    
    //Mute/unmute the volume at the same time as setting it, when modifying it from here. 
    self.muted = (volume == 0);
    self.masterVolume = volume;
}

- (IBAction) toggleMuted: (id)sender
{
    self.muted = !self.muted;
    [[BXBezelController controller] showVolumeBezelForVolume: self.effectiveVolume];
}

- (IBAction) minimizeVolume: (id)sender
{
    self.effectiveVolume = 0.0f;
    [[BXBezelController controller] showVolumeBezelForVolume: self.effectiveVolume];
}

- (IBAction) maximizeVolume: (id)sender
{
    self.effectiveVolume = 1.0f;
    [[BXBezelController controller] showVolumeBezelForVolume: self.effectiveVolume];
}

- (IBAction) incrementVolume: (id)sender
{
    self.muted = NO;
    if (self.masterVolume < 1.0f)
    {
        //Round the volume to the nearest increment after incrementing.
        float incrementedVolume = self.masterVolume + BXMasterVolumeIncrement;
        self.masterVolume = roundf(incrementedVolume * BXMasterVolumeNumIncrements) / BXMasterVolumeNumIncrements;
    }
    [[BXBezelController controller] showVolumeBezelForVolume: self.effectiveVolume];
}

- (IBAction) decrementVolume: (id)sender
{
    if (self.masterVolume > 0.0f)
    {
        //Round the volume to the nearest increment after decrementing.
        float decrementedVolume = self.masterVolume - BXMasterVolumeIncrement;
        self.masterVolume = roundf(decrementedVolume * BXMasterVolumeNumIncrements) / BXMasterVolumeNumIncrements;
    }
    self.muted = (self.masterVolume == 0);
    
    [[BXBezelController controller] showVolumeBezelForVolume: self.effectiveVolume];
}

@end


@implementation BXBaseAppController (BXErrorReporting)

- (void) reportIssueWithTitle: (NSString *)title body: (NSString *)body
{
    NSString *issueURLString = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"BugReportURL"];
    NSAssert(issueURLString.length, @"No issue URL found in Info.plist for key %@", @"BugReportURL");
    
    if (issueURLString.length)
    {
        NSString *encodedTitle  = (title) ? [title stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding] : @"";
        NSString *encodedBody   = (body) ? [body stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding] : @"";
        
        NSString *completeURLString = [NSString stringWithFormat: @"%@?title=%@&body=%@", issueURLString, encodedTitle, encodedBody];
		[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: completeURLString]];
    }
}

- (void) reportIssueForError: (NSError *)error
                   inSession: (BXSession *)session
{
    if ([error matchesDomain: BXEmulatorErrorDomain code: BXEmulatorUnrecoverableError])
    {
        NSString *sessionName = session.displayName;
        
        NSString *issueTitle;
        if (sessionName)
        {
            NSString *issueTitleFormat = NSLocalizedString(@"Unrecoverable emulation error when running %@",
                                                           @"Title of issue when reporting an unrecoverable emulator error. %@ is the name of the gamebox (or current program, if unavailable.)");
            
            issueTitle = [NSString stringWithFormat: issueTitleFormat, sessionName];
        }
        else
        {
            issueTitle = NSLocalizedString(@"Unrecoverable emulation error at MS-DOS prompt",
                                           @"Title of issue when reporting an unrecoverable emulator error that occurred at the DOS prompt.");
        }
        
        //TODO: the one really useful thing we're missing here is a record of running time.
        NSException *exception  = [error.userInfo objectForKey: @"exception"];
        NSString *function      = [exception.userInfo objectForKey: @"function"];
        NSNumber *lineNumber    = [exception.userInfo objectForKey: @"line"];
        
        NSMutableString *issueBody = [NSMutableString stringWithString: @"*Please add a description here of what you were doing (or what the game was doing) when this error occurred.*\n\n\n\n"];
        
        //----
        [issueBody appendString: @"## Error details ##\n\n"];
        [issueBody appendFormat: @"**Error message:** %@\n", exception.reason];
        
        if (function)
        {
            [issueBody appendFormat: @"**In function:** `%@` (line %@)\n", function, lineNumber];
        }
        
        [issueBody appendString: @"**Full stack trace:**\n\n"];
        for (NSDictionary *description in exception.callStackDescriptions)
        {
            NSString *libraryName   = [description objectForKey: ADBCallstackLibraryName];
            NSString *funcName      = [description objectForKey: ADBCallstackHumanReadableFunctionName];
            NSNumber *offset        = [description objectForKey: ADBCallstackSymbolOffset];
            
            [issueBody appendFormat: @"    %@ -- %@ (%@)\n", libraryName, funcName, offset];
        }
        
        //----
        
        if (session.fileURL || session.emulator.runningProcesses.count)
        {
            [issueBody appendString: @"\n\n## Game details ##\n\n"];
            
            if (session.fileURL)
            {
                [issueBody appendFormat: @"**Session path:** %@\n", session.fileURL.path];
            }
            
            if (session.emulator.runningProcesses.count)
            {
                [issueBody appendString: @"**DOSBox processes:**\n\n"];
                for (NSDictionary *processInfo in session.emulator.runningProcesses)
                {
                    NSString *dosPath = [processInfo objectForKey: BXEmulatorDOSPathKey];
                    NSString *args = [processInfo objectForKey: BXEmulatorLaunchArgumentsKey];
                    if (!args) args = @"";
                    [issueBody appendFormat: @"    %@ %@\n", dosPath, args];
                }
            }
        }
        
        [(BXBaseAppController *)[NSApp delegate] reportIssueWithTitle: issueTitle body: issueBody];
    }
    //We don't yet have suitable formulations for other kinds of errors, so just open the issue page blank.
    else
    {
        [(BXBaseAppController *)[NSApp delegate] reportIssueWithTitle: nil body: nil];
    }
}
@end