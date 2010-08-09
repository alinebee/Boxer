/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXAppController.h"
#import "BXAboutController.h"
#import "BXInspectorController.h"
#import "BXPreferencesController.h"
#import "BXSession+BXFileManager.h"
#import "BXImport.h";
#import "BXDOSWindowController.h"
#import "BXValueTransformers.h"
#import "BXGrowlController.h"
#import "NSString+BXPaths.h"
#import "BXThemes.h"
#import <BGHUDAppKit/BGThemeManager.h>


NSString * const BXNewSessionParam = @"--openNewSession";
NSString * const BXActivateOnLaunchParam = @"--activateOnLaunch";

@implementation BXAppController
@synthesize currentSession;


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


#pragma mark -
#pragma mark Initialization and teardown

+ (void) initialize
{
	[self setupDefaults];

	//Create common value transformers
	
	NSValueTransformer *isEmpty		= [[BXArraySizeTransformer alloc] initWithMinSize: 0 maxSize: 0];
	NSValueTransformer *isNotEmpty	= [[BXArraySizeTransformer alloc] initWithMinSize: 1 maxSize: NSIntegerMax];
	NSValueTransformer *capitalizer	= [BXCapitalizer new];
	
	[NSValueTransformer setValueTransformer: [isEmpty autorelease]		forName: @"BXArrayIsEmpty"];
	[NSValueTransformer setValueTransformer: [isNotEmpty autorelease]	forName: @"BXArrayIsNotEmpty"];	
	[NSValueTransformer setValueTransformer: [capitalizer autorelease]	forName: @"BXCapitalizedString"];	
	
	//Initialise our Growl notifier instance
	[GrowlApplicationBridge setGrowlDelegate: [BXGrowlController controller]];

	//Register our BGHUD UI themes
	[[BGThemeManager keyedManager] setTheme: [[BXShadowedTextTheme new] autorelease]	forKey: @"BXShadowedTextTheme"];
	[[BGThemeManager keyedManager] setTheme: [[BXHelpTextTheme new] autorelease]		forKey: @"BXHelpTextTheme"];
	[[BGThemeManager keyedManager] setTheme: [[BXBlueTheme new] autorelease]			forKey: @"BXBlueTheme"];
	[[BGThemeManager keyedManager] setTheme: [[BXBlueprintTheme new] autorelease]		forKey: @"BXBlueprintTheme"];
	[[BGThemeManager keyedManager] setTheme: [[BXBlueprintHelpText new] autorelease]	forKey: @"BXBlueprintHelpText"];
}

+ (void) setupDefaults
{
	//We carry a plist of initial values for application preferences
    NSString *defaultsPath	= [[NSBundle mainBundle] pathForResource: @"UserDefaults" ofType: @"plist"];
    NSDictionary *defaults	= [NSDictionary dictionaryWithContentsOfFile: defaultsPath];
	
    [[NSUserDefaults standardUserDefaults] registerDefaults: defaults];
}

- (void) dealloc
{
	[self setCurrentSession: nil], [currentSession release];
	
	[super dealloc];
}


#pragma mark -
#pragma mark Document management

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

//Quit after the last window was closed if we are a 'subsidiary' process, to avoid leaving extra Boxers littering the Dock
- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)sender
{
	NSUInteger numBoxers = 0;
	NSString *bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	for (NSDictionary *appDetails in [workspace launchedApplications])
	{
		if ([[appDetails objectForKey: @"NSApplicationBundleIdentifier"] isEqualToString: bundleIdentifier]) numBoxers++;
	}
	return numBoxers > 1;
}

//Don't open a new empty document when switching back to the application
- (BOOL) applicationShouldOpenUntitledFile: (NSApplication *)theApplication { return NO; }

//...However, when we've been told to open a new empty session at startup, do so
- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
	NSArray *arguments = [[NSProcessInfo processInfo] arguments];
	
	if ([arguments containsObject: BXNewSessionParam])
		[self openUntitledDocumentAndDisplay: YES error: nil];
	
	if ([arguments containsObject: BXActivateOnLaunchParam]) 
		[NSApp activateIgnoringOtherApps: YES];
}

