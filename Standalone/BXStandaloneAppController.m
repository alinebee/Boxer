//
//  BXStandaloneAppController.m
//  Boxer
//
//  Created by Alun Bestor on 19/07/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXStandaloneAppController.h"
#import "BXSession.h"

#pragma mark -
#pragma mark App-menu replacement constants

enum {
    BXAppMenuTag = 1,
    BXHelpMenuTag = 2,
};

NSString * const BXAppMenuPlaceholderText = @"[Appname]";


#pragma mark -
#pragma mark Error constants

enum {
    BXStandaloneAppMissingGameboxError,
};

NSString * const BXStandaloneAppErrorDomain = @"BXStandaloneAppErrorDomain";


#pragma mark -
#pragma mark Info.plist and User-Defaults constants

NSString * const BXBundledGameboxNameInfoPlistKey = @"BXBundledGameboxName";


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

- (void) _synchronizeTitlesForMainMenuItemWithTag: (NSInteger)tag
{
    NSMenu *menu = [[NSApp mainMenu] itemWithTag: tag].submenu;
    [self _synchronizeTitlesForMenu: menu];
}

- (void) _synchronizeTitlesForMenu: (NSMenu *)menu
{
    NSString *appName = [[self class] appName];
    
    for (NSMenuItem *item in menu.itemArray)
    {
        NSString *title = [item.title stringByReplacingOccurrencesOfString: BXAppMenuPlaceholderText 
                                                                withString: appName];
        
        item.title = title;
    }
}


#pragma mark -
#pragma mark Application lifecycle

- (BOOL) isStandaloneGameBundle
{
    return YES;
}

- (void) applicationWillFinishLaunching: (NSNotification *)notification
{
    [super applicationWillFinishLaunching: notification];
    
    [self _synchronizeTitlesForMainMenuItemWithTag: BXAppMenuTag];
    [self _synchronizeTitlesForMainMenuItemWithTag: BXHelpMenuTag];
}

- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
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
}

- (id) openBundledGameAndDisplay: (BOOL)display error: (NSError **)outError
{
    return [self openUntitledDocumentAndDisplay: display error: outError];
}

- (id) makeUntitledDocumentOfType: (NSString *)typeName error: (NSError **)outError
{
    NSString *bundledGameboxName = [[NSBundle mainBundle] objectForInfoDictionaryKey: BXBundledGameboxNameInfoPlistKey];
    NSURL *bundledGameboxURL = [[NSBundle mainBundle] URLForResource: bundledGameboxName
                                                       withExtension: @"boxer"];
    
    if (bundledGameboxURL)
    {
        BXSession *session = [[BXSession alloc] initWithContentsOfURL: bundledGameboxURL ofType: typeName error: outError];
        return session;
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


@end