/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXWelcomeWindowController.h"
#import "BXAppController.h"
#import "BXValueTransformers.h"


//The height of the bottom window border.
//TODO: determine this from NIB content.
#define BXWelcomeWindowBorderThickness 40.0f

#define BXDocumentStartTag 1
#define BXDocumentEndTag 2

@implementation BXWelcomeWindowController
@synthesize recentDocumentsButton;

#pragma mark -
#pragma mark Initialization and deallocation

+ (void) initialize
{
	BXImageSizeTransformer *welcomeButtonImageSize = [[BXImageSizeTransformer alloc] initWithSize: NSMakeSize(128, 128)];
	[NSValueTransformer setValueTransformer: welcomeButtonImageSize forName: @"BXWelcomeButtonImageSize"];
	[welcomeButtonImageSize release];
}

+ (id) controller
{
	static id singleton = nil;
	
	if (!singleton) singleton = [[self alloc] initWithWindowNibName: @"Welcome"];
	return singleton;
}

- (void) dealloc
{
	[self setRecentDocumentsButton: nil], [recentDocumentsButton release];
	[super dealloc];
}

- (void) windowDidLoad
{
	[[self window] setContentBorderThickness: BXWelcomeWindowBorderThickness + 1 forEdge: NSMinYEdge];
}

#pragma mark -
#pragma mark UI actions

- (IBAction) openRecentDocument: (NSMenuItem *)sender
{
	NSURL *url = [sender representedObject];
	
	[[NSApp delegate] openDocumentWithContentsOfURL: url display: YES error: NULL];
}


#pragma mark -
#pragma mark Open Recent menu

- (void) menuWillOpen: (NSMenu *)menu
{
	NSArray *documents = [[NSApp delegate] recentDocumentURLs];
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	NSFileManager *manager = [NSFileManager defaultManager];
	
	//Delete all document items
	NSUInteger startOfDocuments	= [menu indexOfItemWithTag: BXDocumentStartTag] + 1;
	NSUInteger endOfDocuments	= [menu indexOfItemWithTag: BXDocumentEndTag];
	NSRange documentRange		= NSMakeRange(startOfDocuments, endOfDocuments - startOfDocuments);

	for (NSMenuItem *oldItem in [[menu itemArray] subarrayWithRange: documentRange])
		[menu removeItem: oldItem];
	
	//Then, repopulate it with the recent documents
	NSUInteger insertionPoint = startOfDocuments;
	for (NSURL *url in documents)
	{
		NSAutoreleasePool *pool	= [[NSAutoreleasePool alloc] init];
		NSMenuItem *item		= [[NSMenuItem alloc] init];
		
		[item setRepresentedObject: url];
		[item setTarget: self];
		[item setAction: @selector(openRecentDocument:)];
		
		NSString *path	= [url path];
		NSImage *icon	= [workspace iconForFile: path];
		NSString *title	= [manager displayNameAtPath: path];
		
		[icon setSize: NSMakeSize(16, 16)];
		[item setImage: icon];
		[item setTitle: title];
		
		[menu insertItem: item atIndex: insertionPoint++];
		
		[item release];
		[pool drain];
	}
	//Finish off the list with a separator
	if ([documents count])
		[menu insertItem: [NSMenuItem separatorItem] atIndex: insertionPoint];
}

@end