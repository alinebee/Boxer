/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXBaseAppControllerPrivate.h"
#import "BXAppController+BXGamesFolder.h"

#import "BXAboutController.h"
#import "BXInspectorController.h"
#import "BXPreferencesController.h"
#import "BXWelcomeWindowController.h"
#import "BXMountPanelController.h"
#import "BXBezelController.h"

#import "BXSession+BXFileManagement.h"
#import "BXGamebox.h"
#import "BXImportSession.h"
#import "BXEmulator.h"
#import "BXMIDIDeviceMonitor.h"

#import "NSString+ADBPaths.h"

#import "BXFileTypes.h"
#import "ADBForwardCompatibility.h"
#import "ADBAppKitVersionHelpers.h"


NSString * const BXNewSessionParam = @"--openNewSession";
NSString * const BXShowImportPanelParam = @"--showImportPanel";
NSString * const BXShowPreferencesParam = @"--showPreferences";
NSString * const BXImportURLParam = @"--importURL ";
NSString * const BXActivateOnLaunchParam = @"--activateOnLaunch";


@interface BXAppController ()


//Because we can only run one emulation session at a time, we need to launch a second
//Boxer process for opening additional/subsequent documents
- (void) _launchProcessWithDocumentAtURL: (NSURL *)URL extraArguments: (NSArray *)extraArgs;
- (void) _launchProcessWithImportSessionAtURL: (NSURL *)URL extraArguments: (NSArray *)extraArgs;
- (void) _launchProcessWithUntitledDocumentAndExtraArguments: (NSArray *)extraArgs;
- (void) _launchProcessWithImportPanelAndExtraArguments: (NSArray *)extraArgs;
- (void) _launchProcessWithExtraArguments: (NSArray *)extraArgs;

//Whether it's safe to open a new session
- (BOOL) _canOpenDocumentOfClass: (Class)documentClass;

//Cancel a makeDocument/openDocument request after spawning a new process.
//Returns the error that should be used to cancel AppKit's open request.
- (NSError *) _cancelOpening;

@end


@implementation BXAppController

+ (BOOL) otherBoxersActive
{
	NSString *bundleIdentifier	= [self appIdentifier];
	NSWorkspace *workspace		= [NSWorkspace sharedWorkspace];
	NSUInteger numBoxers = 0;
	
	for (NSDictionary *appDetails in [workspace launchedApplications])
	{
		if ([[appDetails objectForKey: @"NSApplicationBundleIdentifier"] isEqualToString: bundleIdentifier]) numBoxers++;
	}
	return numBoxers > 1;
}

- (void) dealloc
{
    self.gamesFolderURL = nil;
}

- (BXInspectorController *) inspectorController
{
    return [BXInspectorController controller];
}

#pragma mark -
#pragma mark Application open/closing behaviour

//Quit after the last window was closed if we are a 'subsidiary' process,
//to avoid leaving extra Boxers littering the Dock
- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)sender
{
	return [self.class otherBoxersActive];
}

