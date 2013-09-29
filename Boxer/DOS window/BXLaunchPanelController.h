/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Cocoa/Cocoa.h>
#import "BXCollectionItemView.h"

@class BXLauncherItem;
@protocol BXLauncherItemDelegate

- (void) launchItem: (BXLauncherItem *)item;
- (void) revealItemInFinder: (BXLauncherItem *)item;
- (void) removeItem: (BXLauncherItem *)item;

- (BOOL) canLaunchItem: (BXLauncherItem *)item;
- (BOOL) canRevealItemInFinder: (BXLauncherItem *)item;
- (BOOL) canRemoveItem: (BXLauncherItem *)item;

@end

@interface BXLaunchPanelController : NSViewController <NSCollectionViewDelegate, NSTextFieldDelegate, BXLauncherItemDelegate>
{
    NSCollectionView *_launcherList;
    NSScrollView *_launcherScrollView;
    NSSearchField *_filter;
    
    NSMutableArray *_filterKeywords;
    
    NSMutableArray *_allProgramRows;
    NSMutableArray *_favoriteProgramRows;
    NSMutableArray *_recentProgramRows;
    NSMutableArray *_displayedRows;
    
    NSDictionary *_favoritesHeading;
    NSDictionary *_recentProgramsHeading;
    NSDictionary *_allProgramsHeading;
    
    BOOL _allProgramRowsDirty;
    BOOL _favoriteProgramRowsDirty;
    BOOL _recentProgramRowsDirty;
    
    BOOL _shouldUpdateImmediately;
}

@property (assign, nonatomic) IBOutlet NSCollectionView *launcherList;
@property (assign, nonatomic) IBOutlet NSScrollView *launcherScrollView;
@property (assign, nonatomic) IBOutlet NSSearchField *filter;

//An array of NSDictionaries for every item to display in the list.
@property (readonly, retain, nonatomic) NSMutableArray *displayedRows;

//An array of sanitised NSStrings derived from the contents of the search field. 
@property (readonly, retain, nonatomic) NSMutableArray *filterKeywords;

#pragma mark - Actions

- (IBAction) enterSearchText: (NSSearchField *)sender;

//Called by BXDOSWindowController when it is about to switch to/away from the launcher panel.
//Causes it to (re-)populate its program list.
- (void) viewWillAppear;
- (void) viewDidDisappear;

@end


//A custom collection view that uses a different prototype for drive 'headings'
@class BXLauncherItem;
@interface BXLauncherList : NSCollectionView
{
    BXLauncherItem *_headingPrototype;
    BXLauncherItem *_favoritePrototype;
}

@property (assign, nonatomic) IBOutlet BXLauncherItem *headingPrototype;
@property (assign, nonatomic) IBOutlet BXLauncherItem *favoritePrototype;

@end


@interface BXLauncherItem : BXCollectionItem
{
    id <BXLauncherItemDelegate> _delegate;
    BOOL _launchable;
}
@property (assign, nonatomic) IBOutlet id <BXLauncherItemDelegate> delegate;
@property (assign, nonatomic, getter=isLaunchable) BOOL launchable;

- (IBAction) launchProgram: (id)sender;
- (IBAction) revealItemInFinder: (id)sender;
- (IBAction) removeItem: (id)sender;

@end

//Handles the custom appearance and input behaviour of regular program items.
@interface BXLauncherItemView : BXCollectionItemView
@end

//Handles the custom appearance and input behaviour of favorites.
@interface BXLauncherFavoriteView : BXLauncherItemView
@end

//Handles the behaviour of launcher heading rows.
@interface BXLauncherHeadingView : BXCollectionItemView
@end


//Draws the background of the navigation strip at the top of the launch panel
@interface BXLauncherNavigationHeader : NSView
@end