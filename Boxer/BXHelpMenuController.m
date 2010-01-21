/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHelpMenuController.h"
#import "BXSession.h"
#import "BXAppController.h"

@implementation BXHelpMenuController

- (NSString *)mobygamesMenuTitle
{
	BXSession *session = [BXSession mainSession];
	
	if ([session isGamePackage])
	{
		NSString *format = NSLocalizedString(	@"Find %@ at Mobygames",
												@"Help menu item for searching Mobygames: %@ is the display name of the current DOS session.");
		return [NSString stringWithFormat: format, [session displayName], nil];
	}
	else
	{
		return NSLocalizedString(@"Mobygames Website", @"Help menu item for Mobygames website.");
	}
}

- (NSString *)replacementDocsMenuTitle
{
	BXSession *session = [BXSession mainSession];
	
	if ([session isGamePackage])
	{
		NSString *format = NSLocalizedString(	@"Find %@ at ReplacementDocs",
												@"Help menu item for searching ReplacementDocs: %@ is the display name of the current DOS session.");
		return [NSString stringWithFormat: format, [session displayName], nil];
	}
	else
	{
		return NSLocalizedString(@"ReplacementDocs Website", @"Help menu item for ReplacementDocs website.");
	}
}

- (IBAction) showHelp: (id)sender
{
	[[NSApp delegate] openURLFromKey: @"HelpURL"];
}

- (IBAction) showGameAtMobygames: (id)sender
{
	BXSession *session = [BXSession mainSession];
	
	if ([session isGamePackage])
	{
		NSString *search = [session displayName];
		[[NSApp delegate] searchURLFromKey: @"MobygamesSearchURL" withSearchString: search];
	}
	else
	{
		[[NSApp delegate] openURLFromKey: @"MobygamesURL"];
	}
}

- (IBAction) showGameAtReplacementDocs:	(id)sender
{
	BXSession *session = [BXSession mainSession];

	if ([session isGamePackage])
	{
		NSString *search = [session displayName];
		[[NSApp delegate] searchURLFromKey: @"ReplacementDocsSearchURL" withSearchString: search];
	}
	else
	{
		[[NSApp delegate] openURLFromKey: @"ReplacementDocsURL"];	
	}
}




//Populates the application Help menu with the current session's documentation files,
//and set menu item titles appropriately
- (void) menuNeedsUpdate: (NSMenu *) menu
{
	[replacementDocsItem setTitle:	[self replacementDocsMenuTitle]];
	[mobygamesItem setTitle:		[self mobygamesMenuTitle]];

	if (!populated)
	{
		NSArray *docs = [self documentation];
		if ([docs count] > 0)
		{
			NSString *heading = [NSString stringWithFormat:	NSLocalizedString(
									@"%@ Documentation:",
									@"Heading for game documentation in help menu. %@ is the display name of the current DOS session."),
									[docSession displayName], nil]; 
			
			[menu addItem: [NSMenuItem separatorItem]];
			[menu addItemWithTitle: heading action: nil keyEquivalent: @""];
			
			for (NSDictionary *document in docs) [self addItemForDocument: document toMenu: menu];
		}
		populated = YES;
	}
}

- (NSMenuItem *) addItemForDocument: (NSDictionary *)document toMenu: (NSMenu *)menu
{
	SEL itemAction	= @selector(openInDefaultApplication:);	//implemented by BXAppController
	NSSize iconSize	= NSMakeSize(16, 16);

	NSFileManager *manager	= [NSFileManager defaultManager];
	
	NSString *itemPath	= [document objectForKey: @"path"];
	NSString *itemTitle	= [manager displayNameAtPath: itemPath];
	NSImage *itemIcon	= [document objectForKey: @"icon"];
	
	NSMenuItem *newItem = [menu	addItemWithTitle: itemTitle
								action: itemAction
								keyEquivalent: @""];
	
	[newItem setRepresentedObject: document];

	[itemIcon setSize: iconSize];
	[newItem setImage: itemIcon];
	
	return newItem;
}

+ (NSArray *) sortCriteria
{
	//Sort docs by extension then by filename, to group similar items together
	NSSortDescriptor *sortByType, *sortByName;
	SEL comparison = @selector(caseInsensitiveCompare:);
	sortByType	= [[NSSortDescriptor alloc]	initWithKey: @"path.pathExtension"
											ascending: YES
											selector: comparison];
	sortByName	= [[NSSortDescriptor alloc]	initWithKey: @"path.lastPathComponent"
											ascending: YES
											selector: comparison];
	
	NSArray *sortDescriptors = [NSArray arrayWithObjects: sortByType, sortByName, nil];
	[sortByType release], [sortByName release];
	return sortDescriptors;
}

- (void) setDocumentation: (NSArray *)newDocumentation
{
	if (documentation != newDocumentation)
	{
		[documentation autorelease];
		documentation	= [newDocumentation retain];
		docSession		= [BXSession mainSession];
	}
}

- (NSArray *) documentation
{
	BXSession *session = [BXSession mainSession];
	
	//invalidate the documentation if the session has changed
	if (documentation && docSession != session) [self setDocumentation: nil];
	if (!documentation)
	{
		NSArray *docs = [session documentation];
		if ([docs count] > 0) docs = [docs sortedArrayUsingDescriptors: [[self class] sortCriteria]];

		[self setDocumentation: docs];
	}
	return documentation;
}

- (void) dealloc
{
	[self setDocumentation: nil], [documentation release];
	docSession = nil;
	[super dealloc];
}

@end