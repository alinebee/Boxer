/*
 Boxer is copyright 2013 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXDocumentationBrowser.h"
#import "BXSession.h"
#import "BXGamebox.h"
#import "NSURL+BXQuickLookHelpers.h"
#import "NSView+BXDrawing.h"

enum {
    BXDocumentationItemIcon = 1,
    BXDocumentationItemLabel = 2,
};

@interface BXDocumentationBrowser ()

//A copy of the gamebox's reported documentation.
//Repopulated whenever the gamebox announces that it has been updated.
@property (readwrite, copy, nonatomic) NSArray *documentationURLs;

//Called to repopulate and re-sort our local copy of the documentation URLs.
- (void) _syncDocumentationURLs;

@end

@implementation BXDocumentationBrowser
@synthesize documentationScrollView = _documentationScrollView;
@synthesize documentationList = _documentationList;
@synthesize titleLabel = _titleLabel;
@synthesize helpTextLabel = _helpTextLabel;

@synthesize documentationURLs = _documentationURLs;
@synthesize documentationSelectionIndexes = _documentationSelectionIndexes;
@synthesize delegate = _delegate;

#pragma mark - Initialization and deallocation

+ (id) browserForSession: (BXSession *)session
{
    return [[[self alloc] initWithSession: session] autorelease];
}

- (id) initWithSession: (BXSession *)session
{
    self = [self initWithNibName: @"DocumentationBrowser" bundle: nil];
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
        
        if (self.representedObject)
        {
            [self.representedObject addObserver: self
                                     forKeyPath: @"gamebox.documentationURLs"
                                        options: 0
                                        context: NULL];
            
            [self _syncDocumentationURLs];
        }
    }
}

- (void) awakeFromNib
{
    if ([self.documentationScrollView respondsToSelector: @selector(setUsesPredominantAxisScrolling:)])
        self.documentationScrollView.usesPredominantAxisScrolling = YES;
    
    if ([self.documentationScrollView respondsToSelector: @selector(setVerticalScrollElasticity:)])
        self.documentationScrollView.verticalScrollElasticity = NSScrollElasticityNone;
    
    self.documentationList.minItemSize = self.documentationList.itemPrototype.view.frame.size;
    
	[self.view registerForDraggedTypes: @[NSFilenamesPboardType]];
    
    //Insert ourselves into the responder chain ahead of our view.
    self.nextResponder = self.view.nextResponder;
    self.view.nextResponder = self;
}

- (void) dealloc
{
    self.representedObject = nil;
    self.view.nextResponder = nil;
    
    self.documentationURLs = nil;
    self.documentationSelectionIndexes = nil;
    
    [super dealloc];
}

#pragma mark - Error handling

- (NSError *) willPresentError: (NSError *)error
{
    //Give our delegate a crack at the error before we present it
    if ([self.delegate respondsToSelector: @selector(documentationBrowser:willPresentError:)])
        error = [self.delegate documentationBrowser: self willPresentError: error];
    
    return [super willPresentError: error];
}

#pragma mark - Binding accessors

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    if ([keyPath isEqualToString: @"gamebox.documentationURLs"])
    {
        //IMPLEMENTATION NOTE: we delay resyncing the URLs until the end of the run loop,
        //in case there are numerous changes to the documentation going on.
        [NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(_syncDocumentationURLs) object: nil];
        [self performSelector: @selector(_syncDocumentationURLs) withObject: nil afterDelay: 0];
    }
}

- (void) _syncDocumentationURLs
{
    BXSession *session = (BXSession *)self.representedObject;
    
    NSArray *oldURLs = [self.documentationURLs copy];
    NSArray *newURLs = [session.gamebox.documentationURLs sortedArrayUsingDescriptors: self.sortCriteria];
    
    if (![newURLs isEqualToArray: self.documentationURLs])
    {
        if ([self.delegate respondsToSelector: @selector(documentationBrowser:willUpdateFromURLs:toURLs:)])
            [self.delegate documentationBrowser: self willUpdateFromURLs: oldURLs toURLs: newURLs];
        
        if (self.documentationURLs)
        {
            //IMPLEMENTATION NOTE: when refreshing an existing documentation list, we want to disturb
            //the existing entries as little as possible: specifically we want to avoid destroying
            //and recreating an entry for the same URL, as this would cause its respective view
            //to be destroyed and recreated as well.
            
            //So, we walk through the incoming URLs seeing which ones we already have entries for.
            //If we already have an entry for a URL then we reuse our existing NSURL object;
            //otherwise we adopt the new NSURL object. This preserves our existing documentation views.
            
            NSMutableArray *finalURLs = [NSMutableArray arrayWithCapacity: newURLs.count];
            
            for (NSURL *URL in newURLs)
            {
                //Note that indexOfObject: uses an isEqual: equality comparison,
                //rather than a == identity comparison.
                //This means it will return URLs that match the new one but aren't the same object.
                NSUInteger existingURLIndex = [oldURLs indexOfObject: URL];
                if (existingURLIndex != NSNotFound)
                    [finalURLs addObject: [oldURLs objectAtIndex: existingURLIndex]];
                else
                    [finalURLs addObject: URL];
            }
            
            self.documentationURLs = finalURLs;
        }
        else
        {
            self.documentationURLs = [NSMutableArray arrayWithArray: newURLs];
        }
        
        if ([self.delegate respondsToSelector: @selector(documentationBrowser:didUpdateFromURLs:toURLs:)])
            [self.delegate documentationBrowser: self didUpdateFromURLs: oldURLs toURLs: newURLs];
        
        //Flash the scrollbars (if any) to indicate that the content of the scroller has changed.
        if ([self.documentationScrollView respondsToSelector: @selector(flashScrollers)])
            [self.documentationScrollView flashScrollers];
        
        [oldURLs release];
    }
}

+ (NSSet *) keyPathsForValuesAffectingTitle
{
    return [NSSet setWithObject: @"representedObject.displayName"];
}

- (NSString *) title
{
    NSString *titleFormat = NSLocalizedString(@"%@ Documentation", @"Title for documentation list popover. %@ is the display name of the current session.");
    NSString *displayName = [(BXSession *)self.representedObject displayName];
    
    return [NSString stringWithFormat: titleFormat, displayName];
}

+ (NSSet *) keyPathsForValuesAffectingSelectedDocumentationURLs
{
    return [NSSet setWithObjects: @"documentationURLs", @"documentationSelectionIndexes", nil];
}

- (NSArray *) selectedDocumentationURLs
{
    return [self.documentationURLs objectsAtIndexes: self.documentationSelectionIndexes];
}

- (NSArray *) sortCriteria
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


#pragma mark - UI layout

- (NSSize) idealContentSizeForNumberOfItems: (NSUInteger)numItems
{
    NSRect containerBounds = self.view.bounds;
    
    //Base our ideal content size on the documentation list, taking into account
    //how far the list's scroll view is from the edges of the wrapping view.
    NSRect listFrame = self.documentationScrollView.frame;
    NSSize idealListSize = [self.documentationList minContentSizeForNumberOfItems: numItems];
    
    NSSize listMargin = NSMakeSize(containerBounds.size.width - listFrame.size.width,
                                   containerBounds.size.height - listFrame.size.height);
    
    NSSize idealSize = NSMakeSize(idealListSize.width + listMargin.width,
                                  idealListSize.height + listMargin.height);
    
    //Ensure the content size also accommodates the title and help-text
    //(and their own margins), in case they're wider than the documentation list.
    NSSize idealTitleSize       = [self.titleLabel.cell cellSize];
    NSSize idealHelpTextSize    = [self.helpTextLabel.cell cellSize];
    CGFloat titleMargin     = containerBounds.size.width - self.titleLabel.frame.size.width;
    CGFloat helpTextMargin  = containerBounds.size.width - self.helpTextLabel.frame.size.width;
    
    idealSize.width = MAX(idealSize.width, idealTitleSize.width + titleMargin);
    idealSize.width = MAX(idealSize.width, idealHelpTextSize.width + helpTextMargin);
    
    //IMPLEMENTATION NOTE: these calculations assume that all views are pinned to the
    //edges of the container, so that their distance (margin) from each edge of the
    //container will stay constant as the container is resized.
    return idealSize;
}

+ (NSSet *) keyPathsForValuesAffectingIdealContentSize
{
    return [NSSet setWithObjects: @"documentationURLs", @"title", nil];
}

- (NSSize) idealContentSize
{
    return [self idealContentSizeForNumberOfItems: self.documentationURLs.count];
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
        
        if ([self.delegate respondsToSelector: @selector(documentationBrowser:didOpenURLs:)])
            [self.delegate documentationBrowser: self didOpenURLs: self.selectedDocumentationURLs];
    }
}

- (IBAction) revealSelectedDocumentationItemsInFinder: (id)sender
{
    if (self.documentationSelectionIndexes.count)
    {
        [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs: self.selectedDocumentationURLs];
        
        if ([self.delegate respondsToSelector: @selector(documentationBrowser:didRevealURLs:)])
            [self.delegate documentationBrowser: self didRevealURLs: self.selectedDocumentationURLs];
    }
}

- (BOOL) importDocumentationURLs: (NSArray *)URLs
{
    BXSession *session = self.representedObject;
    
    BOOL importedSuccessfully = YES;
    
    NSMutableArray *importedURLs = [NSMutableArray arrayWithCapacity: URLs.count];
    
    for (NSURL *URL in URLs)
    {
        NSError *importingError = nil;
        NSURL *importedURL = [session.gamebox addDocumentationFileFromURL: URL
                                                                withTitle: nil
                                                                 ifExists: BXGameboxDocumentationRename
                                                                    error: &importingError];
        if (importedURL)
        {
            [importedURLs addObject: importedURL];
        }
        else
        {
            //Show the error to the user immediately.
            if (importingError != nil)
            {
                NSWindow *presentingWindow = nil;
                if ([self.delegate respondsToSelector: @selector(documentationBrowser:windowForModalError:)])
                    presentingWindow = [self.delegate documentationBrowser: self windowForModalError: importingError];
                
                if (presentingWindow)
                {
                    [self presentError: importingError
                        modalForWindow: presentingWindow
                              delegate: nil
                    didPresentSelector: NULL
                           contextInfo: NULL];
                }
                else
                {
                    [self presentError: importingError];
                }
            }
            
            //Don't continue importing further.
            importedSuccessfully = NO;
            break;
        }
    }
    
    //If we successfully imported anything, the gamebox should have recorded undos for each one:
    //apply a suitable name for the overall undo operation.
    if (importedURLs.count)
    {
        NSString *actionName;
        
        if (importedURLs.count > 1)
        {
            NSString *actionNameFormat = NSLocalizedString(@"Importing of %u manuals",
                                                           @"Undo menu action title when importing multiple documentation items. %u is the number of items imported as an unsigned integer.");
            
            actionName = [NSString stringWithFormat: actionNameFormat, importedURLs.count];
        }
        else
        {
            NSString *actionNameFormat = NSLocalizedString(@"Importing of “%@”",
                                                           @"Undo menu action title when importing a documentation item. %@ is the display name of the documentation item as it appears in the UI.");
            
            NSString *displayName = [importedURLs.lastObject lastPathComponent].stringByDeletingPathExtension;
            actionName = [NSString stringWithFormat: actionNameFormat, displayName];
        }
        
        [self.undoManager setActionName: actionName];
        
        //Once all imports are complete, select the newly-imported items.
        //IMPLEMENTATION NOTE: we synchronize the URLs immediately as we do this to ensure
        //all the new URLs are present in the documentation list. Otherwise, our URLs won’t
        //be synchronized until the end of the event loop while we wait for more changes.
        [self _syncDocumentationURLs];
        
        NSMutableIndexSet *selectionIndexes = [NSMutableIndexSet indexSet];
        for (NSURL *URL in importedURLs)
        {
            NSUInteger index = [self.documentationURLs indexOfObject: URL];
            if (index != NSNotFound)
                [selectionIndexes addIndex: index];
            
            if (!self.documentationList.allowsMultipleSelection)
                break;
        }
        self.documentationSelectionIndexes = selectionIndexes;
    }
    
    return importedSuccessfully;
}

- (BOOL) removeDocumentationURLs: (NSArray *)URLs
{
    BXSession *session = self.representedObject;
    
    BOOL trashedSuccessfully = YES;
    
    NSMutableArray *trashedURLs = [NSMutableArray arrayWithCapacity: URLs.count];
    NSURL *originalURL = nil;
    for (NSURL *URL in URLs)
    {
        //If this URL is not one that we're allowed to trash, skip it without displaying any kind of error.
        if (![session.gamebox canTrashDocumentationURL: URL])
            continue;
        
        NSError *trashingError = nil;
        NSURL *trashedURL = [session.gamebox trashDocumentationURL: URL error: &trashingError];
        
        if (trashedURL)
        {
            [trashedURLs addObject: trashedURL];
            originalURL = URL;
        }
        else
        {
            //Show the error to the user immediately.
            if (trashingError != nil)
            {
                NSWindow *presentingWindow = nil;
                if ([self.delegate respondsToSelector: @selector(documentationBrowser:windowForModalError:)])
                    presentingWindow = [self.delegate documentationBrowser: self windowForModalError: trashingError];
                
                if (presentingWindow)
                {
                    [self presentError: trashingError
                        modalForWindow: presentingWindow
                              delegate: nil
                    didPresentSelector: NULL
                           contextInfo: NULL];
                }
                else
                {
                    [self presentError: trashingError];
                }
            }
            
            //Don't continue trashing further.
            trashedSuccessfully = NO;
            break;
        }
    }
    
    //If we successfully trashed anything, the gamebox should have recorded undos for each one:
    //apply a suitable name for the overall undo operation.
    if (trashedURLs.count)
    {
        NSString *actionName;
        
        //Vary the title for the undo action, based on if it'll be recorded
        //as a redo operation and based on how many URLs were imported.
        if (trashedURLs.count > 1)
        {
            NSString *actionNameFormat = NSLocalizedString(@"Removal of %u manuals",
                                                           @"Undo menu action title when removing multiple documentation items. %u is the number of items removed as an unsigned integer.");
            
            actionName = [NSString stringWithFormat: actionNameFormat, trashedURLs.count];
        }
        else
        {
            NSString *actionNameFormat = NSLocalizedString(@"Removal of “%@”",
                                                           @"Undo menu action title when removing a documentation item. %@ is the display name of the documentation item as it appears in the UI.");
            
            NSString *displayName = originalURL.lastPathComponent.stringByDeletingPathExtension;
            actionName = [NSString stringWithFormat: actionNameFormat, displayName];
        }
        
        [self.undoManager setActionName: actionName];
    }
    
    return trashedSuccessfully;
}


- (IBAction) trashSelectedDocumentationItems: (id)sender
{
    [self removeDocumentationURLs: self.selectedDocumentationURLs];
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
    
    if (menuItem.action == @selector(revealSelectedDocumentationItemsInFinder:) ||
        menuItem.action == @selector(openSelectedDocumentationItems:))
    {
        return hasSelectedItems;
    }
    else if (menuItem.action == @selector(trashSelectedDocumentationItems:))
    {
        if (!hasSelectedItems)
            return NO;
        
        //Check that all selected items are trashable.
        for (NSURL *URL in self.selectedDocumentationURLs)
        {
            if (![[self.representedObject gamebox] canTrashDocumentationURL: URL])
                return NO;
        }
        
        //If we got this far it means all selected items are trashable.
        return YES;
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
	NSPasteboard *pboard = sender.draggingPasteboard;
	
    NSArray *droppedURLs = [pboard readObjectsForClasses: @[[NSURL class]]
                                                 options: @{ NSPasteboardURLReadingFileURLsOnlyKey : @(YES) }];
        
    BOOL imported = [self importDocumentationURLs: droppedURLs];
    
	return imported;
}


@end


//A private class to implement the QLPreviewItem protocol for BXDocumentPreviews.
@interface BXDocumentationBrowserPreviewItem : NSObject <QLPreviewItem>
{
    NSURL *_previewItemURL;
}
    
@property (copy, nonatomic) NSURL *previewItemURL;

+ (id) previewItemWithURL: (NSURL *)URL;

@end

@implementation BXDocumentationBrowserPreviewItem
@synthesize previewItemURL = _previewItemURL;

+ (id) previewItemWithURL: (NSURL *)URL
{
    BXDocumentationBrowserPreviewItem *previewItem = [[self alloc] init];
    previewItem.previewItemURL = URL;
    return [previewItem autorelease];
}

- (void) dealloc
{   
    self.previewItemURL = nil;
    [super dealloc];
}

@end


@implementation BXDocumentationBrowser (BXDocumentPreviews)

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
    return [BXDocumentationBrowserPreviewItem previewItemWithURL: URL];
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
    
    //Only change the panel preview if a) we're in charge of the panel
    //and b) there's anything selected and c) the selection doesn't contain the current preview item.
    if (panel.currentController == self && self.documentationSelectionIndexes.count &&
        ![self.documentationSelectionIndexes containsIndex: panel.currentPreviewItemIndex])
    {
        panel.currentPreviewItemIndex = self.documentationSelectionIndexes.firstIndex;
    }
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
        
        if ([self.delegate respondsToSelector: @selector(documentationBrowser:didPreviewURLs:)])
            [self.delegate documentationBrowser: self didPreviewURLs: self.selectedDocumentationURLs];
    }
}

@end



@interface BXDocumentationItem ()

//Loads up the icon (or spotlight preview) for the documentation URL as it is displayed in Finder.
- (void) _refreshIcon;

@end

@implementation BXDocumentationItem
@synthesize icon = _icon;

- (void) viewDidLoad
{
    //Prevent our icon view from interfering with drag operations
    [[self.view viewWithTag: BXDocumentationItemIcon] unregisterDraggedTypes];
}

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
        NSImageView *icon = [self viewWithTag: BXDocumentationItemIcon];
        NSTextField *label = [self viewWithTag: BXDocumentationItemLabel];
        
        CGFloat contentWidth = MAX(icon.frame.size.width, [label.cell cellSize].width);
        CGFloat padding = 8.0;
        CGFloat margin = 8.0;
        
        NSRect highlightRegion = NSInsetRect(self.bounds, margin, margin);
        highlightRegion.size.width = MIN(contentWidth + (padding * 2), highlightRegion.size.width);
        highlightRegion.origin.x = self.bounds.origin.x + ((self.bounds.size.width - highlightRegion.size.width) * 0.5);
        
        highlightRegion = NSIntegralRect(highlightRegion);
        
        NSBezierPath *highlightPath = [NSBezierPath bezierPathWithRoundedRect: highlightRegion
                                                                      xRadius: 8.0
                                                                      yRadius: 8.0];
        
        NSColor *highlightColor = [NSColor colorWithCalibratedWhite: 0 alpha: 0.15];
        
        [highlightColor set];
        [highlightPath fill];
    }
}

- (BOOL) acceptsFirstMouse: (NSEvent *)theEvent { return YES; }

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

- (BOOL) acceptsFirstMouse: (NSEvent *)theEvent { return YES; }

- (void) keyDown: (NSEvent *)theEvent
{
    //Trigger a preview when the user presses Space.
    if ([theEvent.charactersIgnoringModifiers isEqualToString: @" "])
    {
        [NSApp sendAction: @selector(previewSelectedDocumentationItems:) to: nil from: self];
    }
    //Open the selected items when the user presses Return.
    else if ([theEvent.charactersIgnoringModifiers isEqualToString: @"\r"])
    {
        [NSApp sendAction: @selector(openSelectedDocumentationItems:) to: nil from: self];
    }
    //Delete the selected items when the user presses Cmd+Backspace.
    else if ([theEvent.charactersIgnoringModifiers isEqualToString: @"\x7f"] &&
             (theEvent.modifierFlags & NSCommandKeyMask))
    {
        [NSApp sendAction: @selector(trashSelectedDocumentationItems:) to: nil from: self];
    }
    else
    {
        [super keyDown: theEvent];
    }
}

- (NSSize) minContentSizeForNumberOfItems: (NSUInteger)numItems
{
    NSSize minItemSize = self.minItemSize;
    if (NSEqualSizes(minItemSize, NSZeroSize))
        minItemSize = self.itemPrototype.view.frame.size;
    
    NSUInteger numColumns, numRows;
    
    if (!numItems) numItems = 1;
    
    //If we have a maximum number of items per row,
    //we'll wrap our items to multiple rows.
    if (self.maxNumberOfColumns > 0)
    {
        numColumns = MIN(self.maxNumberOfColumns, numItems);
        numRows = ceilf((float)numItems / (float)numColumns);
    }
    //Otherwise, we'll display all our items in a single row.
    else
    {
        numColumns = numItems;
        numRows = 1;
    }
    
    return NSMakeSize(numColumns * minItemSize.width,
                      numRows * minItemSize.height);
}

@end


@implementation BXDocumentationDivider

- (void) drawRect: (NSRect)dirtyRect
{
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 0 alpha: 0.15]
                                                         endingColor: [NSColor clearColor]];
    
    [gradient drawInRect: self.bounds relativeCenterPosition: NSZeroPoint];
    
    [gradient release];
}

@end