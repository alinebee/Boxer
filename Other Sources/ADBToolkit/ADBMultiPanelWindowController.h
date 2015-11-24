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

//ADBMultiPanelWindowController is an NSWindowController subclass for managing windows that display
//one out of a set of different panels. This class provides methods for changing the current panel
//and animating transitions from one panel to another (resizing the window and crossfading views).

//This is a more flexible and less structured alternative to ADBTabbedWindowController, written back
//when I was allergic to NSTabView. This provides better animation control (with better crossfades),
//but for tab-based or toolbar-based windows, NSTabbedWindowController is still the better choice.

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface ADBMultiPanelWindowController : NSWindowController
{
    NSView *_panelContainer;
}

#pragma mark -
#pragma mark Properties

/// The currently-displayed panel.
@property (assign, nonatomic, nullable) NSView *currentPanel;

/// The view into which the current panel will be added.
@property (retain, nonatomic) IBOutlet NSView *panelContainer;

#pragma mark -
#pragma mark Animation methods

/// Returns an animation that will fade out oldPanel to reveal newPanel.
/// Suited for panels with an opaque background.
- (NSViewAnimation *) fadeOutPanel: (NSView *)oldPanel overPanel: (NSView *)newPanel;

/// Returns an animation that instantly hides oldPanel then fades in newPanel.
/// Suited for panels with a transparent background.
- (NSViewAnimation *) hidePanel: (NSView *)oldPanel andFadeInPanel: (NSView *)newPanel;

/// Returns the NSAnimation which will perform the transition from one panel to the other.
/// Intended to be overridden by subclasses to define their own animations.
/// Defaults to returning hidePanel:andFadeInPanel: with a duration of 0.25.
- (NSViewAnimation *) transitionFromPanel: (NSView *)oldPanel toPanel: (NSView *)newPanel;

@end

NS_ASSUME_NONNULL_END