//Customise the open panel
- (NSInteger) runModalOpenPanel: (NSOpenPanel *)openPanel
					   forTypes: (NSArray *)extensions
{
	[openPanel setAllowsMultipleSelection: NO];
	[openPanel setCanChooseFiles: YES];
	[openPanel setCanChooseDirectories: YES];
	[openPanel setMessage: NSLocalizedString(@"Choose a gamebox, folder or DOS program to open in DOS.", @"Help text shown at the top of the open panel.")];
	
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
	
	//TWEAK: don't do this if the URL is a gamebox: always treat gameboxes as separate documents.
	NSString *type = [self typeForContentsOfURL: absoluteURL error: nil];
	if (![type isEqualToString: @"net.washboardabs.boxer-game-package"])
	{
		for (id document in [self documents])
		{
			if ([document respondsToSelector: @selector(openFileAtPath:)] && [document openFileAtPath: path])
			{
				if (displayDocument) [document showWindows];
				return document;
			}
		}		
	}
	
	//If no existing session can open the URL, continue with the default document opening behaviour.
	return [super openDocumentWithContentsOfURL: absoluteURL display: displayDocument error: outError];
}

//Prevent the opening of new documents if we have a session already active
- (id) makeUntitledDocumentOfType: (NSString *)typeName error: (NSError **)outError
{
	if (hasLaunchedSession && [[self documentClassForType: typeName] isKindOfClass: [BXSession class]])
	{
		//Launch another instance of Boxer to open the new session
		[self _launchProcessWithUntitledDocument];
		
		//If we don't have a current session going, exit
		if (![self currentSession]) [NSApp terminate: self];
		
		//Otherwise, cancel the existing open request without generating an error message
		*outError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSUserCancelledError userInfo: nil];
		return nil;
	}
	else return [super makeUntitledDocumentOfType: typeName error: outError];
}

- (id) makeDocumentWithContentsOfURL: (NSURL *)absoluteURL
							  ofType: (NSString *)typeName
							   error: (NSError **)outError
{
	if (hasLaunchedSession && [[self documentClassForType: typeName] isKindOfClass: [BXSession class]])
	{
		//Launch another instance of Boxer to open the specified document
		[self _launchProcessWithDocumentAtURL: absoluteURL];
		
		//If we don't have a current session going, exit
		if (![self currentSession]) [NSApp terminate: self];
		
		//Otherwise, cancel the existing open request without generating an error message
		*outError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSUserCancelledError userInfo: nil];
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
	if (hasLaunchedSession && [self documentClassForType: typeName] == [BXSession class])
	{
		//Launch another instance of Boxer to open the specified document
		[self _launchProcessWithDocumentAtURL: absoluteDocumentContentsURL];

		//If we don't have a current session going, exit
		if (![self currentSession]) [NSApp terminate: self];

		//Otherwise, cancel the existing open request without generating an error message
		*outError = [NSError errorWithDomain: NSCocoaErrorDomain code: NSUserCancelledError userInfo: nil];
		return nil;
	}
	else return [super makeDocumentForURL: absoluteDocumentURL
						withContentsOfURL: absoluteDocumentContentsURL
								   ofType: typeName
									error: outError];
}

//Store the specified document as the current session
- (void) addDocument: (NSDocument *)theDocument
{
	[super addDocument: theDocument];
	if ([theDocument isMemberOfClass: [BXSession class]])
	{
		[self setCurrentSession: (BXSession *)theDocument];
		hasLaunchedSession = YES;
	}
}

- (void) removeDocument: (NSDocument *)theDocument
{	
	//Do whatever we were going to do originally
	[super removeDocument: theDocument];
	
	//Clear the current session
	if ([self currentSession] == theDocument) [self setCurrentSession: nil];
	
	//Hide the Inspector panel if there's no longer any sessions open
	if (![self currentSession]) [self setInspectorPanelShown: NO];
}


#pragma mark -
#pragma mark Handling application termination

- (void) applicationWillTerminate: (NSNotification *)notification
{
	//Save our preferences to disk before exiting
	[[NSUserDefaults standardUserDefaults] synchronize];
}


