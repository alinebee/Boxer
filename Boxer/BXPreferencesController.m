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
	
	//Flip the tabs around to force the tab view to call our delegate methods
	[[self panelContainer] selectLastTabViewItem: self];
	[[self panelContainer] selectFirstTabViewItem: self];
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


//Resize the window and fade out the current tab's contents before switching tabs
- (void) tabView: (NSTabView *)tabView willSelectTabViewItem: (NSTabViewItem *)tabViewItem
{
	NSView *newView = [[[tabViewItem view] subviews] lastObject];
	NSView *oldView = [[[[tabView selectedTabViewItem] view] subviews] lastObject]; 
	
	NSSize newSize	= [newView frame].size;
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
	
	
	if ([[self window] isVisible])
	{
		//The tab-view loses the first responder when we hide the original view,
		//so we restore it once we've finished animating
		NSResponder *firstResponder = [[self window] firstResponder];
		
		NSDictionary *resize	= [NSDictionary dictionaryWithObjectsAndKeys:
								   [self window], NSViewAnimationTargetKey,
								   [NSValue valueWithRect: newFrame], NSViewAnimationEndFrameKey,
								   nil];
		
		NSDictionary *fadeOut	= [NSDictionary dictionaryWithObjectsAndKeys:
								   oldView, NSViewAnimationTargetKey,
								   NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey,
								   nil];
		
		NSViewAnimation *animation = [[NSViewAnimation alloc] initWithViewAnimations: [NSArray arrayWithObjects: fadeOut, resize, nil]];
		[animation setDuration: 0.3];
		[animation setAnimationBlockingMode: NSAnimationBlocking];
		[animation startAnimation];
		[animation release];
		[oldView setHidden: NO];
		
		//Restore the first responder
		[[self window] makeFirstResponder: firstResponder];
	}
	else
	{
		[[self window] setFrame: newFrame display: YES];
	}
}

- (void) tabView: (NSTabView *)tabView didSelectTabViewItem: (NSTabViewItem *)tabViewItem
{	
	[[self window] setTitle: [tabViewItem label]];
	
	//Sync the toolbar selection after switching tabs
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
