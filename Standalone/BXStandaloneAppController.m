//
//  BXStandaloneAppController.m
//  Boxer
//
//  Created by Alun Bestor on 19/07/2012.
//  Copyright (c) 2012 Alun Bestor and contributors. All rights reserved.
//

#import "BXStandaloneAppController.h"

enum {
    BXAppMenuTag = 1,
};

NSString * const BXAppMenuPlaceholderText = @"[Appname]";

@interface BXStandaloneAppController ()

//Update the main menu's options to reflect the actual application name.
//Called during application loading.
- (void) _synchronizeAppMenuItemTitles;

@end


@implementation BXStandaloneAppController

- (void) applicationWillFinishLaunching: (NSNotification *)notification
{
    [super applicationWillFinishLaunching: notification];
    
    [self _synchronizeAppMenuItemTitles];
}

- (void) _synchronizeAppMenuItemTitles
{
    NSString *appName = [[self class] appName];
    
    NSMenu *appMenu = [[NSApp mainMenu] itemWithTag: BXAppMenuTag].submenu;
    for (NSMenuItem *item in appMenu.itemArray)
    {
        NSString *title = [item.title stringByReplacingOccurrencesOfString: BXAppMenuPlaceholderText 
                                                                withString: appName];
        
        item.title = title;
    }
}

@end