/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXAppController.h"
#import "BXAppController+BXGamesFolder.h"
#import "BXAppController+BXApplicationModes.h"

#import "BXAboutController.h"
#import "BXInspectorController.h"
#import "BXPreferencesController.h"
#import "BXWelcomeWindowController.h"
#import "BXFirstRunWindowController.h"

#import "BXSession+BXFileManager.h"
#import "BXImportSession.h"
#import "BXEmulator.h"

#import "BXValueTransformers.h"
#import "BXGrowlController.h"
#import "NSString+BXPaths.h"

#import <BGHUDAppKit/BGThemeManager.h>
#import "BXThemes.h"


NSString * const BXNewSessionParam = @"--openNewSession";
NSString * const BXShowImportPanelParam = @"--showImportPanel";
NSString * const BXImportURLParam = @"--importURL ";
NSString * const BXActivateOnLaunchParam = @"--activateOnLaunch";

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
- (void) _cancelOpeningWithError: (NSError **)outError;

//If no document has been opened at startup, perform our standard post-launch action (displaying the welcome panel etc.)
//This is called after application:didFinishLaunching:, and once any windows have been restored by Lion.
- (void) _performPostLaunchActions;
@end


@implementation BXAppController
@synthesize currentSession, generalQueue, joystickController, joypadController;


#pragma mark -
#pragma mark Filetype helper methods

+ (NSSet *) hddVolumeTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
						 @"net.washboardabs.boxer-harddisk-folder",
						 nil];
	return types;
}

+ (NSSet *) cdVolumeTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
						 @"com.goldenhawk.cdrwin-cuesheet",
						 @"net.washboardabs.boxer-cdrom-folder",
						 @"net.washboardabs.boxer-cdrom-bundle",
						 @"public.iso-image",
						 @"com.apple.disk-image-cdr",
						 nil];
	return types;
}

+ (NSSet *) floppyVolumeTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
						 @"net.washboardabs.boxer-floppy-folder",
						 @"com.winimage.raw-disk-image",
						 nil];
	return types;
}

+ (NSSet *) mountableFolderTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
						 @"net.washboardabs.boxer-mountable-folder",
						 nil];
	return types;
}

+ (NSSet *) mountableImageTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
						 @"public.iso-image",					//.iso
						 @"com.apple.disk-image-cdr",			//.cdr
						 @"com.goldenhawk.cdrwin-cuesheet",		//.cue
						 @"net.washboardabs.boxer-disk-bundle", //.cdmedia
						 @"com.winimage.raw-disk-image",		//.ima
						 nil];
	return types;
}

+ (NSSet *) mountableTypes
{
	static NSSet *types = nil;
	if (!types) types = [[[self mountableImageTypes] setByAddingObject: @"public.directory"] retain];
	return types;
}

+ (NSSet *) executableTypes
{
	static NSSet *types = nil;
	if (!types) types = [[NSSet alloc] initWithObjects:
						 @"com.microsoft.windows-executable",	//.exe
						 @"com.microsoft.msdos-executable",		//.com
						 @"com.microsoft.batch-file",			//.bat
						 nil];
	return types;
}

+ (BOOL) isRunningOnLeopard
{
	return (floor(NSAppKitVersionNumber) <= NSAppKitVersionNumber10_5);
}

+ (BOOL) isRunningOnSnowLeopard
{
	double appKitVersion = floor(NSAppKitVersionNumber);
	return (appKitVersion <= NSAppKitVersionNumber10_6 && appKitVersion > NSAppKitVersionNumber10_5);
}

+ (BOOL) isRunningOnLion
{
	double appKitVersion = floor(NSAppKitVersionNumber);
	return (appKitVersion > NSAppKitVersionNumber10_6);
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

+ (NSString *) supportPathCreatingIfMissing: (BOOL)createIfMissing
{
	NSString *basePath = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) objectAtIndex: 0];
	NSString *supportPath = [basePath stringByAppendingPathComponent: @"Boxer"];
	
	if (createIfMissing)
	{
		[[NSFileManager defaultManager] createDirectoryAtPath: supportPath
								  withIntermediateDirectories: YES
												   attributes: nil
														error: NULL];
	}
	return supportPath;
}

+ (NSString *) temporaryPathCreatingIfMissing: (BOOL)createIfMissing
{
	NSString *basePath = NSTemporaryDirectory();
	NSString *tempPath = [basePath stringByAppendingPathComponent: @"Boxer"];
	
	if (createIfMissing)
	{
		[[NSFileManager defaultManager] createDirectoryAtPath: tempPath
								  withIntermediateDirectories: YES
												   attributes: nil
														error: NULL];
	}
	return tempPath;
}

#pragma mark -
#pragma mark Initialization and teardown

