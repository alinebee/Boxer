/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXTabbedWindowController manages a window whose primary component is an NSTabView. It resizes
//its window to accomodate the selected tab, and animates transitions between tabs. It can also
//use an NSToolbar in place of the NSTabView's own tab selector.

#import <Cocoa/Cocoa.h>

@interface BXTabbedWindowController : NSWindowController
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
< NSTabViewDelegate, NSToolbarDelegate >
#endif
{
	IBOutlet NSTabView *mainTabView;
	IBOutlet NSToolbar *toolbarForTabs;
}
@property (retain, nonatomic) NSTabView *tabView;
@property (retain, nonatomic) NSToolbar *toolbarForTabs;

//The index of the current tab view item, mostly for scripting purposes.
@property (assign, nonatomic) NSInteger selectedTabViewItemIndex;

//Select the tab whose index corresponds to the tag of the sender.
- (IBAction) takeSelectedTabViewItemFromTag: (id <NSValidatedUserInterfaceItem>)sender;

//Select the tab whose index corresponds to the tag of the selected control segment.
- (IBAction) takeSelectedTabViewItemFromSegment: (NSSegmentedControl *)sender;

@end