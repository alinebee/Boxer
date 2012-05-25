/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXAppController+BXSupportFiles.h"
#import "BXAppController+BXGamesFolder.h"
#import "BXAppController+BXApplicationModes.h"
#import "BXAppController+BXHotKeys.h"

#import "BXAboutController.h"
#import "BXInspectorController.h"
#import "BXPreferencesController.h"
#import "BXWelcomeWindowController.h"
#import "BXFirstRunWindowController.h"
#import "BXBezelController.h"

#import "BXSession+BXFileManager.h"
#import "BXImportSession.h"
#import "BXEmulator.h"
#import "BXMIDIDeviceMonitor.h"
#import "BXKeyboardEventTap.h"

#import "BXValueTransformers.h"
#import "NSString+BXPaths.h"

#import "BXPostLeopardAPIs.h"
#import "BXAppKitVersionHelpers.h"


NSString * const BXNewSessionParam = @"--openNewSession";
NSString * const BXShowImportPanelParam = @"--showImportPanel";
NSString * const BXImportURLParam = @"--importURL ";
NSString * const BXActivateOnLaunchParam = @"--activateOnLaunch";

#define BXMasterVolumeNumIncrements 12.0f
#define BXMasterVolumeIncrement (1.0f / BXMasterVolumeNumIncrements)

@interface BXAppController ()

//Because we can only run one emulation session at a time, we need to launch a second
//Boxer process for opening additional/subsequent documents
- (void) _launchProcessWithDocumentAtURL: (NSURL *)URL;
- (void) _launchProcessWithImportSessionAtURL: (NSURL *)URL;
- (void) _launchProcessWithUntitledDocument;
- (void) _launchProcessWithImportPanel;

//Whether it's safe to open a new session
- (BOOL) _canOpenDocumentOfClass: (Class)documentClass;

//Cancel a makeDocument/openDocument request after spawning a new process.
//Returns the error that should be used to cancel AppKit's open request.
- (NSError *) _cancelOpening;

@end


@implementation BXAppController
@synthesize currentSession, generalQueue, joystickController, joypadController, MIDIDeviceMonitor, hotkeySuppressionTap;


#pragma mark -
#pragma mark Filetype helper methods

+ (NSString *) localizedVersion
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
}

+ (NSString *) buildNumber
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"];
}


+ (BOOL) otherBoxersActive
{
	NSString *bundleIdentifier	= [[NSBundle mainBundle] bundleIdentifier];
	NSWorkspace *workspace		= [NSWorkspace sharedWorkspace];
	NSUInteger numBoxers = 0;
	
	for (NSDictionary *appDetails in [workspace launchedApplications])
	{
		if ([[appDetails objectForKey: @"NSApplicationBundleIdentifier"] isEqualToString: bundleIdentifier]) numBoxers++;
	}
	return numBoxers > 1;
}


#pragma mark -
#pragma mark Initialization and teardown

+ (void) initialize
{
    if (self == [BXAppController class])
    {
        [self setupDefaults];

        //Create common value transformers
        
        NSValueTransformer *isEmpty		= [[BXArraySizeTransformer alloc] initWithMinSize: 0 maxSize: 0];
        NSValueTransformer *isNotEmpty	= [[BXArraySizeTransformer alloc] initWithMinSize: 1 maxSize: NSIntegerMax];
        NSValueTransformer *capitalizer	= [[BXCapitalizer alloc] init];
        
        BXIconifiedDisplayPathTransformer *pathTransformer = [[BXIconifiedDisplayPathTransformer alloc]
                                                              initWithJoiner: @" ▸ " maxComponents: 0];
        [pathTransformer setMissingFileIcon: [NSImage imageNamed: @"gamefolder"]];
        [pathTransformer setHideSystemRoots: YES];
        
        NSMutableParagraphStyle *pathStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [pathStyle setLineBreakMode: NSLineBreakByTruncatingMiddle];
        [[pathTransformer textAttributes] setObject: pathStyle forKey: NSParagraphStyleAttributeName];
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
}

+ (void) setupDefaults
{
	//We carry a plist of initial values for application preferences
    NSString *defaultsPath	= [[NSBundle mainBundle] pathForResource: @"UserDefaults" ofType: @"plist"];
    NSDictionary *defaults	= [NSDictionary dictionaryWithContentsOfFile: defaultsPath];
	
    [[NSUserDefaults standardUserDefaults] registerDefaults: defaults];
}

- (id) init
{
	if ((self = [super init]))
	{
		generalQueue = [[NSOperationQueue alloc] init];
		[self addApplicationModeObservers];
	}
	return self;
}

- (void) dealloc
{
	//Remove any notification observers we've registered
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[self setCurrentSession: nil], [currentSession release];
	[self setGamesFolderPath: nil], [gamesFolderPath release];
	[self setJoystickController: nil], [joystickController release];
	[self setJoypadController: nil], [joypadController release];
	[self setMIDIDeviceMonitor: nil], [MIDIDeviceMonitor release];
	[self setHotkeySuppressionTap: nil], [hotkeySuppressionTap release];
	
	[generalQueue release], generalQueue = nil;
	
	[super dealloc];
}


#pragma mark -
#pragma mark Application open/closing behaviour


//Quit after the last window was closed if we are a 'subsidiary' process,
//to avoid leaving extra Boxers littering the Dock
- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)sender
{
	return [[self class] otherBoxersActive];
}