+ (void) initialize
{
	[self setupDefaults];

	//Create common value transformers
	
	NSValueTransformer *isEmpty		= [[BXArraySizeTransformer alloc] initWithMinSize: 0 maxSize: 0];
	NSValueTransformer *isNotEmpty	= [[BXArraySizeTransformer alloc] initWithMinSize: 1 maxSize: NSIntegerMax];
	NSValueTransformer *capitalizer	= [BXCapitalizer new];
	
	BXIconifiedDisplayPathTransformer *pathTransformer = [[BXIconifiedDisplayPathTransformer alloc] initWithJoiner: @" ▸ " maxComponents: 0];
	[pathTransformer setMissingFileIcon: [NSImage imageNamed: @"gamefolder"]];
	[pathTransformer setHideSystemRoots: YES];
	NSMutableParagraphStyle *pathStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	[pathStyle setLineBreakMode: NSLineBreakByTruncatingMiddle];
	[[pathTransformer textAttributes] setObject: [pathStyle autorelease] forKey: NSParagraphStyleAttributeName];
	
	[NSValueTransformer setValueTransformer: [isEmpty autorelease]		forName: @"BXArrayIsEmpty"];
	[NSValueTransformer setValueTransformer: [isNotEmpty autorelease]	forName: @"BXArrayIsNotEmpty"];	
	[NSValueTransformer setValueTransformer: [capitalizer autorelease]	forName: @"BXCapitalizedString"];	
	[NSValueTransformer setValueTransformer: [pathTransformer autorelease] forName: @"BXIconifiedGamesFolderPath"];
	
	//Initialise our Growl notifier instance
	[GrowlApplicationBridge setGrowlDelegate: [BXGrowlController controller]];

	//Register our BGHUD UI themes
	[[BGThemeManager keyedManager] setTheme: [[BXShadowedTextTheme new] autorelease]	forKey: @"BXShadowedTextTheme"];
	[[BGThemeManager keyedManager] setTheme: [[BXHelpTextTheme new] autorelease]		forKey: @"BXHelpTextTheme"];
	[[BGThemeManager keyedManager] setTheme: [[BXBlueTheme new] autorelease]			forKey: @"BXBlueTheme"];
	[[BGThemeManager keyedManager] setTheme: [[BXBlueprintTheme new] autorelease]		forKey: @"BXBlueprintTheme"];
	[[BGThemeManager keyedManager] setTheme: [[BXBlueprintHelpText new] autorelease]	forKey: @"BXBlueprintHelpText"];
	[[BGThemeManager keyedManager] setTheme: [[BXWelcomeTheme new] autorelease]			forKey: @"BXWelcomeTheme"];
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


//Don't open a new empty document when switching back to the application:
//instead, show the welcome panel if that's the default startup behaviour.
- (BOOL) applicationShouldOpenUntitledFile: (NSApplication *)theApplication
{
	if (hasFinishedLaunching && 
		[[NSUserDefaults standardUserDefaults] integerForKey: @"startupAction"] == BXStartUpWithWelcomePanel)
		[self orderFrontWelcomePanel: self];
	
	return NO;
}

- (void) applicationWillFinishLaunching:(NSNotification *)notification
{
	//Sync Spaces shortcuts at startup in case we previously crashed
	//and left them overridden
	[self syncSpacesKeyboardShortcuts];
}

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
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

    //Defer our default post-launch actions to the end of the current event cycle,
    //once after Lion has finished restoring windows.
    [self performSelector: @selector(_performPostLaunchActions) withObject: nil afterDelay: 0.1];
}

