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
#import "NDAlias.h"

#import "BXEmulator+BXDOSFileSystem.h"
#import "BXEmulator+BXShell.h"
#import "BXEmulatorErrors.h"
#import "NSWorkspace+ADBFileTypes.h"
#import "NSString+ADBPaths.h"
#import "NSWorkspace+BXExecutableTypes.h"
#import "BXInputController.h"
#import "NSObject+ADBPerformExtensions.h"
#import "NSKeyedArchiver+ADBArchivingAdditions.h"
#import "ADBUserNotificationDispatcher.h"
#import "NSError+ADBErrorHelpers.h"
#import "NSObject+ADBPerformExtensions.h"

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
#define BXSuccessfulProgramRunningTimeThreshold 10

//How soon after the program starts to enter fullscreen, if the run-programs-in-fullscreen toggle
//is enabled. The delay gives the program time to crash and our program panel time to hide.
#define BXAutoSwitchToFullScreenDelay 0.5

//How soon after launching a program to hide the launch panel.
//This gives the program time to start up/fail miserably.
#define BXSwitchToDOSViewDelay 0.25

//How soon after returning to the DOS prompt to display the launch panel.
#define BXSwitchToLaunchPanelDelay 0.5


#pragma mark -
#pragma mark Gamebox settings keys

//How we will store our gamebox-specific settings in user defaults.
//%@ is the unique identifier for the gamebox.
NSString * const BXGameboxSettingsKeyFormat     = @"BXGameSettings: %@";
NSString * const BXGameboxSettingsNameKey       = @"BXGameName";
NSString * const BXGameboxSettingsProfileKey    = @"BXGameProfile";
NSString * const BXGameboxSettingsProfileVersionKey = @"BXGameProfileVersion";
NSString * const BXGameboxSettingsLastLocationKey = @"BXGameLastLocation";

NSString * const BXGameboxSettingsShowProgramPanelKey = @"showProgramPanel";
NSString * const BXGameboxSettingsStartUpInFullScreenKey = @"startUpInFullScreen";
NSString * const BXGameboxSettingsShowLaunchPanelKey = @"showLaunchPanel";
NSString * const BXGameboxSettingsAlwaysShowLaunchPanelKey = @"alwaysShowLaunchPanel";

NSString * const BXGameboxSettingsDrivesKey     = @"BXQueudDrives";

NSString * const BXGameboxSettingsLastProgramPathKey = @"BXLastProgramPath";
NSString * const BXGameboxSettingsLastProgramLaunchArgumentsKey = @"BXLastProgramLaunchArguments";


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
@synthesize targetPath = _targetPath;
@synthesize targetArguments = _targetArguments;
@synthesize lastExecutedProgramPath = _lastExecutedProgramPath;
@synthesize lastExecutedProgramArguments = _lastExecutedProgramArguments;
@synthesize lastLaunchedProgramPath = _lastLaunchedProgramPath;
@synthesize lastLaunchedProgramArguments = _lastLaunchedProgramArguments;
@synthesize gameProfile = _gameProfile;
@synthesize gameSettings = _gameSettings;
@synthesize drives = _drives;
@synthesize executables = _executables;
@synthesize emulating = _emulating;
@synthesize paused = _paused;
@synthesize autoPaused = _autoPaused;
@synthesize interrupted = _interrupted;
@synthesize suspended = _suspended;
@synthesize cachedIcon = _cachedIcon;

@synthesize importQueue = _importQueue;
@synthesize scanQueue = _scanQueue;
@synthesize temporaryFolderPath = _temporaryFolderPath;
@synthesize MT32MessagesReceived = _MT32MessagesReceived;


#pragma mark -
#pragma mark Helper class methods