- (void) applicationWillFinishLaunching: (NSNotification *)notification
{
    //Set up our keyboard event tap
    self.hotkeySuppressionTap = [[[BXKeyboardEventTap alloc] init] autorelease];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    self.hotkeySuppressionTap.delegate = self;
    [self.hotkeySuppressionTap bind: @"enabled"
                           toObject: defaults
                        withKeyPath: @"suppressSystemHotkeys"
                            options: nil];
    
    
    //Start scanning for MIDI devices now
    self.MIDIDeviceMonitor = [[[BXMIDIDeviceMonitor alloc] init] autorelease];
    [self.MIDIDeviceMonitor start];
    
    //Check if we have any games folder, and if not (and we're allowed to create one automatically)
    //then create one now
    if (![self gamesFolderPath] && ![self gamesFolderChosen] && ![[NSUserDefaults standardUserDefaults] boolForKey: @"showFirstRunPanel"])
    {
        NSString *defaultPath = [[self class] preferredGamesFolderPath];
        [self assignGamesFolderPath: defaultPath
                    withSampleGames: YES
                    shelfAppearance: BXShelfAuto
                    createIfMissing: YES
                              error: nil];
    }
}

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
    //Determine if we were passed any startup parameters we need to act upon
	NSArray *arguments = [[NSProcessInfo processInfo] arguments];
	
	for (NSString *argument in arguments)
	{
		if ([argument isEqualToString: BXNewSessionParam])
			[self openUntitledDocumentAndDisplay: YES error: nil];
		
		else if ([argument isEqualToString: BXShowImportPanelParam])
			[self openImportSessionAndDisplay: YES error: nil];
		
		else if ([argument isEqualToString: BXActivateOnLaunchParam]) 
			[NSApp activateIgnoringOtherApps: YES];
		
		else if ([argument hasPrefix: BXImportURLParam])
		{
			NSString *importPath = [argument substringFromIndex: [BXImportURLParam length]];
			[self openImportSessionWithContentsOfURL: [NSURL fileURLWithPath: importPath] display: YES error: nil];
		}
	}
}

