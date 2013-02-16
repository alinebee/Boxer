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


//ADBTabbedWindowController manages a window whose primary component is an NSTabView. It resizes
//its window to accomodate the selected tab, and animates transitions between tabs. It can also
//use an NSToolbar or NSSegmentedControl in place of the NSTabView's own tab selector.

#import <Cocoa/Cocoa.h>

//How long a fade+resize transition will take when switching tabs.
#define ADBTabbedWindowControllerTransitionDuration 0.25

@interface ADBTabbedWindowController : NSWindowController <NSTabViewDelegate, NSToolbarDelegate>
{
    NSTabView *_tabView;
    NSToolbar *_toolbarForTabs;
    BOOL _animatesTabTransitionsWithFade;
}
@property (retain, nonatomic) IBOutlet NSTabView *tabView;
@property (retain, nonatomic) IBOutlet NSToolbar *toolbarForTabs;

//Whether to animate the switch between tabs with a fade-out as well as a resize.
//NO by default, as this does not play nice with layer-backed views.
@property (assign, nonatomic) BOOL animatesTabTransitionsWithFade;

//The index of the current tab view item, mostly for scripting purposes.
@property (assign, nonatomic) NSInteger selectedTabViewItemIndex;

//Select the tab whose index corresponds to the tag of the sender.
- (IBAction) takeSelectedTabViewItemFromTag: (id <NSValidatedUserInterfaceItem>)sender;

//Select the tab whose index corresponds to the tag of the selected control segment.
- (IBAction) takeSelectedTabViewItemFromSegment: (NSSegmentedControl *)sender;

//Whether the controller should set the window title to the specified label
//(taken from the selected tab.)
//NO by default: intended to be overridden by subclasses.
//If YES, then whenever the selected tab changes, the tab's label will be sent
//to windowTitleForDocumentDisplayName: and the result assigned as the window title.
- (BOOL) shouldSyncWindowTitleToTabLabel: (NSString *)label;

@end