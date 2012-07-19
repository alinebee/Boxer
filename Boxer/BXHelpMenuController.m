/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHelpMenuController.h"
#import "BXSession.h"
#import "BXBaseAppController.h"

@implementation BXHelpMenuController
@synthesize mobygamesItem = _mobygamesItem;
@synthesize replacementDocsItem = _replacementDocsItem;
@synthesize documentationDivider = _documentationDivider;

- (NSString *)mobygamesMenuTitle
{
	BXSession *session = [[NSApp delegate] currentSession];
	
	if (session.isGamePackage)
	{
		NSString *format = NSLocalizedString(@"Find %@ at Mobygames",
											 @"Help menu item for searching Mobygames: %@ is the display name of the current DOS session.");
		return [NSString stringWithFormat: format, session.displayName];
	}
	else
	{
		return NSLocalizedString(@"Mobygames Website", @"Help menu item for Mobygames website.");
	}
}

- (NSString *)replacementDocsMenuTitle
{
	BXSession *session = [[NSApp delegate] currentSession];
	
	if ([session isGamePackage])
	{
		NSString *format = NSLocalizedString(@"Find %@ at ReplacementDocs",
											 @"Help menu item for searching ReplacementDocs: %@ is the display name of the current DOS session.");
		return [NSString stringWithFormat: format, session.displayName];
	}
	else
	{
		return NSLocalizedString(@"ReplacementDocs Website", @"Help menu item for ReplacementDocs website.");
	}
}

- (IBAction) showHelp: (id)sender
{
	[NSApp showHelp: sender];
}

- (IBAction) showGameAtMobygames: (id)sender
{
	BXSession *session = [[NSApp delegate] currentSession];
	
	if (session.isGamePackage)
	{
		NSString *search = session.displayName;
		[[NSApp delegate] searchURLFromKey: @"MobygamesSearchURL" withSearchString: search];
	}
	else
	{
		[[NSApp delegate] openURLFromKey: @"MobygamesURL"];
	}
}

- (IBAction) showGameAtReplacementDocs:	(id)sender
{
	BXSession *session = [[NSApp delegate] currentSession];

	if (session.isGamePackage)
	{
		NSString *search = session.displayName;
		[[NSApp delegate] searchURLFromKey: @"ReplacementDocsSearchURL" withSearchString: search];
	}
	else
	{
		[[NSApp delegate] openURLFromKey: @"ReplacementDocsURL"];	
	}
}


//Populates the application Help menu with the current session's documentation files,
//and set menu item titles appropriately
- (void) menuNeedsUpdate: (NSMenu *)menu
{
	self.replacementDocsItem.title = self.replacementDocsMenuTitle;
	self.mobygamesItem.title = self.mobygamesMenuTitle;
    
    //If the current session has changed, reconstruct the list of documentation from that of the new session.
    BXSession *session = [[NSApp delegate] currentSession];
	if (_sessionForDisplayedDocs != session)
	{
        NSArray *docs = [session.documentation sortedArrayUsingDescriptors: [self.class sortCriteria]];

        NSInteger insertionPoint = [menu indexOfItem: self.documentationDivider];
        
        //Clear out all menu items after the insertion point,
        //then reconstruct them for the new session.
        while (menu.numberOfItems > insertionPoint + 1)
            [menu removeItemAtIndex: insertionPoint + 1];
        
		if (docs.count > 0)
		{
			NSString *format = NSLocalizedString(@"%@ Documentation:",
												 @"Heading for game documentation in help menu. %@ is the display name of the current DOS session.");
			NSString *heading = [NSString stringWithFormat:	format, session.displayName]; 
			
            [self.documentationDivider setHidden: NO];
			[menu addItemWithTitle: heading action: nil keyEquivalent: @""];
			
			for (NSDictionary *document in docs)
                [self addItemForDocument: document toMenu: menu];
		}
        else
        {
            [self.documentationDivider setHidden: YES];
        }
		_sessionForDisplayedDocs = session;
	}
}

- (NSMenuItem *) addItemForDocument: (NSDictionary *)document toMenu: (NSMenu *)menu
{
	SEL itemAction	= @selector(openInDefaultApplication:);	//implemented by BXAppController
	NSSize iconSize	= NSMakeSize(16, 16);

	NSFileManager *manager	= [NSFileManager defaultManager];
	
	NSImage *itemIcon	= [document objectForKey: @"icon"];
	NSString *itemPath	= [document objectForKey: @"path"];
	NSString *itemTitle	= [manager displayNameAtPath: itemPath];
	
	NSMenuItem *newItem = [menu	addItemWithTitle: itemTitle
										  action: itemAction
								   keyEquivalent: @""];
	
	newItem.representedObject = document;
    
    itemIcon = [itemIcon copy];
	itemIcon.size = iconSize;
	newItem.image = [itemIcon autorelease];
    
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

- (void) dealloc
{
    self.mobygamesItem = nil;
    self.replacementDocsItem = nil;
    self.documentationDivider = nil;
    
	[super dealloc];
}

@end