#pragma mark -
#pragma mark Actions and action helper methods

- (IBAction) orderFrontImportGamePanel: (id)sender
{
	NSDocument *gameImport = [[BXImport alloc] initWithType: @"GameImport" error: nil];
	[gameImport makeWindowControllers];
	[gameImport showWindows];
}

- (IBAction) orderFrontAboutPanel: (id)sender
{
	[[[self currentSession] DOSWindowController] exitFullScreen: sender];
	[[BXAboutController controller] showWindow: nil];
}
- (IBAction) orderFrontPreferencesPanel: (id)sender
{
	[[[self currentSession] DOSWindowController] exitFullScreen: sender];
	[[BXPreferencesController controller] showWindow: nil];
}

- (IBAction) toggleInspectorPanel: (id)sender
{
	[self setInspectorPanelShown: ![self inspectorPanelShown]];
}

- (void) setInspectorPanelShown: (BOOL)show
{
	BXInspectorController *inspector = [BXInspectorController controller];

	//Only show the inspector if there is a DOS session window; otherwise, we have nothing to inspect.
	//This limitation will be removed as we gain other inspectable window types.
	if (show && [self currentSession])
	{
		[[[self currentSession] DOSWindowController] exitFullScreen: nil];
		[inspector showWindow: nil];
	}
	else if ([inspector isWindowLoaded])
	{
		[[inspector window] orderOut: nil];
	}
}

- (BOOL) inspectorPanelShown
{
	BXInspectorController *inspector = [BXInspectorController controller];
	return [inspector isWindowLoaded] && [[inspector window] isVisible];
}

- (IBAction) showWebsite:			(id)sender	{ [self openURLFromKey: @"WebsiteURL"]; }
- (IBAction) showDonationPage:		(id)sender	{ [self openURLFromKey: @"DonationURL"]; }
- (IBAction) showPerianDownloadPage:(id)sender	{ [self openURLFromKey: @"PerianURL"]; }
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
	
	//Don't allow the Inspector panel to be shown if there's no active session.
	if (theAction == @selector(toggleInspectorPanel:))	return [self currentSession] != nil;
	
	return [super validateUserInterfaceItem: theItem];
}


- (void) openURLFromKey: (NSString *)infoKey
{
	NSString *URLString = [[NSBundle mainBundle] objectForInfoDictionaryKey: infoKey];
	if ([URLString length]) [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: URLString]];
}

- (void) searchURLFromKey: (NSString *)infoKey withSearchString: (NSString *)search
{
	NSString *encodedSearch = [search stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
	NSString *siteString	= [[NSBundle mainBundle] objectForInfoDictionaryKey: infoKey];
	NSString *URLString		= [NSString stringWithFormat: siteString, encodedSearch, nil];
	if ([URLString length]) [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString: URLString]];
}

- (void) sendEmailFromKey: (NSString *)infoKey withSubject:(NSString *)subject
{
	NSString *address = [[NSBundle mainBundle] objectForInfoDictionaryKey: infoKey];
	if ([address length])
	{
		NSString *encodedSubject	= [subject stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
		NSString *mailtoURLString	= [NSString stringWithFormat: @"mailto:%@?subject=%@", address, encodedSubject];
		[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:mailtoURLString]];
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
- (void) revealPath: (NSString *)filePath
{
	NSWorkspace *ws = [NSWorkspace sharedWorkspace];
	NSFileManager *manager = [NSFileManager defaultManager];
	
	BOOL isFolder = NO;
	if (![manager fileExistsAtPath: filePath isDirectory: &isFolder]) return;
	
	if (isFolder && ![ws isFilePackageAtPath: filePath]) [ws openFile: filePath];
	else [ws selectFile: filePath inFileViewerRootedAtPath: [filePath stringByDeletingLastPathComponent]];
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

- (NSWindow *) windowAtPoint: (NSPoint)screenPoint
{
	for (NSWindow *window in [NSApp windows])
	{
		if ([window isVisible] && NSPointInRect(screenPoint, window.frame)) return window;
	}
	return nil;
}

@end
