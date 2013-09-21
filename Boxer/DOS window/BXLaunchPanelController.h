/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Cocoa/Cocoa.h>

typedef enum {
    BXLaunchPanelDisplayFavorites,
    BXLaunchPanelDisplayAllPrograms,
} BXLaunchPanelDisplayMode;

@interface BXLaunchPanelController : NSViewController <NSTextFieldDelegate>
{
    NSSegmentedControl *_tabSelector;
    NSCollectionView *_launcherList;
    NSScrollView *_launcherScrollView;
    NSSearchField *_filter;
    
    NSMutableArray *_filterKeywords;
    
    NSMutableArray *_allProgramRows;
    NSMutableArray *_favoriteProgramRows;
    NSMutableArray *_displayedRows;
    
    BXLaunchPanelDisplayMode _displayMode;
}

@property (assign, nonatomic) IBOutlet NSSegmentedControl *tabSelector;
@property (assign, nonatomic) IBOutlet NSCollectionView *launcherList;
@property (assign, nonatomic) IBOutlet NSScrollView *launcherScrollView;
@property (assign, nonatomic) IBOutlet NSSearchField *filter;
@property (assign, nonatomic) BXLaunchPanelDisplayMode displayMode;

@property (readonly, nonatomic) BOOL hasFavorites;
@property (readonly, nonatomic) BOOL hasPrograms;
@property (readonly, nonatomic) BOOL canLaunchPrograms;

//An array of NSDictionaries for every item to display in the list.
@property (readonly, retain, nonatomic) NSMutableArray *displayedRows;

//An array of sanitised NSStrings derived from the contents of the search field. 
@property (readonly, retain, nonatomic) NSMutableArray *filterKeywords;

//Triggered by favorite buttons to launch the specified program.
//sender is required to be one of our program-list collection view items.
- (IBAction) launchFavoriteProgram: (NSButton *)sender;

- (IBAction) showFavoritePrograms: (id)sender;
- (IBAction) showAllPrograms: (id)sender;
- (IBAction) performSegmentedButtonAction: (id)sender;

- (IBAction) enterSearchText: (NSSearchField *)sender;

@end


//A custom collection view that uses a different prototype for drive 'headings'
@interface BXLauncherList : NSCollectionView
{
    NSCollectionViewItem *_headingPrototype;
    NSCollectionViewItem *_favoritePrototype;
}

@property (assign, nonatomic) IBOutlet NSCollectionViewItem *headingPrototype;
@property (assign, nonatomic) IBOutlet NSCollectionViewItem *favoritePrototype;

@end


//Draws the background of the navigation strip at the top of the launch panel
@interface BXLauncherNavigationHeader : NSView
@end