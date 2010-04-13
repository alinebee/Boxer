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
@synthesize programSelector, sessionMediator;

- (BXSession *) session
{
	return [[self sessionMediator] content];
}

- (void) dealloc
{
	[self setSessionMediator: nil]; [sessionMediator release];
	[self setProgramSelector: nil]; [programSelector release];
	[super dealloc];
}

- (void) setSessionMediator: (NSObjectController *)mediator
{
	[self willChangeValueForKey: @"sessionMediator"];
	
	NSObjectController *oldMediator = [self sessionMediator];
	if (mediator != oldMediator)
	{
		NSArray *observePaths = [NSArray arrayWithObjects:
			@"content.executables",
			@"content.gamePackage.targetPath",
		nil];
		
		for (NSString *path in observePaths)
			[oldMediator removeObserver: self forKeyPath: path];
	
		[oldMediator autorelease];
		sessionMediator = [mediator retain];
	
		for (NSString *path in observePaths)
			[mediator addObserver: self forKeyPath: path options: NSKeyValueObservingOptionInitial context: nil];
	}

	[self didChangeValueForKey: @"sessionMediator"];	
}

//Whenever the session's executables or targets change, repopulate our selector with the new values
- (void)observeValueForKeyPath: (NSString *)keyPath
					  ofObject: (id)object
						change: (NSDictionary *)change
					   context: (void *)context
{
	if		([keyPath isEqualToString: @"content.executables"])				[self syncMenuItems];
	else if ([keyPath isEqualToString: @"content.gamePackage.targetPath"])	[self syncSelection];
}

- (void) syncMenuItems
{
	NSMenu *menu = [[self programSelector] menu];
	NSUInteger count = [menu numberOfItems];
	NSRange programItemRange = NSMakeRange(1, count-3);

	//Remove all the original program options...
	for (NSMenuItem *oldItem in [[menu itemArray] subarrayWithRange: programItemRange])
		[menu removeItem: oldItem];
	
	
	//...and then add all the new ones in their place
	NSUInteger insertionPoint = 1;
	for (NSMenuItem *newItem in [self programMenuItems])
	{
		[menu insertItem: newItem atIndex: insertionPoint];
		insertionPoint++;
	}
	
	[self syncSelection];
}

- (void) syncSelection
{
	NSMenu *menu = [[self programSelector] menu];
	NSString *targetPath = [[[self session] gamePackage] targetPath];
	NSUInteger index = (targetPath == nil) ? 0 : [menu indexOfItemWithRepresentedObject: targetPath];
	[programSelector selectItemAtIndex: index];
}

- (NSArray *) programMenuItems
{
	NSArray *executables	= [[self session] executables];
	NSMutableArray *items	= [NSMutableArray arrayWithCapacity: [executables count]];
		
	if ([executables count])
	{
		BXDOSFilenameTransformer *DOSName = [[BXDOSFilenameTransformer new] autorelease];
		
		NSAutoreleasePool *pool = [NSAutoreleasePool new];
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
		[pool drain];
	}
	
	return items;
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

- (IBAction) showProgramChooserPanel: (id)sender
{
	//Resync the selected item back to what it should be, since choosing the menu item that triggered this will have changed it
	//TODO: see about fixing that upstream, since resyncing it results in an annoying flicker
	[self syncSelection];
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