//If no other window was opened during startup, show our startup window.
//Note that this is only called at startup, not when re-focusing the application;
//that functionality is overridden below in applicationShouldHandleReopen:hasVisibleWindows:  
- (BOOL) applicationShouldOpenUntitledFile: (NSApplication *)theApplication
{
	if (![NSApp isHidden])
	{
		BOOL hasDelayed = NO;
        
        //These are disabled as they do not run correctly on Lion
        BOOL useFlipTransitions = !isRunningOnLionOrAbove();
		
        //If the user has not chosen a games folder yet, then show them the first-run panel
        //(This is modal, so execution will not continue until the panel is dismissed.)
		if (![self gamesFolderPath] && ![self gamesFolderChosen] && [[NSUserDefaults standardUserDefaults] boolForKey: @"showFirstRunPanel"])
		{
            if (useFlipTransitions)
            {
                //Perform with a delay to give the Dock icon bouncing time to finish,
                //since the Core Graphics flip animation interrupts this otherwise.
                [NSThread sleepForTimeInterval: 0.4];
                hasDelayed = YES;
                [self orderFrontFirstRunPanelWithTransition: self];
            }
            else
            {
                [self orderFrontFirstRunPanel: self];
            }
		}
        
		switch ([[NSUserDefaults standardUserDefaults] integerForKey: @"startupAction"])
		{
			case BXStartUpWithWelcomePanel:
				if (useFlipTransitions)
				{
					if (!hasDelayed) [NSThread sleepForTimeInterval: 0.4];
					[self orderFrontWelcomePanelWithTransition: self];
				}
				else
				{
					[self orderFrontWelcomePanel: self];
				}
				break;
			case BXStartUpWithGamesFolder:
				[self revealGamesFolder: self];
				break;
			case BXStartUpWithNothing:
			default:
				break;
		}
	}
    return NO;
}

//Don't open a new empty document when switching back to the application:
//instead, show the welcome panel if that's the default startup behaviour.
- (BOOL)applicationShouldHandleReopen: (NSApplication *)theApplication
                    hasVisibleWindows: (BOOL)hasVisibleWindows
{
	if (!hasVisibleWindows && [[NSUserDefaults standardUserDefaults] integerForKey: @"startupAction"] == BXStartUpWithWelcomePanel)
		[self orderFrontWelcomePanel: self];
	
	return NO;
}

- (void) applicationWillTerminate: (NSNotification *)notification
{
	//Disable our hotkey suppression, just to be safe
    [[self hotkeySuppressionTap] setEnabled: NO];
    
    //Tell any remaining documents to close on exit
	//(NSDocumentController doesn't always do so by default)
	for (id document in [NSArray arrayWithArray: [self documents]]) [document close];
	
	//Save our preferences to disk before exiting
	[[NSUserDefaults standardUserDefaults] synchronize];
    
    //Tell the MIDI device scanner to cancel itself
    [[self MIDIDeviceMonitor] cancel];
	
	//Tell any operations in our queue to cancel themselves,
    //and let them finish in case they're performing critical operations
	[generalQueue cancelAllOperations];
	[generalQueue waitUntilAllOperationsAreFinished];
	
	//If we are the last Boxer process, remove any temporary folder on our way out
	if (![[self class] otherBoxersActive])
	{
		NSFileManager *manager = [NSFileManager defaultManager];
		NSString *tempPath = [self temporaryPathCreatingIfMissing: NO];
		[manager removeItemAtPath: tempPath error: NULL];
	}
}


#pragma mark -
#pragma mark Document handling

- (NSArray *) sessions
{
	NSMutableArray *sessions = [NSMutableArray arrayWithCapacity: 1];
	for (id document in [self documents])
	{
		if ([document isKindOfClass: [BXSession class]]) [sessions addObject: document];
	}
	return sessions;
}

//Customise the open panel
- (NSInteger) runModalOpenPanel: (NSOpenPanel *)openPanel
					   forTypes: (NSArray *)extensions
{
	[openPanel setAllowsMultipleSelection: NO];
	[openPanel setCanChooseFiles: YES];
	[openPanel setCanChooseDirectories: YES];
	[openPanel setMessage: NSLocalizedString(@"Choose a gamebox, folder or DOS program to open in DOS.",
											 @"Help text shown at the top of the open panel.")];
	
	//Todo: add an accessory view and delegate to handle special-case requirements.
	//(like installation, or choosing which drive to mount a folder as.) 
	
	return [super runModalOpenPanel: openPanel forTypes: extensions];
}


