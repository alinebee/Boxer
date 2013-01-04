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

//Called whenever the documentation changes to resize the window and re-layout the document list.
- (void) _syncDocumentationListLayout;

//Used internally by importDocumentationURLs: and removeDocumentationURLs: to handle importing
//new documentation and restoring previously-deleted documentation (via Undo).
- (BOOL) _importDocumentationURLs: (NSArray *)URLs
             restoringDeletedURLs: (NSArray *)originalURLs;

@end

@implementation BXDocumentationBrowser
@synthesize documentationScrollView = _documentationScrollView;
@synthesize documentationList = _documentationList;
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
        self.documentationURLs = [NSMutableArray array];
        self.representedObject = session;
    }
    
    return self;
}

- (void) setRepresentedObject: (id)representedObject
{
    [self.representedObject removeObserver: self forKeyPath: @"gamebox.documentationURLs"];
    
    [super setRepresentedObject: representedObject];
    
    [self.representedObject addObserver: self
                             forKeyPath: @"gamebox.documentationURLs"
                                options: NSKeyValueObservingOptionInitial
                                context: NULL];
}

- (void) awakeFromNib
{
    //Record how big the view is in the XIB: we'll use this as our minimum view size
    //when growing/shrinking the view to account for more documentation items.
    _minViewSize = self.view.frame.size;
    
    if ([self.documentationScrollView respondsToSelector: @selector(setUsesPredominantAxisScrolling:)])
        self.documentationScrollView.usesPredominantAxisScrolling = YES;
    
    if ([self.documentationScrollView respondsToSelector: @selector(setVerticalScrollElasticity:)])
        self.documentationScrollView.verticalScrollElasticity = NSScrollElasticityNone;
    
	[self.view registerForDraggedTypes: @[NSFilenamesPboardType]];
    
    //Insert ourselves into the responder chain ahead of our view.
    self.nextResponder = self.view.nextResponder;
    self.view.nextResponder = self;
    
    [self _syncDocumentationListLayout];
}

- (void) dealloc
{
    self.representedObject = nil;
    
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
    [notifier sortUsingDescriptors: self.sortCriteria];
    
    [oldURLs release];
    
    //Once the documentation has been updated, re-layout the view appropriately.
    [self _syncDocumentationListLayout];
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

- (void) _syncDocumentationListLayout
{
    if (self.documentationList)
    {
        //Work out the ideal width for displaying the current set of documentation.
        NSSize minItemSize = self.documentationList.minItemSize;
        if (NSEqualSizes(minItemSize, NSZeroSize))
            minItemSize = self.documentationList.itemPrototype.view.frame.size;
        
        NSUInteger numItems = MIN(5U, self.documentationURLs.count); //Show a maximum of 5 abreast
        CGFloat idealWidth = numItems * minItemSize.width;
        
        NSSize desiredSize = NSMakeSize(MAX(idealWidth, _minViewSize.width), self.view.frame.size.height);
        
        BOOL shouldResize = YES;
        if ([self.delegate respondsToSelector: @selector(documentationBrowser:shouldResizeToSize:)])
            shouldResize = [self.delegate documentationBrowser: self shouldResizeToSize: desiredSize];
        
        if (shouldResize)
            [self.view setFrameSize: desiredSize];
        
        if ([self.documentationScrollView respondsToSelector: @selector(flashScrollers)])
            [self.documentationScrollView flashScrollers];
    }
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
    }
}

