/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXSessionPrivate.h"

#import "BXFileTypes.h"
#import "BXGamebox.h"
#import "BXGameProfile.h"
#import "BXBootlegCoverArt.h"
#import "BXDrive.h"
#import "BXBaseAppController.h"
#import "BXDOSWindow.h"
#import "BXDOSWindowControllerLion.h"
#import "BXPrintStatusPanelController.h"
#import "BXDocumentationPanelController.h"
#import "BXEmulatorConfiguration.h"
#import "BXCloseAlert.h"

#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator+BXShell.h"
#import "BXEmulatorErrors.h"
#import "NSWorkspace+ADBFileTypes.h"
#import "NSString+ADBPaths.h"
#import "NSURL+ADBFilesystemHelpers.h"
#import "NSWorkspace+BXExecutableTypes.h"
#import "BXInputController.h"
#import "NSObject+ADBPerformExtensions.h"
#import "NSKeyedArchiver+ADBArchivingAdditions.h"
#import "ADBUserNotificationDispatcher.h"
#import "NSError+ADBErrorHelpers.h"
#import "NSObject+ADBPerformExtensions.h"
#import "ADBFilesystem.h"

#import "ADBAppKitVersionHelpers.h"


#pragma mark -
#pragma mark Constants


//The length of time in seconds after which we assume that if the program was
//Windows-only, it would have failed by now. If a program exits before this time,
//then we check if it's a Windows-only program and warn the user if so.
#define BXWindowsOnlyProgramFailTimeThreshold 0.2

//The length of time in seconds after which we count a program as having run successfully,
//and allow it to auto-quit. If a program exits before this time, we count it as
//a probable startup crash and leave the user at the DOS prompt to diagnose it.
#define BXSuccessfulProgramRunningTimeThreshold 3

//How soon after the program starts to enter fullscreen, if the run-programs-in-fullscreen toggle
//is enabled. The delay gives the program time to crash and our program panel time to hide.
#define BXAutoSwitchToFullScreenDelay 0.5

//If a program is launched during the startup process, wait this many seconds before switching to the DOS view.
//If the program terminates in that time, the switch is cancelled. This lets us keep the loading panel
//visible while startup programs are executing, while still switching to DOS when a proper program starts up.
#define BXSwitchToDOSViewDelay 0.5

//How soon after returning to the DOS prompt to display the launch panel.
//This delay is intended to give the player enough time to see any quit message.
#define BXSwitchToLaunchPanelDelay 0.5


//How many recently-launched programs the session should track before it discards older ones.
#define BXRecentProgramsLimit 10

#pragma mark -
#pragma mark Gamebox settings keys

//How we will store our gamebox-specific settings in user defaults.
//%@ is the unique identifier for the gamebox.
NSString * const BXGameboxSettingsKeyFormat     = @"BXGameSettings: %@";
NSString * const BXGameboxSettingsNameKey       = @"BXGameName";
NSString * const BXGameboxSettingsProfileKey    = @"BXGameProfile";
NSString * const BXGameboxSettingsProfileVersionKey = @"BXGameProfileVersion";
NSString * const BXGameboxSettingsLastLocationKey = @"BXGameLastLocation";
NSString * const BXGameboxSettingsRecentProgramsKey = @"BXGameRecentPrograms";

NSString * const BXGameboxSettingsShowProgramPanelKey = @"showProgramPanel";
NSString * const BXGameboxSettingsStartUpInFullScreenKey = @"startUpInFullScreen";
NSString * const BXGameboxSettingsShowLaunchPanelKey = @"showLaunchPanel";
NSString * const BXGameboxSettingsAlwaysShowLaunchPanelKey = @"alwaysShowLaunchPanel";

NSString * const BXGameboxSettingsDrivesKey     = @"BXQueudDrives";

NSString * const BXGameboxSettingsLastProgramPathKey = @"BXLastProgramPath";
NSString * const BXGameboxSettingsLastProgramLaunchArgumentsKey = @"BXLastProgramLaunchArguments";

//Keys inside BXGameRecentPrograms dictionaries
NSString * const BXGameboxSettingsProgramPathKey = @"path";
NSString * const BXGameboxSettingsProgramLaunchArgumentsKey = @"arguments";



#pragma mark -
#pragma mark Notifications

NSString * const BXSessionWillEnterFullScreenNotification	= @"BXSessionWillEnterFullScreen";
NSString * const BXSessionDidEnterFullScreenNotification	= @"BXSessionDidEnterFullScreen";
NSString * const BXSessionWillExitFullScreenNotification	= @"BXSessionWillExitFullScreen";
NSString * const BXSessionDidExitFullScreenNotification		= @"BXSessionDidExitFullScreen";

NSString * const BXSessionDidLockMouseNotification		= @"BXSessionDidLockMouse";
NSString * const BXSessionDidUnlockMouseNotification	= @"BXSessionDidUnlockMouse";

NSString * const BXWillBeginInterruptionNotification = @"BXWillBeginInterruptionNotification";
NSString * const BXDidFinishInterruptionNotification = @"BXDidFinishInterruptionNotification";

NSString * const BXPagesReadyNotificationType       = @"BXPagesReady";
NSString * const BXDriveImportedNotificationType    = @"BXDriveImported";
NSString * const BXGameImportedNotificationType     = @"BXGameImported";


#pragma mark -
#pragma mark Implementation

@implementation BXSession

@synthesize DOSWindowController = _DOSWindowController;
@synthesize printStatusController = _printStatusController;
@synthesize documentationPanelController = _documentationPanelController;

@synthesize gamebox = _gamebox;
@synthesize emulator = _emulator;

@synthesize targetURL = _targetURL;
@synthesize targetArguments = _targetArguments;
@synthesize launchedProgramURL = _launchedProgramURL;
@synthesize launchedProgramArguments = _launchedProgramArguments;

@synthesize gameProfile = _gameProfile;
@synthesize gameSettings = _gameSettings;
@synthesize drives = _drives;
@synthesize executableURLs = _executableURLs;
@synthesize emulating = _emulating;
@synthesize paused = _paused;
@synthesize autoPaused = _autoPaused;
@synthesize interrupted = _interrupted;
@synthesize suspended = _suspended;
@synthesize cachedIcon = _cachedIcon;
@synthesize canOpenURLs = _canOpenURLs;

@synthesize importQueue = _importQueue;
@synthesize scanQueue = _scanQueue;
@synthesize temporaryFolderURL = _temporaryFolderURL;
@synthesize MT32MessagesReceived = _MT32MessagesReceived;

@synthesize mutableRecentPrograms = _mutableRecentPrograms;


#pragma mark -
#pragma mark Helper class methods

+ (BXGameProfile *) profileForGameAtURL: (NSURL *)URL
{
	//Which folder to look in to detect the game we’re running.
	//This will choose any gamebox, Boxer drive folder or floppy/CD volume in the
	//file's path (setting shouldRecurse to YES) if found, falling back on the file's
	//containing folder otherwise (setting shouldRecurse to NO).
	BOOL shouldRecurse = NO;
	NSURL *profileDetectionURL = [self gameDetectionPointForURL: URL
                                         shouldSearchSubfolders: &shouldRecurse];
	
	//Detect any appropriate game profile for this session
	if (profileDetectionURL)
	{
		//IMPLEMENTATION NOTE: we only scan subfolders of the detection path if it's a gamebox,
		//mountable folder or CD/floppy disk, since these will have a finite and manageable file
		//hierarchy to scan.
		//Otherwise, we restrict our search to just the base folder to avoids massive blowouts
		//if the user opens something big like their home folder or startup disk, and to avoid
		//false positives when opening the DOS Games folder.
		return [BXGameProfile detectedProfileForPath: profileDetectionURL.path
									searchSubfolders: shouldRecurse];	
	}
	return nil;
}

+ (NSImage *) bootlegCoverArtForGamebox: (BXGamebox *)gamebox
                             withMedium: (BXReleaseMedium)medium
{
	Class <BXBootlegCoverArt> coverArtClass;
	if (medium == BXUnknownMedium)
        medium = [BXGameProfile mediumOfGameAtURL: gamebox.bundleURL];
    
	switch (medium)
	{
		case BXCDROMMedium:         coverArtClass = [BXJewelCase class];	break;
		case BX525DisketteMedium:	coverArtClass = [BX525Diskette class];	break;
		default:                    coverArtClass = [BX35Diskette class];	break;
	}
	NSString *iconTitle = gamebox.gameName;
	NSImage *icon = [coverArtClass coverArtWithTitle: iconTitle];
	return icon;
}


#pragma mark -
#pragma mark Initialization and cleanup

- (id) init
{
    self = [super init];
	if (self)
	{
		NSURL *defaultsURL = [[NSBundle mainBundle] URLForResource: @"GameDefaults" withExtension: @"plist"];
		NSMutableDictionary *defaults = [NSMutableDictionary dictionaryWithContentsOfURL: defaultsURL];
		
		self.drives = [NSMutableDictionary dictionaryWithCapacity: 10];
		self.executableURLs = [NSMutableDictionary dictionaryWithCapacity: 10];
		
		self.emulator = [[[BXEmulator alloc] init] autorelease];
		self.gameSettings = defaults;
		
		self.importQueue = [[[NSOperationQueue alloc] init] autorelease];
		self.scanQueue = [[[NSOperationQueue alloc] init] autorelease];
	}
	return self;
}

//Called when opening an existing file
- (id) initWithContentsOfURL: (NSURL *)absoluteURL
                      ofType: (NSString *)typeName
                       error: (NSError **)outError
{
    if ((self = [super initWithContentsOfURL: absoluteURL
                                      ofType: typeName
                                       error: outError]))
    {
        //Start up the emulator as soon as we're ready
        //(Super will call readFromURL:, setFileURL: et. al., fully preparing the session for starting)
        if ([self _shouldStartImmediately]) [self start];
    }
    return self;
}

//Called when opening a new document
- (id) initWithType: (NSString *)typeName
              error: (NSError **)outError
{
    if ((self = [super initWithType: typeName
                              error: outError]))
    {
        //Start up the emulator as soon as we're ready
        //See note above
        if ([self _shouldStartImmediately]) [self start];
    }
    return self;
}

- (void) dealloc
{ 	
    self.suppressesDisplaySleep = NO;
    
    self.DOSWindowController = nil;
    self.printStatusController = nil;
    self.documentationPanelController = nil;
    self.emulator = nil;
    self.gamebox = nil;
    self.gameProfile = nil;
    self.gameSettings = nil;
    self.mutableRecentPrograms = nil;
    
    self.targetURL = nil;
    self.targetArguments = nil;
    self.launchedProgramURL = nil;
    self.launchedProgramArguments = nil;
    
    self.drives = nil;
    self.executableURLs = nil;
    
    self.cachedIcon = nil;
    
    self.importQueue = nil;
    self.scanQueue = nil;
    
    self.temporaryFolderURL = nil;
    self.MT32MessagesReceived = nil;
    
	[super dealloc];
}

