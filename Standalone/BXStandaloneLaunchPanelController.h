/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import <Cocoa/Cocoa.h>

@interface BXStandaloneLaunchPanelController : NSViewController
{
    NSCollectionView *_launcherList;
    NSMutableArray<NSDictionary*> *_displayedRows;
}

@property (retain, nonatomic) IBOutlet NSCollectionView *launcherList;

/// An array of NSDictionaries for each item in the favorite-programs list.
@property (retain, nonatomic) NSMutableArray<NSDictionary*> *displayedRows;

@end
