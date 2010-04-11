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
#import "BXSession.h"
#import "BXSessionWindowController.h"
#import "BXValueTransformers.h"
#import "BXGrowlController.h"
#import "NSString+BXPaths.h"
#import "BXThemes.h"
#import <BGHUDAppKit/BGThemeManager.h>


@implementation BXAppController
@synthesize emulationQueue, currentSession;


//Filetypes used by Boxer
//-----------------------

+ (NSArray *) hddVolumeTypes
{
	static NSArray *types = nil;
	if (!types) types = [[NSArray alloc] initWithObjects:
						 @"net.washboardabs.boxer-harddisk-folder",
						 nil];
	return types;
}

+ (NSArray *) cdVolumeTypes
{
	static NSArray *types = nil;
	if (!types) types = [[NSArray alloc] initWithObjects:
						 @"com.goldenhawk.cdrwin-cuesheet",
						 @"net.washboardabs.boxer-cdrom-folder",
						 @"public.iso-image",
						 @"com.apple.disk-image-cdr",
						 nil];
	return types;
}

+ (NSArray *) floppyVolumeTypes
{
	static NSArray *types = nil;
	if (!types) types = [[NSArray alloc] initWithObjects:
						 @"net.washboardabs.boxer-floppy-folder",
						 nil];
	return types;
}

+ (NSArray *) mountableFolderTypes
{
	static NSArray *types = nil;
	if (!types) types = [[NSArray alloc] initWithObjects:
						 @"net.washboardabs.boxer-mountable-folder",
						 nil];
	return types;
}

+ (NSArray *) mountableImageTypes
{
	static NSArray *types = nil;
	if (!types) types = [[NSArray alloc] initWithObjects:
						 @"public.iso-image",					//.iso
						 @"com.apple.disk-image-cdr",			//.cdr
						 @"com.goldenhawk.cdrwin-cuesheet",		//.cue
						 nil];
	return types;
}

+ (NSArray *) mountableTypes
{
	static NSArray *types = nil;
	if (!types) types = [[[self mountableImageTypes] arrayByAddingObject: @"public.directory"] retain];
	return types;
}

+ (NSArray *) executableTypes
{
	static NSArray *types = nil;
	if (!types) types = [[NSArray alloc] initWithObjects:
						 @"com.microsoft.windows-executable",	//.exe
						 @"com.microsoft.msdos-executable",		//.com
						 @"com.microsoft.batch-file",			//.bat
						 nil];
	return types;
}


//Initialisation process
//----------------------

+ (void)initialize
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
}

+ (void)setupDefaults
{
	//We carry a plist of initial values for application preferences
    NSString *defaultsPath	= [[NSBundle mainBundle] pathForResource: @"UserDefaults" ofType:@"plist"];
    NSDictionary *defaults	= [NSDictionary dictionaryWithContentsOfFile:defaultsPath];
	
    [[NSUserDefaults standardUserDefaults] registerDefaults: defaults];
}

- (id) init
{
	if ((self = [super init]))
	{
		//Create our emulator operation queue
		emulationQueue = [[NSOperationQueue alloc] init];
	}
	return self;
}

- (void) dealloc
{
	[self setCurrentSession: nil], [currentSession release];
	[emulationQueue release], emulationQueue = nil;
	
	[super dealloc];
}


//Opening (and closing) files
//---------------------------

//Don't open a new empty document when switching back to the application
- (BOOL) applicationShouldOpenUntitledFile: (NSApplication *)theApplication { return NO; }

//Customise the open panel
- (NSInteger)runModalOpenPanel:(NSOpenPanel *)openPanel forTypes:(NSArray *)extensions
{
	[openPanel setAllowsMultipleSelection: NO];
	[openPanel setCanChooseFiles: YES];
	[openPanel setCanChooseDirectories: YES];
	[openPanel setMessage: NSLocalizedString(@"Choose a gamebox, folder or DOS program to open in DOS.", @"Help text shown at the top of the open panel.")];
	
	//Todo: add an accessory view and delegate to handle special-case requirements.
	//(like installation, or choosing which drive to mount a folder as.) 
	
	return [super runModalOpenPanel: openPanel forTypes: extensions];
}


//Prevent the opening of new documents if we have a session already active
- (id) makeUntitledDocumentOfType:(NSString *)typeName error:(NSError **)outError
{
	if ([self currentSession] && [self documentClassForType: typeName] == [BXSession class])
	{
		//Todo: build an NSError to go here
		return nil;
	}
	else return [super makeUntitledDocumentOfType: typeName error: outError];
}

