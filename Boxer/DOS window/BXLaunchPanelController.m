/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXLaunchPanelController.h"
#import "BXSession+BXFileManagement.h"
#import "BXDrive.h"
#import "BXGamebox.h"
#import "BXEmulator+BXDOSFilesystem.h"
#import "BXValueTransformers.h"
#import "BXCollectionItemView.h"
#import "RegexKitLite.h"

@interface BXLaunchPanelController ()

@property (retain, nonatomic) NSMutableArray *allProgramRows;
@property (retain, nonatomic) NSMutableArray *favoriteProgramRows;
@property (retain, nonatomic) NSMutableArray *displayedRows;

@property (retain, nonatomic) NSMutableArray *filterKeywords;

@end

@implementation BXLaunchPanelController
@synthesize tabSelector = _tabSelector;
@synthesize launcherList = _launcherList;
@synthesize launcherScrollView = _launcherScrollView;
@synthesize allProgramRows = _allProgramRows;
@synthesize favoriteProgramRows = _favoriteProgramRows;
@synthesize displayedRows = _displayedRows;
@synthesize displayMode = _displayMode;
@synthesize filter = _filter;
@synthesize filterKeywords = _filterKeywords;

- (void) awakeFromNib
{
    self.allProgramRows = [NSMutableArray array];
    self.favoriteProgramRows = [NSMutableArray array];
    self.displayedRows = [NSMutableArray array];
    self.filterKeywords = [NSMutableArray array];

    //These attributes are unsupported in 10.6 and so cannot be defined in the XIB.
    if ([self.launcherScrollView respondsToSelector: @selector(setScrollerKnobStyle:)])
        self.launcherScrollView.scrollerKnobStyle = NSScrollerKnobStyleLight;
    
    if ([self.launcherScrollView respondsToSelector: @selector(setUsesPredominantAxisScrolling:)])
        self.launcherScrollView.usesPredominantAxisScrolling = YES;
    
    if ([self.launcherScrollView respondsToSelector: @selector(setHorizontalScrollElasticity:)])
        self.launcherScrollView.horizontalScrollElasticity = NSScrollElasticityNone;
    
    [self _syncTabSelector];
}

- (void) setRepresentedObject: (id)representedObject
{
    if (self.representedObject != representedObject)
    {
        if (self.representedObject)
        {
            [self.representedObject removeObserver: self
                                        forKeyPath: @"executableURLs"];
            
            [self.representedObject removeObserver: self
                                        forKeyPath: @"gamebox.launchers"];
        }
        
        [super setRepresentedObject: representedObject];

        if (self.representedObject)
        {
            [self.representedObject addObserver: self
                                     forKeyPath: @"executableURLs"
                                        options: NSKeyValueObservingOptionInitial
                                        context: nil];
            
            [self.representedObject addObserver: self
                                     forKeyPath: @"gamebox.launchers"
                                        options: NSKeyValueObservingOptionInitial
                                        context: nil];
        }
    }
}

- (void) dealloc
{
    self.allProgramRows = nil;
    self.favoriteProgramRows = nil;
    self.displayedRows = nil;
    self.filterKeywords = nil;
    
    [super dealloc];
}


#pragma mark -
#pragma mark Populating the launcher list

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    if ([keyPath isEqualToString: @"executableURLs"])
    {
        [self _syncAllProgramRows];
    }
    
    else if ([keyPath isEqualToString: @"gamebox.launchers"])
    {
        [self _syncFavoriteProgramRows];
    }
}

- (BOOL) hasFavorites
{
    return self.favoriteProgramRows.count;
}

- (BOOL) hasPrograms
{
    return self.allProgramRows.count;
}

+ (NSImage *) _headingIconForDriveType: (BXDriveType)type
{
    NSString *iconName;
    switch (type)
    {
        case BXDriveCDROM:
            iconName = @"CDROMTemplate";
            break;
        case BXDriveFloppyDisk:
            iconName = @"DisketteTemplate";
            break;
        default:
            iconName = @"HardDiskTemplate";
    }
    
    return [NSImage imageNamed: iconName];
}

