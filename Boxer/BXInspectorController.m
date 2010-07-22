/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXInspectorController.h"
#import "BXSession.h"
#import "BXEmulator.h"
#import "BXDrive.h"
#import "BXAppController.h"
#import "BXValueTransformers.h"
#import "CGSPrivate.h" //For undocumented blur effect functions


const CGFloat BXInspectorPanelBlurRadius = 2.0f;
const CGFloat BXMouseSensitivityRange = 2.0f;

@implementation BXInspectorController
@synthesize panelContainer;
@synthesize panelSelector;
@synthesize gamePanel, cpuPanel, mousePanel, drivePanel;

+ (void) initialize
{
	NSArray *sensitivityThresholds = [NSArray arrayWithObjects:
									  [NSNumber numberWithFloat: 1.0f / BXMouseSensitivityRange],
									  [NSNumber numberWithFloat: 1.0f],
									  [NSNumber numberWithFloat: 1.0f * BXMouseSensitivityRange],
									  nil];
	
	BXBandedValueTransformer *mouseSensitivity = [[BXBandedValueTransformer alloc] initWithThresholds: sensitivityThresholds];
	BXDisplayPathTransformer *displayPath	= [[BXDisplayPathTransformer alloc] initWithJoiner: @" ▸ " maxComponents: 0];
	BXDisplayNameTransformer *displayName	= [BXDisplayNameTransformer new];
	BXImageSizeTransformer *imageSize = [[BXImageSizeTransformer alloc] initWithSize: NSMakeSize(16, 16)];
	
	
	
	[NSValueTransformer setValueTransformer: mouseSensitivity forName: @"BXMouseSensitivitySlider"];
	[NSValueTransformer setValueTransformer: displayPath forName: @"BXDriveDisplayPath"];
	[NSValueTransformer setValueTransformer: displayPath forName: @"BXDocumentationDisplayPath"];
	[NSValueTransformer setValueTransformer: displayName forName: @"BXDocumentationDisplayName"];
	[NSValueTransformer setValueTransformer: imageSize forName: @"BXDocumentationIconSize"];
	
	[displayPath release];
	[displayName release];
	[imageSize release];

}

+ (BXInspectorController *)controller
{
	static BXInspectorController *singleton = nil;
	if (!singleton) singleton = [[self alloc] initWithWindowNibName: @"InspectorPanel"];
	return singleton;
}

- (void) dealloc
{
	[self setPanelContainer: nil],	[panelContainer release];
	[self setGamePanel: nil],		[gamePanel release];
	[self setCpuPanel: nil],		[cpuPanel release];
	[self setDrivePanel: nil],		[drivePanel release];
	[self setPanelSelector: nil],	[panelSelector release];
	
	[super dealloc];
}

- (void) awakeFromNib
{	
	NSPanel *theWindow = (NSPanel *)[self window];

	[theWindow setBecomesKeyOnlyIfNeeded: YES];
		
	[theWindow setFrameAutosaveName: @"InspectorPanel"];
	
	//Set the initial panel based on the user's last chosen panel (defaulting to the CPU panel)
	NSView *initialView;
	NSArray *panels = [self panels];
	NSUInteger selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey: @"initialInspectorPanelIndex"];
	
	if (selectedIndex < [panels count]) initialView = [panels objectAtIndex: selectedIndex];
	else initialView = [self cpuPanel];
	
	[self setCurrentPanel: initialView];
	
	//Listen for changes to the current session
	[[NSApp delegate] addObserver: self
					   forKeyPath: @"currentSession"
						  options: NSKeyValueObservingOptionInitial
						  context: nil];
}

//Whenever the session changes, update the availability of the gamebox panel
- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{	
	if ([keyPath isEqualToString: @"currentSession"])
	{
		BXSession *session			= [[NSApp delegate] currentSession];
		NSInteger gamePanelIndex	= [[self panels] indexOfObject: [self gamePanel]];
		
		//This charade is necessary because NSSegmentedControl has an awful interface
		NSInteger i = 0;
		for (i = 0; i < [[self panelSelector] segmentCount]; i++)
		{
			if ([[[self panelSelector] cell] tagForSegment: i] == gamePanelIndex)
				[[self panelSelector] setEnabled: [session isGamePackage] forSegment: i];
		}
		
		if (![session isGamePackage] && [[self currentPanel] isEqualTo: [self gamePanel]])
			[self setCurrentPanel: [self cpuPanel]];
	}
}

- (void) showWindow: (id)sender
{
	[super showWindow: sender];
	
	//The code below applies a soft gaussian blur underneath the window, and was lifted directly from:
	//http://blog.steventroughtonsmith.com/2008/03/using-core-image-filters-onunder.html
	//This is all private-framework stuff and so may stop working (or compiling) in a future version of OS X.
		
	//Get the current connection to CoreGraphics
	CGSConnection thisConnection = _CGSDefaultConnection();
	CGSWindowFilterRef compositingFilter = NULL;
	NSInteger compositingType = 1; //Applies the effect only underneath the window
	
	if (thisConnection)
	{
		//Create a CoreImage gaussian blur filter.
		CGSNewCIFilterByName(thisConnection, (CFStringRef)@"CIGaussianBlur", &compositingFilter);
		
		if (compositingFilter)
		{
			//Set the parameters of the filter we'll be adding.
			NSDictionary *options = [NSDictionary dictionaryWithObject: [NSNumber numberWithFloat: BXInspectorPanelBlurRadius]
																forKey: @"inputRadius"];
			
			CGSSetCIFilterValuesFromDictionary(thisConnection, compositingFilter, (CFDictionaryRef)options);
			
			//Now apply the filter to our inspector window.
			CGSWindowID windowNumber = [[self window] windowNumber];
			CGSAddWindowFilter(thisConnection, windowNumber, compositingFilter, compositingType);
			
			//Clean up after ourselves.
			CGSReleaseCIFilter(thisConnection, compositingFilter);			
		}
	}
}

