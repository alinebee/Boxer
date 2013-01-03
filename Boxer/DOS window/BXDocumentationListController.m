//
//  BXDocumentationListController.m
//  Boxer
//
//  Created by Alun Bestor on 02/01/2013.
//  Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
//

#import "BXDocumentationListController.h"
#import "BXSession.h"
#import "BXGamebox.h"
#import "NSURL+BXQuickLookHelpers.h"
#import "NSView+BXDrawing.h"

enum {
    BXDocumentationItemIcon = 1,
    BXDocumentationItemLabel = 2,
};

@interface BXDocumentationListController ()

//A copy of the gamebox's reported documentation.
//Repopulated whenever the gamebox announces that it has been updated.
@property (readwrite, copy, nonatomic) NSArray *documentationURLs;

//Called to repopulate and re-sort our local copy of the documentation URLs.
- (void) _syncDocumentationURLs;

@end

@implementation BXDocumentationListController
@synthesize documentationScrollView = _documentationScrollView;
@synthesize documentationList = _documentationList;
@synthesize documentationURLs = _documentationURLs;
@synthesize documentationSelectionIndexes = _documentationSelectionIndexes;


#pragma mark - Initialization and deallocation

+ (id) documentationListForSession: (BXSession *)session
{
    return [[[self alloc] initWithSession: session] autorelease];
}

- (id) initWithSession: (BXSession *)session
{
    self = [self initWithNibName: @"DocumentationList" bundle: nil];
    if (self)
    {
        self.documentationURLs = [NSMutableArray array];
        self.representedObject = session;
    }
    
    return self;
}

- (void) setRepresentedObject: (id)representedObject
{
    if (self.representedObject != representedObject)
    {
        [self.representedObject removeObserver: self forKeyPath: @"gamebox.documentationURLs"];
        
        [super setRepresentedObject: representedObject];
        
        [self.representedObject addObserver: self
                                 forKeyPath: @"gamebox.documentationURLs"
                                    options: NSKeyValueObservingOptionInitial
                                    context: NULL];
    }
}

- (void) awakeFromNib
{
    if ([self.documentationScrollView respondsToSelector: @selector(setUsesPredominantAxisScrolling:)])
        self.documentationScrollView.usesPredominantAxisScrolling = YES;
    
    if ([self.documentationScrollView respondsToSelector: @selector(setVerticalScrollElasticity:)])
        self.documentationScrollView.verticalScrollElasticity = NSScrollElasticityNone;
    
	[self.view registerForDraggedTypes: @[NSFilenamesPboardType]];
    
    //Insert ourselves into the responder chain ahead of our view.
    self.nextResponder = self.view.nextResponder;
    self.view.nextResponder = self;
}

- (void) dealloc
{
    self.view.nextResponder = nil;
    
    self.documentationScrollView = nil;
    self.documentationList = nil;
    self.documentationURLs = nil;
    self.documentationSelectionIndexes = nil;
    
    [super dealloc];
}

#pragma mark - Binding accessors

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    if ([keyPath isEqualToString: @"gamebox.documentationURLs"])
    {
        [self _syncDocumentationURLs];
    }
}

- (void) _syncDocumentationURLs
{
    //IMPLEMENTATION NOTE: when refreshing the documentation list, we want to disturb
    //the existing entries as little as possible: specifically we want to avoid destroying
    //and recreating entries for existing URLs, as this would cause their respective views
    //to be destroyed and recreated as well.
    
    BXSession *session = (BXSession *)self.representedObject;
    NSArray *newURLs = session.gamebox.documentationURLs;
    NSArray *oldURLs = [self.documentationURLs copy]; //We take a copy as this array will mutate during iteration
    
    //To make sure the collection view sees what's happening, we do these permutations
    //to the KVO wrapper instead of the underlying array.
    NSMutableArray *notifier = [self mutableArrayValueForKey: @"documentationURLs"];
    
    //We don't get any information from upstream about which entries have been added and removed,
    //so we work this out for ourselves: removing any URLs that are no longer in the new list,
    //and adding any URLs that weren't in the old list.
    for (NSURL *URL in oldURLs)
    {
        if (![newURLs containsObject: URL])
            [notifier removeObject: URL];
    }
    for (NSURL *URL in newURLs)
    {
        if (![oldURLs containsObject: URL])
            [notifier addObject: URL];
    }
    
    //Finally, re-sort the documentation by filetype and filename.
    [notifier sortUsingDescriptors: self.documentationSortCriteria];
    
    [oldURLs release];
}

+ (NSSet *) keyPathsForValuesAffectingTitle
{
    return [NSSet setWithObject: @"representedObject"];
}

