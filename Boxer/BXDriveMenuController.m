/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXDriveMenuController.h"
#import "BXSession+BXFileManager.h"
#import "BXDrive.h"

@implementation BXDriveMenuController
@synthesize startPoint, endPoint;

- (void) menuNeedsUpdate: (NSMenu *) menu
{
	BXSession *session = [BXSession mainSession];
	NSArray *drives = [session drives];
	NSMenuItem *driveItem;
	
	BOOL showBoundary = NO;
	
	//First, remove all menu items up between our start and end points
	NSInteger startIndex = [menu indexOfItem: [self startPoint]] + 1;
	
	while (driveItem = [menu itemAtIndex: startIndex])
	{
		if ([self endPoint] == driveItem) break;
		[menu removeItemAtIndex: startIndex];
	}
	
	//Repopulate the menu, inserting new items between the start and end points
	for (BXDrive *drive in drives)
	{
		driveItem = [self itemForDrive: drive];
		[menu insertItem: driveItem atIndex: startIndex++];
		showBoundary = YES;
	}
	[[self endPoint] setHidden: !showBoundary];
}

- (NSMenuItem *) itemForDrive: (BXDrive *)drive
{
	SEL itemAction	= @selector(revealInFinder:);	//implemented by BXAppController
	NSSize iconSize	= NSMakeSize(16, 16);
	NSUInteger maxComponents = 2;	//The maximum number of components to show in the file path
	
	NSFileManager *manager	= [NSFileManager defaultManager];

	NSImage	*itemIcon = [drive icon];
	[itemIcon setSize: iconSize];
	
	NSArray *displayComponents	= [manager componentsToDisplayForPath: [drive path]];
	NSUInteger numComponents	= [displayComponents count];
	if (numComponents > maxComponents)
		displayComponents = [displayComponents subarrayWithRange: NSMakeRange(numComponents - maxComponents, maxComponents)];
	
	NSString *displayPath = [displayComponents componentsJoinedByString: @" ▸ "];
	
	NSString *title = [NSString stringWithFormat: @"%@:  %@", [drive letter], displayPath, nil];
	
	NSMenuItem *item = [[NSMenuItem new] autorelease];
	[item setAction: itemAction];
	[item setTitle: title];
	[item setRepresentedObject: drive]; 
	[item setImage: itemIcon];	
	
	return item;
}

- (void) dealloc
{
	[self setStartPoint: nil],	[startPoint release];
	[self setEndPoint: nil],	[endPoint release];
	[super dealloc];
}

@end