- (void) _syncAllProgramRows
{
    [self willChangeValueForKey: @"hasPrograms"];
    
    [self.allProgramRows removeAllObjects];
    
    BXSession *session = (BXSession *)self.representedObject;
    
    NSDictionary *executableURLsByDrive = session.executableURLs;
    NSArray *sortedLetters = [executableURLsByDrive.allKeys sortedArrayUsingSelector: @selector(compare:)];
    
    NSValueTransformer *programNameFormatter = [[BXDOSFilenameTransformer alloc] init];
    
    for (NSString *driveLetter in sortedLetters)
    {
        BXDrive *drive = [session.emulator driveAtLetter: driveLetter];
        NSArray *executableURLsOnDrive = [executableURLsByDrive objectForKey: driveLetter];
        
        if (drive && executableURLsOnDrive.count)
        {
            //First, prepare a group row for this drive.
            NSString *groupRowFormat = NSLocalizedString(@"Drive %1$@ (%2$@)",
                                                   @"Format for grouping rows in All Programs list. %1$@ is the drive letter, and %2$@ is the drive's title.");
            
            NSString *driveTitle = [NSString stringWithFormat: groupRowFormat, drive.letter, drive.title];
            NSImage *driveIcon = [self.class _headingIconForDriveType: drive.type];
            NSDictionary *groupRow = @{
                                       @"isDrive": @(YES),
                                       @"isHeading": @(YES),
                                       @"title": driveTitle,
                                       @"URL": drive.sourceURL,
                                       @"icon": driveIcon,
                                       };
            
            [self.allProgramRows addObject: groupRow];
            
            //Now, add items for each program on that drive.
            for (NSURL *URL in executableURLsOnDrive)
            {
                NSString *dosPath   = [session.emulator DOSPathForURL: URL onDrive: drive];
                NSString *title     = [programNameFormatter transformedValue: URL.path];
                
                NSMutableDictionary *programRow = [NSMutableDictionary dictionary];
                [programRow setObject: title forKey: @"title"];
                [programRow setObject: URL forKey: @"URL"];
                
                //May be nil, if the drive cannot resolve the path
                if (dosPath)
                    [programRow setObject: dosPath forKey: @"dosPath"];
                else
                    NSLog(@"Could not resolve DOS path for %@", URL);
                
                [self.allProgramRows addObject: programRow];
            }
        }
    }
    
    [programNameFormatter release];
    
    [self didChangeValueForKey: @"hasPrograms"];
    
    [self _syncDisplayedRows];
}

- (void) _syncFavoriteProgramRows
{
    [self willChangeValueForKey: @"hasFavorites"];
    
    [self.favoriteProgramRows removeAllObjects];
    
    BXSession *session = (BXSession *)self.representedObject;
    
    NSValueTransformer *programNameFormatter = [[BXDOSFilenameTransformer alloc] init];
    
    for (NSDictionary *launcher in session.gamebox.launchers)
    {
        NSURL *URL          = [launcher objectForKey: BXLauncherURLKey];
        NSString *title     = [launcher objectForKey: BXLauncherTitleKey];
        NSString *arguments = [launcher objectForKey: BXLauncherArgsKey]; //May be nil
        NSString *dosPath   = [session.emulator DOSPathForURL: URL]; //May be nil
        
        //If no title was provided, use the program's filename.
        if (!title.length)
            title = [programNameFormatter transformedValue: URL.path];
        
        NSMutableDictionary *launcherRow = [NSMutableDictionary dictionaryWithDictionary: @{
                                            @"isFavorite": @(YES),
                                            @"URL": URL,
                                            @"title": title,
                                           }];
        
        if (dosPath)
            [launcherRow setObject: dosPath forKey: @"dosPath"];
        else
            NSLog(@"Could not resolve DOS path for %@", URL);
        
        if (arguments)
            [launcherRow setObject: arguments forKey: @"arguments"];
        
        [self.favoriteProgramRows addObject: launcherRow];
    }
    
    [programNameFormatter release];
    
    [self didChangeValueForKey: @"hasFavorites"];
    
    [self _syncDisplayedRows];
}

- (NSUInteger) _relevanceOfRow: (NSDictionary *)row forKeywords: (NSArray *)keywords
{
    NSUInteger relevance = 0;
    
    NSString *title = [row objectForKey: @"title"];
    NSString *path = [row objectForKey: @"dosPath"];
    
    for (NSString *keyword in self.filterKeywords)
    {
        //Title matches are "worth more" than path matches
        if (title.length)
        {
            NSRange matchRange = [title rangeOfString: keyword options: NSCaseInsensitiveSearch];
            if (matchRange.location != NSNotFound)
                relevance += 3;
        }
        
        if (path.length)
        {
            NSRange matchRange = [path rangeOfString: keyword options: NSCaseInsensitiveSearch];
            if (matchRange.location != NSNotFound)
                relevance += 2;
        }
    }
    
    if (relevance > 0 && path.length > 0)
    {
        //Slightly boost the relevance of matches on drive C
        NSString *driveLetter = [path substringToIndex: 1];
        if ([driveLetter isEqualToString: @"C"])
        {
            relevance += 1;
        }
    }
    
    return relevance;
}

