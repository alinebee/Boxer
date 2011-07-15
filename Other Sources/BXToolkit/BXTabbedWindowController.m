/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXTabbedWindowController.h"


#pragma mark -
#pragma mark Implementation

@implementation BXTabbedWindowController
@synthesize tabView = mainTabView, toolbarForTabs;


#pragma mark -
#pragma mark Initialization and deallocation

- (void) dealloc
{
	[self setTabView: nil], [mainTabView release];
	[self setToolbarForTabs: nil], [toolbarForTabs release];
	
	[super dealloc];
}

- (void) windowDidLoad
{
	//At load time, fire off initial notification handlers for the
	//current item to ensure that everything is set up correctly.
	NSTabViewItem *selectedItem = [[self tabView] selectedTabViewItem];
	if (selectedItem)
	{
		[self tabView: [self tabView] willSelectTabViewItem: selectedItem];
		[self tabView: [self tabView] didSelectTabViewItem: selectedItem];
	}
}

#pragma mark -
#pragma mark Tab selection

- (NSInteger) selectedTabViewItemIndex
{
	NSTabViewItem *selectedItem = [[self tabView] selectedTabViewItem];
	if (selectedItem) return [[self tabView] indexOfTabViewItem: selectedItem];
	else return NSNotFound;
}
- (void) setSelectedTabViewItemIndex: (NSInteger)tabIndex
{
	[[self tabView] selectTabViewItemAtIndex: tabIndex];
}

- (IBAction) takeSelectedTabViewItemFromTag: (id <NSValidatedUserInterfaceItem>)sender
{
	[[self tabView] selectTabViewItemAtIndex: [sender tag]];
}

- (IBAction) takeSelectedTabViewItemFromSegment: (NSSegmentedControl *)sender
{
	NSInteger selectedTag = [[sender cell] tagForSegment: [sender selectedSegment]];
	[[self tabView] selectTabViewItemAtIndex: selectedTag];
}

//Resize the window and fade out the current tab's contents before switching tabs
- (void) tabView: (NSTabView *)tabView willSelectTabViewItem: (NSTabViewItem *)tabViewItem
{
	NSTabViewItem *currentItem = [tabView selectedTabViewItem];
	NSView *newView = [[[tabViewItem view] subviews] lastObject];
	NSView *oldView = [[[currentItem view] subviews] lastObject]; 
	
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
	
	
	if ((currentItem != tabViewItem) && [[self window] isVisible])
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


#pragma mark -
#pragma mark 

- (void) toolbarWillAddItem: (NSNotification *)notification
{
	NSToolbarItem *item = [[notification userInfo] objectForKey: @"item"];
	NSInteger tag = [item tag];
	NSUInteger numTabs = [[[self tabView] tabViewItems] count];
	if (tag > -1 && tag < (NSInteger)numTabs)
	{
		NSTabViewItem *matchingTab = [[self tabView] tabViewItemAtIndex: tag];
		[matchingTab setIdentifier: [item itemIdentifier]];
	}
}

- (NSArray *) toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar
{
	NSArray *tabs = [[self tabView] tabViewItems];
	NSMutableArray *identifiers = [NSMutableArray arrayWithCapacity: [tabs count]];
	for (NSTabViewItem *tab in tabs)
	{
		[identifiers addObject: [tab identifier]];
	}
	return identifiers;
}

- (void) tabView: (NSTabView *)tabView didSelectTabViewItem: (NSTabViewItem *)tabViewItem
{
	//Sync the toolbar selection after switching tabs
	[[self toolbarForTabs] setSelectedItemIdentifier: [tabViewItem identifier]];
    
    //Sync the window title to the selected tab's label if desired
    NSString *tabLabel = [tabViewItem label];
    if (tabLabel && [self shouldSyncWindowTitleToTabLabel: tabLabel])
    {
        NSString *title = [self windowTitleForDocumentDisplayName: tabLabel];
        [[self window] setTitle: title];
    }
}

- (BOOL) shouldSyncWindowTitleToTabLabel: (NSString *)label
{
    return NO;
}
@end