- (BOOL) readFromURL: (NSURL *)absoluteURL
			  ofType: (NSString *)typeName
			   error: (NSError **)outError
{
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	
	//Set our launch target to point to this URL, if we don't have a target already.
	if (!self.targetURL)
        self.targetURL = absoluteURL;
    
	//Check if the chosen file is located inside a gamebox.
    NSURL *gameboxURL = [workspace nearestAncestorOfURL: absoluteURL
                                          matchingTypes: [NSSet setWithObject: BXGameboxType]];
	
	//If the fileURL is located inside a gamebox, load the gamebox and use the gamebox itself as the fileURL.
	//This way, the DOS window will show the gamebox as the represented file, and our Recent Documents
	//list will likewise show the gamebox instead.
	if (gameboxURL)
	{
		self.gamebox = [BXGamebox bundleWithURL: gameboxURL];
		
        //Check if the user opened the gamebox itself or a specific file/folder inside the gamebox.
        BOOL hasCustomTarget = ![self.targetURL isEqual: gameboxURL];
        
        //Check if we are flagged to show the launch panel at startup for this game (instead of looking for a target program.)
        BOOL startWithLaunchPanel = [[self.gameSettings objectForKey: BXGameboxSettingsShowLaunchPanelKey] boolValue];
        BOOL alwaysStartWithLaunchPanel = [[self.gameSettings objectForKey: BXGameboxSettingsAlwaysShowLaunchPanelKey] boolValue];
        if (alwaysStartWithLaunchPanel) startWithLaunchPanel = YES;
        
		//If the user opened the gamebox itself instead of a specific file inside it,
        //and we're not flagged to show the launch panel in this situation, then try
        //to locate a program to launch at startup.
        if (!hasCustomTarget && !startWithLaunchPanel)
		{
            //Check if the user was running a program last time, and restore that if available.
		    NSString *previousPath = [self.gameSettings objectForKey: BXGameboxSettingsLastProgramPathKey];
            NSURL *previousURL = nil;
            if (previousPath && !previousPath.isAbsolutePath)
            {
                if (previousPath.isAbsolutePath)
                {
                    previousURL = [NSURL fileURLWithPath: previousPath];
                }
                //If the recorded path is relative, resolve it relative to the gamebox.
                else
                {
                    NSURL *baseURL = self.gamebox.resourceURL;
                    previousURL = [baseURL URLByAppendingPathComponent: previousPath];
                }
            }
            
            //If the previously-running program is available, launch that.
            if ([previousURL checkResourceIsReachableAndReturnError: NULL])
            {
                self.targetURL = previousURL;
                self.targetArguments = [self.gameSettings objectForKey: BXGameboxSettingsLastProgramLaunchArgumentsKey];
            }
            //Otherwise, launch the gamebox's default launcher if it has one.
            else
            {
                NSDictionary *defaultLauncher = self.gamebox.defaultLauncher;
                
                //If there's no nominated default launcher, but the gamebox only *has* one launcher,
                //then launch that by default instead.
                if (!defaultLauncher && self.gamebox.launchers.count == 1)
                    defaultLauncher = self.gamebox.launchers.lastObject;
                
                if (defaultLauncher)
                {
                    self.targetURL = [defaultLauncher objectForKey: BXLauncherURLKey];
                    self.targetArguments = [defaultLauncher objectForKey: BXLauncherArgsKey];
                }
            }
        }
        
        //Once we've finished, clear any flags that override the startup program for this game.
        [self.gameSettings removeObjectForKey: BXGameboxSettingsShowLaunchPanelKey];
		
        //Report the gamebox itself as the source URL for this 'document', appearing as such in the titlebar
        //and the recent items menu.
		//FIXME: move the fileURL reset out of here and into a later step: we can't rely on the order
		//in which NSDocument's setFileURL/readFromURL methods are called.
		self.fileURL = gameboxURL;
	}
    
	return YES;
}

- (void) setGamebox: (BXGamebox *)gamebox
{	
	if (gamebox != self.gamebox)
	{
        self.gamebox.undoDelegate = nil;
        
		[_gamebox release];
		_gamebox = [gamebox retain];
		
		if (self.gamebox)
		{
            self.gamebox.undoDelegate = self;
            //Load up the settings and game profile for this gamebox while we're at it.
			[self _loadGameSettingsForGamebox: self.gamebox];
		}
	}
}

- (void) _loadGameSettingsForGamebox: (BXGamebox *)gamebox
{
    if (gamebox)
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *defaultsKey = [NSString stringWithFormat: BXGameboxSettingsKeyFormat, gamebox.gameIdentifier];
        
        NSDictionary *gameboxSettings = [defaults objectForKey: defaultsKey];
        
        [self _loadGameSettings: gameboxSettings];
    }
}

- (void) _loadGameSettings: (NSDictionary *)gameSettings
{
    //Merge the loaded values in, rather than replacing the default settings altogether.
    [self.gameSettings addEntriesFromDictionary: gameSettings];
    
    //UPDATE: transition the closeOnExit flag from out of the user-specific
    //game settings and into the gamebox itself (v1.3 -> v1.3.1.)
    NSNumber *closeOnExitFlag = [self.gameSettings objectForKey: @"closeOnExit"];
    if (closeOnExitFlag != nil)
    {
        self.gamebox.closeOnExit = closeOnExitFlag.boolValue;
        //Remove the old setting so that we don't import it again next time.
        [self.gameSettings removeObjectForKey: @"closeOnExit"];
    }
    
    //UPDATE: transition the startUpInFullScreen flag from out of the application-wide
    //user defaults and into the user-specific game settings. (v1.3->v2.x)
    NSNumber *startUpInFullScreenFlag = [[NSUserDefaults standardUserDefaults] objectForKey: @"startUpInFullScreen"];
    if (startUpInFullScreenFlag && ![gameSettings objectForKey: BXGameboxSettingsStartUpInFullScreenKey])
    {
        [self.gameSettings setObject: startUpInFullScreenFlag
                              forKey: BXGameboxSettingsStartUpInFullScreenKey];
    }
    
    //Deserialize recent programs, resolving from (potentially relative) paths into logical URLs
    NSArray *recentPrograms = [gameSettings objectForKey: BXGameboxSettingsRecentProgramsKey];
    if (recentPrograms)
    {
        [self willChangeValueForKey: @"recentPrograms"];
        
        self.mutableRecentPrograms = [NSMutableArray arrayWithCapacity: recentPrograms.count];
        NSURL *baseURL = self.gamebox.resourceURL;
        for (NSDictionary *programDetails in recentPrograms)
        {
            NSString *storedPath = [programDetails objectForKey: BXGameboxSettingsProgramPathKey];
            NSString *storedArgs = [programDetails objectForKey: BXGameboxSettingsProgramLaunchArgumentsKey];
            NSURL *resolvedURL;
            if (storedPath.isAbsolutePath)
                resolvedURL = [NSURL fileURLWithPath: storedPath];
            else
                resolvedURL = [baseURL URLByAppendingPathComponent: storedPath];
            
            NSDictionary *resolvedDetails;
            if (storedArgs.length)
                resolvedDetails = @{BXEmulatorLogicalURLKey: resolvedURL, BXEmulatorLaunchArgumentsKey: storedArgs};
            else
                resolvedDetails = @{BXEmulatorLogicalURLKey: resolvedURL};
            
            [self.mutableRecentPrograms addObject: resolvedDetails];
        }
        
        [self didChangeValueForKey: @"recentPrograms"];
        
        //Remove the leftover value from the game settings as it won't be used
        [self.gameSettings removeObjectForKey: BXGameboxSettingsRecentProgramsKey];
    }
    
    //If we don't already have a game profile assigned,
    //then load any previously detected game profile from the game settings
    if (!self.gameProfile)
    {
        NSString *identifier        = [self.gameSettings objectForKey: BXGameboxSettingsProfileKey];
        NSString *profileVersion    = [self.gameSettings objectForKey: BXGameboxSettingsProfileVersionKey];
        
        if (identifier && profileVersion)
        {
            //Check if the profile catalogue version under which the detected profile was saved
            //is older than the current catalogue version. If it is, then we'll redetect rather
            //than use a profile detected from a previous version.
            BOOL profileOutdated = [profileVersion compare: [BXGameProfile catalogueVersion]
                                                   options: NSNumericSearch] == NSOrderedAscending;
            
            if (!profileOutdated)
            {
                //Tweak: don't use saved profiles in debug mode, as this interferes with development
                //of detection rules.
#ifndef BOXER_DEBUG
                BXGameProfile *profile = [BXGameProfile profileWithIdentifier: identifier];
                //NSLog(@"Reusing existing profile with identifier: %@, %@", identifier, profile);
                self.gameProfile = profile;
#endif
            }
        }
    }
}

- (void) setGameProfile: (BXGameProfile *)profile
{
    if (![self.gameProfile isEqual: profile])
    {
        [_gameProfile release];
        _gameProfile = [profile retain];
        
        //Save the profile into our game settings so that we can retrieve it quicker later
        if (self.gameProfile && [self _shouldPersistGameProfile: self.gameProfile])
        {
            NSString *identifier = self.gameProfile.identifier;
            if (identifier)
            {
                [self.gameSettings setObject: identifier forKey: BXGameboxSettingsProfileKey];
                
                //Also store the catalogue version under which the game profile was decided,
                //so that we can invalidate old detections whenever the catalogue is updated.
                [self.gameSettings setObject: [BXGameProfile catalogueVersion]
                                      forKey: BXGameboxSettingsProfileVersionKey];
            }
        }
    }
}

- (void) setEmulator: (BXEmulator *)newEmulator
{
	if (self.emulator != newEmulator)
	{
		if (self.emulator)
		{
			self.emulator.delegate = nil;
			
            [self.emulator unbind: @"masterVolume"];
            
			[self _deregisterForPauseNotifications];
			[self _deregisterForFilesystemNotifications];
		}
		
		[_emulator release];
		_emulator = [newEmulator retain];
		
		if (self.emulator)
		{	
			self.emulator.delegate = (id)self;
			
            [self.emulator bind: @"masterVolume"
                       toObject: [NSApp delegate]
                    withKeyPath: @"effectiveVolume"
                        options: nil];
			
			[self _registerForFilesystemNotifications];
			[self _registerForPauseNotifications];
		}
	}
}

