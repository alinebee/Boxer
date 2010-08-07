/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXImport.h"
#import "BXImport+BXImportPolicies.h"
#import "BXImportWindowController.h"
#import "NSWorkspace+BXFileTypes.h"
#import "BXAppController.h"

@implementation BXImport
@synthesize importWindowController;
@synthesize sourcePath;

#pragma mark -
#pragma mark Initialization and deallocation

- (void) dealloc
{
	[self setSourcePath: nil],		[sourcePath release];
	[self setImportWindowController: nil],	[importWindowController release];
	[super dealloc];
}

- (void) makeWindowControllers
{
	[super makeWindowControllers];
	BXImportWindowController *controller = [[BXImportWindowController alloc] initWithWindowNibName: @"ImportWindow"];
	
	[self addWindowController:			controller];
	[self setImportWindowController:	controller];
	[controller setShouldCloseDocument: YES];
	
	[controller release];
}


- (void) showWindows
{
	//Unlike BXSession, we do not display the DOS window nor launch the emulator
	//when this is called. Instead, we start off with the import window.
	[[self importWindowController] showWindow: self];
}

//We don't want to close the entire document after the emulated session is finished;
//we want to carry on and complete the installation process
- (BOOL) closeOnEmulatorExit { return NO; }


#pragma mark -
#pragma mark Fun installation time

+ (NSSet *)acceptedSourceTypes
{
	static NSSet *acceptedTypes = nil;
	if (!acceptedTypes)
	{
		acceptedTypes = [[BXAppController mountableTypes] retain];
	}
	return acceptedTypes;
}

- (BOOL) canImportFromSourcePath: (NSString *)path
{
	return [[NSWorkspace sharedWorkspace] file: path matchesTypes: [[self class] acceptedSourceTypes]];
}

- (NSArray *)installerPaths
{
	return [[self class] installersAtPath: [self sourcePath] recurse: YES];
}

@end