- (NSString *) title
{
    NSString *titleFormat = NSLocalizedString(@"%@ Documentation", @"Title for documentation list popover. %@ is the display name of the current session.");
    NSString *displayName = [(BXSession *)self.representedObject displayName];
    
    return [NSString stringWithFormat: titleFormat, displayName];
}

- (NSArray *) selectedDocumentationURLs
{
    return [self.documentationURLs objectsAtIndexes: self.documentationSelectionIndexes];
}

- (NSArray *) documentationSortCriteria
{
	//Sort docs by extension then by filename, to group similar items together
	NSSortDescriptor *sortByType, *sortByName;
	SEL comparison = @selector(caseInsensitiveCompare:);
	sortByType	= [[NSSortDescriptor alloc]	initWithKey: @"pathExtension"
                                             ascending: YES
                                              selector: comparison];
	sortByName	= [[NSSortDescriptor alloc]	initWithKey: @"lastPathComponent.stringByDeletingPathExtension"
                                             ascending: YES
                                              selector: comparison];
	
	NSArray *sortDescriptors = @[sortByType, sortByName];
	[sortByType release], [sortByName release];
	return sortDescriptors;
}


#pragma mark - Interface actions

- (IBAction) openSelectedDocumentationItems: (id)sender
{
    if (self.documentationSelectionIndexes.count)
    {
        [[NSWorkspace sharedWorkspace] openURLs: self.selectedDocumentationURLs
                        withAppBundleIdentifier: nil
                                        options: NSWorkspaceLaunchDefault
                 additionalEventParamDescriptor: nil
                              launchIdentifiers: NULL];
        
        //Hide the at the same time
        [self.view.window orderOut: self];
    }
}

- (IBAction) revealSelectedDocumentationItemsInFinder: (id)sender
{
    if (self.documentationSelectionIndexes.count)
    {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: self.selectedDocumentationURLs];
    }
}

- (IBAction) trashSelectedDocumentationItems: (id)sender
{
    BXSession *session = self.representedObject;
    for (NSURL *documentationURL in self.selectedDocumentationURLs)
    {
        NSError *trashError = nil;
        BOOL trashed = [session.gamebox trashDocumentationURL: documentationURL error: &trashError];
        
        if (!trashed && trashError != nil)
        {
            [self presentError: trashError
                modalForWindow: session.windowForSheet
                      delegate: nil
            didPresentSelector: NULL
                   contextInfo: NULL];
            
            //Do not continue if trashing one of the items failed.
            return;
        }
    }
}

- (IBAction) showDocumentationFolderInFinder: (id)sender
{
    BXSession *session = self.representedObject;
    NSURL *documentationURL = [session.gamebox documentationFolderURLCreatingIfMissing: YES error: NULL];
    
    //If the documentation folder couldn't be found or created, show the user the gamebox itself instead.
    if (!documentationURL)
        documentationURL = session.gamebox.bundleURL;
    
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: @[documentationURL]];
}

- (BOOL) validateMenuItem: (NSMenuItem *)menuItem
{
    BOOL hasSelectedItems = (self.documentationSelectionIndexes.count > 0);
    
    if (menuItem.action == @selector(trashSelectedDocumentationItems:) ||
        menuItem.action == @selector(revealSelectedDocumentationItemsInFinder:) ||
        menuItem.action == @selector(openSelectedDocumentationItems:))
    {
        return hasSelectedItems;
    }
    else
    {
        return YES;
    }
}


#pragma mark - Drag-drop

- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender
{
	NSPasteboard *pboard = sender.draggingPasteboard;
    
	if ([pboard canReadObjectForClasses: @[[NSURL class]]
                                options: @{ NSPasteboardURLReadingFileURLsOnlyKey : @(YES) }])
	{
        return NSDragOperationCopy;
	}
	else
    {
        return NSDragOperationNone;
    }
}

- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender
{
    BXSession *session = self.representedObject;
	NSPasteboard *pboard = sender.draggingPasteboard;
	
    NSArray *droppedURLs = [pboard readObjectsForClasses: @[[NSURL class]]
                                                 options: @{ NSPasteboardURLReadingFileURLsOnlyKey : @(YES) }];
        
    BOOL importedAnything = NO;
    
    NSError *importError = nil;
    for (NSURL *documentationURL in droppedURLs)
    {
        NSURL *importedURL = [session.gamebox addDocumentationFileFromURL: documentationURL
                                                                 ifExists: BXGameboxDocumentationRename
                                                                    error: &importError];
        
        if (importedURL != nil)
        {
            importedAnything = YES;
        }
        else
        {
            [self presentError: importError
                modalForWindow: session.windowForSheet
                      delegate: nil
            didPresentSelector: NULL
                   contextInfo: NULL];
        }
        
        //TODO: scroll the view to focus on the last-added item.
    }
    
	return importedAnything;
}