//A miserable hack to notify BXAppController that the inspector panel has been closed,
//so that we can update button states immediately. It has so far proven impossible to manage
//this some other, more preferable way (such as bindings).
- (BOOL) windowShouldClose: (id)sender
{
	[[NSApp delegate] setInspectorPanelShown: NO];
	return YES;
}


- (NSArray *) panels
{
	return [NSArray arrayWithObjects:
		[self gamePanel], [self cpuPanel], [self mousePanel], [self drivePanel],
	nil];
}

- (NSView *) currentPanel
{
	return [[[self panelContainer] subviews] lastObject];
}

- (void) setCurrentPanel: (NSView *)panel
{
	NSView *oldPanel = [self currentPanel];
	
	if (oldPanel != panel)
	{
		[self willChangeValueForKey: @"currentPanel"];

		//Synchronise the selected tab
		NSInteger panelIndex = [[self panels] indexOfObject: panel];
		[[self panelSelector] selectSegmentWithTag: panelIndex];
		
		//Now add the new panel and resize the window to accomodate it

		NSWindow *theWindow	= [self window];
		NSView *container	= [self panelContainer];

		NSRect newFrame, oldFrame = [theWindow frame];
		
		NSSize newSize	= [panel bounds].size;
		NSSize oldSize	= [container bounds].size;
		NSSize difference = NSMakeSize(
			newSize.width - oldSize.width,
			newSize.height - oldSize.height
		);
		
		//Generate a new window frame that can contain the new panel,
		//Ensuring that the top left corner stays put
		newFrame.origin = NSMakePoint(
			oldFrame.origin.x,
			oldFrame.origin.y - difference.height
		);
		newFrame.size	= NSMakeSize(
			oldFrame.size.width + difference.width,
			oldFrame.size.height + difference.height
		);
		
		//Add the new panel into the view
		[container addSubview: panel];
			
		//Animate the panel transition, if we're flipping from a previous panel to a new one
		if (oldPanel)
		{
			[oldPanel removeFromSuperview];
			[self startScalingToFrame: newFrame];
		}
		else
		{
			//Otherwise just resize the window instantly
			[theWindow setFrame: newFrame display: YES];
		}
		
		[self didChangeValueForKey: @"currentPanel"];
	}
}

- (void) startScalingToFrame: (NSRect)newFrame
{
	NSViewAnimation *animation;
	NSDictionary *resize, *fadeIn;

	resize = [NSDictionary dictionaryWithObjectsAndKeys:
		[self window], NSViewAnimationTargetKey,
		[NSValue valueWithRect: newFrame], NSViewAnimationEndFrameKey,
	nil];
	
	fadeIn = [NSDictionary dictionaryWithObjectsAndKeys:
		[self currentPanel], NSViewAnimationTargetKey,
		NSViewAnimationFadeInEffect, NSViewAnimationEffectKey,
	nil];

	//Note: animation is released in our delegate functions
	animation = [[NSViewAnimation alloc] initWithViewAnimations: [NSArray arrayWithObjects: resize, fadeIn, nil]];

	[animation setAnimationBlockingMode: NSAnimationNonblocking];
	[animation setDuration: 0.2];
	[animation setDelegate: self];

	[animation startAnimation];
}

- (void) animationDidEnd: (NSAnimation *)animation
{
	NSWindow *theWindow = [self window];
	//This fixes a weird bug whereby scrollers would drag the window with them after switching panels.
	//TODO: come up with a more direct solution.
	[theWindow setMovableByWindowBackground: NO];
	[theWindow setMovableByWindowBackground: YES];
	
	//Force the window to redraw after the animation has completed
	//to cure an OS X 10.5 text draw bug
	[theWindow display];
	
	[animation release];
}

- (void) animationDidStop: (NSAnimation *)animation
{
	return [self animationDidEnd: animation];
}


#pragma mark -
#pragma mark UI actions

- (IBAction) showGameInspectorPanel:	(id)sender	{ [self setCurrentPanel: [self gamePanel]]; }
- (IBAction) showCPUInspectorPanel:		(id)sender	{ [self setCurrentPanel: [self cpuPanel]]; }
- (IBAction) showMouseInspectorPanel:	(id)sender	{ [self setCurrentPanel: [self mousePanel]]; }
- (IBAction) showDriveInspectorPanel:	(id)sender	{ [self setCurrentPanel: [self drivePanel]]; }
- (IBAction) selectInspectorPanel:		(NSSegmentedControl *)sender
{
	NSInteger selectorIndex = [[sender cell] tagForSegment: [sender selectedSegment]];
	[self setCurrentPanel: [[self panels] objectAtIndex: selectorIndex]];
	
	//Record the user's choice in the user defaults
	//Note: we do this here rather than in setCurrentPanel: because the latter is often called programmatically
	//and we only want to persist actual choices, not states.
	[[NSUserDefaults standardUserDefaults] setInteger: selectorIndex forKey: @"initialInspectorPanelIndex"];
}

@end
