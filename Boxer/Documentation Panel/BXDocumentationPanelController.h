//
//  BXDocumentationPanelController.h
//  Boxer
//
//  Created by Alun Bestor on 05/01/2013.
//  Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BXDocumentationBrowser.h"

@class NSPopover;
@class BXSession;
@interface BXDocumentationPanelController : NSWindowController <NSPopoverDelegate, BXDocumentationBrowserDelegate>
{
    NSPopover *_popover;
    BXDocumentationBrowser *_popoverBrowser;
    BXDocumentationBrowser *_windowBrowser;
    NSSize _maxPopoverSize;
    
    BXSession *_session;
}

#pragma mark - Properties

//The session whose documents are being displayed in the panel.
@property (retain, nonatomic) BXSession *session;

//Whether the panel is currently visible, either as a popover or as a window.
@property (readonly, nonatomic, getter=isShown) BOOL shown;

//The maximum size we permit the popover to get.
@property (assign, nonatomic) NSSize maxPopoverSize;

//Returns whether popovers are available. This will return NO on 10.6.
+ (BOOL) supportsPopover;


#pragma mark - Initialization

//Returns a new controller instance.
+ (BXDocumentationPanelController *) controller;

#pragma mark - Display methods

//Displays the documentation browser in a popover at the specified location.
//On 10.6, which does not support popovers, this will call displayInWindow instead.
- (void) displayForSession: (BXSession *)session
   inPopoverRelativeToRect: (NSRect)positioningRect
                    ofView: (NSView *)positioningView
             preferredEdge: (NSRectEdge)preferredEdge;

//Displays the documentation browser in a floating utility window.
- (void) displayForSession: (BXSession *)session;

//Hides the popover and/or window.
- (void) close;


@end