+ (BXGameProfile *) profileForPath: (NSString *)path
{
	//Which folder to look in to detect the game we’re running.
	//This will choose any gamebox, Boxer drive folder or floppy/CD volume in the
	//file's path (setting shouldRecurse to YES) if found, falling back on the file's
	//containing folder otherwise (setting shouldRecurse to NO).
	BOOL shouldRecurse = NO;
	NSString *profileDetectionPath = [self gameDetectionPointForPath: path 
											  shouldSearchSubfolders: &shouldRecurse];
	
	//Detect any appropriate game profile for this session
	if (profileDetectionPath)
	{
		//IMPLEMENTATION NOTE: we only scan subfolders of the detection path if it's a gamebox,
		//mountable folder or CD/floppy disk, since these will have a finite and manageable file
		//hierarchy to scan.
		//Otherwise, we restrict our search to just the base folder to avoids massive blowouts
		//if the user opens something big like their home folder or startup disk, and to avoid
		//false positives when opening the DOS Games folder.
		return [BXGameProfile detectedProfileForPath: profileDetectionPath
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
	if ((self = [super init]))
	{
		NSString *defaultsPath = [[NSBundle mainBundle] pathForResource: @"GameDefaults" ofType: @"plist"];
		NSMutableDictionary *defaults = [NSMutableDictionary dictionaryWithContentsOfFile: defaultsPath];
		
		self.drives = [NSMutableDictionary dictionaryWithCapacity: 10];
		self.executables = [NSMutableDictionary dictionaryWithCapacity: 10];
		
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
    
    self.targetPath = nil;
    self.targetArguments = nil;
    self.lastExecutedProgramPath = nil;
    self.lastExecutedProgramArguments = nil;
    self.lastLaunchedProgramPath = nil;
    self.lastLaunchedProgramArguments = nil;
    
    self.drives = nil;
    self.executables = nil;
    
    self.cachedIcon = nil;
    
    self.importQueue = nil;
    self.scanQueue = nil;
    
    self.temporaryFolderPath = nil;
    self.MT32MessagesReceived = nil;
    
	[super dealloc];
}

- (BOOL) readFromURL: (NSURL *)absoluteURL
			  ofType: (NSString *)typeName
			   error: (NSError **)outError
{
	NSWorkspace *workspace	= [NSWorkspace sharedWorkspace];
	NSString *filePath		= absoluteURL.path;
	
	//Set our target launch path to point to this file, if we don't have a target already.
	if (!self.targetPath)
        self.targetPath = filePath;
    
	//Check if the chosen file is located inside a gamebox.
	NSString *gameboxPath = [workspace parentOfFile: filePath
                                      matchingTypes: [NSSet setWithObject: BXGameboxType]];
	
	//If the fileURL is located inside a gamebox, load the gamebox and use the gamebox itself as the fileURL.
	//This way, the DOS window will show the gamebox as the represented file, and our Recent Documents
	//list will likewise show the gamebox instead.
	if (gameboxPath)
	{
		self.gamebox = [[[BXGamebox alloc] initWithPath: gameboxPath] autorelease];
		
        //Check if the user opened the gamebox itself or a specific file/folder inside the gamebox.
        BOOL hasCustomTarget = ![self.targetPath isEqualToString: gameboxPath];
        
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
		    NSString *previousProgramPath = [self.gameSettings objectForKey: BXGameboxSettingsLastProgramPathKey];
            
            //If the program path is relative, resolve it relative to the gamebox.
            if (previousProgramPath && !previousProgramPath.isAbsolutePath)
            {
                NSString *basePath = self.gamebox.gamePath;
                previousProgramPath = [basePath stringByAppendingPathComponent: previousProgramPath];
            }
            
            //Check that the previous target path is still reachable.
            BOOL previousPathAvailable = previousProgramPath && [[NSFileManager defaultManager] fileExistsAtPath: previousProgramPath];
            
            //If the previously-running program is available, launch that.
            if (previousPathAvailable)
            {
                self.targetPath = previousProgramPath;
                self.targetArguments = [self.gameSettings objectForKey: BXGameboxSettingsLastProgramLaunchArgumentsKey];
            }
            //Otherwise, launch the gamebox's default launcher if it has one.
            else
            {
                NSDictionary *defaultLauncher = self.gamebox.defaultLauncher;
                
                //If there's no nominated default launcher, but the gamebox only *has* one launcher,
                //then launch that by default instead.
                if (!defaultLauncher && self.gamebox.launchers.count == 1)
                    defaultLauncher = [self.gamebox.launchers objectAtIndex: 0];
                
                if (defaultLauncher)
                {
                    self.targetPath = [defaultLauncher objectForKey: BXLauncherPathKey];
                    self.targetArguments = [defaultLauncher objectForKey: BXLauncherArgsKey];
                }
            }
        }
        
        //Once we've finished, clear any flags that override the startup program for this game.
        [self.gameSettings removeObjectForKey: BXGameboxSettingsShowLaunchPanelKey];
		
		//FIXME: move the fileURL reset out of here and into a later step: we can't rely on the order
		//in which NSDocument's setFileURL/readFromURL methods are called.
		self.fileURL = [NSURL fileURLWithPath: gameboxPath];
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
    //user defaults and into the user-specific game settings. (v1.3->v1.4)
    NSNumber *startUpInFullScreenFlag = [[NSUserDefaults standardUserDefaults] objectForKey: @"startUpInFullScreen"];
    if (startUpInFullScreenFlag && ![gameSettings objectForKey: BXGameboxSettingsStartUpInFullScreenKey])
    {
        [self.gameSettings setObject: startUpInFullScreenFlag
                              forKey: BXGameboxSettingsStartUpInFullScreenKey];
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

- (NSString *) activeProgramPath
{
    if (self.lastExecutedProgramPath)
        return self.lastExecutedProgramPath;
    else
        return self.lastLaunchedProgramPath;
}

- (NSString *) currentPath
{
	if (self.activeProgramPath)
        return self.activeProgramPath;
	else
        return self.emulator.pathOfCurrentDirectory;
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

//Overridden solely so that NSDocumentController will call canCloseDocumentWithDelegate:
//in the first place. This otherwise should have no effect and should not show up in the UI.
- (BOOL) isDocumentEdited
{
    return self.emulator.isRunningProcess || self.isImportingDrives;
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
						  && self.emulator.isRunningProcess
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
			NSString *timingString = [BXEmulator configStringForGameportTimingMode: strictGameportTiming.integerValue];
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
		
		//Strip out these settings once we're done, so we won't preserve them in user defaults.
		NSArray *confSettings = [NSArray arrayWithObjects: @"CPUSpeed", @"coreMode", @"strictGameportTiming", nil];
		[self.gameSettings removeObjectsForKeys: confSettings];

		//Persist these gamebox-specific configuration into the gamebox's configuration file.
		NSString *configPath = self.gamebox.configurationFilePath;
		[self _saveConfiguration: runtimeConf toFile: configPath];
		
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
        [settingsToPersist setObject: self.gamebox.gameName forKey: BXGameboxSettingsNameKey];
        
        //While we're here, update the game settings to reflect the current location of the gamebox.
        NDAlias *packageLocation = [NDAlias aliasWithPath: self.gamebox.bundlePath];
        if (packageLocation)
            [settingsToPersist setObject: packageLocation.data
                                  forKey: BXGameboxSettingsLastLocationKey];
        
        //Record the state of the drive queues for next time we launch this gamebox.
        if ([self _shouldPersistQueuedDrives])
        {
            //Build a list of what drives the user had queued at the time they quit.
            NSMutableArray *queuedDrives = [NSMutableArray arrayWithCapacity: self.allDrives.count];
            for (BXDrive *drive in self.allDrives)
            {
                //Skip our own internal drives and drives that are bundled into the gamebox.
                if (drive.isHidden || drive.isInternal || [self driveIsBundled: drive])
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
        
        //Record the last-launched program for next time we launch this gamebox.
        if ([self _shouldPersistPreviousProgram])
        {
            NSString *lastProgramPath, *lastArguments;
            if (self.lastExecutedProgramPath)
            {
                lastProgramPath = self.lastExecutedProgramPath;
                lastArguments   = self.lastExecutedProgramArguments;
            }
            else
            {
                lastProgramPath = self.lastLaunchedProgramPath;
                lastArguments   = self.lastLaunchedProgramArguments;
            }
            
            //If we were running a program when we were shut down, then record that;
            //otherwise, record the last directory we were in when we were at the DOS prompt.
            NSString *basePath = self.gamebox.resourcePath;
            if (lastProgramPath)
            {
                //Make the program path relative to the gamebox.
                //TODO: if the program was located outside the gamebox,
                //record it as an alias instead.
                NSString *relativePath = [lastProgramPath pathRelativeToPath: basePath];
                
                [settingsToPersist setObject: relativePath
                                      forKey: BXGameboxSettingsLastProgramPathKey];
                
                if (lastArguments)
                    [settingsToPersist setObject: lastArguments
                                          forKey: BXGameboxSettingsLastProgramLaunchArgumentsKey];
                else
                    [settingsToPersist removeObjectForKey: BXGameboxSettingsLastProgramLaunchArgumentsKey];
                    
            }
            else
            {
                NSString *currentDOSPath = self.emulator.pathOfCurrentDirectory;
                if (currentDOSPath)
                {
                    NSString *relativePath = [currentDOSPath pathRelativeToPath: basePath];
                    [settingsToPersist setObject: relativePath
                                          forKey: BXGameboxSettingsLastProgramPathKey];
                }
                else
                {
                    [settingsToPersist removeObjectForKey: BXGameboxSettingsLastProgramPathKey];
                }
                [settingsToPersist removeObjectForKey: BXGameboxSettingsLastProgramLaunchArgumentsKey];
            }
        }
        //Clear any previous data if we're not overwriting it
        else
        {
            [settingsToPersist removeObjectForKey: BXGameboxSettingsLastProgramPathKey];
            [settingsToPersist removeObjectForKey: BXGameboxSettingsLastProgramLaunchArgumentsKey];
        }
        
        //Store the game settings back into the main user defaults
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
    if ([[NSApp delegate] isStandaloneGameBundle]) return [BXBaseAppController appName];
	else if (self.hasGamebox)       return self.gamebox.gameName;
	else if (self.fileURL)          return [super displayName];
	else                            return self.processDisplayName;
}

- (NSString *) processDisplayName
{
	NSString *processName = nil;
	if (self.emulator.isRunningProcess)
	{
		//Use the active program name where possible;
		//Failing that, fall back on the original process name
		if (self.activeProgramPath)
            processName = self.activeProgramPath.lastPathComponent;
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
    if (!self.cachedIcon && self.hasGamebox)
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
    if (self.gamebox)
    {
        if (![self.cachedIcon isEqual: icon])
        {
            self.cachedIcon = icon;
            self.gamebox.coverArt = icon;
        
            //Force the window's icon to update to account for the new icon.
            [self.DOSWindowController synchronizeWindowTitleWithDocumentName];
        }
    }
}

+ (NSSet *) keyPathsForValuesAffectingHasGamebox        { return [NSSet setWithObject: @"gamebox"]; }
+ (NSSet *) keyPathsForValuesAffectingRepresentedIcon	{ return [NSSet setWithObjects: @"gamebox", @"gamebox.coverArt", nil]; }
+ (NSSet *) keyPathsForValuesAffectingCurrentPath       { return [NSSet setWithObjects: @"activeProgramPath", @"emulator.pathOfCurrentDirectory", nil]; }
+ (NSSet *) keyPathsForValuesAffectingActiveProgramPath { return [NSSet setWithObjects: @"lastExecutedProgramPath", @"lastLaunchedProgramPath", nil]; }



#pragma mark -
#pragma mark Emulator delegate methods and notifications

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
    [configURLs addObject: [appBundle URLForResource: @"Preflight"
                                       withExtension: @"conf"
                                        subdirectory: @"Configurations"]];

	//If we don't have a previously-determined game profile already,
    //detect the game profile from our target path and set it now.
	if (self.targetPath && !self.gameProfile)
	{
		BXGameProfile *profile = [self.class profileForPath: self.targetPath];
        
        //If no specific game can be found, then record the profile explicitly as an unknown game
        //rather than leaving it blank. This stops us trying to redetect it again next time.
        if (!profile) profile = [BXGameProfile genericProfile];
        self.gameProfile = profile;
	}
	
	//Load the appropriate configuration files from our game profile.
    for (NSString *confName in self.gameProfile.configurations)
    {
        NSURL *profileConf = [appBundle URLForResource: confName
                                         withExtension: @"conf"
                                          subdirectory: @"Configurations"];
        
        if (profileConf) [configURLs addObject: profileConf];
        else NSLog(@"Missing configuration profile: %@", confName);
    }
	
	//Next, load the gamebox's own configuration file if it has one.
    NSString *packageConfPath = self.gamebox.configurationFile;
    if (packageConfPath)
        [configURLs addObject: [NSURL fileURLWithPath: packageConfPath isDirectory: NO]];
    
	
    //Last but not least, load Boxer's launch configuration.
    [configURLs addObject: [appBundle URLForResource: @"Launch"
                                       withExtension: @"conf"
                                        subdirectory: @"Configurations"]];
    
    
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
	NSString *target = self.targetPath;
    NSString *arguments = self.targetArguments;
    
	if (target)
	{
        BOOL targetIsExecutable = [self.class isExecutable: target];
        
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
			target = target.stringByDeletingLastPathComponent;
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
        
		[self openFileAtPath: target
               withArguments: arguments
              clearingScreen: YES];
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

- (void) emulatorWillStartProgram: (NSNotification *)notification
{
    //Flag that the program the user launched is now executing.
    _executingLaunchedProgram = YES;
    
    //If we've finished the startup process, then show the DOS view at this point.
    //(We won't show the DOS view before then, because we don't want startup programs
    //to trigger a switch of view: we don't know at that point yet whether the user is
    //overriding the startup program to show the launch panel.)
    if (_hasLaunched)
    {
        [NSObject cancelPreviousPerformRequestsWithTarget: self.DOSWindowController
                                                 selector: @selector(showLaunchPanel)
                                                   object: self];
        
        [self.DOSWindowController performSelector: @selector(showDOSView)
                                       withObject: self
                                       afterDelay: BXSwitchToDOSViewDelay];
    }
    
	//Don't set the active program if we already have one: this way, we keep
	//track of which program the user manually launched, and won't glom onto
    //other programs spawned by the original program (e.g. if it was a batch file.)
	if (!self.lastExecutedProgramPath)
	{
		NSString *programPath = [notification.userInfo objectForKey: BXEmulatorLocalPathKey];
        
        if (programPath.length)
        {
            NSString *arguments = [notification.userInfo objectForKey: BXEmulatorLaunchArgumentsKey];
            self.lastExecutedProgramPath = programPath;
            self.lastExecutedProgramArguments = arguments;
		}
	}
	
	//Track how long this program has run for
	_programStartTime = [NSDate timeIntervalSinceReferenceDate];
    
    //Enable/disable display-sleep suppression
    [self _syncSuppressesDisplaySleep];
}

- (void) emulatorDidFinishProgram: (NSNotification *)notification
{
	//Clear the last executed program when a startup program or 'non-defaultable'
    //program finishes. This way, programWillStart: won't hang onto programs
    //we can't use as the default, such as autoexec commands or dispatch batchfiles.
    
	//Note that we don't clear lastLaunchedProgramPath here, since the program may be
    //passing control on to another program afterwards and we want to maintain a record
    //of which program the user themselves actually launched. Both the last executed
    //and the last launched program are always cleared down in didReturnToShell:.
    
    //FIXME: this is a really convoluted heuristic and we really should redesign this
    //behaviour to better express what we're trying to do (which is: track the programs
    //that the user has chosen to launch themselves.)
	NSString *executedPath = self.lastExecutedProgramPath;
    BOOL executedPathCanBeDefault = (executedPath && _hasLaunched && [self.gamebox validateTargetPath: &executedPath error: nil]);
	if (!executedPathCanBeDefault)
	{
		self.lastExecutedProgramPath = nil;
        self.lastExecutedProgramArguments = nil;
	}
	
	//Check the running time of the program. If it was suspiciously short,
	//then check for possible error conditions that we can inform the user about.
	NSTimeInterval programRunningTime = [NSDate timeIntervalSinceReferenceDate] - _programStartTime; 
	if (programRunningTime < BXWindowsOnlyProgramFailTimeThreshold)
	{
        NSString *programPath = [notification.userInfo objectForKey: @"localPath"];
        if (programPath.length)
        {
            BXExecutableType programType = [[NSWorkspace sharedWorkspace] executableTypeAtPath: programPath
                                                                                         error: NULL];
            
            //If this was a windows-only program, explain further to the user why Boxer cannot run it.
            if (programType == BXExecutableTypeWindows)
            {
                //If the user launched this program directly from Finder, then show
                //a proper alert to the user and offer to close the DOS session.
                if ([programPath isEqualToString: self.targetPath])
                {
                    BXCloseAlert *alert = [BXCloseAlert closeAlertAfterWindowsOnlyProgramExited: programPath];
                    [alert beginSheetModalForWindow: self.windowForSheet
                                      modalDelegate: self
                                     didEndSelector: @selector(_windowsOnlyProgramCloseAlertDidEnd:returnCode:contextInfo:)
                                        contextInfo: NULL];
                    
                }
                //Otherwise, just print out explanatory text at the DOS prompt.
                else
                {
                    NSString *warningFormat = NSLocalizedStringFromTable(@"Windows-only game warning", @"Shell", nil);
                    NSString *programName = programPath.lastPathComponent.uppercaseString;
                    NSString *warningText = [NSString stringWithFormat: warningFormat, programName];
                    [self.emulator displayString: warningText];
                }
            }
        }
	}
}

- (void) emulatorDidReturnToShell: (NSNotification *)notification
{
	//If we should close after exiting, then close down the application now
	if ([self _shouldCloseOnProgramExit])
	{
		[self close];
	}
	
	//If a program has been properly launched, clear the active program.
    //(We don't want to clear it if we've nipped back to the DOS prompt
    //while we're still in the process of launching the program.)
    if (_executingLaunchedProgram)
	{
        _executingLaunchedProgram = NO;
        self.lastExecutedProgramPath = nil;
        self.lastExecutedProgramArguments = nil;
        self.lastLaunchedProgramPath = nil;
        self.lastLaunchedProgramArguments = nil;
	}
    
    //Clear our cache of sent MT-32 messages on behalf of BXAudioControls.
    [self.MT32MessagesReceived removeAllObjects];
    
    //Explicitly disable numpad simulation upon returning to the DOS prompt.
    //Disabled for now until we can record that the user has toggled the option while at the DOS prompt,
    //and conditionally leave it on in that case, to prevent it switching off when executing commands. 
    //self DOSWindowController.inputController.simulatedNumpadActive = NO;
    
        
	//Show the program chooser after returning to the DOS prompt, if appropriate.
	if ([self _shouldShowLaunchPanelAtPrompt])
	{
		[NSObject cancelPreviousPerformRequestsWithTarget: self.DOSWindowController
												 selector: @selector(showDOSView)
												   object: self];
		
		//Switch to the launch panel only after a delay.
		[self.DOSWindowController performSelector: @selector(showLaunchPanel)
                                       withObject: self
                                       afterDelay: BXSwitchToLaunchPanelDelay];
	}
    //Otherwise, ensure we're displaying the DOS view.
    else
    {
        [self.DOSWindowController showDOSView];
    }

    //Enable/disable display-sleep suppression
    [self _syncSuppressesDisplaySleep];
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

- (BOOL) _shouldCloseOnProgramExit
{
    //If we're a standalone game app and the launcher panel is disabled,
    //then close down after exiting to DOS; otherwise, return to the launcher panel.
    if ([[NSApp delegate] isStandaloneGameBundle])
    {
        return !self.allowsLauncherPanel;
    }
    
	//Don't close if the auto-close preference is disabled for this gamebox
	if (!self.gamebox.closeOnExit) return NO;
	
	//Don't close if we launched a program other than the default program for the gamebox
	if (![self.lastLaunchedProgramPath isEqualToString: self.gamebox.targetPath]) return NO;
	
	//Don't close if there are drive imports in progress
	if (self.isImportingDrives) return NO;
	
	//Don't close if the last program quit suspiciously early, since this may be a crash
	NSTimeInterval executionTime = [NSDate timeIntervalSinceReferenceDate] - _programStartTime;
	if (executionTime < BXSuccessfulProgramRunningTimeThreshold) return NO;
	
	//Don't close if the user is currently holding down the Option key override
	CGEventFlags currentModifiers = CGEventSourceFlagsState(kCGEventSourceStateCombinedSessionState);
	BOOL optionKeyDown = (currentModifiers & NSAlternateKeyMask) == NSAlternateKeyMask;
	if (optionKeyDown) return NO;
	
	//If we get this far then go right ahead and die
	return YES;
}

//We leave the panel open when we don't have a default program already
//and can adopt the current program as the default program. This way
//we can ask the user what they want to do with the program.
- (BOOL) _shouldLeaveProgramPanelOpenAfterLaunch
{
    if (!self.gamebox.targetPath)
    {
        NSString *activePath = [[self.activeProgramPath copy] autorelease];
        return [self.gamebox validateTargetPath: &activePath error: NULL];
    }
    else
        return NO;
}

- (BOOL) _shouldShowLaunchPanelAtPrompt
{
    if ([[NSApp delegate] isStandaloneGameBundle])
        return YES;
    
    if (!self.gamebox)
    {
        return NO;
    }
    else
    {
        /*
        NSNumber *showProgramPanel = [self.gameSettings objectForKey: BXGameboxSettingsShowProgramPanelKey];
        if (showProgramPanel != nil)
        {
            return showProgramPanel.boolValue;
        }
        else
        {
            return YES;
        }
        */
        
        //Don't show the launch panel if the user had manually switched to the DOS prompt
        //from the launch panel.
        if (_userSwitchedToDOSPrompt)
            return NO;
        
        //Otherwise, show the damn launch panel.
        return YES;
    }
}

- (void) _startEmulator
{	
	//Set the emulator's current working directory relative to whatever we're opening
	if (self.fileURL)
	{
		NSString *filePath = self.fileURL.path;
		BOOL isFolder = NO;
		if ([[NSFileManager defaultManager] fileExistsAtPath: filePath isDirectory: &isFolder])
		{
			//If we're opening a folder/gamebox, use that as the base path; if we're opening
			//a program or disc image, use its containing folder as the base path instead.
			self.emulator.basePath = (isFolder) ? filePath : filePath.stringByDeletingLastPathComponent;
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
    NSLog(@"Uncaught emulation exception: %@ (%@)", exception.debugDescription, exception.callStackSymbols);
    
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
    if (self.gamebox)
	{
        //TODO: deal with any mounting errors that occurred. Since all this happens automatically
        //during startup, we can't give errors straight to the user as they will seem cryptic.
        		
        //First, mount any bundled drives from the gamebox.
		NSMutableArray *packageVolumes = [NSMutableArray arrayWithCapacity: 10];
		[packageVolumes addObjectsFromArray: self.gamebox.floppyVolumes];
		[packageVolumes addObjectsFromArray: self.gamebox.hddVolumes];
		[packageVolumes addObjectsFromArray: self.gamebox.cdVolumes];
		
		BOOL hasProperDriveC = NO;
        NSString *titleForDriveC = NSLocalizedString(@"Game Drive", @"The display title for the gamebox’s C drive.");
        
        for (NSString *volumePath in packageVolumes)
		{
			BXDrive *bundledDrive = [BXDrive driveFromPath: volumePath atLetter: nil];
            
            //If this will be our C drive, give it a custom title.
            if ([bundledDrive.letter isEqualToString: @"C"])
            {
                hasProperDriveC = YES;
                bundledDrive.title = titleForDriveC;
                
                //If our target was the gamebox itself, rewrite it to point to this C drive
                //so that we'll start up at drive C.
                if ([self.targetPath isEqualToString: self.gamebox.gamePath])
                    self.targetPath = volumePath;
            }
            
            [self mountDrive: bundledDrive
                    ifExists: BXDriveQueue
                     options: BXBundledDriveMountOptions
                       error: nil];
		}
        
        //If we don't have a drive C after mounting all of the gamebox's drives,
        //that means it's an old-style gamebox without an explicit drive C of its own.
        //In this case, mount the gamebox itself as drive C.
        if (!hasProperDriveC)
        {
            BXDrive *packageDrive = [BXDrive hardDriveFromPath: self.gamebox.gamePath
                                                      atLetter: @"C"];
            
            packageDrive.title = titleForDriveC;
            
            [self mountDrive: packageDrive
                    ifExists: BXDriveReplace
                     options: BXBundledDriveMountOptions
                       error: nil];
        }
	}
	
	//Automount all currently mounted floppy and CD-ROM volumes if desired.
    if ([self _shouldAutoMountExternalVolumes])
    {
        [self mountFloppyVolumesWithError: nil];
        [self mountCDVolumesWithError: nil];
	}
    
	//Mount our internal DOS toolkit and temporary drives
	[self mountToolkitDriveWithError: nil];
    if (!self.gameProfile || [self.gameProfile shouldMountTempDrive])
        [self mountTempDriveWithError: nil];
    
    //If the game needs a CD-ROM to be present, then mount a dummy CD drive
    //if necessary.
    if (self.gameProfile.requiresCDROM)
        [self mountDummyCDROMWithError: nil];
    
    
    //Now, restore any drives that the user had in the drives list last time they ran this session.
    NSArray *previousDrives = [self.gameSettings objectForKey: BXGameboxSettingsDrivesKey];
    for (NSData *driveInfo in previousDrives)
    {
        BXDrive *drive = [NSKeyedUnarchiver unarchiveObjectWithData: driveInfo];
        
        //Skip drives that couldn't be decoded (which will happen if the path for the drive
        //had moved or been ejected/deleted in the interim.)
        if (!drive) continue;
        
        //The drive has a flag indicating whether it was currently mounted last time.
        //Read this off, then clear the flag (it'll be reinstated later if we decide to mount it.)
        BOOL driveWasMounted = drive.isMounted;
        drive.mounted = NO;
        
        BXDriveConflictBehaviour shouldReplace = driveWasMounted ? BXDriveReplace : BXDriveQueue;
        
        //Check if we already have a drive queued that represents this drive.
        //If so, we'll ignore the previous drive and just remount the existing one
        //if the drive had been mounted before.
        BXDrive *existingDrive = [self queuedDriveForPath: drive.path];
        
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
	if (self.targetPath && [self shouldMountNewDriveForPath: self.targetPath])
	{
        //Unlike the drives built into the gamebox, we do actually
        //want to show errors if something goes wrong here.
        NSError *mountError = nil;
        [self mountDriveForPath: self.targetPath
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

- (void) _saveConfiguration: (BXEmulatorConfiguration *)configuration toFile: (NSString *)filePath
{
    NSAssert(filePath != nil, @"No file path provided.");
    
	NSFileManager *manager = [NSFileManager defaultManager];
	BOOL fileExists = [manager fileExistsAtPath: filePath];
	
	//Save the configuration if any changes have been made, or if the file at that path does not exist.
	if (!fileExists || !configuration.isEmpty)
	{
		BXEmulatorConfiguration *gameboxConf = [BXEmulatorConfiguration configurationWithContentsOfFile: filePath error: nil];
		
		//If a configuration file exists at that path already, then merge
		//the changes with its existing settings.
		if (gameboxConf)
		{
			[gameboxConf addSettingsFromConfiguration: configuration];
		}
		//Otherwise, use the runtime configuration as our basis
		else gameboxConf = configuration;
		
		
		//Add comment preambles to saved configuration
		gameboxConf.preamble = NSLocalizedStringFromTable(@"Configuration preamble", @"Configuration",
                                                          @"Used by generated configuration files as a commented header at the top of the file.");
        gameboxConf.startupCommandsPreamble = NSLocalizedStringFromTable(@"Preamble for startup commands", @"Configuration",
                                                                         @"Used in generated configuration files as a commented header underneath the [autoexec] section.");
		
		
		//Compare against the combined configuration we'll inherit from Boxer's base settings plus
        //the profile-specific configurations (if any), and eliminate any duplicate configuration
        //parameters from the gamebox conf. This way, we don't persist settings we don't need to.
        NSString *baseConfPath = [[NSBundle mainBundle] pathForResource: @"Preflight"
                                                                 ofType: @"conf"
                                                            inDirectory: @"Configurations"];
        
        NSAssert(baseConfPath != nil, @"Missing preflight conf file");
        BXEmulatorConfiguration *baseConf = [BXEmulatorConfiguration configurationWithContentsOfFile: baseConfPath error: nil];
        
        [baseConf removeStartupCommands];
        
		for (NSString *profileConfName in self.gameProfile.configurations)
        {
			NSString *profileConfPath = [[NSBundle mainBundle] pathForResource: profileConfName
																		ofType: @"conf"
																   inDirectory: @"Configurations"];
			
            NSAssert1(profileConfPath != nil, @"Missing configuration file: %@", profileConfName);
            if (profileConfPath)
            {
                BXEmulatorConfiguration *profileConf = [BXEmulatorConfiguration configurationWithContentsOfFile: profileConfPath error: nil];
                if (profileConf) [baseConf addSettingsFromConfiguration: profileConf];
            }
		}
        
        [gameboxConf excludeDuplicateSettingsFromConfiguration: baseConf];
		
		[gameboxConf writeToFile: filePath error: NULL];
	}
}

- (void) _cleanup
{
	//Delete the temporary folder, if one was created
	if (self.temporaryFolderPath)
	{
		NSFileManager *manager = [NSFileManager defaultManager];
		[manager removeItemAtPath: self.temporaryFolderPath error: NULL];
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
	
	//Only allow auto-pausing if the mode is enabled in the user's settings,
    //or if the emulator is waiting at the DOS prompt.
	if (self.emulator.isAtPrompt ||
        [[NSUserDefaults standardUserDefaults] boolForKey: @"pauseWhileInactive"])
    {
        //Auto-pause if Boxer is in the background.
        if (![NSApp isActive]) return YES;
        
        //Auto-pause if the DOS window is miniaturized.
        //IMPLEMENTATION NOTE: we used to toggle this when the DOS window was hidden (not visible),
        //but that gave rise to corner cases if shouldAutoPause was called just before the window
        //was to appear.
        if (self.DOSWindowController.window.isMiniaturized)
            return YES;
        
        //Autopause if the DOS window is showing the launcher panel.
        if (self.DOSWindowController.currentPanel == BXDOSWindowLaunchPanel)
        {
            return YES;
        }
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
