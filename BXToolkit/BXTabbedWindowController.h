/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXTabbedWindowController manages a window whose primary component is an NSTabView. It resizes
//its window to accomodate the selected tab and animates transitions between tabs.

#import <Cocoa/Cocoa.h>

@interface BXTabbedWindowController : NSWindowController
{
	IBOutlet NSTabView *mainTabView;
}
@property (retain, nonatomic) NSTabView *tabView;

//Select the tab whose index corresponds to the tag of the sender.
- (IBAction) takeSelectedTabViewItemFromTag: (id <NSValidatedUserInterfaceItem>)sender;

//Select the tab whose index corresponds to the tag of the selected control segment.
- (IBAction) takeSelectedTabViewItemFromSegment: (NSSegmentedControl *)sender;

@end