- (id) openDocumentWithContentsOfURL: (NSURL *)absoluteURL
							 display: (BOOL)displayDocument
							   error: (NSError **)outError
{
	NSString *path = [absoluteURL path];
	
	//First go through our existing sessions, checking if any can open the specified URL.
	//(This will be possible if the URL is accessible to a session's emulated filesystem,
	//and the session is not already running a program.)
	
	//TWEAK: if it’s a gamebox, then check if we have a session open for that gamebox.
	//If so, ask that session to launch the default program in that gamebox (if there is any)
	//or else focus it.
	NSString *type = [self typeForContentsOfURL: absoluteURL error: nil];
	if ([type isEqualToString: @"net.washboardabs.boxer-game-package"])
	{
		for (BXSession *session in [self sessions])
		{
			if ([[[session gamePackage] bundlePath] isEqualToString: path])
			{
				NSString *defaultTarget = [[session gamePackage] targetPath];
				if (defaultTarget) [session openFileAtPath: defaultTarget];
				
				[session showWindows];
				return session;
			}
		}
	}
	//For other filetypes, just see if any of the sessions we have can open the file.
	else
	{
		for (BXSession *session in [self sessions])
		{
			if ([session openFileAtPath: path])
			{
				if (displayDocument) [session showWindows];
				return session;
			}
		}		
	}
	
	//If no existing session can open the URL, continue with the default document opening behaviour.
	return [super openDocumentWithContentsOfURL: absoluteURL display: displayDocument error: outError];
}

//Prevent the opening of new documents if we have a session already active
- (id) makeUntitledDocumentOfType: (NSString *)typeName error: (NSError **)outError
{
	[self hideWelcomePanel: self];
	if (![self _canOpenDocumentOfClass: [self documentClassForType: typeName]])
	{
		//Launch another instance of Boxer to open the new session
		[self _launchProcessWithUntitledDocument];
		NSError *cancelError = [self _cancelOpening];
        if (outError) *outError = cancelError;
		return nil;
	}
	else return [super makeUntitledDocumentOfType: typeName error: outError];
}

- (id) makeDocumentWithContentsOfURL: (NSURL *)absoluteURL
							  ofType: (NSString *)typeName
							   error: (NSError **)outError
{
	[self hideWelcomePanel: self];
	if (![self _canOpenDocumentOfClass: [self documentClassForType: typeName]])
	{
		//Launch another instance of Boxer to open the specified document
		[self _launchProcessWithDocumentAtURL: absoluteURL];
		NSError *cancelError = [self _cancelOpening];
        if (outError) *outError = cancelError;
		return nil;
	}
	else return [super makeDocumentWithContentsOfURL: absoluteURL
											  ofType: typeName
											   error: outError];
}

- (id) makeDocumentForURL: (NSURL *)absoluteDocumentURL
		withContentsOfURL: (NSURL *)absoluteDocumentContentsURL
				   ofType: (NSString *)typeName
					error: (NSError **)outError
{
	[self hideWelcomePanel: self];
	if (![self _canOpenDocumentOfClass: [self documentClassForType: typeName]])
	{
		//Launch another instance of Boxer to open the specified document
		[self _launchProcessWithDocumentAtURL: absoluteDocumentContentsURL];
		NSError *cancelError = [self _cancelOpening];
        if (outError) *outError = cancelError;
		return nil;
	}
	else return [super makeDocumentForURL: absoluteDocumentURL
						withContentsOfURL: absoluteDocumentContentsURL
								   ofType: typeName
									error: outError];
}

- (id) openImportSessionAndDisplay: (BOOL)displayDocument error: (NSError **)outError
{
	[self hideWelcomePanel: self];
	//If it's too late for us to open an import session, launch a new Boxer process to do it
	if (![self _canOpenDocumentOfClass: [BXImportSession class]])
	{
		[self _launchProcessWithImportPanel];
		NSError *cancelError = [self _cancelOpening];
        if (outError) *outError = cancelError;
		return nil;
	}
	else
	{
		BXImportSession *importer = [[BXImportSession alloc] initWithType: nil error: outError];
		if (importer)
		{
			[self addDocument: importer];
			if (displayDocument)
			{
				[importer makeWindowControllers];
				[importer showWindows];
			}
		}
		return [importer autorelease];
	}
}