- (NSURL *) currentURL
{
	if (self.launchedProgramURL)
        return self.launchedProgramURL;
	else
        return self.emulator.currentDirectoryURL;
}

#pragma mark -
#pragma mark Window management

- (void) makeWindowControllers
{
	BXDOSWindowController *controller;
	if (isRunningOnLionOrAbove())
	{
		controller = [[BXDOSWindowControllerLion alloc] initWithWindowNibName: @"DOSWindow"];
	}
	else
	{
		controller = [[BXDOSWindowController alloc] initWithWindowNibName: @"DOSWindow"];
	}
	
	[self addWindowController: controller];
	self.DOSWindowController = controller;
	
	controller.shouldCloseDocument = YES;
	
	[controller release];
}

- (void) removeWindowController: (NSWindowController *)windowController
{
	if (windowController == self.DOSWindowController)
	{
        self.DOSWindowController = nil;
	}
	[super removeWindowController: windowController];
}

- (void) setDOSWindowController: (BXDOSWindowController *)controller
{
    if (controller != self.DOSWindowController)
    {
        if (self.DOSWindowController)
        {
            [self.DOSWindowController removeObserver: self forKeyPath: @"currentPanel"];
        }
        
        [_DOSWindowController release];
        _DOSWindowController = [controller retain];
        
        if (self.DOSWindowController)
        {
            [self.DOSWindowController addObserver: self
                                       forKeyPath: @"currentPanel"
                                          options: 0
                                          context: NULL];
        }
    }
}


#pragma mark -
#pragma mark Flow control

- (void) start
{
	//We schedule our internal _startEmulator method to be called separately on the main thread,
	//so that it doesn't block completion of whatever UI event led to this being called.
	//This prevents menu highlights from getting 'stuck' because of DOSBox's main loop blocking
	//the thread.
	
    
	if (!_hasStarted) [self performSelector: @selector(_startEmulator)
                                 withObject: nil
                                 afterDelay: 0.1];
	
	//So we don't try to restart the emulator
	_hasStarted = YES;
}

//Cancel the DOSBox emulator
- (void) cancel
{
    [self.emulator cancel];
    //Flag ourselves early as no longer emulating: this
    //disables certain parts of our behaviour to prevent
    //interference while the emulator is shutting down.
    self.emulating = NO;
}


#pragma mark -
#pragma mark Handling document closing

//Tell the emulator to close itself down when the document closes
- (void) close
{
	//Ensure that the document close procedure only happens once, no matter how many times we close
	if (!_isClosing)
	{
		_isClosing = YES;
		[self cancel];
		
		[self synchronizeSettings];
		[self _cleanup];
		
		[super close];
	}
}

- (void) restartShowingLaunchPanel: (BOOL)showLaunchPanel
{
    NSURL *reopenURL = self.fileURL;
    
    [self.gameSettings setObject: @(showLaunchPanel)
                          forKey: BXGameboxSettingsShowLaunchPanelKey];
    
    [self close];
    
    if (reopenURL)
        [[NSApp delegate] openDocumentWithContentsOfURL: reopenURL display: YES error: NULL];
    else
        [[NSApp delegate] openUntitledDocumentAndDisplay: YES error: NULL];
}

- (BOOL) isEntireFileLoaded
{
    return NO;
}

- (BOOL) canCloseSafely
{
    if (self.emulator.isRunningActiveProcess)
        return NO;
    
    if (self.isImportingDrives)
        return NO;
    
    return YES;
}

//Overridden solely so that NSDocumentController will call canCloseDocumentWithDelegate:
//in the first place. This otherwise should have no effect and should not show up in the UI.
- (BOOL) isDocumentEdited
{
    return ![self canCloseSafely];
}

//Overridden to display our own custom confirmation alert instead of the standard NSDocument one.
- (void) canCloseDocumentWithDelegate: (id)delegate
				  shouldCloseSelector: (SEL)shouldCloseSelector
						  contextInfo: (void *)contextInfo
{
	//Define an invocation for the callback, which has the signature:
	//- (void)document:(NSDocument *)document shouldClose:(BOOL)shouldClose contextInfo:(void *)contextInfo;
    NSInvocation *callback = [NSInvocation invocationWithTarget: delegate selector: shouldCloseSelector];
	[callback setArgument: &self atIndex: 2];
	[callback setArgument: &contextInfo atIndex: 4];
	
	BOOL hasActiveImports = self.isImportingDrives;
	
	
	//We confirm the close if a process is running and if we're not already shutting down
	BOOL shouldConfirm = hasActiveImports ||
						(![[NSUserDefaults standardUserDefaults] boolForKey: @"suppressCloseAlert"]
						  && self.emulator.isRunningActiveProcess
						  && !self.emulator.isCancelled);
	
	if (shouldConfirm)
	{
		//Show our custom close alert, passing it the callback so we can complete
		//our response down in _closeAlertDidEnd:returnCode:contextInfo:
		
		BXCloseAlert *alert;
		if (hasActiveImports) 
			alert = [BXCloseAlert closeAlertWhileImportingDrives: self];
		else
			alert = [BXCloseAlert closeAlertWhileSessionIsEmulating: self];
		
		[alert beginSheetModalForWindow: self.windowForSheet
						  modalDelegate: self
						 didEndSelector: @selector(_closeAlertDidEnd:returnCode:contextInfo:)
							contextInfo: [callback retain]];
	}
	else
	{
		BOOL shouldClose = YES;
		//Otherwise we can respond directly: call the callback straight away with YES for shouldClose:
		[callback setArgument: &shouldClose atIndex: 3];
		[callback invoke];
	}
}

- (void) _closeAlertDidEnd: (BXCloseAlert *)alert
				returnCode: (int)returnCode
			   contextInfo: (NSInvocation *)callback
{
	if (alert.showsSuppressionButton && alert.suppressionButton.state == NSOnState)
		[[NSUserDefaults standardUserDefaults] setBool: YES forKey: @"suppressCloseAlert"];
	
	BOOL shouldClose = (returnCode == NSAlertFirstButtonReturn);
	[callback setArgument: &shouldClose atIndex: 3];
	[callback invoke];
	
	//Release the previously-retained callback
	[callback release];
}

- (void) _windowsOnlyProgramCloseAlertDidEnd: (BXCloseAlert *)alert
								  returnCode: (int)returnCode
								 contextInfo: (void *)contextInfo
{
	if (returnCode == NSAlertFirstButtonReturn)
	{
		[self close];
	}
}

