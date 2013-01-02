//
//  BXDocumentationListController.h
//  Boxer
//
//  Created by Alun Bestor on 02/01/2013.
//  Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BXCollectionItemView.h"

//BXDocumentationListController manages the popup list of documentation for the gamebox.

@class BXSession;
@interface BXDocumentationListController : NSViewController <NSCollectionViewDelegate, NSDraggingDestination>
{
    NSCollectionView *_documentationList;
    NSArray *_documentationURLs;
    NSIndexSet *_documentationSelectionIndexes;
    NSScrollView *_documentationScrollView;
}

#pragma mark - Properties

@property (retain, nonatomic) IBOutlet NSScrollView *documentationScrollView;

//The collection view in which our documentation will be displayed.
@property (retain, nonatomic) IBOutlet NSCollectionView *documentationList;

//An array of NSURLs for the documentation files included in this gamebox.
//This is mapped directly to the documentation URLs reported by the gamebox.
@property (readonly, copy, nonatomic) NSArray *documentationURLs;

//An array of criteria for how the documentation files should be sorted in the UI.
//Documentation will be sorted by type and then by name, to group similar types
//of documentation files together.
@property (readonly, nonatomic) NSArray *documentationSortCriteria;

//The currently selected documentation items. Normally, only one item can be selected at a time.
@property (retain, nonatomic) NSIndexSet *documentationSelectionIndexes;

//An array of the currently-selected documentation items.
@property (readonly, nonatomic) NSArray *selectedDocumentationURLs;


#pragma mark - Constructors

//Returns a newly-created BXDocumentationListController instance
//whose UI is loaded from DocumentationList.xib.
+ (id) documentationListForSession: (BXSession *)session;
- (id) initWithSession: (BXSession *)session;


#pragma mark - Interface actions

- (IBAction) openSelectedDocumentationItems: (id)sender;
- (IBAction) revealSelectedDocumentationItemsInFinder: (id)sender;
- (IBAction) trashSelectedDocumentationItems: (id)sender;
- (IBAction) showDocumentationFolderInFinder: (id)sender;


#pragma mark - Drag-dropping

//Responding to attempts to drag new files into the documentation list.
- (NSDragOperation) draggingEntered: (id <NSDraggingInfo>)sender;
- (BOOL) performDragOperation: (id <NSDraggingInfo>)sender;


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