@end


//A private class to implement the QLPreviewItem protocol for BXDocumentPreviews.
@interface BXDocumentationListPreviewItem : NSObject <QLPreviewItem>
{
    NSURL *_previewItemURL;
}
@property (copy, nonatomic) NSURL *previewItemURL;

+ (id) previewItemWithURL: (NSURL *)URL;

@end

@implementation BXDocumentationListPreviewItem
@synthesize previewItemURL = _previewItemURL;

+ (id) previewItemWithURL: (NSURL *)URL
{
    BXDocumentationListPreviewItem *previewItem = [[self alloc] init];
    previewItem.previewItemURL = URL;
    return [previewItem autorelease];
}

- (void) dealloc
{
    self.previewItemURL = nil;
    [super dealloc];
}

@end


@implementation BXDocumentationListController (BXDocumentPreviews)

#pragma mark - QLPreviewPanelController protocol implementations

- (BOOL) acceptsPreviewPanelControl: (QLPreviewPanel *)panel
{
    return YES;
}

- (void) beginPreviewPanelControl: (QLPreviewPanel *)panel
{
    panel.delegate = self;
    panel.dataSource = self;
    panel.currentPreviewItemIndex = self.documentationSelectionIndexes.firstIndex;
}

- (void) endPreviewPanelControl: (QLPreviewPanel *)panel
{
    panel.delegate = nil;
    panel.dataSource = nil;
}

#pragma mark - QLPreviewPanelDataSource protocol implementations

- (NSInteger) numberOfPreviewItemsInPreviewPanel: (QLPreviewPanel *)panel
{
    return self.documentationURLs.count;
}

- (id <QLPreviewItem>) previewPanel: (QLPreviewPanel *)panel previewItemAtIndex: (NSInteger)index
{
    NSURL *URL = [self.documentationURLs objectAtIndex: index];
    return [BXDocumentationListPreviewItem previewItemWithURL: URL];
}

#pragma mark - QLPreviewPanelDelegate protocol implementations

