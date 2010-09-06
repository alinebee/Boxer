/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXMultiPanelWindowController.h"


@implementation BXMultiPanelWindowController
@synthesize panelContainer;

- (void) dealloc
{
	[self setPanelContainer: nil], [panelContainer release];
	
	[super dealloc];
}

- (NSView *) currentPanel
{
	return [[[self panelContainer] subviews] lastObject];
}

- (void) setCurrentPanel: (NSView *)newPanel
{
	NSView *oldPanel = [self currentPanel];
	
	//If no panel was specified, then just remove the old panel and don't resize at all
	if (!newPanel)
	{
		[oldPanel removeFromSuperview];
	}
	
	else if (oldPanel != newPanel)
	{
		NSRect newFrame, oldFrame = [[self window] frame];
		
		NSSize newSize	= [newPanel frame].size;
		NSSize oldSize	= [[self panelContainer] frame].size;
		
		NSSize difference = NSMakeSize(newSize.width - oldSize.width,
									   newSize.height - oldSize.height);
		
		//Generate a new window frame that can contain the new panel,
		//Ensuring that the top left corner stays put
		newFrame.origin = NSMakePoint(oldFrame.origin.x,
									  oldFrame.origin.y - difference.height);
		newFrame.size	= NSMakeSize(oldFrame.size.width + difference.width,
									 oldFrame.size.height + difference.height);
		
		
		//Animate the transition from one panel to the next, if we have a previous panel and the window is actually on screen
		if (oldPanel && [[self window] isVisible])
		{
			//Resize the new panel to the same size as the old one, in preparation for window resizing
			//FIXME: this doesn't actually work properly
			//[newPanel setFrame: [oldPanel frame]];
			
			//Add the new panel beneath the old one
			[[self panelContainer] addSubview: newPanel positioned: NSWindowBelow relativeTo: oldPanel];
			
			NSViewAnimation *animation = [[self transitionFromPanel: oldPanel toPanel: newPanel] retain];
			NSDictionary *resize = [NSDictionary dictionaryWithObjectsAndKeys:
									[self window], NSViewAnimationTargetKey,
									[NSValue valueWithRect: newFrame], NSViewAnimationEndFrameKey,
									nil];
			
			[animation setViewAnimations: [[animation viewAnimations] arrayByAddingObject: resize]];
			[animation setAnimationBlockingMode: NSAnimationBlocking];
			[animation startAnimation];
			[animation release];
			
			//Reset the properties of the original panel once the animation is complete
			[oldPanel removeFromSuperview];
			[oldPanel setFrameSize: oldSize];
			[oldPanel setHidden: NO];
			
			//Fixes a weird bug whereby scrollers would drag the window with them after switching panels
			if ([[self window] isMovableByWindowBackground])
			{
				[[self window] setMovableByWindowBackground: NO];
				[[self window] setMovableByWindowBackground: YES];
			}
			
			//Fixes infinite-redraw bug caused by animated fade
			[newPanel display];
		}
		//If we don't have a previous panel or the window isn't visible, then perform the swap immediately without animating
		else
		{
			[oldPanel removeFromSuperview];
			[[self window] setFrame: newFrame display: YES];
			[[self panelContainer] addSubview: newPanel];
		}
		
		//Activate the designated first responder for this panel after switching
		//(Currently this is piggybacking off NSView's nextKeyView, which is kinda not good)
		[[self window] makeFirstResponder: [newPanel nextKeyView]];
	}
}

- (NSViewAnimation *) fadeOutPanel: (NSView *)oldPanel overPanel: (NSView *)newPanel
{
	NSDictionary *fadeOut = [NSDictionary dictionaryWithObjectsAndKeys:
							 oldPanel, NSViewAnimationTargetKey,
							 NSViewAnimationFadeOutEffect, NSViewAnimationEffectKey,
							 nil];
	
	NSViewAnimation *animation = [[NSViewAnimation alloc] init];
	[animation setViewAnimations: [NSArray arrayWithObject: fadeOut]];
	return [animation autorelease];
}

- (NSViewAnimation *) hidePanel: (NSView *)oldPanel andFadeInPanel: (NSView *)newPanel
{
	NSDictionary *fadeIn = [NSDictionary dictionaryWithObjectsAndKeys:
							newPanel, NSViewAnimationTargetKey,
							NSViewAnimationFadeInEffect, NSViewAnimationEffectKey,
							nil];
	
	[oldPanel setHidden: YES];
	NSViewAnimation *animation = [[NSViewAnimation alloc] init];
	[animation setViewAnimations: [NSArray arrayWithObject: fadeIn]];
	return [animation autorelease];
}

- (NSViewAnimation *) transitionFromPanel: (NSView *)oldPanel toPanel: (NSView *)newPanel
{
	NSViewAnimation *animation = [self hidePanel: oldPanel andFadeInPanel: newPanel];
	[animation setDuration: 0.25];
	return animation;
}

@end