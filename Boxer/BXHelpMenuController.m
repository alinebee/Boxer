/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHelpMenuController.h"
#import "BXSession.h"
#import "BXBaseAppController.h"

@interface BXHelpMenuController ()

//Used internally to populate the help menu with items for the paths in BXHelpMenuController documentation.
- (void) _populateMenu: (NSMenu *)menu withDocumentationFromSession: (BXSession *)session;
- (NSMenuItem *) _insertItemForDocument: (NSDictionary *)docPath
                                 toMenu: (NSMenu *)menu
                                atIndex: (NSUInteger)index;

- (void) _populateMenu: (NSMenu *)menu withHelpLinks: (NSArray *)links;
- (NSMenuItem *) _insertItemForLink: (NSDictionary *)linkInfo
                             toMenu: (NSMenu *)menu
                            atIndex: (NSUInteger)index;

@end


@implementation BXHelpMenuController
@synthesize mobygamesItem = _mobygamesItem;
@synthesize replacementDocsItem = _replacementDocsItem;
@synthesize documentationDivider = _documentationDivider;
@synthesize helpLinksDivider = _helpLinksDivider;

- (void) awakeFromNib
{
    [[NSApp delegate] addObserver: self
                       forKeyPath: @"currentSession.documentation"
                          options: 0
                          context: nil];
    
    _needsHelpLinksRefresh = YES;
    _needsSessionDocsRefresh = YES;
}

- (void) dealloc
{
    [[NSApp delegate] removeObserver: self forKeyPath: @"currentSession.documentation"];
    
    self.mobygamesItem = nil;
    self.replacementDocsItem = nil;
    self.documentationDivider = nil;
    self.helpLinksDivider = nil;
    
    [super dealloc];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    //Regenerate the documentation whenever it or the current session changes
    if ([keyPath isEqualToString: @"currentSession.documentation"])
    {
        _needsSessionDocsRefresh = YES;
    }
}


#pragma mark -
#pragma mark Menu actions

- (IBAction) showHelp: (id)sender
{
	[NSApp showHelp: sender];
}

- (IBAction) showGameAtMobygames: (id)sender
{
	BXSession *session = [[NSApp delegate] currentSession];
	
	if (session.hasGamebox)
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

	if (session.hasGamebox)
	{
		NSString *search = session.displayName;
		[[NSApp delegate] searchURLFromKey: @"ReplacementDocsSearchURL" withSearchString: search];
	}
	else
	{
		[[NSApp delegate] openURLFromKey: @"ReplacementDocsURL"];	
	}
}

- (IBAction) openLinkFromMenuItem: (NSMenuItem *)sender
{
    NSURL *url = sender.representedObject;
	if (url)
        [[NSWorkspace sharedWorkspace] openURL: url];
}

- (IBAction) openDocumentFromMenuItem: (NSMenuItem *)sender
{
    NSString *documentPath = sender.representedObject;
	if (documentPath)
        [[NSWorkspace sharedWorkspace] openFile: documentPath
                                withApplication: nil
                                  andDeactivate: YES];
}


#pragma mark -
#pragma mark Populating the menu

