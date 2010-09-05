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
@synthesize panelSelector;

+ (void) initialize
{
	NSArray *sensitivityThresholds = [NSArray arrayWithObjects:
									  [NSNumber numberWithFloat: 1.0f / BXMouseSensitivityRange],
									  [NSNumber numberWithFloat: 1.0f],
									  [NSNumber numberWithFloat: 1.0f * BXMouseSensitivityRange],
									  nil];
	
	BXBandedValueTransformer *mouseSensitivity = [[BXBandedValueTransformer alloc] initWithThresholds: sensitivityThresholds];
	
	[NSValueTransformer setValueTransformer: mouseSensitivity forName: @"BXMouseSensitivitySlider"];
	
	[mouseSensitivity release];
}

+ (BXInspectorController *)controller
{
	static BXInspectorController *singleton = nil;
	if (!singleton) singleton = [[self alloc] initWithWindowNibName: @"InspectorPanel"];
	return singleton;
}

- (void) dealloc
{
	[self setPanelSelector: nil], [panelSelector release];
	
	[super dealloc];
}

- (void) awakeFromNib
{
	[super awakeFromNib];

	[(NSPanel *)[self window] setBecomesKeyOnlyIfNeeded: YES];
	[[self window] setFrameAutosaveName: @"InspectorPanel"];
	
	//Set the initial panel based on the user's last chosen panel (defaulting to the CPU panel)
	NSInteger selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey: @"initialInspectorPanelIndex"];
	
	if (selectedIndex < [[self tabView] numberOfTabViewItems])
	{
		[[self tabView] selectTabViewItemAtIndex: selectedIndex];
	}
	
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
		BXSession *session = [[NSApp delegate] currentSession];
		
		//Disable the gamebox tab if the current session is not a gamebox
		
		//Find the panel selector segment whose tag corresponds to the game inspector panel
		//(This charade is necessary because NSSegmentedControl has an awful interface)
		NSInteger i;
		for (i = 0; i < [[self panelSelector] segmentCount]; i++)
		{
			if ([[[self panelSelector] cell] tagForSegment: i] == BXGameInspectorPanelTag)
				[[self panelSelector] setEnabled: [session isGamePackage] forSegment: i];
		}
		
		//If the gamebox tab was already selected, then switch to the next tab
		if (![session isGamePackage] &&
			[[self tabView] indexOfTabViewItem: [[self tabView] selectedTabViewItem]] == BXGameInspectorPanelTag)
		{
			[[self tabView] selectTabViewItemAtIndex: BXCPUInspectorPanelTag];
		}
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


#pragma mark -
#pragma mark Tab selection

- (IBAction) showGameInspectorPanel: (id)sender		{ [[self tabView] selectTabViewItemAtIndex: BXGameInspectorPanelTag]; }
- (IBAction) showCPUInspectorPanel: (id)sender		{ [[self tabView] selectTabViewItemAtIndex: BXCPUInspectorPanelTag]; }
- (IBAction) showMouseInspectorPanel: (id)sender	{ [[self tabView] selectTabViewItemAtIndex: BXMouseInspectorPanelTag]; }
- (IBAction) showDriveInspectorPanel: (id)sender	{ [[self tabView] selectTabViewItemAtIndex: BXDriveInspectorPanelTag]; }

- (void) tabView: (NSTabView *)tabView didSelectTabViewItem: (NSTabViewItem *)tabViewItem
{
	//Record the user's choice of tab, and synchronize the selected segment
	NSInteger selectedIndex = [tabView indexOfTabViewItem: tabViewItem];
	
	if (selectedIndex != NSNotFound)
	{
		[[NSUserDefaults standardUserDefaults] setInteger: selectedIndex
												   forKey: @"initialInspectorPanelIndex"];
		
		[[self panelSelector] selectSegmentWithTag: selectedIndex];
	}
}

- (BOOL) tabView: (NSTabView *)tabView shouldSelectTabViewItem: (NSTabViewItem *)tabViewItem
{
	return ([tabView indexOfTabViewItem: tabViewItem] != BXGameInspectorPanelTag ||
			[[[NSApp delegate] currentSession] isGamePackage]);
}

@end
