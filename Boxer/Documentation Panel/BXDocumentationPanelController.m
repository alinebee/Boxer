//
//  BXDocumentationPanelController.m
//  Boxer
//
//  Created by Alun Bestor on 05/01/2013.
//  Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
//

#import "BXDocumentationPanelController.h"
#import "BXDocumentationBrowser.h"
#import "NSWindow+BXWindowDimensions.h"

@interface BXDocumentationPanelController ()

#pragma mark - Properties

//The popover for this documentation panel. Created the first time it is needed.
//Unused on 10.6, which does not support popovers.
@property (retain, nonatomic) NSPopover *popover;

//The documentation browsers for our popover and window respectively.
//Populated the first time the documentation list is displayed in either mode.
//(These cannot be shared, as the two may be displayed at the same time.)
@property (retain, nonatomic) BXDocumentationBrowser *popoverBrowser;
@property (retain, nonatomic) BXDocumentationBrowser *windowBrowser;

//Resize the window/popover to suit the documentation browser's preferred size.
- (void) _syncWindowSize;
- (void) _syncPopoverSize;

@end

@implementation BXDocumentationPanelController
@synthesize popover = _popover;
@synthesize windowBrowser = _windowBrowser;
@synthesize popoverBrowser = _popoverBrowser;
@synthesize maxPopoverSize = _maxPopoverSize;

#pragma mark - Initialization and deallocation

+ (BXDocumentationPanelController *) controller
{
    return [[[self alloc] initWithWindowNibName: @"DocumentationPanel"] autorelease];
}

- (id) initWithWindow: (NSWindow *)window
{
    self = [super initWithWindow: window];
    if (self)
    {
        self.maxPopoverSize = NSMakeSize(640, 480);
    }
    return self;
}

- (void) dealloc
{
    [self.popoverBrowser removeObserver: self forKeyPath: @"intrinsicContentSize"];
    [self.windowBrowser removeObserver: self forKeyPath: @"intrinsicContentSize"];
    
    self.popover = nil;
    self.popoverBrowser = nil;
    self.windowBrowser = nil;
    
    [super dealloc];
}

- (void) windowDidLoad
{
    self.windowBrowser = [BXDocumentationBrowser browserForSession: nil];
    self.window.contentSize = self.windowBrowser.view.frame.size;
    self.window.contentView = self.windowBrowser.view;
    
    [self.windowBrowser addObserver: self forKeyPath: @"intrinsicContentSize"
                            options: 0
                            context: nil];
}

#pragma mark - Layout management

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    if (object == self.windowBrowser && [keyPath isEqualToString: @"intrinsicContentSize"])
    {
        [self _syncWindowSize];
    }
    else if (object == self.popoverBrowser && [keyPath isEqualToString: @"intrinsicContentSize"])
    {
        [self _syncPopoverSize];
    }
}

- (void) _syncWindowSize
{
    if (self.isWindowLoaded)
    {
        NSSize targetSize = self.windowBrowser.intrinsicContentSize;
        //Cap the content size to our maximum and minimum window size
        NSSize minSize = self.window.contentMinSize;
        NSSize maxSize = self.window.contentMaxSize;
        targetSize.width = MIN(maxSize.width, targetSize.width);
        targetSize.width = MAX(minSize.width, targetSize.width);
        targetSize.height = MIN(maxSize.height, targetSize.height);
        targetSize.height = MAX(minSize.height, targetSize.height);
        
        //Resize the window from the top left corner.
        NSPoint anchor = NSMakePoint(0.0, 1.0);
        NSRect frameRect = [self.window frameRectForContentSize: targetSize
                                                relativeToFrame: self.window.frame
                                                     anchoredAt: anchor];
        
        [self.window setFrame: frameRect display: YES animate: self.window.isVisible];
    }
}

- (void) _syncPopoverSize
{
    if (self.popover)
    {
        NSSize targetSize = self.popoverBrowser.intrinsicContentSize;
        
        //Cap the content size to our own maximum size
        targetSize.width = MIN(targetSize.width, self.maxPopoverSize.width);
        targetSize.height = MIN(targetSize.height, self.maxPopoverSize.height);
        
        self.popover.contentSize = targetSize;
    }
}

- (void) setMaxPopoverSize: (NSSize)maxPopoverSize
{
    if (!NSEqualSizes(self.maxPopoverSize, maxPopoverSize))
    {
        _maxPopoverSize = maxPopoverSize;
        [self _syncPopoverSize];
    }
}

#pragma mark - Display

+ (BOOL) supportsPopover
{
    return NSClassFromString(@"NSPopover") != nil;
}

- (void) displayForSession: (BXSession *)session
   inPopoverRelativeToRect: (NSRect)positioningRect
                    ofView: (NSView *)positioningView
             preferredEdge: (NSRectEdge)preferredEdge
{
    //If popovers are available, create one now and display it.
    if ([self.class supportsPopover])
    {
        //Create the popover and browser the first time they are needed.
        if (!self.popover)
        {
            self.popoverBrowser = [BXDocumentationBrowser browserForSession: session];
            
            self.popover = [[[NSPopover alloc] init] autorelease];
            self.popover.behavior = NSPopoverBehaviorSemitransient;
            self.popover.animates = YES;
            
            self.popover.contentViewController = self.popoverBrowser;
            
            [self.popoverBrowser addObserver: self
                                  forKeyPath: @"intrinsicContentSize"
                                     options: NSKeyValueObservingOptionInitial
                                     context: nil];
        }
        
        [self willChangeValueForKey: @"shown"];
        
        self.popoverBrowser.representedObject = session;
        [self.popover showRelativeToRect: positioningRect ofView: positioningView preferredEdge: preferredEdge];
        
        [self didChangeValueForKey: @"shown"];
    }
    //Otherwise fall back on the standard window appearance.
    else
    {
        [self displayForSession: session];
    }
}

- (void) displayForSession: (BXSession *)session
{
    [self willChangeValueForKey: @"shown"];
    
    //Ensure the window and associated browser are created.
    self.window;
    
    //Ensure the browser knows which session it's representing.
    //(This will populate the browser and will trigger the window to be resized.)
    self.windowBrowser.representedObject = session;
    
    [self.window makeKeyAndOrderFront: self];
    
    [self didChangeValueForKey: @"shown"];
}

- (void) close
{
    [self willChangeValueForKey: @"shown"];
    
    if (self.isWindowLoaded)
        [self.window orderOut: self];
    
    if (self.popover)
        [self.popover performClose: self];
    
    [self didChangeValueForKey: @"shown"];
}

- (BOOL) isShown
{
    return (self.popover.isShown || (self.isWindowLoaded && self.window.isVisible));
}

@end
