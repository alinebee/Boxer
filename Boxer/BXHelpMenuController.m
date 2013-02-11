/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHelpMenuController.h"
#import "BXSession.h"
#import "BXBaseAppController.h"
#import "BXGamebox.h"
#import "BXFileTypes.h"

@interface BXHelpMenuController ()

//Used internally to populate the help menu with items for the paths in BXHelpMenuController documentation.
- (void) _populateMenu: (NSMenu *)menu withDocumentationFromSession: (BXSession *)session;
- (NSMenuItem *) _insertItemForDocumentationURL: (NSURL *)documentationURL
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
                       forKeyPath: @"currentSession.gamebox.documentationURLs"
                          options: 0
                          context: nil];
    
    _needsHelpLinksRefresh = YES;
    _needsSessionDocsRefresh = YES;
}

- (void) dealloc
{
    [[NSApp delegate] removeObserver: self forKeyPath: @"currentSession.gamebox.documentationURLs"];
    
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
    if ([keyPath isEqualToString: @"currentSession.gamebox.documentationURLs"])
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
    NSURL *documentURL = sender.representedObject;
	if (documentURL)
        [BXFileTypes openURLsInPreferredApplications: @[documentURL]];
}


#pragma mark -
#pragma mark Populating the menu

+ (NSString *) mobygamesMenuTitleForSession: (BXSession *)session
{	
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

+ (NSString *)replacementDocsMenuTitleForSession: (BXSession *)session
{	
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
    BXSession *session = [[NSApp delegate] currentSession];
    
	self.replacementDocsItem.title = [self.class replacementDocsMenuTitleForSession: session];
	self.mobygamesItem.title = [self.class mobygamesMenuTitleForSession: session];
    
    //If the current session or its documentation have changed,
    //reconstruct the documentation list.
	if (_needsSessionDocsRefresh && self.documentationDivider)
	{
        [self _populateMenu: menu withDocumentationFromSession: session];
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
    
    NSArray *documentation = session.gamebox.documentationURLs;
    if (documentation.count > 0)
    {
        NSArray *sortedDocs = [documentation sortedArrayUsingDescriptors: [self.class documentationSortCriteria]];
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
        
        for (NSURL *documentationURL in sortedDocs)
        {
            insertionPoint++;
            [self _insertItemForDocumentationURL: documentationURL toMenu: menu atIndex: insertionPoint];
        }
    }
    else
    {
        self.documentationDivider.hidden = YES;
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

- (NSMenuItem *) _insertItemForDocumentationURL: (NSURL *)documentationURL
                                         toMenu: (NSMenu *)menu
                                        atIndex: (NSUInteger)index
{
	SEL itemAction	= @selector(openDocumentFromMenuItem:);
	NSSize iconSize	= NSMakeSize(16, 16);
    
    NSImage *icon = nil;
    [documentationURL getResourceValue: &icon forKey: NSURLEffectiveIconKey error: NULL];

	NSString *itemTitle	= documentationURL.lastPathComponent.stringByDeletingPathExtension;
	
	NSMenuItem *newItem = [menu	insertItemWithTitle: itemTitle
                                             action: itemAction
                                      keyEquivalent: @""
                                            atIndex: index];
	
    newItem.target = self;
	newItem.representedObject = documentationURL;
    
    //Resize the icon if one is available
    if (icon)
    {
        icon = [icon copy];
        icon.size = iconSize;
        newItem.image = icon;
        [icon release];
    }
    
	return newItem;
}

+ (NSArray *) documentationSortCriteria
{
	//Sort docs by extension then by filename, to group similar items together
	NSSortDescriptor *sortByType, *sortByName;
	SEL comparison = @selector(caseInsensitiveCompare:);
	sortByType	= [[NSSortDescriptor alloc]	initWithKey: @"pathExtension"
											ascending: YES
											selector: comparison];
	sortByName	= [[NSSortDescriptor alloc]	initWithKey: @"lastPathComponent"
											ascending: YES
											selector: comparison];
	
	NSArray *sortDescriptors = [NSArray arrayWithObjects: sortByType, sortByName, nil];
	[sortByType release], [sortByName release];
	return sortDescriptors;
}

@end