- (id) makeDocumentWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	if ([self currentSession] && [self documentClassForType: typeName] == [BXSession class])
	{
		//Todo: build an NSError to go here
		return nil;
	}
	else return [super makeDocumentWithContentsOfURL: absoluteURL ofType: typeName error: outError];
}

- (id) makeDocumentForURL:	(NSURL *)absoluteDocumentURL
	withContentsOfURL:		(NSURL *)absoluteDocumentContentsURL
	ofType:					(NSString *)typeName
	error:					(NSError **)outError
{
	if ([self currentSession] && [self documentClassForType: typeName] == [BXSession class])
	{
		//Todo: build an NSError to go here
		return nil;
	}
	else return [super makeDocumentForURL: absoluteDocumentURL withContentsOfURL: absoluteDocumentContentsURL ofType: typeName error: outError];
}

//Store the specified document as the current session
- (void) addDocument: (NSDocument *)theDocument
{
	[super addDocument: theDocument];
	if ([theDocument isMemberOfClass: [BXSession class]])
	{
		BXSession *theSession = (BXSession *)theDocument;
		[self setCurrentSession: theSession];
	}
}

//Tidy up when the current session closes
- (void) removeDocument: (NSDocument *)theDocument
{
	[super removeDocument: theDocument];
	if ([self currentSession] == theDocument) [self setCurrentSession: nil];
}


//For some reason the default setter isn't firing key-change notifications correctly???
- (void) setCurrentSession: (BXSession *)session
{
	[self willChangeValueForKey: @"currentSession"];
		
	[currentSession autorelease];
	currentSession = [session retain];
	
	[self didChangeValueForKey: @"currentSession"];
}


//Handling application termination
//--------------------------------

- (NSApplicationTerminateReply) applicationShouldTerminate: (NSApplication *)theApplication
{
	//Go through our windows asking each one to close
	for (id theWindow in [theApplication windows])
	{
		id delegate = [theWindow delegate];
		if ([delegate respondsToSelector: @selector(windowShouldClose:)] &&
			![delegate windowShouldClose: theWindow]) return NSTerminateCancel;
	}
	return NSTerminateNow;
}

- (void) applicationWillTerminate: (NSNotification *)notification
{
	//Force all emulation threads to finish up, then wait until they do before we shut down the application
	//Note: this is currently disabled as it seems to hang forever
	[emulationQueue cancelAllOperations];
	//[emulationQueue waitUntilAllOperationsAreFinished];

	//Save our preferences to disk before exiting
	[[NSUserDefaults standardUserDefaults] synchronize];
}


//UI support functions
//--------------------
//Should probably be abstracted off to a separate class at this point, linked into the responder chain

- (IBAction) orderFrontAboutPanel:			(id)sender
{
	[[[self currentSession] mainWindowController] exitFullScreen: sender];
	[[BXAboutController controller] showWindow: nil];
}
- (IBAction) orderFrontPreferencesPanel:	(id)sender
{
	[[[self currentSession] mainWindowController] exitFullScreen: sender];
	[[BXPreferencesController controller] showWindow: nil];
}

- (IBAction) toggleInspectorPanel: (id)sender
{
	[self setInspectorPanelShown: ![self inspectorPanelShown]];
}

- (void) setInspectorPanelShown: (BOOL)show
{
	[self willChangeValueForKey: @"inspectorPanelShown"];
	
	BXInspectorController *inspector = [BXInspectorController controller];

	//Only show the inspector if there is a DOS session window; otherwise, we have nothing to inspect.
	//This limitation will be removed as we gain other inspectable window types.
	if (show && [self currentSession])
	{
		[[[self currentSession] mainWindowController] exitFullScreen: nil];
		[inspector showWindow: nil];
	}
	else if ([inspector isWindowLoaded])
	{
		[[inspector window] orderOut: nil];
	}
	
	[self didChangeValueForKey: @"inspectorPanelShown"];	
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
	NSString *path;
	
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
	NSString *path;
	
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


//Sound-related functions
//-----------------------

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

- (BOOL) validateUserInterfaceItem: (id)theItem
{	
	SEL theAction = [theItem action];

	//Disable actions that would open new sessions once we already have one active
	if (theAction == @selector(newDocument:))			return [self currentSession] == nil;
	if (theAction == @selector(openDocument:))			return [self currentSession] == nil;
	if (theAction == @selector(toggleInspectorPanel:))	return [self currentSession] != nil;
	
	return [super validateUserInterfaceItem: theItem];
}


//Event-related functions
//-----------------------

- (NSWindow *) windowAtPoint: (NSPoint)screenPoint
{
	for (NSWindow *window in [NSApp windows])
	{
		if ([window isVisible] && NSPointInRect(screenPoint, window.frame)) return window;
	}
	return nil;
}

@end