- (BOOL) _importDocumentationURLs: (NSArray *)URLs
             restoringDeletedURLs: (NSArray *)originalURLs
{
    BXSession *session = self.representedObject;
    
    BOOL importedSuccessfully = YES;
    
    NSMutableArray *importedURLs = [NSMutableArray arrayWithCapacity: URLs.count];
    NSUInteger offset=0;
    for (NSURL *URL in URLs)
    {
        NSError *importingError = nil;
        NSString *title = nil;
        
        //If we're restoring a previously-deleted URL, then try to give it the same
        //name as it previously had. This compensates for any renaming of the file
        //when it was moved to the Trash.
        if (originalURLs)
        {
            NSURL *originalURL = [originalURLs objectAtIndex: offset];
            title = originalURL.lastPathComponent.stringByDeletingPathExtension;
        }
        NSURL *importedURL = [session.gamebox addDocumentationFileFromURL: URL
                                                                withTitle: title
                                                                 ifExists: BXGameboxDocumentationRename
                                                                    error: &importingError];
        
        if (importedURL)
        {
            [importedURLs addObject: importedURL];
            offset++;
            
            //If we're restoring a previously-deleted URL, then clean up the source URL from the Trash.
            if (originalURLs)
                [[NSFileManager defaultManager] removeItemAtURL: URL error: NULL];
        }
        else
        {
            //Show the error to the user immediately.
            if (importingError != nil)
            {
                [self presentError: importingError
                    modalForWindow: [self.representedObject windowForSheet]
                          delegate: nil
                didPresentSelector: NULL
                       contextInfo: NULL];
            }
            
            //Don't continue importing further.
            importedSuccessfully = NO;
            break;
        }
    }
    
    if (importedURLs.count)
    {
        [self.undoManager registerUndoWithTarget: self
                                        selector: @selector(removeDocumentationURLs:)
                                          object: importedURLs];
        
        NSString *actionName;
        
        //Vary the title for the undo action, based on if it'll be recorded
        //as a redo operation and based on how many URLs were imported.
        if (importedURLs.count > 1)
        {
            NSString *actionNameFormat;
            if (self.undoManager.isUndoing)
                actionNameFormat = NSLocalizedString(@"Removal of %u manuals", @"Undo menu action title when removing multiple documentation items. %u is the number of items removed as an unsigned integer.");
            else
                actionNameFormat = NSLocalizedString(@"Importing of %u manuals", @"Undo menu action title when importing multiple documentation items. %u is the number of items imported as an unsigned integer.");
            
            actionName = [NSString stringWithFormat: actionNameFormat, importedURLs.count];
        }
        else
        {
            NSString *actionNameFormat;
            if (self.undoManager.isUndoing)
                actionNameFormat = NSLocalizedString(@"Removal of “%@”", @"Undo menu action title when removing a documentation item. %@ is the display name of the documentation item as it appears in the UI.");
            else
                actionNameFormat = NSLocalizedString(@"Importing of “%@”", @"Undo menu action title when importing a documentation item. %@ is the display name of the documentation item as it appears in the UI.");
            
            NSString *displayName = [importedURLs.lastObject lastPathComponent].stringByDeletingPathExtension;
            actionName = [NSString stringWithFormat: actionNameFormat, displayName];
        }
        
        [self.undoManager setActionName: actionName];
    }
    
    return importedSuccessfully;
}

- (BOOL) importDocumentationURLs: (NSArray *)URLs
{
    return [self _importDocumentationURLs: URLs restoringDeletedURLs: nil];
}
    
- (BOOL) removeDocumentationURLs: (NSArray *)URLs
{
    BXSession *session = self.representedObject;
    
    BOOL trashedSuccessfully = YES;
    
    NSMutableArray *trashedURLs = [NSMutableArray arrayWithCapacity: URLs.count];
    for (NSURL *URL in URLs)
    {
        NSError *trashingError = nil;
        NSURL *trashedURL = [session.gamebox trashDocumentationURL: URL error: &trashingError];
        
        if (trashedURL)
        {
            [trashedURLs addObject: trashedURL];
        }
        else
        {
            //Show the error to the user immediately.
            if (trashingError != nil)
            {
                [self presentError: trashingError
                    modalForWindow: [self.representedObject windowForSheet]
                          delegate: nil
                didPresentSelector: NULL
                       contextInfo: NULL];
            }
            
            //Don't continue importing further.
            trashedSuccessfully = NO;
            break;
        }
    }
    
    if (trashedURLs.count)
    {
        id undoProxy = [self.undoManager prepareWithInvocationTarget: self];
        [undoProxy _importDocumentationURLs: trashedURLs restoringDeletedURLs: URLs];
        
        NSString *actionName;
        
        //Vary the title for the undo action, based on if it'll be recorded
        //as a redo operation and based on how many URLs were imported.
        if (trashedURLs.count > 1)
        {
            NSString *actionNameFormat;
            if (self.undoManager.isUndoing)
                actionNameFormat = NSLocalizedString(@"Importing of %u manuals", @"Undo menu action title when importing multiple documentation items. %u is the number of items imported as an unsigned integer.");
            else
                actionNameFormat = NSLocalizedString(@"Removal of %u manuals", @"Undo menu action title when removing multiple documentation items. %u is the number of items removed as an unsigned integer.");
            
            actionName = [NSString stringWithFormat: actionNameFormat, trashedURLs.count];
        }
        else
        {
            NSString *actionNameFormat;
            if (self.undoManager.isUndoing)
                actionNameFormat = NSLocalizedString(@"Importing of “%@”", @"Undo menu action title when importing a documentation item. %@ is the display name of the documentation item as it appears in the UI.");
            else
            actionNameFormat = NSLocalizedString(@"Removal of “%@”", @"Undo menu action title when removing a documentation item. %@ is the display name of the documentation item as it appears in the UI.");
            
            NSString *displayName = [trashedURLs.lastObject lastPathComponent].stringByDeletingPathExtension;
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

@end


@implementation BXDocumentationDivider

- (void) drawRect: (NSRect)dirtyRect
{
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor: [NSColor grayColor]
                                                         endingColor: [NSColor clearColor]];
    
    [gradient drawInRect: self.bounds relativeCenterPosition: NSZeroPoint];
    
    [gradient release];
}

@end