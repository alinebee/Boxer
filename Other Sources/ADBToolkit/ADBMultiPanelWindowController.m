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


#import "ADBMultiPanelWindowController.h"


@implementation ADBMultiPanelWindowController
@synthesize panelContainer = _panelContainer;

- (void) dealloc
{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    self.panelContainer = nil;
    
	[super dealloc];
#pragma clang diagnostic pop
}

- (NSView *) currentPanel
{
	return self.panelContainer.subviews.lastObject;
}

- (void) setCurrentPanel: (NSView *)newPanel
{
	NSView *oldPanel = self.currentPanel;
	
	//If no panel was specified, then just remove the old panel and don't resize at all
	if (!newPanel)
	{
		[oldPanel removeFromSuperview];
	}
	
	else if (oldPanel != newPanel)
	{
		NSRect newFrame, oldFrame = self.window.frame;
		
		NSSize newSize	= newPanel.frame.size;
		NSSize oldSize	= self.panelContainer.frame.size;
		
		NSSize difference = NSMakeSize(newSize.width - oldSize.width,
									   newSize.height - oldSize.height);
		
		//Generate a new window frame that can contain the new panel,
		//Ensuring that the top left corner stays put.
		newFrame.origin = NSMakePoint(oldFrame.origin.x,
									  oldFrame.origin.y - difference.height);
		newFrame.size	= NSMakeSize(oldFrame.size.width + difference.width,
									 oldFrame.size.height + difference.height);
		
		
		//Animate the transition from one panel to the next, if we have a previous panel and the window is actually on screen
		if (oldPanel && self.window.isVisible)
		{
			//Resize the new panel to the same size as the old one, in preparation for window resizing
			//FIXME: this doesn't actually work properly
			//[newPanel setFrame: [oldPanel frame]];
			
			//Add the new panel beneath the old one
			[self.panelContainer addSubview: newPanel
                                 positioned: NSWindowBelow
                                 relativeTo: oldPanel];
			
			NSViewAnimation *animation = [self transitionFromPanel: oldPanel
                                                           toPanel: newPanel];
            
            NSDictionary *resize = @{
                NSViewAnimationTargetKey: self.window,
                NSViewAnimationEndFrameKey: [NSValue valueWithRect: newFrame],
            };
            
            animation.viewAnimations = [animation.viewAnimations arrayByAddingObject: resize];
            
            animation.animationBlockingMode = NSAnimationBlocking;
            
            [animation retain];
			[animation startAnimation];
			[animation release];
			
			//Reset the properties of the original panel once the animation is complete
			[oldPanel removeFromSuperview];
            oldPanel.frameSize = oldSize;
			oldPanel.hidden = NO;
			
			//Fixes a weird bug in 10.5 (and 10.6?) whereby scrollers would drag the window
            //with them after switching panels
			if (self.window.isMovableByWindowBackground)
			{
				self.window.movableByWindowBackground = NO;
				self.window.movableByWindowBackground = YES;
			}
			
			//Fixes infinite-redraw bug caused by animated fade
			[newPanel display];
		}
		//If we don't have a previous panel or the window isn't visible, then perform the swap immediately without animating
		else
		{
			[oldPanel removeFromSuperview];
			[self.window setFrame: newFrame display: YES];
			[self.panelContainer addSubview: newPanel];
		}
		
		//Activate the designated first responder for this panel after switching
		//(Currently this is piggybacking off NSView's nextKeyView, which is kinda not good)
		[self.window makeFirstResponder: newPanel.nextKeyView];
	}
}

- (NSViewAnimation *) fadeOutPanel: (NSView *)oldPanel overPanel: (NSView *)newPanel
{
	NSDictionary *fadeOut = @{
        NSViewAnimationTargetKey: oldPanel,
        NSViewAnimationEffectKey: NSViewAnimationFadeOutEffect,
    };
	
	NSViewAnimation *animation = [[NSViewAnimation alloc] initWithViewAnimations: @[fadeOut]];
	return [animation autorelease];
}

- (NSViewAnimation *) hidePanel: (NSView *)oldPanel
                 andFadeInPanel: (NSView *)newPanel
{
    
	NSDictionary *fadeIn = @{
        NSViewAnimationTargetKey: newPanel,
        NSViewAnimationEffectKey: NSViewAnimationFadeInEffect,
    };
	
    oldPanel.hidden = YES;
	NSViewAnimation *animation = [[NSViewAnimation alloc] initWithViewAnimations: @[fadeIn]];
	return [animation autorelease];
}

- (NSViewAnimation *) transitionFromPanel: (NSView *)oldPanel
                                  toPanel: (NSView *)newPanel
{
	NSViewAnimation *animation = [self hidePanel: oldPanel andFadeInPanel: newPanel];
    animation.duration = 0.25;
	return animation;
}

@end