- (void) applicationWillFinishLaunching: (NSNotification *)notification
{
    [super applicationWillFinishLaunching: notification];
    
    //Check if we have any games folder, and if not then create one automatically now
    if (!self.gamesFolderURL && !self.gamesFolderChosen)
    {
        NSURL *defaultURL = [self.class preferredGamesFolderURL];
        [self assignGamesFolderURL: defaultURL
                   withSampleGames: YES
                   shelfAppearance: BXShelfAuto
                   createIfMissing: YES
                             error: NULL];
    }
}

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
    //Determine if we were passed any startup parameters we need to act upon
	NSArray *arguments = [NSProcessInfo processInfo].arguments;
	
	for (NSString *argument in arguments)
	{
		if ([argument isEqualToString: BXNewSessionParam])
			[self openUntitledDocumentAndDisplay: YES error: nil];
		
		else if ([argument isEqualToString: BXShowImportPanelParam])
			[self openImportSessionAndDisplay: YES error: nil];
        
		else if ([argument isEqualToString: BXShowPreferencesParam])
			[self orderFrontPreferencesPanel: self];
		
		else if ([argument isEqualToString: BXActivateOnLaunchParam]) 
			[NSApp activateIgnoringOtherApps: YES];
		
		else if ([argument hasPrefix: BXImportURLParam])
		{
			NSString *importPath = [argument substringFromIndex: BXImportURLParam.length];
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
                
			case BXStartUpWithDOSPrompt:
                return YES;
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
    {
		[self orderFrontWelcomePanel: self];
	}
	return NO;
}


#pragma mark - Document handling

//Customise the open panel
- (NSInteger) runModalOpenPanel: (NSOpenPanel *)openPanel
					   forTypes: (NSArray *)extensions
{
    openPanel.allowsMultipleSelection = NO;
    openPanel.canChooseFiles = YES;
    openPanel.canChooseDirectories = YES;
    
    openPanel.message = NSLocalizedString(@"Choose a gamebox, folder or DOS program to open in DOS.",
                                          @"Help text shown at the top of the open panel.");
	
	//Todo: add an accessory view and delegate to handle special-case requirements.
	//(like installation, or choosing which drive to mount a folder as.) 
	
	return [super runModalOpenPanel: openPanel forTypes: extensions];
}


- (void) openDocumentWithContentsOfURL: (NSURL *)absoluteURL
							   display: (BOOL)displayDocument
					 completionHandler: (void (^)(NSDocument * _Nullable, BOOL, NSError * _Nullable))completionHandler
{
	//First go through our existing sessions, checking if any can open the specified URL.
	//(This will be possible if the URL is accessible to a session's emulated filesystem,
	//and the session is not already running a program.)
	
	//TWEAK: if it’s a gamebox, then foreground any existing session for that gamebox.
	NSString *type = [self typeForContentsOfURL: absoluteURL error: nil];
	if ([type isEqualToString: BXGameboxType])
	{
		for (BXSession *session in self.sessions)
		{
			if ([session.gamebox.bundleURL isEqual: absoluteURL])
			{
				[session showWindows];
				completionHandler(session, YES, nil);
				return;
			}
		}
	}
	//For other filetypes, just see if any of the sessions we have can open the file.
	else
	{
		for (BXSession *session in self.sessions)
		{
			if ([session openURLInDOS: absoluteURL error: nil])
			{
				if (displayDocument)
				{
					[session showWindows];
				}
				
				completionHandler(session, YES, nil);
				return;
			}
		}
	}
	
	//If no existing session can open the URL, continue with the default document opening behaviour.
	[super openDocumentWithContentsOfURL: absoluteURL display: displayDocument completionHandler: completionHandler];
}

//Prevent the opening of new documents if we have a session already active
- (id) makeUntitledDocumentOfType: (NSString *)typeName error: (NSError **)outError
{
	[self hideWelcomePanel: self];
	if ([self _canOpenDocumentOfClass: [self documentClassForType: typeName]])
	{
        return [super makeUntitledDocumentOfType: typeName error: outError];
    }
    else
    {
		//Launch another instance of Boxer to open the new session
		[self _launchProcessWithUntitledDocumentAndExtraArguments: nil];
		NSError *cancelError = [self _cancelOpening];
        if (outError) *outError = cancelError;
		return nil;
	}
}

- (id) makeDocumentWithContentsOfURL: (NSURL *)absoluteURL
							  ofType: (NSString *)typeName
							   error: (NSError **)outError
{
	[self hideWelcomePanel: self];
	if ([self _canOpenDocumentOfClass: [self documentClassForType: typeName]])
	{
        return [super makeDocumentWithContentsOfURL: absoluteURL
                                             ofType: typeName
                                              error: outError];
    }
    else
    {
		//Launch another instance of Boxer to open the specified document
		[self _launchProcessWithDocumentAtURL: absoluteURL extraArguments: nil];
		NSError *cancelError = [self _cancelOpening];
        if (outError) *outError = cancelError;
		return nil;
	}
}

- (id) makeDocumentForURL: (NSURL *)absoluteDocumentURL
		withContentsOfURL: (NSURL *)absoluteDocumentContentsURL
				   ofType: (NSString *)typeName
					error: (NSError **)outError
{
	[self hideWelcomePanel: self];
	if ([self _canOpenDocumentOfClass: [self documentClassForType: typeName]])
	{
        return [super makeDocumentForURL: absoluteDocumentURL
                       withContentsOfURL: absoluteDocumentContentsURL
                                  ofType: typeName
                                   error: outError];
    }
    else
    {
		//Launch another instance of Boxer to open the specified document
		[self _launchProcessWithDocumentAtURL: absoluteDocumentContentsURL extraArguments: nil];
		
        NSError *cancelError = [self _cancelOpening];
        if (outError)
            *outError = cancelError;
        
		return nil;
	}
}

- (id) openImportSessionAndDisplay: (BOOL)displayDocument error: (NSError **)outError
{
	[self hideWelcomePanel: self];
    
	if ([self _canOpenDocumentOfClass: [BXImportSession class]])
	{
		BXImportSession *importer = [[BXImportSession alloc] initWithType: @"net.washboardabs.boxer-game-package" error: outError];
		if (importer)
		{
			[self addDocument: importer];
			if (displayDocument)
			{
				[importer makeWindowControllers];
				[importer showWindows];
			}
		}
		return importer;
	}
    //If it's too late for us to open an import session, launch a new Boxer process to do it
	else
    {
		[self _launchProcessWithImportPanelAndExtraArguments: nil];
        
		NSError *cancelError = [self _cancelOpening];
        if (outError)
            *outError = cancelError;
		
        return nil;
	}
}

- (id) openImportSessionWithContentsOfURL: (NSURL *)url
                                  display: (BOOL)displayDocument
                                    error: (NSError **)outError
{
	[self hideWelcomePanel: self];
	//If it's too late for us to open an import session, launch a new Boxer process to do it
	if ([self _canOpenDocumentOfClass: [BXImportSession class]])
	{
		BXImportSession *importer = [[BXImportSession alloc] initWithContentsOfURL: url
                                                                            ofType: @"net.washboardabs.boxer-game-package"
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
		return importer;
	}
    else
    {
		[self _launchProcessWithImportSessionAtURL: url extraArguments: nil];
        
		NSError *cancelError = [self _cancelOpening];
        if (outError)
            *outError = cancelError;
        
		return nil;
	}
	
}

- (void) noteNewRecentDocument: (NSDocument *)theDocument
{
	//Don't add incomplete game imports to the Recent Documents list.
    //TODO: move this logic off to the session itself, so we don't have to know about its internal state.
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


- (void) removeDocument: (NSDocument *)theDocument
{
    [super removeDocument: theDocument];
    
	//Hide the Inspector panel if there's no longer any sessions open
	if (!self.currentSession)
        [BXInspectorController controller].visible = NO;
}


#pragma mark - Spawning document processes

- (IBAction) relaunch: (id)sender
{
    [self _relaunchWithPreviousState];
}

- (void) _relaunchWithPreviousState
{
    BXSession *currentSession = self.currentSession;
    BOOL prefsVisible = [BXPreferencesController controller].window.isVisible;

    [self terminateWithHandler: ^{
        NSArray *extraArgs = nil;
        if (prefsVisible)
            extraArgs = @[ BXShowPreferencesParam ];
        
        if (currentSession.isGameImport)
        {
            if (currentSession.fileURL)
                [self _launchProcessWithImportSessionAtURL: currentSession.fileURL extraArguments: extraArgs];
            else
                [self _launchProcessWithImportPanelAndExtraArguments: extraArgs];
        }
        else if (currentSession)
        {
            if (currentSession.fileURL)
                [self _launchProcessWithDocumentAtURL: currentSession.fileURL extraArguments: extraArgs];
            else
                [self _launchProcessWithUntitledDocumentAndExtraArguments: extraArgs];
        }
        else
        {
            [self _launchProcessWithExtraArguments: extraArgs];
        }
    }];
}

- (void) _launchProcessWithDocumentAtURL: (NSURL *)URL extraArguments: (NSArray *)extraArgs
{
	NSString *executablePath	= [[NSBundle mainBundle] executablePath];
	NSArray *params				= @[ URL.path, BXActivateOnLaunchParam ];
	[NSTask launchedTaskWithLaunchPath: executablePath arguments: [params arrayByAddingObjectsFromArray: extraArgs]];
}

- (void) _launchProcessWithUntitledDocumentAndExtraArguments: (NSArray *)extraArgs
{
	NSString *executablePath	= [[NSBundle mainBundle] executablePath];
	NSArray *params				= @[ BXNewSessionParam, BXActivateOnLaunchParam ];
	[NSTask launchedTaskWithLaunchPath: executablePath arguments: [params arrayByAddingObjectsFromArray: extraArgs]];
}

- (void) _launchProcessWithImportPanelAndExtraArguments: (NSArray *)extraArgs
{
	NSString *executablePath	= [[NSBundle mainBundle] executablePath];
	NSArray *params				= @[ BXShowImportPanelParam, BXActivateOnLaunchParam ];
	[NSTask launchedTaskWithLaunchPath: executablePath arguments: [params arrayByAddingObjectsFromArray: extraArgs]];
}

- (void) _launchProcessWithImportSessionAtURL: (NSURL *)URL extraArguments: (NSArray *)extraArgs
{
	NSString *executablePath	= [[NSBundle mainBundle] executablePath];
	NSString *URLParam			= [BXImportURLParam stringByAppendingString: URL.path];
	NSArray *params				= @[ URLParam, BXActivateOnLaunchParam ];
	[NSTask launchedTaskWithLaunchPath: executablePath arguments: [params arrayByAddingObjectsFromArray: extraArgs]];
}

- (void) _launchProcessWithExtraArguments: (NSArray *)extraArgs
{
	NSString *executablePath	= [[NSBundle mainBundle] executablePath];
	NSArray *params				= @[ BXActivateOnLaunchParam ];
	[NSTask launchedTaskWithLaunchPath: executablePath arguments: [params arrayByAddingObjectsFromArray: extraArgs]];
}

- (NSError *) _cancelOpening
{
	//If we don't have a current session going, exit after cancelling
	if (!self.currentSession)
        [NSApp terminate: self];
	
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
		if (self.sessions.count > 0) return NO;
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

- (IBAction) hideWelcomePanel: (id)sender
{
	[[[BXWelcomeWindowController controller] window] orderOut: self];
}

- (IBAction) orderFrontImportGamePanel: (id)sender
{
	//If we already have an import session active, just bring it to the front
	for (BXSession *session in self.sessions)
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
	BOOL show = !controller.visible;
	if (!show || self.currentSession.isEmulating)
	{
        controller.visible = show;		
	}
}

- (IBAction) orderFrontInspectorPanel: (id)sender
{
	if (self.currentSession.isEmulating)
	{
		[[BXInspectorController controller] showWindow: sender];
	}
}

//These are passthroughs for when BXInspectorController isn't in the responder chain
- (IBAction) showGamePanel:		(id)sender	{ [[BXInspectorController controller] showGamePanel: sender]; }
- (IBAction) showCPUPanel:		(id)sender	{ [[BXInspectorController controller] showCPUPanel: sender]; }
- (IBAction) showDrivesPanel:	(id)sender	{ [[BXInspectorController controller] showDrivesPanel: sender]; }
- (IBAction) showMousePanel:	(id)sender	{ [[BXInspectorController controller] showMousePanel: sender]; }

- (IBAction) showMountPanel: (id)sender
{
    [[BXMountPanelController controller] showMountPanelForSession: self.currentSession];
}

- (IBAction) showWebsite:			(id)sender	{ [self openURLFromKey: @"WebsiteURL"]; }
- (IBAction) showDonationPage:		(id)sender	{ [self openURLFromKey: @"DonationURL"]; }
- (IBAction) showBugReportPage:		(id)sender	{ [self openURLFromKey: @"BugReportURL"]; }
- (IBAction) showJoypadDownloadPage:(id)sender	{ [self openURLFromKey: @"JoypadURL"]; }

- (IBAction) sendEmail: (id)sender
{
	NSString *subject		= @"Boxer feedback";
	NSString *versionName	= [self.class localizedVersion];
	NSString *buildNumber	= [self.class buildNumber];
	NSString *fullSubject	= [NSString stringWithFormat: @"%@ (v%@ %@)", subject, versionName, buildNumber];
	[self sendEmailFromKey: @"ContactEmail" withSubject: fullSubject];
}

- (BOOL) validateUserInterfaceItem: (id <NSValidatedUserInterfaceItem>)theItem
{	
	SEL theAction = theItem.action;
	
	if (theAction == @selector(revealCurrentSession:))
		return (self.currentSession.hasGamebox || self.currentSession.currentURL != nil);
		
	//Don't allow any of the following actions while a modal window is active.
	if ([NSApp modalWindow]) return NO;
	
	//Don't allow the Inspector panel to be shown if there's no active session.
	if (theAction == @selector(toggleInspectorPanel:) ||
		theAction == @selector(orderFrontInspectorPanel:) ||
        theAction == @selector(showGamePanel:) ||
        theAction == @selector(showCPUPanel:) ||
        theAction == @selector(showDrivesPanel:) ||
        theAction == @selector(showMousePanel:) ||
        theAction == @selector(showMountPanel:))
    {
        return self.currentSession.isEmulating;
    }
	
	//Don't allow game imports or the games folder to be opened if no games folder has been set yet.
	if (theAction == @selector(revealGamesFolder:) ||
		theAction == @selector(orderFrontImportGamePanel:))
    {
        return self.gamesFolderURL != nil;
    }
    
	return [super validateUserInterfaceItem: theItem];
}

- (IBAction) revealCurrentSession: (id)sender
{
	NSURL *sessionURL = nil;
	BXSession *session = self.currentSession;
	if (session)
	{
		//When running a gamebox, offer up the gamebox itself
		if (session.hasGamebox)
            sessionURL = session.gamebox.bundleURL;
        
		//Otherwise, offer up the current DOS program or directory
		else sessionURL = session.currentURL;
	}
    
	if (sessionURL)
    {
        [self revealURLsInFinder: @[sessionURL]];
    }
}

@end
