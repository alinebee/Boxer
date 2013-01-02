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

@interface BXDocumentationListController ()

//A copy of the gamebox's reported documentation.
//Repopulated whenever the gamebox announces that it has been updated.
@property (readwrite, copy, nonatomic) NSArray *documentationURLs;

@end

@implementation BXDocumentationListController
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

- (void) dealloc
{
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
        //Make a copy of the documentation, since this list may be expensive to generate.
        self.documentationURLs = [object valueForKeyPath: keyPath];
    }
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

- (void) setView: (NSView *)view
{
    [super setView: view];
    
	[self.view registerForDraggedTypes: @[NSFilenamesPboardType]];
}

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


@interface BXDocumentationItem ()

//Reimplemented to be read-write internally.
@property (copy, nonatomic) NSImage *icon;

//Loads up the icon for the documentation URL as it is displayed in Finder.
- (void) _refreshFinderIcon;

//Loads up a spotlight preview of the contents of the documentation URL.
- (void) _refreshSpotlightPreview;

@end

@implementation BXDocumentationItem
@synthesize icon = _icon;

- (void) setRepresentedObject: representedObject
{
    [super setRepresentedObject: representedObject];
    
    [self _refreshFinderIcon];
}

- (void) _refreshFinderIcon
{
    if (self.representedObject)
    {
        NSImage *finderIcon = nil;
        BOOL loadedIcon = [(NSURL *)self.representedObject getResourceValue: &finderIcon forKey: NSURLEffectiveIconKey error: NULL];
        if (loadedIcon)
            self.icon = finderIcon;
    }
}

- (void) _refreshSpotlightPreview
{
    //Currently unimplemented
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
        
        NSColor *highlightColor = [NSColor colorWithCalibratedWhite: 0 alpha: 0.25];
        
        [highlightColor set];
        [highlightPath fill];
    }
}

@end