- (id) openImportSessionWithContentsOfURL: (NSURL *)url
                                  display: (BOOL)displayDocument
                                    error: (NSError **)outError
{
	[self hideWelcomePanel: self];
	//If it's too late for us to open an import session, launch a new Boxer process to do it
	if (![self _canOpenDocumentOfClass: [BXImportSession class]])
	{
		[self _launchProcessWithImportSessionAtURL: url];
		NSError *cancelError = [self _cancelOpening];
        if (outError) *outError = cancelError;
		return nil;
	}
	else
	{
		BXImportSession *importer = [[BXImportSession alloc] initWithContentsOfURL: url
                                                                            ofType: nil
                                                                             error: outError];
		if (importer)
		{
			[self addDocument: importer];
			if (displayDocument)
			{
				[importer makeWindowControllers];
				[importer showWindows];
			}
		}
		return [importer autorelease];
	}
}

- (void) noteNewRecentDocument: (NSDocument *)theDocument
{
	//Don't add incomplete game imports to the Recent Documents list.
	if ([theDocument respondsToSelector: @selector(importStage)] &&
		[(id)theDocument importStage] != BXImportSessionFinished)
	{
		return;
	}
	else
	{
		[super noteNewRecentDocument: theDocument];
	}
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
	if ([self currentSession] == theDocument) [self setCurrentSession: nil];
	
	//Hide the Inspector panel if there's no longer any sessions open
	if (![self currentSession]) [[BXInspectorController controller] setPanelShown: NO];
}



#pragma mark -
#pragma mark Spawning document processes

- (void) _launchProcessWithDocumentAtURL: (NSURL *)URL
{	
	NSString *executablePath	= [[NSBundle mainBundle] executablePath];
	NSArray *params				= [NSArray arrayWithObjects: [URL path], BXActivateOnLaunchParam, nil]; 
	[NSTask launchedTaskWithLaunchPath: executablePath arguments: params];
}

- (void) _launchProcessWithUntitledDocument
{
	NSString *executablePath	= [[NSBundle mainBundle] executablePath];
	NSArray *params				= [NSArray arrayWithObjects: BXNewSessionParam, BXActivateOnLaunchParam, nil]; 
	[NSTask launchedTaskWithLaunchPath: executablePath arguments: params];	
}

- (void) _launchProcessWithImportPanel
{
	NSString *executablePath	= [[NSBundle mainBundle] executablePath];
	NSArray *params				= [NSArray arrayWithObjects: BXShowImportPanelParam, BXActivateOnLaunchParam, nil]; 
	[NSTask launchedTaskWithLaunchPath: executablePath arguments: params];	
}

- (void) _launchProcessWithImportSessionAtURL: (NSURL *)URL
{
	NSString *executablePath	= [[NSBundle mainBundle] executablePath];
	NSString *URLParam			= [BXImportURLParam stringByAppendingString: [URL path]];
	NSArray *params				= [NSArray arrayWithObjects: BXActivateOnLaunchParam, URLParam, nil]; 
	[NSTask launchedTaskWithLaunchPath: executablePath arguments: params];	
}

- (NSError *) _cancelOpening
{
	//If we don't have a current session going, exit after cancelling
	if (![self currentSession]) [NSApp terminate: self];
	
	//Otherwise, cancel the existing open request without generating an error message,
	//and we'll leave the current session going
	return [NSError errorWithDomain: NSCocoaErrorDomain
                               code: NSUserCancelledError
                           userInfo: nil];
}

- (BOOL) _canOpenDocumentOfClass: (Class)documentClass
{
	if ([documentClass isSubclassOfClass: [BXSession class]])
	{
		//Only allow a session to open if no emulator has started yet,
		//and no other sessions are open (which could start their own emulators)
		if (![BXEmulator canLaunchEmulator]) return NO;
		if ([[self sessions] count] > 0) return NO;
	}
	return YES;
}


#pragma mark -
#pragma mark Actions and action helper methods

- (IBAction) orderFrontWelcomePanel: (id)sender
{
	[[BXWelcomeWindowController controller] showWindow: sender];
}

- (IBAction) orderFrontWelcomePanelWithTransition: (id)sender
{	
	[[BXWelcomeWindowController controller] showWindowWithTransition: sender];
}

- (IBAction) orderFrontFirstRunPanel: (id)sender
{
	//The welcome panel and first-run panel are mutually exclusive.
	[self hideWelcomePanel: self];
	
	[[BXFirstRunWindowController controller] showWindow: sender];
}

