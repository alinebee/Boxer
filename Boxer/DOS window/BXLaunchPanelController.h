/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Cocoa/Cocoa.h>
#import "BXCollectionItemView.h"

@class BXLauncherItem;

@protocol BXLauncherItemDelegate <NSObject>

- (void) openItemInDOS: (BXLauncherItem *)item;
- (void) revealItemInFinder: (BXLauncherItem *)item;
- (void) removeItem: (BXLauncherItem *)item;

- (BOOL) canOpenItemInDOS: (BXLauncherItem *)item;
- (BOOL) canRevealItemInFinder: (BXLauncherItem *)item;
- (BOOL) canRemoveItem: (BXLauncherItem *)item;

@end

@interface BXLaunchPanelController : NSViewController <NSCollectionViewDelegate, NSTextFieldDelegate, BXLauncherItemDelegate>
{
    NSCollectionView *__weak _launcherList;
    NSScrollView *__weak _launcherScrollView;
    NSSearchField *__weak _filter;
    
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

@property (weak, nonatomic) IBOutlet NSCollectionView *launcherList;
@property (weak, nonatomic) IBOutlet NSScrollView *launcherScrollView;
@property (weak, nonatomic) IBOutlet NSSearchField *filter;

/// An array of NSDictionaries for every item to display in the list.
@property (readonly, strong, nonatomic) NSMutableArray<NSDictionary*> *displayedRows;

/// An array of sanitised NSStrings derived from the contents of the search field.
@property (readonly, strong, nonatomic) NSMutableArray<NSString*> *filterKeywords;

#pragma mark - Actions

- (IBAction) enterSearchText: (NSSearchField *)sender;

/// Called by \c BXDOSWindowController when it is about to switch to/away from the launcher panel.
/// Causes it to (re-)populate its program list.
- (void) willShowPanel;
- (void) didHidePanel;

@end


@class BXLauncherItem;
/// A custom collection view that uses a different prototype for drive 'headings'
@interface BXLauncherList : NSCollectionView
{
    BXLauncherItem *__weak _headingPrototype;
    BXLauncherItem *__weak _favoritePrototype;
}

@property (weak, nonatomic) IBOutlet BXLauncherItem *headingPrototype;
@property (weak, nonatomic) IBOutlet BXLauncherItem *favoritePrototype;

@end

@class BXLauncherItemView;
@interface BXLauncherItem : BXCollectionItem
{
    id <BXLauncherItemDelegate> __unsafe_unretained _delegate;
    BOOL _launchable;
    NSMenu *_menu;
}
@property (unsafe_unretained, nonatomic) IBOutlet id <BXLauncherItemDelegate> delegate;
@property (assign, nonatomic, getter=isLaunchable) BOOL launchable;
@property (strong, nonatomic) IBOutlet NSMenu *menu; //The context menu to display for this item.

- (IBAction) openItemInDOS: (id)sender;
- (IBAction) revealItemInFinder: (id)sender;
- (IBAction) removeItem: (id)sender;

/// Returns the menu which the specified view should display when right-clicked.
/// Allows the launcher item to customise the menu based on the contents of its represented object.
- (NSMenu *) menuForView: (BXLauncherItemView *)view;
@end

/// A base class for launcher items that registers mouse-hover events.
@interface BXLauncherItemView : BXCollectionItemView
{
    BOOL _mouseInside;
    BOOL _active;
    BOOL _enabled;
}

/// Typecast to indicate the type of delegate this view expects.
@property (weak, nonatomic) BXLauncherItem *delegate;

/// Whether the mouse cursor is currently inside the view.
@property (assign, nonatomic, getter=isMouseInside) BOOL mouseInside;

/// Whether the item is in the process of being clicked on or otherwise triggered.
@property (assign, nonatomic, getter=isActive) BOOL active;

/// Whether the item is able to be activated.
@property (assign, nonatomic, getter=isEnabled) BOOL enabled;
@end

/// Handles the custom appearance and input behaviour of regular program items.
@interface BXLauncherRegularItemView : BXLauncherItemView
@end

/// Handles the custom appearance and input behaviour of favorites.
@interface BXLauncherFavoriteView : BXLauncherRegularItemView
@end

/// Handles the behaviour of launcher heading rows.
@interface BXLauncherHeadingView : BXLauncherItemView
@end


/// Draws the background of the navigation strip at the top of the launch panel
@interface BXLauncherNavigationHeader : NSView
@end
