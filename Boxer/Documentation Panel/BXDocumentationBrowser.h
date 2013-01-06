/*
 Boxer is copyright 2013 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import "BXCollectionItemView.h"

//BXDocumentationBrowser manages the list of documentation for the gamebox.

@class BXSession;
@class BXDocumentationList;
@protocol BXDocumentationBrowserDelegate;
@interface BXDocumentationBrowser : NSViewController <NSCollectionViewDelegate, NSDraggingDestination>
{
    NSArray *_documentationURLs;
    NSIndexSet *_documentationSelectionIndexes;
    
    NSScrollView *_documentationScrollView;
    BXDocumentationList *_documentationList;
    NSTextField *_titleLabel;
    NSTextField *_helpTextLabel;
    
    id <BXDocumentationBrowserDelegate> _delegate;
}

#pragma mark - Properties

//The delegate to which we will send BXDocumentationBrowserDelegate messages.
@property (assign, nonatomic) IBOutlet id <BXDocumentationBrowserDelegate> delegate;

//The scrolling wrapper in which our documenation list is displayed.
@property (assign, nonatomic) IBOutlet NSScrollView *documentationScrollView;

//The title at the top of the browser.
@property (assign, nonatomic) IBOutlet NSTextField *titleLabel;

//The help text displayed at the bottom of the browser.
@property (assign, nonatomic) IBOutlet NSTextField *helpTextLabel;

//The collection view in which our documentation will be displayed.
@property (assign, nonatomic) IBOutlet BXDocumentationList *documentationList;

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

//The ideal size for displaying the browser without clipping.
//This varies based on the number of documentation items and the length of the title.
@property (readonly, nonatomic) NSSize intrinsicContentSize;

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

@optional

//Called when the user opens one or more documentation files from the list.
- (void) documentationBrowser: (BXDocumentationBrowser *)browser didOpenURLs: (NSArray *)URLs;

//Called when the user opens a QuickLook preview on the specified items.
- (void) documentationBrowser: (BXDocumentationBrowser *)browser didPreviewURLs: (NSArray *)URLs;

//Called when the user shows the specified items in Finder.
- (void) documentationBrowser: (BXDocumentationBrowser *)browser didRevealURLs: (NSArray *)URLs;

//Called when the browser has encountered an error that it cannot deal with and will present it.
//This is analoguous to willPresentError:, and likewise you can return a different error to customize
//the error that will be displayed.
- (NSError *) documentationBrowser: (BXDocumentationBrowser *)browser willPresentError: (NSError *)error;

//Called when the browser wants to present an error, to return the window in which it should present the error modally.
//If this returns nil, or is unimplemented, the error will be presented as application-modal instead.
- (NSWindow *) documentationBrowser: (BXDocumentationBrowser *)browser windowForModalError: (NSError *)error;

@end



//BXDocumentationItem manages each individual documentation file listed in the documentation popup.
@interface BXDocumentationItem : BXCollectionItem
{
    NSImage *_icon;
}

//The icon for the documentation file.
//This will initially be the Finder file icon, but will be replaced with a Spotlight image preview
//asynchronously.
@property (retain, nonatomic) NSImage *icon;

//The display name of the documentation file.
//This will be the filename of the documentation file sans extension.
@property (readonly, nonatomic) NSString *displayName;

@end

//Custom appearance for documentation items. Highlights the background when selected.
@interface BXDocumentationWrapper : BXCollectionItemView
@end


//Custom subclass for documentation list collection view to tweak keyboard and mouse handling
//and to calculate our ideal display size.
@interface BXDocumentationList : NSCollectionView

//Returns the size the documentation list will need to be in order to display
//the specified number of items without scrolling.
- (NSSize) minContentSizeForNumberOfItems: (NSUInteger)numItems;

@end


//A horizontal divider that fades from grey at the center to transparent at the edges.
@interface BXDocumentationDivider : NSView
@end