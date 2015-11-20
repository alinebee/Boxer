/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Cocoa/Cocoa.h>
#import "BXDocumentationBrowser.h"

NS_ASSUME_NONNULL_BEGIN

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
@property (retain, nonatomic, nullable) BXSession *session;

//Whether the panel is currently visible, either as a popover or as a window.
@property (readonly, nonatomic, getter=isShown) BOOL shown;

//The maximum size we permit the popover to get.
@property (assign, nonatomic) NSSize maxPopoverSize;

//Returns whether popovers are available. This will return NO on 10.6.
+ (BOOL) supportsPopover;


#pragma mark - Initialization

//Returns a new controller instance.
+ (instancetype) controller;

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


#pragma mark - Layout

- (NSRect) windowRectForIdealBrowserSize: (NSSize)targetSize;
- (NSSize) popoverSizeForIdealBrowserSize: (NSSize)targetSize;

//Resize the window/popover to be suitable for the current number of documentation items.
- (void) sizeToFit;

@end

NS_ASSUME_NONNULL_END