- (void) _performPostLaunchActions
{
    //If no document was opened during startup, and we didn't launch hidden,
	//then display the chosen startup window
	if (![NSApp isHidden] && ![[self documents] count] && ![[NSApp windows] count])
	{
		BOOL hasDelayed = NO;
        
        //These are disabled as they do not run correctly on Lion
        BOOL useFlipTransitions = ![[self class] isRunningOnLion];
		
		//If the user has not chosen a games folder yet, then show them the first-run panel
		//(This is modal, so execution will not continue until the panel is dismissed.)
		if (![self gamesFolderPath] && ![self gamesFolderChosen])
		{
			//Perform with a delay to give the Dock icon bouncing time to finish,
			//since the Core Graphics flip animation interrupts this otherwise.
			if (useFlipTransitions)
			{
				[NSThread sleepForTimeInterval: 0.4];
				hasDelayed = YES;
				[self orderFrontFirstRunPanelWithFlip: self];
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
					[self orderFrontWelcomePanelWithFlip: self];
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
	
	hasFinishedLaunching = YES;
}


- (void) applicationWillTerminate: (NSNotification *)notification
{
	//Tell any remaining documents to close on exit
	//(NSDocumentController doesn't always do so by default)
	for (id document in [NSArray arrayWithArray: [self documents]]) [document close];
	
	//Save our preferences to disk before exiting
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	//Restore Spaces shortcuts if we were overriding them
	[self syncSpacesKeyboardShortcuts];
	
	//Tell any operations in our queue to cancel themselves
	[generalQueue cancelAllOperations];
	[generalQueue waitUntilAllOperationsAreFinished];
	
	//If we are the last Boxer process, remove any temporary folder on our way out
	if (![[self class] otherBoxersActive])
	{
		NSFileManager *manager = [NSFileManager defaultManager];
		NSString *tempPath = [[self class] temporaryPathCreatingIfMissing: NO];
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
		[self _cancelOpeningWithError: outError];
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
		[self _cancelOpeningWithError: outError];
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
		[self _cancelOpeningWithError: outError];
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
		[self _cancelOpeningWithError: outError];
		return nil;
	}
	else
	{
		id session = [[[BXImportSession alloc] initWithType: nil error: outError] autorelease];
		if (session)
		{
			[self addDocument: session];
			if (displayDocument)
			{
				[session makeWindowControllers];
				[session showWindows];
			}
		}
		return session;
	}
}

- (id) openImportSessionWithContentsOfURL: (NSURL *)url display: (BOOL)display error: (NSError **)outError
{
	//If it's too late for us to open an import session, launch a new Boxer process to do it
	if (![self _canOpenDocumentOfClass: [BXImportSession class]])
	{
		[self _launchProcessWithImportSessionAtURL: url];
		[self _cancelOpeningWithError: outError];
		return nil;
	}
	else
	{
		BXImportSession *importer = [self openImportSessionAndDisplay: display error: outError];
		[importer importFromSourcePath: [url path]];
		return importer;
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

- (void) _cancelOpeningWithError: (NSError **)outError
{
	//If we don't have a current session going, exit after cancelling
	if (![self currentSession]) [NSApp terminate: self];
	
	//Otherwise, cancel the existing open request without generating an error message,
	//and we'll leave the current session going
	if (outError) *outError = [NSError errorWithDomain: NSCocoaErrorDomain
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

- (IBAction) orderFrontWelcomePanelWithFlip: (id)sender
{	
	[[BXWelcomeWindowController controller] showWindowWithFlip: sender];
}

- (IBAction) orderFrontFirstRunPanel: (id)sender
{
	//The welcome panel and first-run panel are mutually exclusive.
	[self hideWelcomePanel: self];
	
	[[BXFirstRunWindowController controller] showWindow: sender];
}

- (IBAction) orderFrontFirstRunPanelWithFlip: (id)sender
{
	//The welcome panel and first-run panel are mutually exclusive.
	[self hideWelcomePanel: self];
	
	[[BXFirstRunWindowController controller] showWindowWithFlip: sender];
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

- (IBAction) showWebsite:			(id)sender	{ [self openURLFromKey: @"WebsiteURL"]; }
- (IBAction) showDonationPage:		(id)sender	{ [self openURLFromKey: @"DonationURL"]; }
- (IBAction) showBugReportPage:		(id)sender	{ [self openURLFromKey: @"BugReportURL"]; }
- (IBAction) showPerianDownloadPage:(id)sender	{ [self openURLFromKey: @"PerianURL"]; }
- (IBAction) showJoypadDownloadPage:(id)sender	{ [self openURLFromKey: @"JoypadURL"]; }
- (IBAction) sendEmail:				(id)sender
{
	NSString *subject		= @"Boxer feedback";
	NSString *versionName	= [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
	NSString *buildNumber	= [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"];
	NSString *fullSubject	= [NSString stringWithFormat: @"%@ (v%@ %@)", subject, versionName, buildNumber, nil];
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
		theAction == @selector(orderFrontInspectorPanel:))	return [[self currentSession] isEmulating];
	
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
	NSString *URLString		= [NSString stringWithFormat: siteString, encodedSearch, nil];
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
		return [ws openFile: filePath];
	}
	else
	{
		return [ws selectFile: filePath inFileViewerRootedAtPath: [filePath stringByDeletingLastPathComponent]];
	}
}


#pragma mark -
#pragma mark Miscellaneous UI-related methods


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
- (void) playUISoundWithName: (NSString *)soundName atVolume: (float)volume
{
	if ([self shouldPlayUISounds])
	{
		NSSound *theSound = [NSSound soundNamed: soundName];
		[theSound setVolume: volume];
		[theSound play];
	}
}


#pragma mark -
#pragma mark Event-related methods

//TODO: make this a class method on NSWindow instead
- (NSWindow *) windowAtPoint: (NSPoint)screenPoint
{
	for (NSWindow *window in [NSApp windows])
	{
		if ([window isVisible] && NSPointInRect(screenPoint, window.frame)) return window;
	}
	return nil;
}

@end