- (NSString *)mobygamesMenuTitle
{
	BXSession *session = [[NSApp delegate] currentSession];
	
	if (session.hasGamebox)
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
	
	if (session.hasGamebox)
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


//Populates the application Help menu with the current session's documentation files,
//and set menu item titles appropriately
- (void) menuNeedsUpdate: (NSMenu *)menu
{
    //Couldn't we update these more easily with bindings?
	self.replacementDocsItem.title = self.replacementDocsMenuTitle;
	self.mobygamesItem.title = self.mobygamesMenuTitle;
    
    //If the current session or its documentation have changed,
    //reconstruct the documentation list.
	if (_needsSessionDocsRefresh && self.documentationDivider)
	{
        [self _populateMenu: menu withDocumentationFromSession: [[NSApp delegate] currentSession]];
		_needsSessionDocsRefresh = NO;
	}
    
    if (_needsHelpLinksRefresh && self.helpLinksDivider)
    {
        NSArray *helpLinks = [[NSBundle mainBundle] objectForInfoDictionaryKey: @"BXHelpLinks"];
        [self _populateMenu: menu withHelpLinks: helpLinks];
        _needsHelpLinksRefresh = NO;
    }
}

- (void) _populateMenu: (NSMenu *)menu withHelpLinks: (NSArray *)links
{
    NSInteger insertionPoint = [menu indexOfItem: self.helpLinksDivider];
    
    for (NSDictionary *linkInfo in links)
    {
        insertionPoint++;
        [self _insertItemForLink: linkInfo toMenu: menu atIndex: insertionPoint];
    }
    
    //Only show the divider if we have any links in the list.
    self.helpLinksDivider.hidden = (links.count == 0);
}

- (void) _populateMenu: (NSMenu *)menu withDocumentationFromSession: (BXSession *)session
{
    NSInteger insertionPoint = [menu indexOfItem: self.documentationDivider];
    
    //Clear out all menu items after the insertion point,
    //then reconstruct them from the new documentation list.
    while (menu.numberOfItems > insertionPoint + 1)
        [menu removeItemAtIndex: insertionPoint + 1];
    
    NSArray *documentation = session.documentation;
    if (documentation.count > 0)
    {
        NSArray *sortedDocs = [documentation sortedArrayUsingDescriptors: [self.class sortCriteria]];
        NSString *heading;
        
        if ([[NSApp delegate] isStandaloneGameBundle])
        {
            heading = NSLocalizedString(@"Game Documentation:",
                                        @"Heading for game documentation in help menu for standalone game bundles.");
        }
        else
        {
            NSString *format = NSLocalizedString(@"%@ Documentation:",
                                                 @"Heading for game documentation in help menu. %@ is the display name of the current DOS session.");
            
            heading = [NSString stringWithFormat: format, session.displayName];
        }
        
        self.documentationDivider.hidden = NO;
        insertionPoint++;
        [menu insertItemWithTitle: heading action: nil keyEquivalent: @"" atIndex: insertionPoint];
        
        for (NSDictionary *document in sortedDocs)
        {
            insertionPoint++;
            [self _insertItemForDocument: document toMenu: menu atIndex: insertionPoint];
        }
    }
    else
    {
        [self.documentationDivider setHidden: YES];
    }
}


- (NSMenuItem *) _insertItemForLink: (NSDictionary *)linkInfo toMenu: (NSMenu *)menu atIndex: (NSUInteger)index
{
    SEL itemAction = @selector(openLinkFromMenuItem:);
    
    NSString *itemTitle = [linkInfo objectForKey: @"BXHelpLinkTitle"];
    NSURL *itemURL = [NSURL URLWithString: [linkInfo objectForKey: @"BXHelpLinkURL"]];
    
    NSMenuItem *newItem = [menu insertItemWithTitle: itemTitle
                                             action: itemAction
                                      keyEquivalent: @""
                                            atIndex: index];
    
    newItem.target = self;
    newItem.representedObject = itemURL;
    
    return newItem;
}

- (NSMenuItem *) _insertItemForDocument: (NSDictionary *)documentInfo toMenu: (NSMenu *)menu atIndex: (NSUInteger)index
{
	SEL itemAction	= @selector(openDocumentFromMenuItem:);	//implemented by BXAppController
	NSSize iconSize	= NSMakeSize(16, 16);

	NSFileManager *manager	= [NSFileManager defaultManager];
	
	NSImage *itemIcon	= [documentInfo objectForKey: @"icon"];
	NSString *itemPath	= [documentInfo objectForKey: @"path"];
	NSString *itemTitle	= [manager displayNameAtPath: itemPath];
	
	NSMenuItem *newItem = [menu	insertItemWithTitle: itemTitle
                                             action: itemAction
                                      keyEquivalent: @""
                                            atIndex: index];
	
    newItem.target = self;
	newItem.representedObject = itemPath;
    
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

@end