//Returns an array of rows that match the specified keywords, sorted by relevance
- (NSArray *) _rowsMatchingKeywords: (NSArray *)keywords inRows: (NSArray *)rows
{
    NSUInteger i, numRows = rows.count;
    NSMutableArray *matches = [NSMutableArray arrayWithCapacity: numRows];
    
    NSUInteger *relevances = calloc(numRows, sizeof(NSUInteger));
    
    for (i=0; i<numRows; i++)
    {
        NSDictionary *row = [rows objectAtIndex: i];
        //Skip header rows
        if ([[row objectForKey: @"isHeading"] boolValue])
            continue;
        
        NSUInteger relevance = [self _relevanceOfRow: row forKeywords: keywords];
        if (relevance > 0)
        {
            relevances[i] = relevance;
            [matches addObject: row];
        }
    }
    
    [matches sortUsingComparator: ^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSUInteger obj1Index = [rows indexOfObject: obj1];
        NSUInteger obj2Index = [rows indexOfObject: obj2];
        NSUInteger obj1Relevance = relevances[obj1Index], obj2Relevance = relevances[obj2Index];
        
        if (obj1Relevance < obj2Relevance) {
            return NSOrderedDescending;
        }
        
        if (obj1Relevance > obj2Relevance) {
            return NSOrderedAscending;
        }
        
        //Sort by path in the event of a tie
        NSString *dosPath1 = [obj1 objectForKey: @"dosPath"], *dosPath2 = [obj2 objectForKey: @"dosPath"];
        return [dosPath1 compare: dosPath2 options: NSCaseInsensitiveSearch];
    }];
    
    free(relevances);
    return matches;
}

- (void) _syncDisplayedRows
{
    NSMutableArray *displayedRows = [NSMutableArray arrayWithCapacity: 10];
    
    if (self.filterKeywords.count)
    {
        NSLog(@"Keywords: %@", self.filterKeywords);
        NSArray *matchingFavorites   = [self _rowsMatchingKeywords: self.filterKeywords inRows: self.favoriteProgramRows];
        NSArray *matchingPrograms    = [self _rowsMatchingKeywords: self.filterKeywords inRows: self.allProgramRows];
        
        BOOL needsHeadings = (matchingFavorites.count && matchingPrograms.count);
        if (needsHeadings)
        {
            NSDictionary *favoritesHeading = @{@"icon": [NSImage imageNamed: @"FavoriteOutlineTemplate"],
                                               @"title": NSLocalizedString(@"Favorites", @"Heading for favorite search results in launcher panel."),
                                               @"isHeading": @(YES),
                                               };
            [displayedRows addObject: favoritesHeading];
        }
        [displayedRows addObjectsFromArray: matchingFavorites];
        
        if (needsHeadings)
        {
            NSDictionary *allProgramsHeading = @{
                                               @"icon": [NSImage imageNamed: @"NSListViewTemplate"],
                                               @"title": NSLocalizedString(@"All Programs", @"Heading for rest of search results in launcher panel."),
                                               @"isHeading": @(YES),
                                               };
            [displayedRows addObject: allProgramsHeading];
        }
        [displayedRows addObjectsFromArray: matchingPrograms];
    }
    else if (self.displayMode == BXLaunchPanelDisplayFavorites)
    {
        [displayedRows addObjectsFromArray: self.favoriteProgramRows];
    }
    else
    {
        [displayedRows addObjectsFromArray: self.allProgramRows];
    }
    
    //IMPLEMENTATION NOTE: replacing the whole array at once, rather than emptying and refilling it,
    //allows the collection view to correctly persist previously-existing rows: animating them into their new location
    //rather than fading them out and back in again.
    self.displayedRows = displayedRows;
    
    [self _syncTabSelector];
}

- (void) _syncFilterKeywords
{
    [self.filterKeywords removeAllObjects];
    
    NSString *rawKeywords = self.filter.stringValue;
    if (rawKeywords.length)
    {
        for (NSString *keyword in [rawKeywords componentsSeparatedByCharactersInSet: [NSCharacterSet whitespaceCharacterSet]])
        {
            NSString *sanitisedKeyword = keyword;
            if (![self.filterKeywords containsObject: sanitisedKeyword])
                [self.filterKeywords addObject: sanitisedKeyword];
        }
    }
    [self _syncDisplayedRows];
}