//Save our configuration changes to disk before exiting
- (void) synchronizeSettings
{
	if (self.hasGamebox)
	{
		//Go through the settings working out which ones we should store in user defaults,
		//and which ones we should store in the gamebox's configuration file
        //(and which we should not persist altogether).
		BXEmulatorConfiguration *runtimeConf = [BXEmulatorConfiguration configuration];
		
		//These are the settings we want to keep in the configuration file
		NSNumber *CPUSpeed      = [self.gameSettings objectForKey: @"CPUSpeed"];
		NSNumber *coreMode		= [self.gameSettings objectForKey: @"coreMode"];
		NSNumber *strictGameportTiming = [self.gameSettings objectForKey: @"strictGameportTiming"];
		
		if (coreMode)
		{
			NSString *coreString = [BXEmulator configStringForCoreMode: coreMode.integerValue];
			[runtimeConf setValue: coreString forKey: @"core" inSection: @"cpu"];
		}
		
		if (strictGameportTiming)
		{
			NSString *timingString = [BXEmulator configStringForGameportTimingMode: strictGameportTiming.unsignedIntegerValue];
			[runtimeConf setValue: timingString forKey: @"timed" inSection: @"joystick"];
		}
		
		if (CPUSpeed)
		{
            NSInteger speed = CPUSpeed.integerValue;
            BOOL isAutoSpeed = (speed == BXAutoSpeed);
			NSString *cyclesString = [BXEmulator configStringForFixedSpeed: speed
																	isAuto: isAutoSpeed];
			
			[runtimeConf setValue: cyclesString forKey: @"cycles" inSection: @"cpu"];
		}
		
		//Strip out these settings once we're done, so we won't preserve them in user defaults and won't re-record them
        //if they haven't changed by the next time the settings are synchronized.
		NSArray *confSettings = [NSArray arrayWithObjects: @"CPUSpeed", @"coreMode", @"strictGameportTiming", nil];
		[self.gameSettings removeObjectsForKeys: confSettings];

		//Persist these gamebox-specific configuration into the gamebox's configuration file.
		[self _saveGameboxConfiguration: runtimeConf];
        
        
		
        //Now that we've saved those settings to the gamebox conf,
        //persist the rest of the game state to user defaults.
        
        //Trim out any settings that are the same as the original defaults.
        //This way, if a later version of Boxer changes the defaults, those
        //will be propagated through to existing games.
		NSString *defaultsPath = [[NSBundle mainBundle] pathForResource: @"GameDefaults" ofType: @"plist"];
		NSMutableDictionary *defaultSettings = [NSMutableDictionary dictionaryWithContentsOfFile: defaultsPath];
        
        NSMutableDictionary *settingsToPersist = [NSMutableDictionary dictionaryWithDictionary: self.gameSettings];
        for (NSString *key in self.gameSettings)
        {
            id initialValue = [defaultSettings objectForKey: key];
            id currentValue = [self.gameSettings objectForKey: key];
            if ([initialValue isEqual: currentValue])
                [settingsToPersist removeObjectForKey: key];
        }

        //Add the gamebox name into the settings, to make it easier
        //to identify to which gamebox the record belongs.
        [settingsToPersist setObject: self.gamebox.gameName
                              forKey: BXGameboxSettingsNameKey];
        
        //While we're here, update the game settings to record the last known location of the gamebox.
        //(This is currently unused by Boxer, but is being tracked in case later versions want to check
        //if a gamebox has been renamed or moved.)
        [settingsToPersist setObject: self.gamebox.bundleURL.path
                              forKey: BXGameboxSettingsLastLocationKey];
        
        
        //Record the state of the drive queues for next time we launch this gamebox.
        if ([self _shouldPersistQueuedDrives])
        {
            //Build a list of what drives the user had queued at the time they quit.
            NSMutableArray *queuedDrives = [NSMutableArray arrayWithCapacity: self.allDrives.count];
            for (BXDrive *drive in self.allDrives)
            {
                //Skip our own internal drives and drives that are bundled into the gamebox.
                if (drive.isHidden || drive.isVirtual || [self driveIsBundled: drive])
                    continue;
                
                NSData *driveInfo = [NSKeyedArchiver archivedDataWithRootObject: drive];
                
                [queuedDrives addObject: driveInfo];
            }
            
            [settingsToPersist setObject: queuedDrives forKey: BXGameboxSettingsDrivesKey];
        }
        //Clear any previous data if we're not overwriting it
        else
        {
            [settingsToPersist removeObjectForKey: BXGameboxSettingsDrivesKey];
        }
        
        //Clean up the recent programs list, deleting any transient data and making URLs gamebox-relative
        //before persisting them.
        if (self.mutableRecentPrograms.count)
        {
            NSURL *baseURL = self.gamebox.resourceURL;
            
            NSMutableArray *recentProgramsToPersist = [NSMutableArray arrayWithCapacity: self.mutableRecentPrograms.count];
            for (NSDictionary *programDetails in self.mutableRecentPrograms)
            {
                NSURL *URL = [programDetails objectForKey: BXEmulatorLogicalURLKey];
                if (!URL)
                    continue;
                
                NSMutableDictionary *detailsToPersist = [NSMutableDictionary dictionaryWithCapacity: 2];
                
                if ([URL isBasedInURL: baseURL])
                {
                    NSString *relativePath = [URL pathRelativeToURL: baseURL];
                    [detailsToPersist setObject: relativePath forKey: BXGameboxSettingsProgramPathKey];
                }
                else
                {
                    [detailsToPersist setObject: URL.path
                                         forKey: BXGameboxSettingsProgramPathKey];
                }
                
                NSString *arguments = [programDetails objectForKey: BXEmulatorLaunchArgumentsKey];
                if (arguments.length)
                {
                    [detailsToPersist setObject: arguments
                                         forKey: BXGameboxSettingsProgramLaunchArgumentsKey];
                }
                
                [recentProgramsToPersist addObject: detailsToPersist];
            }
            
            [settingsToPersist setObject: recentProgramsToPersist forKey: BXGameboxSettingsRecentProgramsKey];
        }
        else
        {
            [settingsToPersist removeObjectForKey: BXGameboxSettingsRecentProgramsKey];
        }
        
        //Record the current program in order to resume it next time we launch this gamebox.
        if ([self _shouldPersistPreviousProgram])
        {
            NSURL *currentURL = self.currentURL;
            
            //If we were running a program when we were shut down, then record that;
            //otherwise, record the last directory we were in when we were at the DOS prompt.
            //TODO: resolve paths to shadowed locations into paths to virtual gamebox resources.
            if (currentURL)
            {
                NSURL *baseURL = self.gamebox.resourceURL;
                
                //Make the program path relative to the root of the gamebox, if it was located within the gamebox itself.
                //TODO: if the program was located outside the gamebox, and is reachable in the OS X filesystem,
                //record it as a bookmark instead of an absolute path.
                NSString *pathToPersist;
                if ([currentURL isBasedInURL: baseURL])
                {
                    pathToPersist = [currentURL pathRelativeToURL: baseURL];
                }
                else
                {
                    pathToPersist = currentURL.path;
                }
                
                [settingsToPersist setObject: pathToPersist
                                      forKey: BXGameboxSettingsLastProgramPathKey];
                
                if (self.launchedProgramArguments)
                    [settingsToPersist setObject: self.launchedProgramArguments
                                          forKey: BXGameboxSettingsLastProgramLaunchArgumentsKey];
                else
                    [settingsToPersist removeObjectForKey: BXGameboxSettingsLastProgramLaunchArgumentsKey];
                    
            }
            else
            {
                [settingsToPersist removeObjectForKey: BXGameboxSettingsLastProgramPathKey];
                [settingsToPersist removeObjectForKey: BXGameboxSettingsLastProgramLaunchArgumentsKey];
            }
        }
        //Clear any previous record of the last launched program if we're not overwriting it.
        else
        {
            [settingsToPersist removeObjectForKey: BXGameboxSettingsLastProgramPathKey];
            [settingsToPersist removeObjectForKey: BXGameboxSettingsLastProgramLaunchArgumentsKey];
        }
        
        //Store the game settings back into the main user defaults.
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *defaultsKey = [NSString stringWithFormat: BXGameboxSettingsKeyFormat, self.gamebox.gameIdentifier];
        [defaults setObject: settingsToPersist forKey: defaultsKey];
        
        //Finally, also ensure our shadow volume matches the current game metadata.
        NSURL *stateURL = self.currentGameStateURL;
        if ([stateURL checkResourceIsReachableAndReturnError: NULL])
            [self _updateInfoForGameStateAtURL: stateURL];
	}
}


#pragma mark -
#pragma mark Describing the document/process

- (NSString *) displayName
{
    if ([[NSApp delegate] isStandaloneGameBundle])
        return [BXBaseAppController appName];
    
	else if (self.hasGamebox)
        return self.gamebox.gameName;
    
	else if (self.fileURL)
        return [super displayName];
    
	else
        return self.processDisplayName;
}

- (NSString *) processDisplayName
{
	NSString *processName = nil;
	if (self.emulator.isRunningActiveProcess)
	{
		//Use the name of the last launched program where possible;
		//Failing that, fall back on the original process name
		if (self.launchedProgramURL)
            processName = self.launchedProgramURL.lastPathComponent;
		else
            processName = self.emulator.processName;
	}
	return processName;
}


#pragma mark -
#pragma mark Introspecting the gamebox

- (BOOL) hasGamebox
{
    return (self.gamebox != nil);
}

+ (NSSet *) keyPathsForValuesAffectingAllowsLauncherPanel
{
    return [NSSet setWithObject: @"gamebox.launchers"];
}

- (BOOL) allowsLauncherPanel
{
    if (!self.hasGamebox)
        return NO;
    
    //Prevent access to the launcher panel if this is a standalone game bundle with only one launch option,
    //and it hasn't been overridden to always show the launch panel.
    //In such cases the launcher panel is unnecessary.
    if ([[NSApp delegate] isStandaloneGameBundle])
    {
        BOOL alwaysStartWithLaunchPanel = [[self.gameSettings objectForKey: BXGameboxSettingsAlwaysShowLaunchPanelKey] boolValue];
        if (!alwaysStartWithLaunchPanel && self.gamebox.launchers.count == 1)
            return NO;
    }
    
    return YES;
}

- (BOOL) isGameImport
{
    return NO;
}

- (NSImage *)representedIcon
{
    if (self.hasGamebox && self.cachedIcon == nil)
    {
        NSImage *icon = self.gamebox.coverArt;
        
        //If the gamebox has no custom icon (or has lost it), then generate
        //a new one for it now and try to apply it to the gamebox.
        //IMPLEMENTATION NOTE: we don't do this if we're part of a standalone
        //game bundle, because then we'll be using the app's own icon instead.
        if (!icon && ![[NSApp delegate] isStandaloneGameBundle])
        {
            BXReleaseMedium medium = self.gameProfile.releaseMedium;
            icon = [self.class bootlegCoverArtForGamebox: self.gamebox
                                              withMedium: medium];
            
            //This may fail, if the game package is on a read-only medium.
            //We don't care about this though, since we now have cached the
            //generated icon and will use that for the lifetime of the session.
            self.gamebox.coverArt = icon;
        }
        
        self.cachedIcon = icon;
    }
    
    return self.cachedIcon;
}

- (void) setRepresentedIcon: (NSImage *)icon
{
    //Note: this equality check is fairly feeble, since we cannot
    //(and should not) compare image data for equality.
    if (self.hasGamebox && ![self.cachedIcon isEqual: icon])
    {
        self.gamebox.coverArt = icon;
        self.cachedIcon = icon;
        
        //Force the window's icon to update to account for the new icon.
        [self.DOSWindowController synchronizeWindowTitleWithDocumentName];
    }
}

+ (NSSet *) keyPathsForValuesAffectingHasGamebox        { return [NSSet setWithObject: @"gamebox"]; }
+ (NSSet *) keyPathsForValuesAffectingRepresentedIcon	{ return [NSSet setWithObjects: @"gamebox", @"gamebox.coverArt", nil]; }
+ (NSSet *) keyPathsForValuesAffectingCurrentURL        { return [NSSet setWithObjects: @"launchedProgramURL", @"emulator.currentDirectoryURL", nil]; }

- (NSArray *) recentPrograms
{
    return self.mutableRecentPrograms;
}

- (void) noteRecentProgram: (NSDictionary *)programDetails
{
    [self willChangeValueForKey: @"recentPrograms"];
    
    if (!self.mutableRecentPrograms)
        self.mutableRecentPrograms = [NSMutableArray arrayWithCapacity: 1];
    
    if (self.mutableRecentPrograms.count)
    {
        //Remove any existing record of this program, since we'll be bumping it up to the front of the list.
        [self removeRecentProgram: programDetails];
        [self.mutableRecentPrograms insertObject: programDetails atIndex: 0];
    }
    else
    {
        [self.mutableRecentPrograms addObject: programDetails];
    }
    
    //If we're over our limit, get rid of older ones.
    while (self.mutableRecentPrograms.count > BXRecentProgramsLimit)
        [self.mutableRecentPrograms removeLastObject];
    
    [self didChangeValueForKey: @"recentPrograms"];
}

- (void) removeRecentProgram: (NSDictionary *)programDetails
{
    [self willChangeValueForKey: @"recentPrograms"];
    
    NSURL *programURL = [programDetails objectForKey: BXEmulatorLogicalURLKey];
    NSString *programArgs = [programDetails objectForKey: BXEmulatorLaunchArgumentsKey];
    
    for (NSDictionary *existingDetails in [NSArray arrayWithArray: self.mutableRecentPrograms])
    {
        NSURL *existingURL = [existingDetails objectForKey: BXEmulatorLogicalURLKey];
        if ([programURL isEqual: existingURL])
        {
            NSString *existingArgs = [existingDetails objectForKey: BXEmulatorLaunchArgumentsKey];
            
            if ((!existingArgs && !programArgs) || [existingArgs isEqualToString: programArgs])
            {
                [self.mutableRecentPrograms removeObject: existingDetails];
            }
        }
    }
    
    [self didChangeValueForKey: @"recentPrograms"];
}

- (void) clearRecentPrograms
{
    [self willChangeValueForKey: @"recentPrograms"];
    [self.mutableRecentPrograms removeAllObjects];
    [self didChangeValueForKey: @"recentPrograms"];
}


#pragma mark - Emulator delegate methods and notifications

- (BOOL) emulatorShouldDisplayStartupMessages: (BXEmulator *)emulator
{
    if ([[NSApp delegate] isStandaloneGameBundle])
        return NO;
    
    return YES;
}

