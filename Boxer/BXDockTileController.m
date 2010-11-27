/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */



#import "BXDockTileController.h"
#import "BXAppController.h"
#import "BXSession.h"

@implementation BXDockTileController

- (void) awakeFromNib
{
	//Listen for changes to the current session's represented icon
	[[NSApp delegate] addObserver: self
					   forKeyPath: @"currentSession.representedIcon"
						  options: NSKeyValueObservingOptionInitial
						  context: nil];
}

- (void) dealloc
{
	[[NSApp delegate] removeObserver: self forKeyPath: @"currentSession.representedIcon"];
	[super dealloc];
}

//Whenever the represented icon changes, force a redraw of our icon view
- (void) observeValueForKeyPath: (NSString *)keyPath
					   ofObject: (id)object
						 change: (NSDictionary *)change
						context: (void *)context
{	
	if ([keyPath isEqualToString: @"currentSession.representedIcon"]) [self syncIconWithActiveSession];
}

- (void) syncIconWithActiveSession
{
	BXSession *session = [[NSApp delegate] currentSession];
	NSImage *icon = [[session representedIcon] copy];
	if (!icon && [session gamePackage])
	{
		//If the session didn't have an icon of its own, generate a bootleg one based on the gamebox
		icon = [BXSession bootlegCoverArtForGamePackage: [session gamePackage] withEra: BXUnknownEra];
	}
	[icon setSize: NSMakeSize(128, 128)];
	[NSApp setApplicationIconImage: icon];
	[icon release];
}
@end
