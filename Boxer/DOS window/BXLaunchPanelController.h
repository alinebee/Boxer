/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Cocoa/Cocoa.h>

@interface BXLaunchPanelController : NSViewController
{
    NSTabView *_tabView;
    NSSegmentedControl *_tabSelector;
    NSCollectionView *_allProgramsList;
    NSCollectionView *_favoriteProgramsList;
    
    NSMutableArray *_allProgramRows;
    NSMutableArray *_favoriteProgramRows;
}

@property (retain, nonatomic) IBOutlet NSTabView *tabView;
@property (retain, nonatomic) IBOutlet NSSegmentedControl *tabSelector;
@property (retain, nonatomic) IBOutlet NSCollectionView *allProgramsList;
@property (retain, nonatomic) IBOutlet NSCollectionView *favoriteProgramsList;

@property (readonly, nonatomic) BOOL canLaunchPrograms;

//An array of NSDictionaries for each item in the all-programs list.
//This will include rows for each drive.
@property (retain, nonatomic) NSMutableArray *allProgramRows;

//An array of NSDictionaries for each item in the favorite-programs list.
@property (retain, nonatomic) NSMutableArray *favoriteProgramRows;

//Triggered by program-list buttons to launch the specified program.
//sender is required to be one of our program-list collection view items.
- (IBAction) launchFavoriteProgram: (NSButton *)sender;

@end
