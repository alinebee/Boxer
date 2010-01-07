/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXPreferencesController.h"
#import "BXSession.h"


@implementation BXPreferencesController

+ (BXPreferencesController *) controller
{
	static BXPreferencesController *singleton = nil;
	
	if (!singleton) singleton = [[self alloc] initWithWindowNibName: @"Preferences"];
	return singleton;
}

- (void) awakeFromNib
{
	//Bind to the filter preference so that we can synchronise our filter selection controls when it changes
	[[NSUserDefaults standardUserDefaults] addObserver: self forKeyPath: @"filterType" options: NSKeyValueObservingOptionInitial context: nil];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{
	//Whenever the key path changes, synchronise our filter selection controls
	if ([object isEqualTo: [NSUserDefaults standardUserDefaults]]
		&& [keyPath isEqualToString: @"filterType"])
	{
		[self syncFilterControls];
	}
}

- (IBAction) toggleFilterType: (id)sender
{
	BXSession *session = [BXSession mainSession];
	
	if (session && [session mainWindowController])
	{
		//If there's an active session, then let it handle the toggling
		[[session mainWindowController] toggleFilterType: sender];
	}
	else
	{
		//Otherwise then do the work by hand
		NSInteger filterType = [sender tag];
		[[NSUserDefaults standardUserDefaults] setInteger: filterType forKey: @"filterType"];
	}

}

- (void) syncFilterControls
{
	NSInteger defaultFilter = [[NSUserDefaults standardUserDefaults] integerForKey: @"filterType"];

	for (id view in [filterGallery subviews])
	{
		if ([view isKindOfClass: [NSButton class]])
		{
			[view setState: [view tag] == defaultFilter];
		}
	}
}
@end