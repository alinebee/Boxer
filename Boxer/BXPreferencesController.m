/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXPreferencesController.h"
#import "BXSession.h"


@implementation BXPreferencesController
@synthesize filterGallery, panelContainer;

#pragma mark -
#pragma mark Initialization and deallocation

+ (BXPreferencesController *) controller
{
	static BXPreferencesController *singleton = nil;
	
	if (!singleton) singleton = [[self alloc] initWithWindowNibName: @"Preferences"];
	return singleton;
}

- (void) awakeFromNib
{
	//Bind to the filter preference so that we can synchronise our filter selection controls when it changes
	[[NSUserDefaults standardUserDefaults] addObserver: self
											forKeyPath: @"filterType"
											   options: NSKeyValueObservingOptionInitial
											   context: nil];
	
	[self tabView: [self panelContainer] didSelectTabViewItem: [[self panelContainer] selectedTabViewItem]];
}

- (void) dealloc
{
	[self setFilterGallery: nil], [filterGallery release];
	[self setPanelContainer: nil], [panelContainer release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Switching panels

- (IBAction) showPanel: (NSToolbarItem *)sender
{
	[[self panelContainer] selectTabViewItemAtIndex: [sender tag]];
}

- (void) tabView: (NSTabView *)tabView didSelectTabViewItem: (NSTabViewItem *)tabViewItem
{
	[[self window] setTitle: [tabViewItem label]];
	
	NSSize newSize	= [[[[tabViewItem view] subviews] lastObject] frame].size;
	NSSize oldSize	= [tabView frame].size;
	NSSize difference = NSMakeSize(newSize.width - oldSize.width,
								   newSize.height - oldSize.height);
	
	//Generate a new window frame that can contain the new panel,
	//Ensuring that the top left corner stays put
	NSRect newFrame, oldFrame = [[self window] frame];
	
	newFrame.origin = NSMakePoint(oldFrame.origin.x,
								  oldFrame.origin.y - difference.height);
	newFrame.size	= NSMakeSize(oldFrame.size.width + difference.width,
								 oldFrame.size.height + difference.height);
	
	[[self window] setFrame: newFrame display: YES animate: YES];
	
	//Sync the toolbar selection also
	NSInteger tabIndex = [tabView indexOfTabViewItem: tabViewItem];
	for (NSToolbarItem *item in [[[self window] toolbar] items])
	{
		if ([item tag] == tabIndex)
		{
			[[[self window] toolbar] setSelectedItemIdentifier: [item itemIdentifier]];
			break;
		}
	}
}

#pragma mark -
#pragma mark Managing filter gallery state

- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{
	//Whenever the key path changes, synchronise our filter selection controls
	if ([object isEqualTo: [NSUserDefaults standardUserDefaults]] && [keyPath isEqualToString: @"filterType"])
	{
		[self syncFilterControls];
	}
}

- (IBAction) toggleDefaultFilterType: (id)sender
{
	NSInteger filterType = [sender tag];
	[[NSUserDefaults standardUserDefaults] setInteger: filterType forKey: @"filterType"];
}

- (void) syncFilterControls
{
	NSInteger defaultFilter = [[NSUserDefaults standardUserDefaults] integerForKey: @"filterType"];

	for (id view in [filterGallery subviews])
	{
		if ([view isKindOfClass: [NSButton class]])
		{
			[view setState: ([view tag] == defaultFilter)];
		}
	}
}
@end
