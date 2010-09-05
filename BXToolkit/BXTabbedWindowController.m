/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXTabbedWindowController.h"

#pragma mark -
#pragma mark Private method declarations

@interface BXTabbedWindowController ()

//Calls willSelectTabViewItem: and didSelectTabViewItem: with the currently-selected tab view item,
//to perform any synchronisation needed when the tab view is first assigned to us.
- (void) _synchronizeSelectedTab;
@end


#pragma mark -
#pragma mark Implementation

@implementation BXTabbedWindowController
@synthesize tabView = mainTabView;


#pragma mark -
#pragma mark Initialization and deallocation

- (void) dealloc
{
	[self setTabView: nil], [mainTabView release];
	
	[super dealloc];
}

- (void) awakeFromNib
{
	[self _synchronizeSelectedTab];
}


#pragma mark -
#pragma mark Tab selection

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

- (void) _synchronizeSelectedTab
{
	[self tabView: mainTabView willSelectTabViewItem: [mainTabView selectedTabViewItem]];
	[self tabView: mainTabView didSelectTabViewItem: [mainTabView selectedTabViewItem]];
}

@end