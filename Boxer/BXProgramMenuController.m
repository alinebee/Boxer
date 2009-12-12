/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXProgramMenuController.h"
#import "BXValueTransformers.h"
#import "BXSession+BXFileManager.h"
#import "BXEmulator.h"

@implementation BXProgramMenuController
@synthesize programSelector;

- (BXSession *) session	{ return [BXSession mainSession]; }

- (void) awakeFromNib
{
	[self syncMenuItems];	
	[[NSApp delegate] addObserver: self forKeyPath: @"currentSession.executables" options: 0 context: nil];
	[[NSApp delegate] addObserver: self forKeyPath: @"currentSession.gamePackage.targetPath" options: 0 context: nil];
}

- (void) dealloc
{
	[[NSApp delegate] removeObserver: self forKeyPath: @"currentSession.executables"];
	[[NSApp delegate] removeObserver: self forKeyPath: @"currentSession.gamePackage.targetPath"];
	[super dealloc];
}

//Whenever the session's executables change, repopulate our selector
- (void)observeValueForKeyPath: (NSString *)keyPath
					  ofObject: (id)object
						change: (NSDictionary *)change
					   context: (void *)context
{
	if		([keyPath isEqualToString: @"currentSession.executables"])				[self syncMenuItems];
	else if ([keyPath isEqualToString: @"currentSession.gamePackage.targetPath"])	[self syncSelection];
}

- (void) syncMenuItems
{
	[self willChangeValueForKey: @"hasItems"];
	
	NSMenu *menu = [programSelector menu];
	[(id)menu removeAllItems];
	for (NSMenuItem *item in [self programMenuItems]) [menu addItem: item];
		
	[self didChangeValueForKey: @"hasItems"];
	
	[self syncSelection];
}

- (void) syncSelection
{
	NSMenu *menu = [programSelector menu];
	NSString *targetPath = [[[self session] gamePackage] targetPath];
	[programSelector selectItemAtIndex: [menu indexOfItemWithRepresentedObject: targetPath]];
}

- (BOOL) hasItems
{
	return [[[self session] executables] count] > 0;
}

- (NSArray *) programMenuItems
{
	NSArray *executables = [[self session] executables];
	NSMutableArray *items	= [NSMutableArray arrayWithCapacity: [executables count]];
	
	if ([executables count])
	{
		NSMenuItem *noneItem	= [[NSMenuItem new] autorelease];
		[noneItem setTitle: NSLocalizedString(@"None", @"None option for default program selector.")];
		[items addObject: noneItem];
		
		BXDOSFilenameTransformer *DOSName = [[BXDOSFilenameTransformer new] autorelease];
		
		for (NSDictionary *data in executables)
		{
			NSMenuItem *item = [[NSMenuItem new] autorelease];
			NSString *path	= [data objectForKey: @"path"];
			NSImage *icon	= [data objectForKey: @"icon"];
			[icon setSize: NSMakeSize(16, 16)];
			
			[item setRepresentedObject: path];
			[item setImage: icon];
			[item setTitle: [DOSName transformedValue: [item representedObject]]];
			
			[items addObject: item];
		}
	}
	
	return (NSArray *)items;
}

- (IBAction) changeDefaultProgram: (id)sender
{
	NSString *selectedPath = [[sender selectedItem] representedObject];
	[[[self session] gamePackage] setTargetPath: selectedPath];
}

- (IBAction) launchDefaultProgram: (id)sender
{
	NSString *filePath = [[[self programSelector] selectedItem] representedObject];
	[[self session] openFileAtPath: filePath];
}

- (BOOL) validateUserInterfaceItem: (id)theItem
{
	if ([theItem action] == @selector(launchDefaultProgram:))
	{
		BXEmulator *emulator = [[self session] emulator];
		NSString *filePath = [[[self programSelector] selectedItem] representedObject];
		return filePath && [emulator isExecuting] && ![emulator isRunningProcess];
	}
	return YES;
}
@end