- (IBAction) orderFrontFirstRunPanelWithTransition: (id)sender
{
	//The welcome panel and first-run panel are mutually exclusive.
	[self hideWelcomePanel: self];
	
	[[BXFirstRunWindowController controller] showWindowWithTransition: sender];
}

- (IBAction) hideWelcomePanel: (id)sender
{
	[[[BXWelcomeWindowController controller] window] orderOut: self];
}

- (IBAction) orderFrontImportGamePanel: (id)sender
{
	//If we already have an import session active, just bring it to the front
	for (BXSession *session in [self sessions])
	{
		if ([session isKindOfClass: [BXImportSession class]])
		{
			[session showWindows];
			return;
		}
	}
	//Otherwise, launch a new import session
	[self openImportSessionAndDisplay: YES error: nil];
}

- (IBAction) orderFrontAboutPanel: (id)sender
{
	[[BXAboutController controller] showWindow: sender];
}
- (IBAction) orderFrontPreferencesPanel: (id)sender
{
	[[BXPreferencesController controller] showWindow: sender];
}

- (IBAction) toggleInspectorPanel: (id)sender
{
	BXInspectorController *controller = [BXInspectorController controller];
	BOOL show = ![controller panelShown];
	if (!show || [[self currentSession] isEmulating])
	{
		[controller setPanelShown: show];		
	}
}

- (IBAction) orderFrontInspectorPanel: (id)sender
{
	if ([[self currentSession] isEmulating])
	{
		[[BXInspectorController controller] showWindow: sender];
	}
}

//These are passthroughs for when BXInspectorController isn't in the responder chain
- (IBAction) showGamePanel:		(id)sender	{ [[BXInspectorController controller] showGamePanel: sender]; }
- (IBAction) showCPUPanel:		(id)sender	{ [[BXInspectorController controller] showCPUPanel: sender]; }
- (IBAction) showDrivesPanel:	(id)sender	{ [[BXInspectorController controller] showDrivesPanel: sender]; }
- (IBAction) showMousePanel:	(id)sender	{ [[BXInspectorController controller] showMousePanel: sender]; }



- (IBAction) showWebsite:			(id)sender	{ [self openURLFromKey: @"WebsiteURL"]; }
- (IBAction) showDonationPage:		(id)sender	{ [self openURLFromKey: @"DonationURL"]; }
- (IBAction) showBugReportPage:		(id)sender	{ [self openURLFromKey: @"BugReportURL"]; }
- (IBAction) showPerianDownloadPage:(id)sender	{ [self openURLFromKey: @"PerianURL"]; }
- (IBAction) showJoypadDownloadPage:(id)sender	{ [self openURLFromKey: @"JoypadURL"]; }
- (IBAction) showUniversalAccessPrefsPane: (id)sender
{
    NSString *systemLibraryPath = [NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSSystemDomainMask, NO) objectAtIndex: 0];
    NSString *prefsPanePath = [systemLibraryPath stringByAppendingPathComponent: @"PreferencePanes/UniversalAccessPref.prefPane"];
    [[NSWorkspace sharedWorkspace] openFile: prefsPanePath];
}

- (IBAction) sendEmail: (id)sender
{
	NSString *subject		= @"Boxer feedback";
	NSString *versionName	= [[self class] localizedVersion];
	NSString *buildNumber	= [[self class] buildNumber];
	NSString *fullSubject	= [NSString stringWithFormat: @"%@ (v%@ %@)", subject, versionName, buildNumber];
	[self sendEmailFromKey: @"ContactEmail" withSubject: fullSubject];
}

- (BOOL) validateUserInterfaceItem: (id)theItem
{	
	SEL theAction = [theItem action];
	
	if (theAction == @selector(revealCurrentSessionPath:))
		return ([[self currentSession] isGamePackage] || [[self currentSession] currentPath] != nil);
		
	//Don't allow any of the following actions while a modal window is active.
	if ([NSApp modalWindow]) return NO;
	
	//Don't allow the Inspector panel to be shown if there's no active session.
	if (theAction == @selector(toggleInspectorPanel:) ||
		theAction == @selector(orderFrontInspectorPanel:) ||
        theAction == @selector(showGamePanel:) ||
        theAction == @selector(showCPUPanel:) ||
        theAction == @selector(showDrivesPanel:) ||
        theAction == @selector(showMousePanel:))
    {
        return [[self currentSession] isEmulating];
    }
	
	//Don't allow game imports or the games folder to be opened if no games folder has been set yet.
	if (theAction == @selector(revealGamesFolder:) ||
		theAction == @selector(orderFrontImportGamePanel:))	return [self gamesFolderPath] != nil;
		
	return [super validateUserInterfaceItem: theItem];
}

