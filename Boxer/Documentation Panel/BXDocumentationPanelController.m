//
//  BXDocumentationPanelController.m
//  Boxer
//
//  Created by Alun Bestor on 05/01/2013.
//  Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
//

#import "BXDocumentationPanelController.h"
#import "NSWindow+BXWindowDimensions.h"
#import "BXSession.h"

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


//Resize the window/popover to accommodate the specified number of documentation items.
- (void) _sizeWindowToFitNumberOfItems: (NSUInteger)numItems;
- (void) _sizePopoverToFitNumberOfItems: (NSUInteger)numItems;

@end

@implementation BXDocumentationPanelController
@synthesize session = _session;
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
        self.maxPopoverSize = NSMakeSize(640, 448);
    }
    return self;
}

- (void) dealloc
{
    self.session = nil;
    self.popover = nil;
    self.popoverBrowser = nil;
    self.windowBrowser = nil;
    
    [super dealloc];
}

- (void) windowDidLoad
{
    self.windowBrowser = [BXDocumentationBrowser browserForSession: nil];
    self.windowBrowser.delegate = self;
    self.windowBrowser.representedObject = self.session;
    
    self.window.contentSize = self.windowBrowser.view.frame.size;
    self.window.contentView = self.windowBrowser.view;
    
    //Fix the responder chain, which will have been reset when we assigned
    //the browser's view as the content view of the window.
    self.windowBrowser.nextResponder = self.windowBrowser.view.nextResponder;
    self.windowBrowser.view.nextResponder = self.windowBrowser;

    [self _sizeWindowToFitNumberOfItems: self.windowBrowser.documentationURLs.count];
}

- (void) setSession: (BXSession *)session
{
    if (self.session != session)
    {
        [_session release];
        _session = [session retain];
        
        self.popoverBrowser.representedObject = session;
        self.windowBrowser.representedObject = session;
    }
}


#pragma mark - Layout management

- (NSRect) windowRectForIdealBrowserSize: (NSSize)targetSize
{
    //Cap the desired size to our maximum and minimum window size
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
    
    return frameRect;
}

- (NSSize) popoverSizeForIdealBrowserSize: (NSSize)targetSize
{
    //Cap the desired size to our own maximum size
    targetSize.width = MIN(targetSize.width, self.maxPopoverSize.width);
    targetSize.height = MIN(targetSize.height, self.maxPopoverSize.height);
    
    return targetSize;
}

- (void) _sizeWindowToFitNumberOfItems: (NSUInteger)numItems
{
    if (self.windowBrowser)
    {
        NSSize idealSize = [self.windowBrowser idealContentSizeForNumberOfItems: numItems];
        NSRect windowRect = [self windowRectForIdealBrowserSize: idealSize];
        [self.window setFrame: windowRect display: self.window.isVisible animate: self.window.isVisible];
    }
}

- (void) _sizePopoverToFitNumberOfItems: (NSUInteger)numItems
{
    if (self.popoverBrowser)
    {
        NSSize idealSize = [self.popoverBrowser idealContentSizeForNumberOfItems: numItems];
        NSSize popoverSize = [self popoverSizeForIdealBrowserSize: idealSize];
        self.popover.contentSize = popoverSize;
    }
}

- (void) sizeToFit
{
    [self _sizeWindowToFitNumberOfItems: self.windowBrowser.documentationURLs.count];
    [self _sizePopoverToFitNumberOfItems: self.popoverBrowser.documentationURLs.count];
}

- (void) documentationBrowser: (BXDocumentationBrowser *)browser willUpdateFromURLs: (NSArray *)oldURLs toURLs: (NSArray *)newURLs
{
    NSUInteger oldCount = oldURLs.count, newCount = newURLs.count;
    
    //Freeze the size of the browser's existing documentation items while it updates, to prevent them reflowing.
    //TODO: find a less destructive way to do this, e.g. by temporarily disabling autoresizing.
    NSCollectionView *collection = browser.documentationList;
    if (collection.content.count)
    {
        NSSize lockedSize = [collection frameForItemAtIndex: 0].size;
        collection.minItemSize = lockedSize;
        collection.maxItemSize = lockedSize;
    }
    
    //If items are being added to the browser, then expand the popover/window to accommodate them
    //*before* they are added to the collection.
    if (newCount > oldCount)
    {
        if (browser == self.windowBrowser)
            [self _sizeWindowToFitNumberOfItems: newCount];
        else
            [self _sizePopoverToFitNumberOfItems: newCount];
    }
}

- (void) documentationBrowser: (BXDocumentationBrowser *)browser didUpdateFromURLs: (NSArray *)oldURLs toURLs: (NSArray *)newURLs
{
    NSUInteger oldCount = oldURLs.count, newCount = newURLs.count;
    
    //Unfreeze the items to allow them to be re-laid-out.
    //TODO: persist the original values and restore them afterward.
    NSCollectionView *collection = browser.documentationList;
    collection.minItemSize = NSZeroSize;
    collection.maxItemSize = NSZeroSize;
    
    //If items were deleted from the browser, then shrink the popover/window
    //after they're gone to accommodate the now-reduced browser dimensions.
    if (newCount < oldCount)
    {
        if (browser == self.windowBrowser)
            [self _sizeWindowToFitNumberOfItems: newCount];
        else
            [self _sizePopoverToFitNumberOfItems: newCount];
    }
}

- (void) setMaxPopoverSize: (NSSize)maxPopoverSize
{
    if (!NSEqualSizes(self.maxPopoverSize, maxPopoverSize))
    {
        _maxPopoverSize = maxPopoverSize;
        [self _sizePopoverToFitNumberOfItems: self.popoverBrowser.documentationURLs.count];
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
            self.popoverBrowser.delegate = self;
            
            self.popover = [[[NSPopover alloc] init] autorelease];
            self.popover.behavior = NSPopoverBehaviorSemitransient; //Allows files to be drag-dropped into the popover
            self.popover.animates = YES;
            self.popover.delegate = self;
            
            self.popover.contentViewController = self.popoverBrowser;
            
            [self _sizePopoverToFitNumberOfItems: self.popoverBrowser.documentationURLs.count];
        }
        
        [self willChangeValueForKey: @"shown"];
        
        self.session = session;
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
    
    self.session = session;
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

//Tear-off popovers are disabled for now because they screw up the responder chain
//and can cause rendering errors when the original popover is reused.
/*
- (NSWindow *) detachableWindowForPopover: (NSPopover *)popover
{
    return self.window;
}
 */

#pragma mark - Delegate responses

//Close our popover/window when the user performs any action.
- (void) documentationBrowser: (BXDocumentationBrowser *)browser didOpenURLs: (NSArray *)URLs
{
    [self close];
}

- (void) documentationBrowser: (BXDocumentationBrowser *)browser didPreviewURLs: (NSArray *)URLs
{
    [self close];
}

- (void) documentationBrowser: (BXDocumentationBrowser *)browser didRevealURLs: (NSArray *)URLs
{
    [self close];
}

- (NSUndoManager *) windowWillReturnUndoManager: (NSWindow *)window
{
    return self.session.undoManager;
}

- (NSWindow *) documentationBrowser: (BXDocumentationBrowser *)browser windowForModalError: (NSError *)error
{
    if (self.isWindowLoaded && self.window.isVisible)
        return self.window;
    else
        return self.session.windowForSheet;
}

- (NSError *) documentationBrowser: (BXDocumentationBrowser *)browser willPresentError: (NSError *)error
{
    //Close the documentation browser when an error will appear.
    if (self.popover.isShown)
        [self close];
    
    return error;
}

@end
