/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */


#import "ADBTabbedWindowController.h"


#pragma mark -
#pragma mark Implementation

@implementation ADBTabbedWindowController
@synthesize tabView = _tabView;
@synthesize toolbarForTabs = _toolbarForTabs;
@synthesize animatesTabTransitionsWithFade = _animatesTabTransitionsWithFade;


#pragma mark -
#pragma mark Initialization and deallocation

- (void) dealloc
{
    self.tabView = nil;
    self.toolbarForTabs = nil;
    
	[super dealloc];
}

- (void) windowDidLoad
{
	//At load time, fire off initial notification handlers for the
	//current item to ensure that everything is set up correctly.
	NSTabViewItem *selectedItem = self.tabView.selectedTabViewItem;
	if (selectedItem)
	{
		[self tabView: self.tabView willSelectTabViewItem: selectedItem];
		[self tabView: self.tabView didSelectTabViewItem: selectedItem];
	}
}

#pragma mark -
#pragma mark Tab selection

- (NSInteger) selectedTabViewItemIndex
{
	NSTabViewItem *selectedItem = self.tabView.selectedTabViewItem;
	if (selectedItem) return [self.tabView indexOfTabViewItem: selectedItem];
	else return NSNotFound;
}

- (void) setSelectedTabViewItemIndex: (NSInteger)tabIndex
{
	[self.tabView selectTabViewItemAtIndex: tabIndex];
}

- (IBAction) takeSelectedTabViewItemFromTag: (id <NSValidatedUserInterfaceItem>)sender
{
	[self.tabView selectTabViewItemAtIndex: sender.tag];
}

- (IBAction) takeSelectedTabViewItemFromSegment: (NSSegmentedControl *)sender
{
	NSInteger selectedTag = [sender.cell tagForSegment: sender.selectedSegment];
	[self.tabView selectTabViewItemAtIndex: selectedTag];
}

//Resize the window and fade out the current tab's contents before switching tabs
- (void) tabView: (NSTabView *)tabView willSelectTabViewItem: (NSTabViewItem *)tabViewItem
{
	NSTabViewItem *currentItem = tabView.selectedTabViewItem;
	NSView *newView = [tabViewItem.view subviews].lastObject;
	NSView *oldView = [currentItem.view subviews].lastObject;
	
	NSSize newSize	= newView.frame.size;
	NSSize oldSize	= tabView.frame.size;
	NSSize difference = NSMakeSize(newSize.width - oldSize.width,
								   newSize.height - oldSize.height);
	
	//Generate a new window frame that can contain the new panel,
	//Ensuring that the top left corner stays put
	NSRect newFrame, oldFrame = self.window.frame;
	
	newFrame.origin = NSMakePoint(oldFrame.origin.x,
								  oldFrame.origin.y - difference.height);
	newFrame.size	= NSMakeSize(oldFrame.size.width + difference.width,
								 oldFrame.size.height + difference.height);
	
	
	if ((currentItem != tabViewItem) && self.window.isVisible)
	{
        //The tab-view loses the first responder when we hide the original view,
        //so we restore it once we've finished animating
        NSResponder *firstResponder = self.window.firstResponder;
        
        //If a fade transition is enabled, synchronise the resizing and fading animations
        if (self.animatesTabTransitionsWithFade)
        {
            NSDictionary *resize = @{
                NSViewAnimationTargetKey: self.window,
                NSViewAnimationEndFrameKey: [NSValue valueWithRect: newFrame],
            };
            
            NSDictionary *fadeOut = @{
                NSViewAnimationTargetKey: oldView,
                NSViewAnimationFadeOutEffect: NSViewAnimationEffectKey,
            };
            
            NSViewAnimation *animation = [[NSViewAnimation alloc] initWithViewAnimations: @[fadeOut, resize]];
            animation.duration = ADBTabbedWindowControllerTransitionDuration;
            animation.animationBlockingMode = NSAnimationBlocking;
            
            [animation startAnimation];
            [animation release];
            
            //The fade-out animation will have automatically hidden the view at the end.
            //Unhide it before we switch the tab so that it won't remain hidden when switching back.
            oldView.hidden = NO;
		}
        //Otherwise, if we need to resize the window, then hide the original view
        //while animating the resize.
        else if (!NSEqualRects(oldFrame, newFrame))
        {
            oldView.hidden = YES;
            
            NSDictionary *resize = @{
                NSViewAnimationTargetKey: self.window,
                NSViewAnimationEndFrameKey: [NSValue valueWithRect: newFrame],  
            };
            
            //IMPLEMENTATION NOTE: We could just use setFrame:display:animate:,
            //but we want a constant speed between tab transitions
            NSViewAnimation *animation = [[NSViewAnimation alloc] initWithViewAnimations: @[resize]];
            animation.duration = ADBTabbedWindowControllerTransitionDuration;
            animation.animationBlockingMode = NSAnimationBlocking;
            
            [animation startAnimation];
            [animation release];
            
            oldView.hidden = NO;
        }
        
		//Restore the first responder
		[self.window makeFirstResponder: firstResponder];
	}
	else
	{
		[self.window setFrame: newFrame display: YES];
	}
}


#pragma mark - NSToolbarDelegate methods

- (void) toolbarWillAddItem: (NSNotification *)notification
{
	NSToolbarItem *item = [notification.userInfo objectForKey: @"item"];
	NSInteger tag = item.tag;
	NSUInteger numTabs = self.tabView.tabViewItems.count;
	if (tag > -1 && tag < (NSInteger)numTabs)
	{
		NSTabViewItem *matchingTab = [self.tabView tabViewItemAtIndex: tag];
        matchingTab.identifier = item.itemIdentifier;
	}
}

- (NSArray *) toolbarSelectableItemIdentifiers: (NSToolbar *)toolbar
{
	NSArray *tabs = self.tabView.tabViewItems;
	NSMutableArray *identifiers = [NSMutableArray arrayWithCapacity: tabs.count];
	for (NSTabViewItem *tab in tabs)
	{
		[identifiers addObject: tab.identifier];
	}
	return identifiers;
}

- (void) tabView: (NSTabView *)tabView didSelectTabViewItem: (NSTabViewItem *)tabViewItem
{
	//Sync the toolbar selection after switching tabs
	[self.toolbarForTabs setSelectedItemIdentifier: tabViewItem.identifier];
    
    //Sync the window title to the selected tab's label if desired
    NSString *tabLabel = tabViewItem.label;
    if (tabLabel && [self shouldSyncWindowTitleToTabLabel: tabLabel])
    {
        self.window.title = [self windowTitleForDocumentDisplayName: tabLabel];
    }
}

- (BOOL) shouldSyncWindowTitleToTabLabel: (NSString *)label
{
    return NO;
}
@end