- (void) showHelpAnchor: (NSString *)anchor
{
	NSString *bookID = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleHelpBookName"];
	[[NSHelpManager sharedHelpManager] openHelpAnchor: anchor inBook: bookID];
}

- (void) openURLFromKey: (NSString *)infoKey
{
	NSString *URLString = [[NSBundle mainBundle] objectForInfoDictionaryKey: infoKey];
	if ([URLString length]) [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: URLString]];
}

- (void) searchURLFromKey: (NSString *)infoKey withSearchString: (NSString *)search
{
	NSString *encodedSearch = [search stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
	NSString *siteString	= [[NSBundle mainBundle] objectForInfoDictionaryKey: infoKey];
	NSString *URLString		= [NSString stringWithFormat: siteString, encodedSearch];
	if ([URLString length]) [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: URLString]];
}

- (void) sendEmailFromKey: (NSString *)infoKey withSubject:(NSString *)subject
{
	NSString *address = [[NSBundle mainBundle] objectForInfoDictionaryKey: infoKey];
	if ([address length])
	{
		NSString *encodedSubject	= [subject stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
		NSString *mailtoURLString	= [NSString stringWithFormat: @"mailto:%@?subject=%@", address, encodedSubject];
		[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:mailtoURLString]];
	}
}

- (IBAction) revealInFinder: (id)sender
{
	if ([sender respondsToSelector: @selector(representedObject)]) sender = [sender representedObject];
	NSString *path = nil;
	
	//NSString paths
	if ([sender isKindOfClass: [NSString class]])			path = sender;
	//NSURLs and BXDrives
	else if ([sender respondsToSelector: @selector(path)])	path = [sender path];
	//NSDictionaries with paths
	else if ([sender isKindOfClass: [NSDictionary class]])	path = [sender objectForKey: @"path"];	
	
	if (path) [self revealPath: path];	
}

- (IBAction) revealCurrentSessionPath: (id)sender
{
	NSString *path = nil;
	BXSession *session = [self currentSession];
	if (session)
	{
		//When running a gamebox, offer up the gamebox itself
		if ([session isGamePackage]) path = [[session fileURL] path];
		//Otherwise, offer up the current DOS program or directory
		else path = [session currentPath];
	}
	if (path) [self revealPath: path];
}

- (IBAction) openInDefaultApplication: (id)sender
{
	if ([sender respondsToSelector: @selector(representedObject)]) sender = [sender representedObject];
	NSString *path = nil;
	
	//NSString paths
	if ([sender isKindOfClass: [NSString class]])			path = sender;
	//NSURLs and BXDrives
	else if ([sender respondsToSelector: @selector(path)])	path = [sender path];
	//NSDictionaries with paths
	else if ([sender isKindOfClass: [NSDictionary class]])	path = [sender objectForKey: @"path"];	
	
	if (path) [[NSWorkspace sharedWorkspace] openFile: path withApplication: nil andDeactivate: YES];
}

//Displays a file path in Finder. This will display the containing folder of files,
//but will display folders in their own window (so that the DOS Games folder's special appearance is retained.)
- (BOOL) revealPath: (NSString *)filePath
{
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	NSFileManager *manager = [NSFileManager defaultManager];
	
	BOOL isFolder = NO;
	if (![manager fileExistsAtPath: filePath isDirectory: &isFolder]) return NO;
	
	if (isFolder && ![ws isFilePackageAtPath: filePath])
	{
		return [ws selectFile: nil inFileViewerRootedAtPath: filePath];
	}
	else
	{
		return [ws selectFile: filePath inFileViewerRootedAtPath: [filePath stringByDeletingLastPathComponent]];
	}
}


#pragma mark -
#pragma mark Sound-related methods


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
    if (self.muted) return 0.0;
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
