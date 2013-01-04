/*
 Boxer is copyright 2013 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "BXCollectionItemView.h"

//BXDocumentationListController manages the popup list of documentation for the gamebox.

@class BXSession;
@protocol BXDocumentationBrowserDelegate;
@interface BXDocumentationBrowser : NSViewController <NSCollectionViewDelegate, NSDraggingDestination>
{
    NSCollectionView *_documentationList;
    NSArray *_documentationURLs;
    NSIndexSet *_documentationSelectionIndexes;
    NSScrollView *_documentationScrollView;
    
    NSSize _minViewSize;
    
    id <BXDocumentationBrowserDelegate> _delegate;
}

#pragma mark - Properties

//The delegate to which we will send BXDocumentationBrowserDelegate messages.
@property (assign, nonatomic) id <BXDocumentationBrowserDelegate> delegate;

//The scrolling wrapper in which our documenation list is displayed.
@property (retain, nonatomic) IBOutlet NSScrollView *documentationScrollView;

//The collection view in which our documentation will be displayed.
@property (retain, nonatomic) IBOutlet NSCollectionView *documentationList;

//An array of NSURLs for the documentation files included in this gamebox.
//This is mapped directly to the documentation URLs reported by the gamebox.
@property (readonly, copy, nonatomic) NSArray *documentationURLs;

//An array of criteria for how the documentation files should be sorted in the UI.
//Documentation will be sorted by type and then by name, to group similar types
//of documentation files together.
@property (readonly, nonatomic) NSArray *sortCriteria;

//The currently selected documentation items. Normally, only one item can be selected at a time.
@property (retain, nonatomic) NSIndexSet *documentationSelectionIndexes;

//An array of the currently-selected documentation items.
@property (readonly, nonatomic) NSArray *selectedDocumentationURLs;


#pragma mark - Constructors

//Returns a newly-created BXDocumentationListController instance
//whose UI is loaded from DocumentationList.xib.
+ (id) browserForSession: (BXSession *)session;
- (id) initWithSession: (BXSession *)session;


#pragma mark - Interface actions

- (IBAction) openSelectedDocumentationItems: (id)sender;
- (IBAction) revealSelectedDocumentationItemsInFinder: (id)sender;
- (IBAction) trashSelectedDocumentationItems: (id)sender;
- (IBAction) showDocumentationFolderInFinder: (id)sender;

//Helper methods for adding/removing documentation items.
//These will register undo actions and will present error sheets if importing/removal fails.
- (BOOL) removeDocumentationURLs: (NSArray *)URLs;
- (BOOL) importDocumentationURLs: (NSArray *)URLs;


#pragma mark - Drag-dropping

//Responding to attempts to drag new files into the documentation list.
- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender;
- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender;

@end

//The BXDocumentationPreviews category expands BXDocumentationListController to allow documentation to be shown in a QuickLook preview panel.
@interface BXDocumentationBrowser (BXDocumentationPreviews) <QLPreviewPanelDelegate, QLPreviewPanelDataSource>

//Displays a QuickLook preview panel for the specified documentation items.
- (IBAction) previewSelectedDocumentationItems: (id)sender;

@end


@protocol BXDocumentationBrowserDelegate <NSObject>

//Called when the documentation list grows or shrinks, to ask permission to grow/shrink the view to match.
//Can be used by the upstream context to resize the view manually instead.
- (BOOL) documentationBrowser: (BXDocumentationBrowser *)browser shouldResizeToSize: (NSSize)contentSize;

//Called when the user opens one or more documentation files from the list.
- (void) documentationBrowser: (BXDocumentationBrowser *)browser didOpenURLs: (NSArray *)URLs;

//Called when the user opens a QuickLook preview on the specified items.
- (void) documentationBrowser: (BXDocumentationBrowser *)browser didPreviewURLs: (NSArray *)URLs;

@end



//BXDocumentationItem manages each individual documentation file listed in the documentation popup.
@interface BXDocumentationItem : BXCollectionItem
{
    NSImage *_icon;
}

//The icon for the documentation file.
//This will initially be the Finder file icon, but will be replaced with a Spotlight image preview
//asynchronously.
@property (readonly, copy, nonatomic) NSImage *icon;

//The display name of the documentation file.
//This will be the filename of the documentation file sans extension.
@property (readonly, nonatomic) NSString *displayName;

@end

//Custom appearance for documentation items. Highlights the background when selected.
@interface BXDocumentationWrapper : BXCollectionItemView
@end


//Custom subclass for documentation list collection view to tweak keyboard and mouse handling.
@interface BXDocumentationList : NSCollectionView
@end


//A horizontal divider that fades from grey at the center to transparent at the edges.
@interface BXDocumentationDivider : NSView
@end