- (NSRect) previewPanel: (QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem: (id<QLPreviewItem>)item
{
    NSInteger itemIndex = [self.documentationURLs indexOfObject: item.previewItemURL];
    if (itemIndex != NSNotFound)
    {
        NSView *itemView = [self.documentationList itemAtIndex: itemIndex].view;
        NSView *itemIcon = [itemView viewWithTag: BXDocumentationItemIcon];
        
        NSRect frameInList = [self.documentationList convertRect: itemIcon.bounds fromView: itemIcon];
        
        //Ensure that the frame is currently visible within the scroll view.
        if (NSIntersectsRect(frameInList, self.documentationScrollView.documentVisibleRect))
        {
            NSRect frameInWindow = [self.documentationList convertRect: frameInList toView: nil];
            NSRect frameOnScreen = [self.view.window convertRectToScreen: frameInWindow];
        
            return frameOnScreen;
        }
    }
    
    //If we can't determine a suitable source frame from which the specified item can zoom,
    //then return an empty rect to make have the preview fade in instead.
    return NSZeroRect;
}

- (NSImage *) previewPanel: (QLPreviewPanel *)panel transitionImageForPreviewItem: (id <QLPreviewItem>)item contentRect: (NSRect *)contentRect
{
    NSInteger itemIndex = [self.documentationURLs indexOfObject: item.previewItemURL];
    
    if (itemIndex != NSNotFound)
    {
        NSView *itemView = [self.documentationList itemAtIndex: itemIndex].view;
        NSView *itemIcon = [itemView viewWithTag: BXDocumentationItemIcon];
        
        NSImage *snapshot = [itemIcon imageWithContentsOfRect: itemIcon.bounds];
        return snapshot;
    }
    else return nil;
}

- (IBAction) previewSelectedDocumentationItems: (id)sender
{
    if ([QLPreviewPanel sharedPreviewPanelExists] && [QLPreviewPanel sharedPreviewPanel].isVisible)
    {
        [[QLPreviewPanel sharedPreviewPanel] orderOut: self];
    }
    else
    {
        [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront: self];
    }
}

- (void) setDocumentationSelectionIndexes: (NSIndexSet *)indexes
{
    if (![self.documentationSelectionIndexes isEqualToIndexSet: indexes])
    {
        [_documentationSelectionIndexes release];
        _documentationSelectionIndexes = [indexes retain];
    }
    
    [self synchronizePreviewToSelection];
}

- (void) synchronizePreviewToSelection
{
    if (![QLPreviewPanel sharedPreviewPanelExists])
        return;
    
    QLPreviewPanel *panel = [QLPreviewPanel sharedPreviewPanel];
    
    //Only change the panel preview if a) we're in charge of the panel and
    //b) the selection doesn't contain the current preview item.
    if (panel.currentController == self &&
        ![self.documentationSelectionIndexes containsIndex: panel.currentPreviewItemIndex])
    {
        panel.currentPreviewItemIndex = self.documentationSelectionIndexes.firstIndex;
    }
}

@end



@interface BXDocumentationItem ()

//Reimplemented to be read-write internally.
@property (copy, nonatomic) NSImage *icon;

//Loads up the icon (or spotlight preview) for the documentation URL as it is displayed in Finder.
- (void) _refreshIcon;

@end

@implementation BXDocumentationItem
@synthesize icon = _icon;

- (void) setRepresentedObject: representedObject
{
    if (representedObject != self.representedObject)
    {
        [super setRepresentedObject: representedObject];
        [self _refreshIcon];
    }
}

- (void) _refreshIcon
{
    if (self.representedObject)
    {
        //First, check if the file has a custom icon. If so we will use this and be done with it.
        NSImage *customIcon = nil;
        BOOL loadedCustomIcon = [(NSURL *)self.representedObject getResourceValue: &customIcon forKey: NSURLCustomIconKey error: NULL];
        
        if (loadedCustomIcon && customIcon != nil)
        {
            self.icon = customIcon;
            return;
        }
        //If the file doesn't have a custom icon, then initially display the default icon for this file type
        //while we try to load a Quick Look thumbnail for the file.
        else
        {
            //First, load and display Finder's standard icon for the file.
            NSImage *defaultIcon = nil;
            BOOL loadedDefaultIcon = [(NSURL *)self.representedObject getResourceValue: &defaultIcon forKey: NSURLEffectiveIconKey error: NULL];
            if (loadedDefaultIcon && defaultIcon != nil)
            {
                self.icon = defaultIcon;
            }
            //Meanwhile, load in a quicklook preview for this file in the background.
            NSURL *previewURL = [self.representedObject copy];
            //Take retina displays into account when calculating the appropriate preview size.
            NSSize thumbnailSize = self.view.bounds.size;
            if ([self.view respondsToSelector: @selector(convertSizeToBacking:)])
                thumbnailSize = [self.view convertSizeToBacking: thumbnailSize];
            
            //We perform this in an asynchronous block, because it can take a while
            //to prepare the thumbnail.
            dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0);
            dispatch_async(queue, ^{
                NSImage *thumbnail = [previewURL quickLookThumbnailWithMaxSize: thumbnailSize iconStyle: YES];
                
                //Double-check that our represented object hasn't changed in the meantime.
                if ([previewURL isEqual: self.representedObject])
                {
                    //Ensure we change the icon on the main thread, where the UI is doing its thing.
                    [self performSelectorOnMainThread: @selector(setIcon:) withObject: thumbnail waitUntilDone: YES];
                }
            });
            
            [previewURL release];
        }
    }
}

+ (NSSet *) keyPathsForValuesAffectingDisplayName
{
    return [NSSet setWithObject: @"representedObject"];
}

- (NSString *)displayName
{
    return [(NSURL *)self.representedObject lastPathComponent].stringByDeletingPathExtension;
}

@end


@implementation BXDocumentationWrapper

- (void) collectionViewItemDidChangeSelection
{
    [self setNeedsDisplay: YES];
}

- (void) drawRect: (NSRect)dirtyRect
{
    if (self.delegate.isSelected)
    {
        NSBezierPath *highlightPath = [NSBezierPath bezierPathWithRoundedRect: self.bounds
                                                                      xRadius: 8
                                                                      yRadius: 8];
        
        NSColor *highlightColor = [NSColor colorWithCalibratedWhite: 0 alpha: 0.15];
        
        [highlightColor set];
        [highlightPath fill];
    }
}

- (void) mouseDown: (NSEvent *)theEvent
{
    //Open the corresponding documentation item when the view is double-clicked.
    if (theEvent.clickCount > 1)
    {
        //Ensure that the item is selected.
        self.delegate.selected = YES;
        [NSApp sendAction: @selector(openSelectedDocumentationItems:)
                       to: nil
                     from: self];
    }
    else
    {
        [super mouseDown: theEvent];
    }
}
@end



@implementation BXDocumentationList

- (void) keyDown: (NSEvent *)theEvent
{
    //Trigger a preview when the space key is hit.
    if ([theEvent.charactersIgnoringModifiers isEqualToString: @" "])
    {
        [NSApp sendAction: @selector(previewSelectedDocumentationItems:) to: nil from: self];
    }
    else
    {
        [super keyDown: theEvent];
    }
}
@end