- (void) emulatorDidInitialize: (NSNotification *)notification
{
	//Flag that we are now officially emulating.
	//We wait until now because at this point the emulator is in
	//a properly initialized state, and can respond properly to
	//commands and settings changes.
	//TODO: move this decision off to the emulator itself.
	self.emulating = YES;
    
    //Start preventing the display from going to sleep
    [self _syncSuppressesDisplaySleep];
}

- (void) emulatorDidFinish: (NSNotification *)notification
{
    //If we were fast-forwarding, clear the bezel now.
    [self releaseFastForward: self];
    
    //Hide our documentation and print status panel.
    [self.printStatusController.window orderOut: self];
    
	//Flag that we're no longer emulating
	self.emulating = NO;
    
    //Turn off display-sleep suppression
    [self _syncSuppressesDisplaySleep];

	//Clear the final rendered frame
	[self.DOSWindowController updateWithFrame: nil];
	
	//Close the document once we're done, if desired
	if ([self _shouldCloseOnEmulatorExit])
        [self close];
}

- (NSArray *) configurationURLsForEmulator: (BXEmulator *)emulator
{
    NSMutableArray *configURLs = [[NSMutableArray alloc] initWithCapacity: 4];
    
    //Load Boxer's baseline configuration first.
    NSBundle *appBundle = [NSBundle mainBundle];
    NSURL *preflightConfURL = [appBundle URLForResource: @"Preflight"
                                          withExtension: @"conf"
                                           subdirectory: @"Configurations"];
    NSAssert(preflightConfURL != nil, @"Missing preflight configuration.");
    [configURLs addObject: preflightConfURL];

	//If we don't have a previously-determined game profile already, detect the game profile
    //from our gamebox (or target URL, in the case of regular sessions).
	if (!self.gameProfile)
	{
        NSURL *detectionURL = (self.hasGamebox) ? self.gamebox.bundleURL : self.targetURL;
        if (detectionURL)
        {
            BXGameProfile *detectedProfile = [self.class profileForGameAtURL: self.targetURL];
            
            if (detectedProfile)
            {
                self.gameProfile = detectedProfile;
            }
            //If no specific game was detected, then record the profile explicitly as an unknown game
            //rather than leaving it blank. This stops us trying to redetect it again next time.
            else
            {
                self.gameProfile = [BXGameProfile genericProfile];
            }
        }
	}
	
	//Load the appropriate configuration files from our game profile.
    for (NSString *confName in self.gameProfile.configurations)
    {
        NSURL *profileConfURL = [appBundle URLForResource: confName
                                         withExtension: @"conf"
                                          subdirectory: @"Configurations"];
        
        NSAssert(profileConfURL != nil, @"Missing configuration profile: %@", confName);
        [configURLs addObject: profileConfURL];
    }
	
	//Next, load the gamebox's own configuration file if it has one.
    NSURL *packageConfURL = self.gamebox.configurationFileURL;
    if ([packageConfURL checkResourceIsReachableAndReturnError: NULL])
        [configURLs addObject: packageConfURL];
    
	
    //Last but not least, load Boxer's launch configuration.
    NSURL *launchURL = [appBundle URLForResource: @"Launch"
                                   withExtension: @"conf"
                                    subdirectory: @"Configurations"];
    
    NSAssert(launchURL != nil, @"Missing launch configuration profile.");
    [configURLs addObject: launchURL];
    
    
    //TWEAK: Sanitise the configurations folder of a standalone game app the first time the app is launched,
    //by deleting all unused conf files.
    if ([[NSApp delegate] isStandaloneGameBundle])
    {   
        NSFileManager *manager = [[NSFileManager alloc] init];
        NSURL *confBaseURL = [appBundle.resourceURL URLByAppendingPathComponent: @"Configurations"];
        NSArray *allConfigs = [manager contentsOfDirectoryAtURL: confBaseURL
                                     includingPropertiesForKeys: nil
                                                        options: 0
                                                          error: NULL];
        
        if (allConfigs.count > configURLs.count)
        {
            for (NSURL *confURL in allConfigs)
            {
                //If this configuration is unused by this game, expunge it.
                if (![configURLs containsObject: confURL])
                {
                    [manager removeItemAtURL: confURL error: NULL];
                }
            }
        }
        [manager release];
    }
    
    return [configURLs autorelease];
}

- (void) runPreflightCommandsForEmulator: (BXEmulator *)theEmulator
{
	if (!_hasConfigured)
	{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        if ([self _shouldAllowSkippingStartupProgram])
        {
            //If the Option key is held down during the startup process, skip the default program.
            CGEventFlags currentModifiers = CGEventSourceFlagsState(kCGEventSourceStateCombinedSessionState);
            _userSkippedDefaultProgram = (currentModifiers & NSAlternateKeyMask) == NSAlternateKeyMask;
        }
        
		[self _mountDrivesForSession];
		
		//Flag that we have completed our initial game configuration.
		_hasConfigured = YES;
        
        [pool drain];
	}
}

- (void) runLaunchCommandsForEmulator: (BXEmulator *)theEmulator
{
	_hasLaunched = YES;
    
    //Do any just-in-time configuration, which should override all previous startup stuff.
	NSNumber *frameskip = [self.gameSettings objectForKey: @"frameskip"];
	if (frameskip && [self validateValue: &frameskip forKey: @"frameskip" error: nil])
		[self setValue: frameskip forKey: @"frameskip"];
	
	
	//After all preflight configuration has finished, go ahead and open whatever
    //file or folder we're pointing at.
	NSURL *targetURL = self.targetURL;
    NSString *arguments = self.targetArguments;
    
	if (targetURL)
	{
        BOOL targetIsExecutable = ([targetURL matchingFileType: [BXFileTypes executableTypes]] != nil);
        
        //If the Option key is held down during the startup process, skip the default program.
        //(Repeated from runPreflightCommandsForEmulator: above, in case the user started
        //holding the key down in between.)
        if ([self _shouldAllowSkippingStartupProgram] && !_userSkippedDefaultProgram)
        {
            CGEventFlags currentModifiers = CGEventSourceFlagsState(kCGEventSourceStateCombinedSessionState);
            _userSkippedDefaultProgram = (currentModifiers & NSAlternateKeyMask) == NSAlternateKeyMask;
        }
        
		//If the Option key was held down, don't launch the gamebox's target;
		//Instead, just switch to its parent folder.
		if (_userSkippedDefaultProgram && targetIsExecutable)
		{
			targetURL = targetURL.URLByDeletingLastPathComponent;
            targetIsExecutable = NO;
            arguments = nil;
		}
        
        //Display the DOS view and switch into fullscreen now, if the user had previously quit while in fullscreen
        //and if they haven't skipped the startup program.
        BOOL startInFullScreen = [[self.gameSettings objectForKey: BXGameboxSettingsStartUpInFullScreenKey] boolValue];
        if (startInFullScreen)
        {
            BXDOSWindowPanel initialPanel = (targetIsExecutable) ? BXDOSWindowDOSView : BXDOSWindowLaunchPanel;
            [self.DOSWindowController switchToPanel: initialPanel animate: NO];
            [self.DOSWindowController enterFullScreen];
        }
        
        NSError *launchError = nil;
		[self openURLInDOS: targetURL
             withArguments: arguments
               clearScreen: YES
              onCompletion: BXSessionProgramCompletionBehaviorAuto
                     error: &launchError];
        
        //Display any error that occurred when trying to launch
        if (launchError)
        {
            [self presentError: launchError
                modalForWindow: self.windowForSheet
                      delegate: nil
            didPresentSelector: NULL
                   contextInfo: NULL];
        }
	}
    
    //Clear the program-skipping flag for next launch.
    _userSkippedDefaultProgram = NO;
}

- (void) emulator: (BXEmulator *)theEmulator didFinishFrame: (BXVideoFrame *)frame
{
	[self.DOSWindowController updateWithFrame: frame];
}

- (NSSize) maxFrameSizeForEmulator: (BXEmulator *)theEmulator
{
	return self.DOSWindowController.maxFrameSize;
}

- (NSSize) viewportSizeForEmulator: (BXEmulator *)theEmulator
{
	return self.DOSWindowController.viewportSize;
}

- (void) processEventsForEmulator: (BXEmulator *)theEmulator
{
    //Only pump the event queue ourselves if the emulator has taken over the main thread.
    if (!theEmulator.isConcurrent)
        [self _processEventsUntilDate: nil];
}

- (void) emulatorWillStartRunLoop: (BXEmulator *)theEmulator {}
- (void) emulatorDidFinishRunLoop: (BXEmulator *)theEmulator {}


- (void) _showDOSViewAfterProgramStart
{
    [self _cancelDOSViewAfterProgramStart];
    
    if (!self.DOSWindowController.DOSViewShown)
    {
        [NSObject cancelPreviousPerformRequestsWithTarget: self.DOSWindowController
                                                 selector: @selector(showLaunchPanel)
                                                   object: self];
        
        [self.DOSWindowController performSelector: @selector(showDOSView)
                                       withObject: self
                                       afterDelay: BXSwitchToDOSViewDelay];
    }
}

- (void) _cancelDOSViewAfterProgramStart
{
    [NSObject cancelPreviousPerformRequestsWithTarget: self.DOSWindowController
                                             selector: @selector(showDOSView)
                                               object: self];
}

- (void) emulatorWillStartProgram: (NSNotification *)notification
{
    NSDictionary *processInfo = notification.userInfo;
    
    //Show the DOS view after a short delay: if the program finishes executing before this,
    //it'll be cancelled and we'll remain at the current view.
    //This lets us keep the autoexec programs covered with a discreet loading-screen veil,
    //while still switching into the DOS view if a 'real' program starts up in earnest.
    [self _showDOSViewAfterProgramStart];
    
	//Don't override our record of the launched program if we already recorded one
    //back in openURLInDOS:error:. This way we maintain a record of which program
    //Boxer itself launched for the purposes of our launch history, and we won't
    //glom onto any subprocesses spawned by the original program. (Plus we'll still
    //catch programs that were launched from the commandline.)
	if (!self.launchedProgramURL && ![self.emulator processIsInternal: processInfo])
	{
		NSURL *programURL = [processInfo objectForKey: BXEmulatorLogicalURLKey];
        
        if (programURL)
        {
            NSString *arguments = [processInfo objectForKey: BXEmulatorLaunchArgumentsKey];
            self.launchedProgramURL = programURL;
            self.launchedProgramArguments = arguments;
            
            if ([self _shouldNoteRecentProgram: processInfo])
                [self noteRecentProgram: processInfo];
		}
	}
    
    //Disable display-sleeping while a program is running.
    [self _syncSuppressesDisplaySleep];
    
    self.canOpenURLs = !self.emulator.isRunningActiveProcess;
}

