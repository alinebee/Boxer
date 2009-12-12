/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */



#import "BXDockTileController.h"
#import "BXAppController.h"


//Todo: rework this wretched thing to go back to setting NSApp applicationIconImage instead.
//Rendering a custom view is complete overkill, especially given the pain that comes from
//using NSViewController nib loading.
@implementation BXDockTileController

- (void) dealloc
{
	[[NSApp delegate] removeObserver: self forKeyPath: @"currentSession.representedIcon"];
	[super dealloc];
}

- (void) awakeFromNib
{
	//Trigger NSViewController's nib-loading machinery after we've been thawed from our first containing nib. This will cause us to load our own nib, which will call awakeFromNib again - but this time the view will be ready, and this will do nothing.
	//God I hate NSViewController sometimes.
	[self view];

	//Listen for changes to the current session's represented icon
	[[NSApp delegate] addObserver: self forKeyPath: @"currentSession.representedIcon" options: 0 context: nil];	
}

- (void) setView:(NSView *)view
{
	[super setView: view];
	
	[[NSApp dockTile] setContentView: view];
}

//Whenever the represented icon changes, force a redraw of our icon view
- (void)observeValueForKeyPath: (NSString *)keyPath
					  ofObject: (id)object
						change: (NSDictionary *)change
					   context: (void *)context
{	
	if ([keyPath isEqualToString: @"currentSession.representedIcon"]) [[NSApp dockTile] display];
}
@end