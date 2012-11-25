//
//  BXStandaloneAppController.m
//  Boxer
//
//  Created by Alun Bestor on 19/07/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXStandaloneAppController.h"
#import "BXSession.h"
#import "BXEmulator.h"
#import "BXStandaloneAboutController.h"
#import "BXBaseAppController+BXHotKeys.h"

#pragma mark -
#pragma mark App-menu replacement constants

enum {
    BXAppMenuTag = 1,
    BXHelpMenuTag = 2,
};

NSString * const BXMenuPlaceholderAppName            = @"[AppName]";
NSString * const BXMenuPlaceholderOrganizationName   = @"[OrganizationName]";


#pragma mark -
#pragma mark Error constants

enum {
    BXStandaloneAppMissingGameboxError,
};

NSString * const BXStandaloneAppErrorDomain = @"BXStandaloneAppErrorDomain";


#pragma mark -
#pragma mark Info.plist and User-Defaults constants

NSString * const BXOrganizationNameInfoPlistKey = @"BXOrganizationName";
NSString * const BXBundledGameboxNameInfoPlistKey = @"BXBundledGameboxName";
NSString * const BXOrganizationWebsiteURLInfoPlistKey = @"BXOrganizationWebsiteURL";


#pragma mark -
#pragma mark Private method declarations

@interface BXStandaloneAppController ()

//Update the specified menu's options to reflect the actual application name.
//Called during application loading.
- (void) _synchronizeTitlesForMenu: (NSMenu *)menu;
- (void) _synchronizeTitlesForMainMenuItemWithTag: (NSInteger)tag;

@end


#pragma mark -
#pragma mark Implementation

@implementation BXStandaloneAppController

#pragma mark -
#pragma mark Custom menu handling

+ (NSString *) organizationName
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: BXOrganizationNameInfoPlistKey];
}

- (void) _synchronizeTitlesForMainMenuItemWithTag: (NSInteger)tag
{
    NSMenu *menu = [[NSApp mainMenu] itemWithTag: tag].submenu;
    [self _synchronizeTitlesForMenu: menu];
}

- (void) _synchronizeTitlesForMenu: (NSMenu *)menu
{
    NSString *appName = [self.class appName];
    NSString *organizationName = [self.class organizationName];
    
    for (NSMenuItem *item in menu.itemArray)
    {
        NSString *title = item.title;
        
        if (appName.length)
            title = [title stringByReplacingOccurrencesOfString: BXMenuPlaceholderAppName 
                                                     withString: appName];
        
        if (organizationName.length)
            title = [title stringByReplacingOccurrencesOfString: BXMenuPlaceholderOrganizationName 
                                                     withString: organizationName];
        
        item.title = title;
    }
}


#pragma mark -
#pragma mark Application lifecycle

- (BOOL) isStandaloneGameBundle
{
    return YES;
}

- (BOOL) isUnbrandedGameBundle
{
    //If no organization name was provided, hide all branding.
    return ([self.class organizationName].length == 0);
}

- (NSUInteger) maximumRecentDocumentCount
{
    return 0;
}

- (void) applicationWillFinishLaunching: (NSNotification *)notification
{
    [super applicationWillFinishLaunching: notification];
    
    [self _synchronizeTitlesForMainMenuItemWithTag: BXAppMenuTag];
    [self _synchronizeTitlesForMainMenuItemWithTag: BXHelpMenuTag];
}

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
    [NSApp activateIgnoringOtherApps: YES];
    
    NSError *launchError = nil;
    BXSession *session = [self openBundledGameAndDisplay: YES error: &launchError];
    
    if (!session)
    {
        if (launchError)
        {
            [self presentError: launchError];
        }
        
        [NSApp terminate: self];
    }
    else
    {
        [self showHotkeyWarningIfUnavailable];
    }
}

- (id) openBundledGameAndDisplay: (BOOL)display error: (NSError **)outError
{
    return [self openUntitledDocumentAndDisplay: display error: outError];
}

- (id) makeUntitledDocumentOfType: (NSString *)typeName error: (NSError **)outError
{
    if ([BXEmulator canLaunchEmulator])
    {
        NSString *bundledGameboxName = [[NSBundle mainBundle] objectForInfoDictionaryKey: BXBundledGameboxNameInfoPlistKey];
        
        if (![bundledGameboxName.pathExtension isEqualToString: @"boxer"])
            bundledGameboxName = [bundledGameboxName stringByAppendingPathExtension: @"boxer"];
        
        NSURL *bundledGameboxURL = [[NSBundle mainBundle] URLForResource: bundledGameboxName
                                                           withExtension: nil];
        
        if (bundledGameboxURL)
        {
            BXSession *session = [[BXSession alloc] initWithContentsOfURL: bundledGameboxURL
                                                                   ofType: typeName
                                                                    error: outError];
            return [session autorelease];
        }
        else
        {
            if (outError)
            {
                NSString *errorTitle = @"This application does not contain a bundled gamebox.";
                NSString *errorSuggestion = @"Ensure that the gamebox is placed in the Resources folder of the application, and that the Info.plist contains a “BXBundledGameboxName” key specifying the name of the gamebox without an extension.";
                NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                           errorTitle, NSLocalizedDescriptionKey,
                                           errorSuggestion, NSLocalizedRecoverySuggestionErrorKey,
                                           nil];
                
                *outError = [NSError errorWithDomain: BXStandaloneAppErrorDomain
                                                code: BXStandaloneAppMissingGameboxError
                                            userInfo: errorInfo];
            }
            
            return nil;
        }
    }
    //If we've already launched the emulator once (i.e. if we're restarting the game)
    //then we'll need to replace ourselves with a separate process to handle it.
    else
    {
        NSString *executablePath = [[NSBundle mainBundle] executablePath];
        [NSTask launchedTaskWithLaunchPath: executablePath arguments: [NSArray array]];
        
        if (outError)
            *outError = [NSError errorWithDomain: NSCocoaErrorDomain
                                            code: NSUserCancelledError
                                        userInfo: nil];
        return nil;
    }
}

- (id) makeDocumentWithContentsOfURL: (NSURL *)absoluteURL
                              ofType: (NSString *)typeName
                               error: (NSError **)outError
{
    return [self makeUntitledDocumentOfType: typeName error: outError];
}

//Suppress the automatic opening of untitled files when the user refocuses the application.
- (BOOL) applicationShouldOpenUntitledFile: (NSApplication *)sender
{
    return NO;
}

- (BOOL) applicationShouldHandleReopen: (NSApplication *)sender
                     hasVisibleWindows: (BOOL)flag
{
    return NO;
}

//Close the entire application when the game window is closed.
- (BOOL) applicationShouldTerminateAfterLastWindowClosed: (NSApplication *)sender
{
    return YES;
}

#pragma mark -
#pragma mark UI actions

- (IBAction) orderFrontAboutPanel: (id)sender
{
    //Show the default OS X app about panel if this is an unbranded game app.
    if (self.isUnbrandedGameBundle)
    {
        [NSApp orderFrontStandardAboutPanel: self];
    }
    else
    {
        [[BXStandaloneAboutController controller] showWindow: sender];
    }
}

- (IBAction) visitOrganizationWebsite: (id)sender
{
    [self openURLFromKey: BXOrganizationWebsiteURLInfoPlistKey];
}

@end