- (void) emulatorDidFinishProgram: (NSNotification *)notification
{
    //Cancel any pending switch to the DOS view that was started in emulatorWillStartProgram:.
    [self _cancelDOSViewAfterProgramStart];
    
    NSDictionary *processInfo = notification.userInfo;
    BOOL wasUserExecutable = ![self.emulator processIsBatchFile: processInfo] &&![self.emulator processIsInternal: processInfo];
    
    //Measure the running time of the program. If it was suspiciously short,
	//then check for possible error conditions that we can inform the user about.
    if (wasUserExecutable)
    {
        NSDate *launchDate = [notification.userInfo objectForKey: BXEmulatorLaunchDateKey];
        NSDate *exitDate = [notification.userInfo objectForKey: BXEmulatorExitDateKey];
        NSTimeInterval runningTime = [exitDate timeIntervalSinceDate: launchDate];
        
        if (runningTime < BXWindowsOnlyProgramFailTimeThreshold)
        {
            NSURL *programURL = [notification.userInfo objectForKey: BXEmulatorLogicalURLKey];
            BXDrive *drive = [notification.userInfo objectForKey: BXEmulatorDriveKey];
            if (programURL && drive.filesystem)
            {
                NSString *path = [drive.filesystem pathForLogicalURL: programURL];
                BXExecutableType programType = [BXFileTypes typeOfExecutableAtPath: path filesystem: drive.filesystem error: NULL];
                
                //If this was a windows-only program, explain further to the user why Boxer cannot run it.
                if (programType == BXExecutableTypeWindows)
                {
                    //If the user launched this program directly from Finder, then show
                    //a proper alert to the user and offer to close the DOS session.
                    if ([programURL isEqual: self.targetURL])
                    {
                        BXCloseAlert *alert = [BXCloseAlert closeAlertAfterWindowsOnlyProgramExited: programURL.path];
                        [alert beginSheetModalForWindow: self.windowForSheet
                                          modalDelegate: self
                                         didEndSelector: @selector(_windowsOnlyProgramCloseAlertDidEnd:returnCode:contextInfo:)
                                            contextInfo: NULL];
                        
                    }
                    //Otherwise, just print out explanatory text at the DOS prompt.
                    else
                    {
                        NSString *warningFormat = NSLocalizedStringFromTable(@"Windows-only game warning", @"Shell", nil);
                        NSString *programName = programURL.lastPathComponent.uppercaseString;
                        NSString *warningText = [NSString stringWithFormat: warningFormat, programName];
                        [self.emulator displayString: warningText];
                    }
                }
            }
        }
    }
    
    //Clear our record of the most recently launched program once it exits
    if ([self.launchedProgramURL isEqual: [processInfo objectForKey: BXEmulatorLogicalURLKey]])
    {
        self.launchedProgramURL = nil;
        self.launchedProgramArguments = nil;
    }
    
    self.canOpenURLs = !self.emulator.isRunningActiveProcess;
}

- (void) emulatorDidReturnToShell: (NSNotification *)notification
{
    //Clear our cache of sent MT-32 messages on behalf of BXAudioControls.
    [self.MT32MessagesReceived removeAllObjects];
    
    //Let the display sleep while we're at the shell
    [self _syncSuppressesDisplaySleep];
    
    //If this was the last program in the stack, then clean up a bunch of our state
    //and switch back to the launcher panel if appropriate.
    BOOL wasLastProcess = (self.emulator.runningProcesses.count == 0);
    if (wasLastProcess)
    {
        NSDictionary *processInfo = notification.userInfo;
        BXSessionProgramCompletionBehavior completionBehavior = [self _behaviorAfterReturningToShellFromProcess: processInfo];
        
        if (completionBehavior == BXSessionCloseOnCompletion)
        {
            [self close];
        }
        else if (completionBehavior == BXSessionShowLauncherOnCompletion)
        {
            NSAssert(self.allowsLauncherPanel, @"BXSessionShowLauncherOnCompletion specified for a session that has no launcher panel.");
            [self.DOSWindowController showLaunchPanel];
            
            //Switch to the launch panel only after a short delay.
            //Disabled for now: a delay here seems needless.
            /*
            [self.DOSWindowController performSelector: @selector(showLaunchPanel)
                                           withObject: self
                                           afterDelay: BXSwitchToLaunchPanelDelay];
             */
        }
        else if (completionBehavior == BXSessionShowDOSPromptOnCompletion)
        {
            [self.DOSWindowController showDOSView];
        }
        
        //Clear our completion behaviour so that the previous value won't influence
        //future programs launched straight from DOS.
        _programCompletionBehavior = BXSessionProgramCompletionBehaviorDoNothing;
        
        //Make sure we've cleared our record of the launched program altogether.
        self.launchedProgramURL = nil;
        self.launchedProgramArguments = nil;
    }
}

- (void) emulatorDidChangeEmulationState: (NSNotification *)notification
{
	//These reside in BXEmulatorControls, as should this function, but so be it
	[self willChangeValueForKey: @"sliderSpeed"];
	[self didChangeValueForKey: @"sliderSpeed"];
	
	[self willChangeValueForKey: @"frameskip"];
	[self didChangeValueForKey: @"frameskip"];
	
	[self willChangeValueForKey: @"dynamic"];
	[self didChangeValueForKey: @"dynamic"];	
}


#pragma mark -
#pragma mark Private methods

- (void) _processEventsUntilDate: (NSDate *)requestedDate
{
    //Implementation note: in a better world, this code wouldn't be here as event
	//dispatch is normally done automatically by NSApplication at opportune moments.
	//However, DOSBox's emulation loop takes over the application's main thread,
	//leaving no time for events to get processed and dispatched.
	//Hence in each iteration of DOSBox's run loop, we pump NSApplication's event
	//queue for all pending events and send them on their way.
    
    //Once BXEmulator is running in its own thread/process, this will be unnecessary
    //and we can ditch it altogether.
	
	//Bugfix: if we are in the process of shutting down, then don't dispatch events:
	//NSApp may not know yet that our window has closed, and will crash when trying
	//send events to it. This isn't a bug per se but an edge-case with the
	//NSWindow/NSDocument close flow.
	
    NSEvent *event;
    [requestedDate retain];
    
	NSDate *untilDate = self.isSuspended ? [NSDate distantFuture] : requestedDate;
	
	while (!_isClosing && (event = [NSApp nextEventMatchingMask: NSAnyEventMask
                                                      untilDate: untilDate
                                                         inMode: NSDefaultRunLoopMode
                                                        dequeue: YES]))
	{
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
        //Listen for key-up events for our fast-forward key and handle them ourselves.
        //Swallow all key-down events while this is happening.
        //IMPLEMENTATION NOTE: this is essentially a standard Cocoa event-listening loop
        //turned inside out, so that the emulation will keep running 'around' our listening.
        if (_waitingForFastForwardRelease)
        {
            if (event.type == NSKeyUp)
                [self releaseFastForward: self];
            else if (event.type == NSKeyDown)
                event = nil;
        }
        
        if (event)
        {
            [NSApp sendEvent: event];
		}
		//If we're suspended, keep dispatching events until we are unpaused;
        //otherwise, exit once our original requested date has passed (which
        //will be after the first batch of events has been processed,
        //if requestedDate was nil or in the past.)
		untilDate = self.isSuspended ? [NSDate distantFuture] : requestedDate;
        
        [pool drain];
	}
    
    [requestedDate release];
}

#pragma mark -
#pragma mark Behavioural modifiers

- (BOOL) _shouldAllowSkippingStartupProgram
{
    //For standalone game apps, only allow the user to skip the startup program
    //if there is more than one launch option to display on the launch panel.
    if ([[NSApp delegate] isStandaloneGameBundle])
    {
        return self.allowsLauncherPanel;
    }
    else return YES;
}

- (BOOL) _shouldAutoMountExternalVolumes
{
    //If this is a standalone game app, assume it has everything it needs
    //and ignore external volumes.
    if ([[NSApp delegate] isStandaloneGameBundle])
        return NO;
    else
        return YES;
}

- (BOOL) _shouldPersistGameProfile: (BXGameProfile *)profile
{
    return YES;
}

- (BOOL) _shouldPersistQueuedDrives
{
    //Don't bother persisting drives for standalone game apps:
    //they should already include everything they need.
    if ([[NSApp delegate] isStandaloneGameBundle])
        return NO;
    else
        return YES;
}

- (BOOL) _shouldPersistPreviousProgram
{
    //For standalone game apps, only bother recording the previous program
    //if the gamebox has more than one launch option to choose from.
    if ([[NSApp delegate] isStandaloneGameBundle])
    {
        BOOL hasMultipleLaunchers = (self.gamebox.launchers.count > 1);
        return hasMultipleLaunchers;
    }
    else return YES;
}

- (BOOL) _shouldCloseOnEmulatorExit { return YES; }
- (BOOL) _shouldStartImmediately { return YES; }


- (BXSessionProgramCompletionBehavior) _behaviorAfterReturningToShellFromProcess: (NSDictionary *)processInfo
{
    //Standalone-specific behaviour:
    //- if the game has launchers, then always return to the launcher panel;
    //- otherwise, exit the application altogether.
    if ([[NSApp delegate] isStandaloneGameBundle])
    {
        if (self.allowsLauncherPanel)
            return BXSessionShowLauncherOnCompletion;
        else
            return BXSessionCloseOnCompletion;
    }
    else if (_programCompletionBehavior == BXSessionCloseOnCompletion)
    {
        return BXSessionCloseOnCompletion;
    }
    else if (_programCompletionBehavior == BXSessionShowDOSPromptOnCompletion)
    {
        NSLog(@"DOS prompt specifically requested, showing it now");
        return BXSessionShowDOSPromptOnCompletion;
    }
    else if (_programCompletionBehavior == BXSessionShowLauncherOnCompletion)
    {
        if (!self.allowsLauncherPanel)
        {
            NSLog(@"Launcher requested but unavailable, showing DOS prompt");
            return BXSessionShowDOSPromptOnCompletion;
        }
        
        //If this program took suspiciously little time to run, stay at the DOS prompt
        //in case it crashed or displayed some helpful message.
        if (![self.emulator processIsInternal: processInfo])
        {
            NSDate *launchDate = [processInfo objectForKey: BXEmulatorLaunchDateKey];
            NSDate *exitDate = [processInfo objectForKey: BXEmulatorExitDateKey];
            NSTimeInterval runningTime = [exitDate timeIntervalSinceDate: launchDate];
            
            if (runningTime < BXSuccessfulProgramRunningTimeThreshold)
            {
                NSLog(@"Suspiciously short running time: %f, overriding return to launcher.", runningTime);
                return BXSessionShowDOSPromptOnCompletion;
            }
        }
        
        //Otherwise, go ahead and show the launcher
        return BXSessionShowLauncherOnCompletion;
    }
    //If the loading panel is still displaying by the time we return to the shell,
    //then we have to do *something*: switch to the most appropriate panel for the session.
    else if (self.DOSWindowController.currentPanel == BXDOSWindowLoadingPanel)
    {
        if (self.allowsLauncherPanel)
            return BXSessionShowLauncherOnCompletion;
        else
            return BXSessionShowDOSPromptOnCompletion;
    }
    else
    {
        return BXSessionProgramCompletionBehaviorDoNothing;
    }
}