#pragma mark -
#pragma mark Launching programs

+ (NSSet *) keyPathsForValuesAffectingCanLaunchPrograms
{
    return [NSSet setWithObjects: @"representedObject.isEmulating", @"representedObject.emulator.isAtPrompt", nil];
}

- (BOOL) canLaunchPrograms
{
    BXSession *session = self.representedObject;
    return session.isEmulating && session.emulator.isAtPrompt;
}

- (IBAction) launchFavoriteProgram: (NSButton *)sender
{
    NSCollectionViewItem *item = [(BXCollectionItemView *)sender.superview delegate];
    
    //The collection view item's represented object is expected to be a dictionary
    //containing details of the program to launch.
    NSDictionary *programDetails = item.representedObject;
    
    NSURL *programURL = [programDetails objectForKey: @"URL"];
    
	if (programURL)
    {
        NSString *arguments = [programDetails objectForKey: @"arguments"];
    
        BXSession *session = (BXSession *)self.representedObject;
        [session openURLInDOS: programURL
                withArguments: arguments
               clearingScreen: YES];
    }
}

- (IBAction) showFavoritePrograms: (id)sender
{
    self.displayMode = BXLaunchPanelDisplayFavorites;
}

- (IBAction) showAllPrograms: (id)sender
{
    self.displayMode = BXLaunchPanelDisplayAllPrograms;
}

#pragma mark - Display mode handling

- (void) setDisplayMode: (BXLaunchPanelDisplayMode)mode
{
    if (mode != self.displayMode)
    {
        _displayMode = mode;
        [self _syncDisplayedRows];
    }
}

- (void) _syncTabSelector
{
    if (self.filterKeywords.count)
        self.tabSelector.selectedSegment = -1;
    else
        self.tabSelector.selectedSegment = self.displayMode;
}

- (void) performSegmentedButtonAction: (NSSegmentedControl *)sender
{
    self.displayMode = (BXLaunchPanelDisplayMode)sender.selectedSegment;
    self.filter.stringValue = @"";
    [self _syncFilterKeywords];
}

#pragma mark - Filtering

- (IBAction) enterSearchText: (NSSearchField *)sender
{
    [self _syncFilterKeywords];
}

- (BOOL) control: (NSControl *)control textView: (NSTextView *)textView doCommandBySelector: (SEL)command
{
    NSLog(@"Search command: %@", NSStringFromSelector(command));
    return NO;
}

@end



@implementation BXLauncherList
@synthesize headingPrototype = _headingPrototype;
@synthesize favoritePrototype = _favoritePrototype;

- (NSCollectionViewItem *) newItemForRepresentedObject: (NSDictionary *)object
{
    BOOL isFavorite = [[object objectForKey: @"isFavorite"] boolValue];
    if (isFavorite)
    {
        NSCollectionViewItem *clone = [self.favoritePrototype copy];
        clone.representedObject = object;
        return clone;
    }
    
    BOOL isHeading = [[object objectForKey: @"isHeading"] boolValue];
    if (isHeading)
    {
        NSCollectionViewItem *clone = [self.headingPrototype copy];
        clone.representedObject = object;
        return clone;
    }
    else
    {
        return [super newItemForRepresentedObject: object];
    }
}

@end


@implementation BXLauncherNavigationHeader

- (void) drawRect: (NSRect)dirtyRect
{
    NSColor *backgroundColor = [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.05];
    
    NSRect bevelHighlightRect = NSMakeRect(0, 0, self.bounds.size.width, 1);
    NSRect bevelShadowRect = NSOffsetRect(bevelHighlightRect, 0, 1);
    
    [backgroundColor set];
    NSRectFillUsingOperation(dirtyRect, NSCompositeSourceOver);
    
    if ([self needsToDrawRect: bevelHighlightRect])
    {
        NSColor *bevelHighlight = [NSColor colorWithCalibratedWhite: 1.0 alpha: 0.1];
        [bevelHighlight set];
        NSRectFillUsingOperation(bevelHighlightRect, NSCompositeSourceOver);
    }
    
    if ([self needsToDrawRect: bevelShadowRect])
    {
        NSColor *bevelShadow = [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.1];
        [bevelShadow set];
        NSRectFillUsingOperation(bevelShadowRect, NSCompositeSourceOver);
    }
}
@end