- (BOOL) _shouldNoteRecentProgram: (NSDictionary *)processInfo
{
    if ([self.emulator processIsInternal: processInfo])
        return NO;
    
    //Do not record any programs launched during the startup process...
    //except for the program we ourselves intended to launch.
    if (self.emulator.isRunningAutoexec)
    {
        NSURL *programURL = [processInfo objectForKey: BXEmulatorLogicalURLKey];
        if (![programURL isEqual: self.targetURL])
            return NO;
    }
    return YES;
}

- (void) _startEmulator
{	
	//Set the emulator's current working directory relative to whatever we're opening
	if (self.fileURL)
	{
		if ([self.fileURL checkResourceIsReachableAndReturnError: NULL])
		{
			//If we're opening a folder/gamebox, use that as the base path; if we're opening
			//a program or disc image, use its containing folder as the base path instead.
            if (self.fileURL.isDirectory)
                self.emulator.baseURL = self.fileURL;
            else
                self.emulator.baseURL = self.fileURL.URLByDeletingLastPathComponent;
		}
	}
	
	//Start up the emulator itself.
    if ([[NSUserDefaults standardUserDefaults] boolForKey: @"useMultithreadedEmulation"])
    {
        [self.emulator performSelectorInBackground: @selector(start) withObject: nil];
    }
    else
    {
        @try
        {
            [self.emulator start];
        }
        @catch (NSException *exception)
        {
            //Convert unrecoverable exceptions into errors and display them to the user.
            if ([exception.name isEqualToString: BXEmulatorUnrecoverableException])
            {
                [self _reportEmulatorException: exception];
            }
            //Throw all other exceptions upstairs.
            else
            {
                @throw exception;
            }
        }
    }
}

- (void) _reportEmulatorException: (NSException *)exception
{
    //Ensure it gets logged to the console, if nothing else
    [NSApp reportException: exception];
    //NSLog(@"Uncaught emulation exception: %@ (%@)", exception.debugDescription, exception.callStackSymbols);
    
    NSString *errorMessage;
    NSString *currentProcessName = self.processDisplayName;
    if (currentProcessName)
    {
        NSString *messageFormat = NSLocalizedString(@"%1$@ has encountered a serious error and must be relaunched.",
                                                    @"Bold message shown in alert when an unrecoverable emulation error is encountered while running a process. %1$@ is the name of the currently-active program");
        
        errorMessage = [NSString stringWithFormat: messageFormat, currentProcessName];
    }
    else
    {
        errorMessage = NSLocalizedString(@"The MS-DOS prompt has encountered a serious error and must be relaunched.",
                                         @"Bold message shown in alert when an unrecoverable emulation error while no process is running.");
    }
    
    NSString *suggestion = NSLocalizedString(@"If this continues to occur after relaunching, please send us an error report.", @"Suggestion text shown in alert when an unrecoverable emulation error is encountered.");
    
    NSArray *options = @[NSLocalizedString(@"Relaunch", @"Button to restart the current session, shown in alert when Boxer encounters an unrecoverable emulation error."),
                         
                         NSLocalizedString(@"Close", @"Button to close the current session, shown in alert when Boxer encounters an unrecoverable emulation error."),
                         
                         NSLocalizedString(@"Send Report…", @"Button to open the issue tracker, shown in alert when Boxer encounters an unrecoverable emulation error."),
                         ];
    
    NSDictionary *userInfo = @{NSLocalizedDescriptionKey: errorMessage,
                               NSLocalizedRecoverySuggestionErrorKey: suggestion,
                               NSLocalizedRecoveryOptionsErrorKey: options,
                               NSRecoveryAttempterErrorKey: self,
                               @"exception": exception,
                               };
    
    NSError *userError = [NSError errorWithDomain: BXEmulatorErrorDomain
                                             code: BXEmulatorUnrecoverableError
                                         userInfo: userInfo];
    
    [self presentError: userError
        modalForWindow: self.windowForSheet
              delegate: nil
    didPresentSelector: NULL
           contextInfo: NULL];
}

- (void) attemptRecoveryFromError: (NSError *)error
                      optionIndex: (NSUInteger)recoveryOptionIndex
                         delegate: (id)delegate
               didRecoverSelector: (SEL)didRecoverSelector
                      contextInfo: (void *)contextInfo
{
    BOOL didRecover;
    if ([error matchesDomain: BXEmulatorErrorDomain code: BXEmulatorUnrecoverableError])
    {
        switch(recoveryOptionIndex)
        {
            case 0: //Restart
                //Restart at the launch panel, in case it's unsafe to launch the previous program
                [self restartShowingLaunchPanel: YES];
                break;
            case 1: //Close
                [self close];
                break;
            case 2: //Report
                [[NSApp delegate] reportIssueForError: error inSession: self];
                [self close];
                break;
        }
    }
    else
    {
        didRecover = NO;
    }
    [delegate performSelector: didRecoverSelector withValues: &didRecover, &contextInfo];
}

- (void) _mountDrivesForSession
{
    //If we're running a gamebox, first mount all the drives that are bundled inside it.
    if (self.gamebox)
	{
        NSArray *bundledDrives = self.gamebox.bundledDrives;
        
        for (BXDrive *drive in bundledDrives)
        {
            if ([drive.letter isEqualToString: @"C"])
            {
                drive.title = NSLocalizedString(@"Game Drive", @"The display title for the gamebox’s C drive.");
                
                //If our target was the gamebox itself, rewrite it to point to this C drive
                //so that we'll start up at drive C.
                if ([self.targetURL isEqual: self.gamebox.bundleURL])
                    self.targetURL = drive.sourceURL;
            }
            
            NSError *mountError = nil;
            [self mountDrive: drive
                    ifExists: BXDriveQueue
                     options: BXBundledDriveMountOptions
                       error: &mountError];
            
            //TODO: deal with any mounting errors that occur. Since all this happens automatically
            //during startup, we can't really give errors straight to the user as they will seem cryptic.
        }
    }
	
	//Automount all currently mounted floppy and CD-ROM volumes if appropriate.
    if ([self _shouldAutoMountExternalVolumes])
    {
        [self mountFloppyVolumesWithError: nil];
        [self mountCDVolumesWithError: nil];
	}
    
	//Mount our internal DOS toolkit and temporary drives.
	[self mountToolkitDriveWithError: nil];
    if (!self.gameProfile || [self.gameProfile shouldMountTempDrive])
        [self mountTempDriveWithError: nil];
    
    //If this game needs a CD-ROM to be present and we don't already have one, then mount a dummy CD drive.
    if (self.gameProfile.requiresCDROM)
        [self mountDummyCDROMWithError: nil];
    
    
    //Now, restore any drives that the user had in the drives list last time they ran this session.
    NSArray *previousDrives = [self.gameSettings objectForKey: BXGameboxSettingsDrivesKey];
    
    for (NSData *driveInfo in previousDrives)
    {
        BXDrive *drive = [NSKeyedUnarchiver unarchiveObjectWithData: driveInfo];
        
        //Skip drives that couldn't be decoded (which will happen if the drive's location
        //can no longer be resolved.)
        if (!drive) continue;
        
        //The drive has a flag indicating whether it was currently mounted last time.
        //Read this off, then clear the flag (it'll be reinstated later if we decide to mount it.)
        BOOL driveWasMounted = drive.isMounted;
        drive.mounted = NO;
        
        BXDriveConflictBehaviour shouldReplace = driveWasMounted ? BXDriveReplace : BXDriveQueue;
        
        //Check if we already have a drive queued that represents this drive.
        //If so, we'll ignore the previous drive and just remount the existing one
        //if the drive had been mounted before.
        BXDrive *existingDrive = [self queuedDriveRepresentingURL: drive.sourceURL];
        
        if (existingDrive)
            drive = existingDrive;
        
        NSError *mountError = nil;
        [self mountDrive: drive
                ifExists: shouldReplace
                 options: BXBundledDriveMountOptions
                   error: &mountError];
    }
	
	//Once all regular drives are in place, check if our target program/folder
    //is now accessible in DOS: if not, add another drive allowing access to it.
	if (self.targetURL && [self shouldMountNewDriveForURL: self.targetURL])
	{
        //Unlike the drives built into the gamebox, we do actually
        //want to show errors if something goes wrong here.
        NSError *mountError = nil;
        [self mountDriveForURL: self.targetURL
                      ifExists: BXDriveReplace
                       options: BXTargetMountOptions
                         error: &mountError];
        
        if (mountError)
        {
            [self presentError: mountError
                modalForWindow: self.windowForSheet
                      delegate: nil
            didPresentSelector: NULL
                   contextInfo: NULL];
        }
	}
}

- (void) _saveGameboxConfiguration: (BXEmulatorConfiguration *)configuration
{
    NSAssert(self.hasGamebox, @"_saveGameboxConfiguration: called with no gamebox.");
    
    NSURL *configurationURL = self.gamebox.configurationFileURL;
	BOOL fileExists = [configurationURL checkResourceIsReachableAndReturnError: NULL];
	
	//Write a new configuration file if the new configuration has any modified settings,
    //or if the gamebox does not have a configuration file yet.
    if (!fileExists || !configuration.isEmpty)
	{
		BXEmulatorConfiguration *gameboxConf = [BXEmulatorConfiguration configurationWithContentsOfURL: configurationURL
                                                                                                 error: NULL];
		
		//If a configuration file exists at that path already, then merge
		//the changes with its existing settings.
		if (gameboxConf)
		{
			[gameboxConf addSettingsFromConfiguration: configuration];
		}
		//Otherwise, use the runtime configuration as our basis
		else
        {
            gameboxConf = configuration;
        }
		
		
		//Add comment preambles to saved configuration
		gameboxConf.preamble = NSLocalizedStringFromTable(@"Configuration preamble", @"Configuration",
                                                          @"Used by generated configuration files as a commented header at the top of the file.");
        gameboxConf.startupCommandsPreamble = NSLocalizedStringFromTable(@"Preamble for startup commands", @"Configuration",
                                                                         @"Used in generated configuration files as a commented header underneath the [autoexec] section.");
		
		
		//Compare against the combined configuration we'll inherit from Boxer's base settings plus
        //the profile-specific configurations (if any), and eliminate any duplicate configuration
        //parameters from the gamebox conf. This way, we don't persist settings we don't need to.
        NSURL *baseConfURL = [[NSBundle mainBundle] URLForResource: @"Preflight"
                                                     withExtension: @"conf"
                                                      subdirectory: @"Configurations"];
        
        NSAssert(baseConfURL != nil, @"Missing preflight conf file");
        BXEmulatorConfiguration *baseConf = [BXEmulatorConfiguration configurationWithContentsOfURL: baseConfURL
                                                                                              error: NULL];
        
        [baseConf removeStartupCommands];
        
		for (NSString *profileConfName in self.gameProfile.configurations)
        {
			NSURL *profileConfURL = [[NSBundle mainBundle] URLForResource: profileConfName
                                                            withExtension: @"conf"
                                                             subdirectory: @"Configurations"];
			
            NSAssert1(profileConfURL != nil, @"Missing configuration file: %@", profileConfName);
            if (profileConfURL)
            {
                BXEmulatorConfiguration *profileConf = [BXEmulatorConfiguration configurationWithContentsOfURL: profileConfURL
                                                                                                         error: NULL];
                if (profileConf)
                    [baseConf addSettingsFromConfiguration: profileConf];
            }
		}
        
        [gameboxConf excludeDuplicateSettingsFromConfiguration: baseConf];
        
		[gameboxConf writeToURL: configurationURL error: NULL];
	}
}

- (void) _cleanup
{
	//Delete the temporary folder, if one was created
	if (self.temporaryFolderURL)
	{
		NSFileManager *manager = [NSFileManager defaultManager];
		[manager removeItemAtURL: self.temporaryFolderURL error: NULL];
	}
	
	//Cancel any in-progress operations specific to this session
	[self.importQueue cancelAllOperations];
    [self.scanQueue cancelAllOperations];
    
	[self.importQueue waitUntilAllOperationsAreFinished];
	[self.scanQueue waitUntilAllOperationsAreFinished];
    
    //Remove any notifications that were posted by this session
    [[ADBUserNotificationDispatcher dispatcher] removeAllNotificationsOfType: nil fromSender: self];
    
    //Clean up our relationship with the documentation panel (which is otherwise a circular relationship.)
    if (self.documentationPanelController.session == self)
    {
        [self.documentationPanelController close];
        self.documentationPanelController.session = nil;
    }
}


#pragma mark -
#pragma mark Pause-state handling

+ (NSSet *) keyPathsForValuesAffectingProgramIsActive
{
    return [NSSet setWithObjects: @"paused", @"autopaused", @"emulating", @"emulator.isAtPrompt", nil];
}

- (BOOL) programIsActive
{
    if (self.isPaused || self.isAutoPaused) return NO;
    if (!self.isEmulating) return NO;
    
    @synchronized(self.emulator)
    {
        if (self.emulator.isAtPrompt) return NO;
    }
    
    return YES;
}

- (void) setPaused: (BOOL)flag
{
	if (self.paused != flag)
	{
		_paused = flag;
		[self _syncSuspendedState];
	}
}

- (void) setInterrupted: (BOOL)flag
{
	if (self.interrupted != flag)
	{
		_interrupted = flag;
		[self _syncSuspendedState];
	}
}

- (void) setAutoPaused: (BOOL)flag
{
	if (self.autoPaused != flag)
	{
		_autoPaused = flag;
		[self _syncSuspendedState];
	}
}

- (void) setSuspended: (BOOL)flag
{
	if (_suspended != flag)
	{
        //Enable/disable display-sleep suppression
        [self _syncSuppressesDisplaySleep];
        
		_suspended = flag;
        
		//Tell the emulator to prepare for being suspended, or to resume after we unpause.
        if (self.suspended)
        {
            [self.emulator pause];
        }
        else
        {
            [self.emulator resume];
        }
        
        if (!self.emulator.isConcurrent)
        { 
            //The suspended state is only checked inside the event loop
            //inside -emulatorDidBeginRunLoop:, which only processes when
            //there's any events in the queue. We post a dummy event to ensure
            //that the loop ticks over and recognises the pause state.
            NSEvent *dummyEvent = [NSEvent otherEventWithType: NSApplicationDefined
                                                     location: NSZeroPoint
                                                modifierFlags: 0
                                                    timestamp: CFAbsoluteTimeGetCurrent()
                                                 windowNumber: 0
                                                      context: nil
                                                      subtype: 0
                                                        data1: 0
                                                        data2: 0];
            
            [NSApp postEvent: dummyEvent atStart: NO];
        }
	}
}

- (void) _syncSuspendedState
{
	self.suspended = (self.paused || self.autoPaused || (self.interrupted && !self.emulator.isConcurrent));
}

- (void) _syncAutoPausedState
{
    self.autoPaused = [self _shouldAutoPause];
}

- (BOOL) _shouldAutoPause
{
	//Don't auto-pause if the emulator hasn't finished starting up yet.
	if (!self.isEmulating) return NO;
	
    //Always autopause when the DOS window is showing the launcher panel.
    if (self.DOSWindowController.currentPanel == BXDOSWindowLaunchPanel)
    {
        return YES;
    }
    
	//Otherwise, only allow auto-pausing if the "Auto-pause in background" toggle is enabled in the user's settings.
	if ([[NSUserDefaults standardUserDefaults] boolForKey: @"pauseWhileInactive"])
    {
        //Auto-pause if Boxer is in the background.
        if (![NSApp isActive]) return YES;
        
        //Auto-pause if the DOS window is miniaturized.
        //IMPLEMENTATION NOTE: we used to toggle this when the DOS window was hidden (not visible),
        //but that gave rise to corner cases if shouldAutoPause was called just before the window
        //was to appear.
        if (self.DOSWindowController.window.isMiniaturized)
            return YES;
    }
	
    return NO;
}

- (void) _interruptionWillBegin: (NSNotification *)notification
{
    //TODO: increment interruptions?
    self.interrupted = YES;
}

- (void) _interruptionDidFinish: (NSNotification *)notification
{
    self.interrupted = NO;
}

- (void) _registerForPauseNotifications
{
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	
	[center addObserver: self
			   selector: @selector(_syncAutoPausedState)
				   name: NSWindowDidMiniaturizeNotification
				 object: self.DOSWindowController.window];
	
	[center addObserver: self
			   selector: @selector(_syncAutoPausedState)
				   name: NSWindowDidDeminiaturizeNotification
				 object: self.DOSWindowController.window];
	
	[center addObserver: self
			   selector: @selector(_syncAutoPausedState)
				   name: NSApplicationDidResignActiveNotification
				 object: NSApp];
	
	[center addObserver: self
			   selector: @selector(_syncAutoPausedState)
				   name: NSApplicationDidBecomeActiveNotification
				 object: NSApp];
	
	[center addObserver: self
			   selector: @selector(_interruptionWillBegin:)
				   name: NSMenuDidBeginTrackingNotification
				 object: nil];
	
	[center addObserver: self
			   selector: @selector(_interruptionDidFinish:)
				   name: NSMenuDidEndTrackingNotification
				 object: nil];
	
	[center addObserver: self
			   selector: @selector(_interruptionWillBegin:)
				   name: BXWillBeginInterruptionNotification
				 object: nil];
	
	[center addObserver: self
			   selector: @selector(_interruptionDidFinish:)
				   name: BXDidFinishInterruptionNotification
				 object: nil];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    if (object == self.DOSWindowController && [keyPath isEqualToString: @"currentPanel"])
    {
        [self _syncAutoPausedState];
    }
}

- (void) _deregisterForPauseNotifications
{
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	
	[center removeObserver: self name: NSWindowWillMiniaturizeNotification object: nil];
	[center removeObserver: self name: NSWindowDidDeminiaturizeNotification object: nil];
    
	[center removeObserver: self name: NSMenuDidEndTrackingNotification object: nil];
	[center removeObserver: self name: NSMenuDidBeginTrackingNotification object: nil];
	
	[center removeObserver: self name: NSApplicationWillResignActiveNotification object: nil];
	[center removeObserver: self name: NSApplicationDidBecomeActiveNotification object: nil];
	
	[center removeObserver: self name: BXWillBeginInterruptionNotification object: nil];
	[center removeObserver: self name: BXDidFinishInterruptionNotification object: nil];
}


#pragma mark -
#pragma mark Power management

- (BOOL) suppressesDisplaySleep
{
    return (_displaySleepAssertionID != kIOPMNullAssertionID);
}

- (void) setSuppressesDisplaySleep: (BOOL)flag
{
    if (flag != self.suppressesDisplaySleep)
    {
        if (flag)
        {
            NSString *reason = NSLocalizedString(@"Emulating DOS application", @"A reason supplied to the power management system for why Boxer is preventing the Mac's display from sleeping. Must be 128 characters or less");
            
            IOReturn success = IOPMAssertionCreateWithName(kIOPMAssertionTypeNoDisplaySleep, 
                                                           kIOPMAssertionLevelOn,
                                                           (CFStringRef)reason,
                                                           &_displaySleepAssertionID);
            if (success != kIOReturnSuccess)
            {
                _displaySleepAssertionID = kIOPMNullAssertionID;
            }
        }
        else
        {
            IOPMAssertionRelease(_displaySleepAssertionID);
            _displaySleepAssertionID = kIOPMNullAssertionID;
        }
    }
}

- (BOOL) _shouldSuppressDisplaySleep
{
    if (!self.isEmulating) return NO;
    if (self.isPaused || self.isAutoPaused) return NO;
    if (self.emulator.isAtPrompt) return NO;
    return YES;
}

- (void) _syncSuppressesDisplaySleep
{
    self.suppressesDisplaySleep = [self _shouldSuppressDisplaySleep];
}


#pragma mark - Undo management

- (NSUndoManager *) undoManagerForClient: (id <ADBUndoable>)undoClient operation: (SEL)operation
{
    return self.undoManager;
}

- (void) removeAllUndoActionsForClient: (id <ADBUndoable>)undoClient
{
    [self.undoManager removeAllActionsWithTarget: undoClient];
}

@end
