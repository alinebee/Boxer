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
#import "BXBaseAppController.h"
#import "BXSessionError.h"
#import "BXEmulator.h" //For recentPrograms keys
#import "NSShadow+ADBShadowExtensions.h"
#import "NSBezierPath+MCAdditions.h"


//Display the 3 most recently launched programs.
#define BXLaunchPanelMaxRecentRows 3

@interface BXLaunchPanelController ()

@property (retain, nonatomic) NSMutableArray *allProgramRows;
@property (retain, nonatomic) NSMutableArray *favoriteProgramRows;
@property (retain, nonatomic) NSMutableArray *recentProgramRows;
@property (retain, nonatomic) NSMutableArray *displayedRows;

@property (retain, nonatomic) NSDictionary *favoritesHeading;
@property (retain, nonatomic) NSDictionary *recentProgramsHeading;
@property (retain, nonatomic) NSDictionary *allProgramsHeading;

@property (retain, nonatomic) NSMutableArray *filterKeywords;

@end

@implementation BXLaunchPanelController
@synthesize launcherList = _launcherList;
@synthesize launcherScrollView = _launcherScrollView;
@synthesize allProgramRows = _allProgramRows;
@synthesize favoriteProgramRows = _favoriteProgramRows;
@synthesize recentProgramRows = _recentProgramRows;
@synthesize favoritesHeading = _favoritesHeading;
@synthesize recentProgramsHeading = _recentProgramsHeading;
@synthesize allProgramsHeading = _allProgramsHeading;
@synthesize displayedRows = _displayedRows;
@synthesize filter = _filter;
@synthesize filterKeywords = _filterKeywords;

- (void) awakeFromNib
{
    self.allProgramRows = [NSMutableArray array];
    self.favoriteProgramRows = [NSMutableArray array];
    self.recentProgramRows = [NSMutableArray array];
    self.displayedRows = [NSMutableArray array];
    self.filterKeywords = [NSMutableArray array];

    //These attributes are unsupported in 10.6 and so cannot be defined in the XIB.
    if ([self.launcherScrollView respondsToSelector: @selector(setScrollerKnobStyle:)])
        self.launcherScrollView.scrollerKnobStyle = NSScrollerKnobStyleLight;
    
    if ([self.launcherScrollView respondsToSelector: @selector(setUsesPredominantAxisScrolling:)])
        self.launcherScrollView.usesPredominantAxisScrolling = YES;
    
    if ([self.launcherScrollView respondsToSelector: @selector(setHorizontalScrollElasticity:)])
        self.launcherScrollView.horizontalScrollElasticity = NSScrollElasticityNone;
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
                                        forKeyPath: @"canOpenURLs"];
            
            [self.representedObject removeObserver: self
                                        forKeyPath: @"recentPrograms"];
            
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
                                     forKeyPath: @"canOpenURLs"
                                        options: NSKeyValueObservingOptionInitial
                                        context: nil];
            
            [self.representedObject addObserver: self
                                     forKeyPath: @"recentPrograms"
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
    self.recentProgramRows = nil;
    self.displayedRows = nil;
    
    self.favoritesHeading = nil;
    self.recentProgramsHeading = nil;
    self.allProgramsHeading = nil;
    
    self.filterKeywords = nil;
    
    [super dealloc];
}


#pragma mark - Populating the launcher list

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    if ([keyPath isEqualToString: @"executableURLs"])
    {
        _allProgramRowsDirty = YES;
        _recentProgramRowsDirty = YES;
        _favoriteProgramRowsDirty = YES;
        if (_shouldUpdateImmediately)
        {
            [self _syncAllProgramRows];
            //Also resync the favorites and recents, since more accurate path info may have become available for them
            [self _syncFavoriteProgramRows];
            [self _syncRecentProgramRows];
        }
    }
    
    else if ([keyPath isEqualToString: @"recentPrograms"])
    {
        _recentProgramRowsDirty = YES;
        if (_shouldUpdateImmediately)
            [self _syncRecentProgramRows];
    }
    
    else if ([keyPath isEqualToString: @"gamebox.launchers"])
    {
        _favoriteProgramRowsDirty = YES;
        if (_shouldUpdateImmediately)
            [self _syncFavoriteProgramRows];
    }
    
    else if ([keyPath isEqualToString: @"canOpenURLs"])
    {
        if (_shouldUpdateImmediately)
            [self _syncLaunchableState];
    }
}

- (void) viewWillAppear
{
    _shouldUpdateImmediately = YES;
    
    if (_allProgramRowsDirty)
        [self _syncAllProgramRows];
    
    if (_recentProgramRowsDirty)
        [self _syncRecentProgramRows];
    
    if (_favoriteProgramRowsDirty)
        [self _syncFavoriteProgramRows];
    
    [self _syncLaunchableState];
}

- (void) viewDidDisappear
{
    _shouldUpdateImmediately = NO;
}

- (void) _syncAllProgramRows
{
    [self.allProgramRows removeAllObjects];
    
    BXSession *session = (BXSession *)self.representedObject;
    
    NSDictionary *executableURLsByDrive = session.executableURLs;
    NSArray *sortedLetters = [executableURLsByDrive.allKeys sortedArrayUsingSelector: @selector(compare:)];
    
    for (NSString *driveLetter in sortedLetters)
    {
        //FIXME: ultimately this should list programs for queued drives as well as mounted drives,
        //but we currently don't scan drives until they're mounted.
        BXDrive *drive = [session.emulator driveAtLetter: driveLetter];
        if (!drive || drive.isHidden)
            continue;
        
        NSArray *executableURLsOnDrive = [executableURLsByDrive objectForKey: driveLetter];
        if (executableURLsOnDrive.count)
        {
            NSDictionary *driveItem = [self _listItemForDrive: drive];
            [self.allProgramRows addObject: driveItem];
            
            //Now, add items for each program on that drive.
            for (NSURL *URL in executableURLsOnDrive)
            {
                NSDictionary *programItem = [self _listItemForProgramAtURL: URL
                                                                   onDrive: drive
                                                             withArguments: nil
                                                                     title: nil];
                [self.allProgramRows addObject: programItem];
            }
        }
    }
    _allProgramRowsDirty = NO;
    [self _syncDisplayedRows];
}

- (void) _syncRecentProgramRows
{
    [self.recentProgramRows removeAllObjects];
    
    BXSession *session = (BXSession *)self.representedObject;
    
    for (NSDictionary *programDetails in session.recentPrograms)
    {
        //Stop filling them up when we get to our maximum number
        if (self.recentProgramRows.count >= BXLaunchPanelMaxRecentRows)
            break;
        
        NSURL *URL          = [programDetails objectForKey: BXEmulatorLogicalURLKey];
        BXDrive *drive      = [programDetails objectForKey: BXEmulatorDriveKey];
        NSString *arguments = [programDetails objectForKey: BXEmulatorLaunchArgumentsKey];
        
        //Filter the recent programs to eliminate:
        //- Programs that aren't reachable in DOS right now
        //- Programs that already match one of our favorites (should we really do this?)
        if (![session.emulator logicalURLIsAccessibleInDOS: URL])
            continue;
        
        BOOL matchesLauncher = NO;
        for (NSDictionary *launcher in session.gamebox.launchers)
        {
            NSURL *launcherURL      = [launcher objectForKey: BXLauncherURLKey];
            NSString *launcherArgs  = [launcher objectForKey: BXLauncherArgsKey];
            if ([launcherURL isEqual: URL] &&
                ((!launcherArgs && !arguments) || [launcherArgs isEqual: arguments]))
            {
                matchesLauncher = YES;
                break;
            }
        }
        if (matchesLauncher)
            continue;
        
        NSDictionary *item = [self _listItemForProgramAtURL: URL
                                                    onDrive: drive
                                              withArguments: arguments
                                                      title: nil];
        
        NSMutableDictionary *annotatedItem = [item mutableCopy];
        [annotatedItem setObject: programDetails forKey: @"recentProgram"];
        
        [self.recentProgramRows addObject: annotatedItem];
        [annotatedItem release];
    }
    
    _recentProgramRowsDirty = NO;
    [self _syncDisplayedRows];
}

- (void) _syncFavoriteProgramRows
{
    [self.favoriteProgramRows removeAllObjects];
    
    BXSession *session = (BXSession *)self.representedObject;
    
    for (NSDictionary *launcher in session.gamebox.launchers)
    {
        NSDictionary *item = [self _listItemForLauncher: launcher];
        [self.favoriteProgramRows addObject: item];
    }
    
    _favoriteProgramRowsDirty = NO;
    [self _syncDisplayedRows];
}

- (void) _syncDisplayedRows
{
    NSMutableArray *displayedRows = [NSMutableArray arrayWithCapacity: 10];
    
    NSArray *matchingFavorites, *matchingRecents, *matchingPrograms;
    
    BOOL needsFavoritesHeading, needsAllProgramsHeading, needsRecentProgramsHeading;
    if (self.filterKeywords.count)
    {
        matchingFavorites   = [self _rowsMatchingKeywords: self.filterKeywords inRows: self.favoriteProgramRows];
        matchingRecents     = [self _rowsMatchingKeywords: self.filterKeywords inRows: self.recentProgramRows];
        matchingPrograms    = [self _rowsMatchingKeywords: self.filterKeywords inRows: self.allProgramRows];
        needsFavoritesHeading       = matchingFavorites.count && (matchingRecents.count || matchingPrograms.count);
        needsRecentProgramsHeading  = matchingRecents.count && (matchingFavorites.count || matchingPrograms.count);
        needsAllProgramsHeading     = matchingPrograms.count && (matchingFavorites.count || matchingRecents.count);
    }
    else
    {
        matchingFavorites   = self.favoriteProgramRows;
        matchingRecents     = self.recentProgramRows;
        matchingPrograms    = self.allProgramRows;
        needsFavoritesHeading = matchingFavorites.count;
        needsRecentProgramsHeading = matchingRecents.count;
        needsAllProgramsHeading = NO;
    }
    
    if (needsFavoritesHeading)
    {
        [displayedRows addObject: self.favoritesHeading];
    }
    [displayedRows addObjectsFromArray: matchingFavorites];
    
    if (needsRecentProgramsHeading)
    {
        [displayedRows addObject: self.recentProgramsHeading];
    }
    [displayedRows addObjectsFromArray: matchingRecents];
    
    if (needsAllProgramsHeading)
    {
        [displayedRows addObject: self.allProgramsHeading];
    }
    [displayedRows addObjectsFromArray: matchingPrograms];
    
    //IMPLEMENTATION NOTE: replacing the whole array at once, rather than emptying and refilling it,
    //allows the collection view to correctly persist previously-existing rows: animating them into their new location
    //rather than fading them out and back in again.
    self.displayedRows = displayedRows;
}

- (void) _syncLaunchableState
{
    NSUInteger numItems = self.displayedRows.count;
    
    //IMPLEMENTATION NOTE: we have to walk through every collection view item telling it whether or
    //not it's able to launch its program right now. We used to handle this by exposing a "canLaunchPrograms"
    //property on the panel controller and having individual items listen for changes to that: but this resulted
    //in KVO deallocation exceptions. (These may have indicated a leak, but it seemed rather like the views were
    //getting cleaned up in the wrong order because of our complex XIB structure. This bears further investigation.)
    if (numItems > 0)
    {
        for (NSUInteger i=0; i<numItems; i++)
        {
            BXLauncherItem *item = (BXLauncherItem *)[self.launcherList itemAtIndex: i];
            item.launchable = [self canLaunchItem: item];
        }
    }
}

- (NSDictionary *) favoritesHeading
{
    //Create the heading the first time we need it. By using a persistent object rather than regenerating it,
    //we ensure that the collection view will keep using the same view for it.
    if (!_favoritesHeading)
    {
        self.favoritesHeading = @{@"icon": [NSImage imageNamed: @"FavoriteOutlineTemplate"],
                                  @"title": NSLocalizedString(@"Favorites", @"Heading for favorites in launcher panel."),
                                  @"isHeading": @(YES),
                                  };
    }
    return [[_favoritesHeading retain] autorelease];
}

- (NSDictionary *) recentProgramsHeading
{
    //Create the heading the first time we need it. By using a persistent object rather than regenerating it,
    //we ensure that the collection view will keep using the same view for it.
    if (!_recentProgramsHeading)
    {
        self.recentProgramsHeading = @{@"icon": [NSImage imageNamed: @"RecentItemsTemplate"],
                                       @"title": NSLocalizedString(@"Recent", @"Heading for recent programs list in launcher panel."),
                                       @"isHeading": @(YES),
                                       };
    }
    return [[_recentProgramsHeading retain] autorelease];
}

- (NSDictionary *) allProgramsHeading
{
    //Create the heading the first time we need it. By using a persistent object rather than regenerating it,
    //we ensure that the collection view will keep using the same view for it.
    if (!_allProgramsHeading)
    {
        self.allProgramsHeading = @{@"icon": [NSImage imageNamed: @"LauncherListTemplate"],
                                    @"title": NSLocalizedString(@"All Programs", @"Heading for all programs search results in launcher panel."),
                                    @"isHeading": @(YES),
                                    };
    }
    return [[_allProgramsHeading retain] autorelease];
}

- (NSDictionary *) _listItemForProgramAtURL: (NSURL *)URL
                                    onDrive: (BXDrive *)drive
                              withArguments: (NSString *)arguments
                                      title: (NSString *)title
{
    BXSession *session = (BXSession *)self.representedObject;
    
    if (!drive)
    {
        drive = [session queuedDriveRepresentingURL: URL]; //May return nil
    }
    
    NSString *dosPath = [session.emulator DOSPathForLogicalURL: URL]; //May also return nil
    
    if (!title)
    {
        NSValueTransformer *programNameFormatter = [[BXDOSFilenameTransformer alloc] init];
        title = [programNameFormatter transformedValue: URL.path];
        [programNameFormatter release];
    }
    NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary: @{@"title": title,
                                                                                 @"URL": URL,
                                                                                }];
    
    if (drive)
        [item setObject: drive forKey: @"drive"];
    
    if (arguments)
        [item setObject: arguments forKey: @"arguments"];
    
    //May be nil, if the drive cannot resolve the path or was not mounted.
    if (dosPath)
    {
        
        [item setObject: dosPath forKey: @"dosPath"];
    }
    else
    {
        NSLog(@"Could not resolve DOS path for %@", URL);
    }
    
    return item;
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

- (NSDictionary *) _listItemForDrive: (BXDrive *)drive
{
    NSString *titleFormat = NSLocalizedString(@"Drive %1$@ (%2$@)",
                                              @"Format for drive headings in the launcher list. %1$@ is the drive letter, and %2$@ is the drive's title.");
    
    NSString *driveTitle = [NSString stringWithFormat: titleFormat, drive.letter, drive.title];
    NSImage *driveIcon = [self.class _headingIconForDriveType: drive.type];
    NSDictionary *item = @{
                           @"isDrive": @(YES),
                           @"isHeading": @(YES),
                           @"title": driveTitle,
                           @"URL": drive.sourceURL,
                           @"drive": drive,
                           @"icon": driveIcon,
                           };
    
    return item;
}

- (NSDictionary *) _listItemForLauncher: (NSDictionary *)launcher
{
    BXSession *session = (BXSession *)self.representedObject;
    
    NSURL *URL          = [launcher objectForKey: BXLauncherURLKey];
    NSString *title     = [launcher objectForKey: BXLauncherTitleKey];
    NSString *arguments = [launcher objectForKey: BXLauncherArgsKey]; //May be nil
    
    BXDrive *drive      = [session queuedDriveRepresentingURL: URL]; //May be nil
    NSString *dosPath   = [session.emulator DOSPathForLogicalURL: URL]; //May be nil
    
    //If no title was provided, use the program's filename.
    if (!title.length)
    {
        NSValueTransformer *programNameFormatter = [[BXDOSFilenameTransformer alloc] init];
        title = [programNameFormatter transformedValue: URL.path];
        [programNameFormatter release];
    }
    
    NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary: @{
                                                                                 @"isFavorite": @(YES),
                                                                                 @"URL": URL,
                                                                                 @"title": title,
                                                                                 @"launcher": launcher,
                                                                                 }];
    
    if (dosPath)
        [item setObject: dosPath forKey: @"dosPath"];
    else
        NSLog(@"Could not resolve DOS path for %@", URL);
    
    if (drive)
        [item setObject: drive forKey: @"drive"];
    
    if (arguments)
        [item setObject: arguments forKey: @"arguments"];
    
    return item;
}


#pragma mark - Filtering programs

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


#pragma mark - Program actions

- (void) launchItem: (BXLauncherItem *)item
{
    NSDictionary *itemDetails = item.representedObject;
    NSURL *URL = [itemDetails objectForKey: @"URL"];
    
	if (URL)
    {
        NSString *arguments = [itemDetails objectForKey: @"arguments"];
    
        BXSession *session = self.representedObject;
        
        BOOL canLaunch = YES;
        NSError *launchError = nil;
        
        //Check if we need to mount a drive first in order to run this program
        if ([session shouldMountNewDriveForURL: URL])
        {
            BXDrive *drive = [session mountDriveForURL: URL
                                              ifExists: BXDriveReplace
                                               options: BXDefaultDriveMountOptions
                                                 error: &launchError];
            
            //Display an error if a drive could not be mounted for the program.
            if (!drive)
            {
                canLaunch = NO;
            }
        }
        
        if (canLaunch)
        {
            BXSessionProgramCompletionBehavior completionBehavior;
            //If this is a drive, then show the DOS prompt so the user can get on with mucking around with it
            if ([[itemDetails objectForKey: @"isDrive"] boolValue])
            {
                completionBehavior = BXSessionShowDOSPromptOnCompletion;
            }
            //Otherwise, if we're launching a regular program, return to the launcher panel after it's finished
            else
            {
                completionBehavior = BXSessionShowLauncherOnCompletion;
            }
            
            [session openURLInDOS: URL
                    withArguments: arguments
                      clearScreen: YES
                     onCompletion: completionBehavior
                            error: &launchError];
        }
        
        //Display any error that occurred when trying to launch (apart from "hey, we're not ready yet!")
        if (launchError && ![launchError matchesDomain: BXSessionErrorDomain code: BXSessionNotReady])
        {
            [self presentError: launchError
                modalForWindow: session.windowForSheet
                      delegate: nil
            didPresentSelector: NULL
                   contextInfo: NULL];
        }
    }
}

- (BOOL) canLaunchItem: (BXLauncherItem *)item
{
    BXSession *session = self.representedObject;
    if (!session.canOpenURLs)
        return NO;
    
    //TODO: check if the specified URL can actually be opened in DOS
    //(This requires us to check if we can mount a drive for the URL if it's not already accessible, etc.)
    return ([item.representedObject objectForKey: @"URL"] != nil);
}

- (void) revealItemInFinder: (BXLauncherItem *)item
{
    NSDictionary *itemDetails = item.representedObject;
    NSURL *URL = [itemDetails objectForKey: @"URL"];
    
    //If the URL is absent or doesn't physically exist, e.g. it's inside a disc image,
    //then reveal the backing drive if available.
    if (!URL || ![URL checkResourceIsReachableAndReturnError: NULL])
    {
        BXDrive *drive = [itemDetails objectForKey: @"drive"];
        URL = drive.sourceURL;
    }
    
    if (URL)
    {
        [[NSApp delegate] revealURLsInFinder: @[URL]];
    }
}

- (BOOL) canRevealItemInFinder: (BXLauncherItem *)item
{
    NSURL *URL = [item.representedObject objectForKey: @"URL"];
    return [URL checkResourceIsReachableAndReturnError: NULL];
}

- (void) removeItem: (BXLauncherItem *)item
{
    BXSession *session = self.representedObject;
    NSDictionary *launcher = [item.representedObject objectForKey: @"launcher"];
    if (launcher)
    {
        //This should trigger a re-evaluation of our favorites list
        [session.gamebox removeLauncher: launcher];
    }
    else
    {
        NSDictionary *recentProgram = [item.representedObject objectForKey: @"recentProgram"];
        
        //This should trigger a re-evaluation of our recent programs list
        [session removeRecentProgram: recentProgram];
    }
}

- (BOOL) canRemoveItem: (BXLauncherItem *)item
{
    return ([item.representedObject objectForKey: @"launcher"] != nil) || ([item.representedObject objectForKey: @"recentProgram"] != nil);
}


#pragma mark - Filtering

- (IBAction) enterSearchText: (NSSearchField *)sender
{
    [self _syncFilterKeywords];
}

- (BOOL) control: (NSControl *)control textView: (NSTextView *)textView doCommandBySelector: (SEL)command
{
    NSLog(@"Search command: %@", NSStringFromSelector(command));
    if (command == @selector(insertNewline:))
    {
        //TODO: launch the first search result
    }
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
        [clone.view setFrameSize: NSMakeSize(640, 100)];
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


@implementation BXLauncherItem
@synthesize delegate = _delegate;
@synthesize launchable = _launchable;


- (id) copyWithZone: (NSZone *)zone
{
    BXLauncherItem *clone = [super copyWithZone: zone];
    clone.delegate = self.delegate;
    clone.launchable = self.isLaunchable;
    return clone;
}

- (void) dealloc
{
    self.delegate = nil;
    [super dealloc];
}

- (IBAction) launchProgram: (id)sender
{
    [self.delegate launchItem: self];
}

- (IBAction) revealItemInFinder: (id)sender
{
    [self.delegate revealItemInFinder: self];
}

- (IBAction) removeItem: (id)sender
{
    [self.delegate removeItem: self];
}

- (BOOL) validateMenuItem: (NSMenuItem *)menuItem
{
    SEL action = menuItem.action;
    
    if (action == @selector(launchProgram:))
    {
        return [self.delegate canLaunchItem: self];
    }
    else if (action == @selector(revealItemInFinder:))
    {
        return [self.delegate canRevealItemInFinder: self];
    }
    else if (action == @selector(removeItem:))
    {
        menuItem.hidden = ![self.delegate canRemoveItem: self];
        return !menuItem.isHidden;
    }
    else
    {
        return YES;
    }
}

- (void) setLaunchable: (BOOL)launchable
{
    _launchable = launchable;
    if ([self.view respondsToSelector: @selector(setEnabled:)])
    {
        [(id)self.view setEnabled: launchable];
    }
}

@end

@implementation BXLauncherItemView
@synthesize mouseInside = _mouseInside;
@synthesize active = _active;
@synthesize enabled = _enabled;

- (void) awakeFromNib
{
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect: NSZeroRect
                                                                options: NSTrackingMouseEnteredAndExited | NSTrackingEnabledDuringMouseDrag | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect
                                                                  owner: self
                                                               userInfo: nil];
    
    //Set up a tracking rect so that we receive mouseEntered/exited events
    [self addTrackingArea: trackingArea];
    [trackingArea release];
}

- (void) mouseEntered: (NSEvent *)theEvent
{
    self.mouseInside = YES;
}

- (void) mouseExited: (NSEvent *)theEvent
{
    self.mouseInside = NO;
}

- (void) setMouseInside: (BOOL)mouseInside
{
    if (_mouseInside != mouseInside)
    {
        _mouseInside = mouseInside;
        [self setNeedsDisplay: YES];
    }
}

- (void) setActive: (BOOL)active
{
    if (_active != active)
    {
        _active = active;
        [self setNeedsDisplay: YES];
    }
}

- (void) setEnabled: (BOOL)enabled
{
    if (_enabled != enabled)
    {
        _enabled = enabled;
        [self setNeedsDisplay: YES];
    }
}

- (void) mouseDown: (NSEvent *)theEvent
{
    self.active = YES;
    
    //Enter an event loop listening for the mouse-up event.
    //If we don't do this, the collection view will swallow the mouse-up and we'll never see it.
    NSEvent *eventInDrag = [self.window nextEventMatchingMask: NSLeftMouseUpMask];
    switch (eventInDrag.type)
    {
        case NSLeftMouseUp:
            [self mouseUp: eventInDrag];
            return;
    }
}

- (void) mouseUp: (NSEvent *)theEvent
{
    self.active = NO;
    
    NSPoint locationInWindow = self.window.mouseLocationOutsideOfEventStream;
    NSPoint locationInView = [self convertPoint: locationInWindow fromView: nil];
    if ([self mouse: locationInView inRect: self.bounds])
        [NSApp sendAction: @selector(launchProgram:) to: self.delegate from: self];
}

- (BOOL) acceptsFirstMouse: (NSEvent *)theEvent
{
    return NO;
}

- (BOOL) acceptsFirstResponder
{
    return self.isEnabled;
}

@end

@implementation BXLauncherRegularItemView

- (void) drawRect: (NSRect)dirtyRect
{
    if (self.isEnabled)
    {
        if (self.isActive)
        {
            NSColor *fillColor = [[NSColor alternateSelectedControlColor] colorWithAlphaComponent: 0.25];
            NSColor *borderColor = [[NSColor whiteColor] colorWithAlphaComponent: 0.1];
            NSShadow *innerShadow = [NSShadow shadowWithBlurRadius: 4.0
                                                            offset: NSMakeSize(0, -1.0)
                                                             color: [NSColor colorWithCalibratedWhite: 0.0 alpha: 0.15]];
            
            NSRect fillRect = NSInsetRect(self.bounds, 0, 1);
            NSBezierPath *fillPath = [NSBezierPath bezierPathWithRect: fillRect];
            
            NSRect topBorderRect = NSMakeRect(self.bounds.origin.x, self.bounds.size.height - 1, self.bounds.size.width, 1);
            NSRect bottomBorderRect = NSMakeRect(self.bounds.origin.x, 0, self.bounds.size.width, 1);
            
            [NSGraphicsContext saveGraphicsState];
                [fillColor set];
                [[NSGraphicsContext currentContext] setCompositingOperation: NSCompositePlusDarker];
                [fillPath fill];
                [fillPath fillWithInnerShadow: innerShadow];
            [NSGraphicsContext restoreGraphicsState];
            
            [NSGraphicsContext saveGraphicsState];
                [borderColor set];
                [NSBezierPath fillRect: topBorderRect];
                [NSBezierPath fillRect: bottomBorderRect];
            [NSGraphicsContext restoreGraphicsState];
        }
        else if (self.isMouseInside)
        {
            NSGradient *gradient = [[NSGradient alloc] initWithStartingColor: [NSColor colorWithCalibratedWhite: 1.0 alpha: 0.1]
                                                                 endingColor: [NSColor colorWithCalibratedWhite: 1.0 alpha: 0.0]];
            
            NSPoint centerPoint = NSMakePoint(NSMidX(self.bounds), NSMidY(self.bounds));
            [gradient drawFromCenter: centerPoint
                              radius: self.bounds.size.width * 0.25
                            toCenter: centerPoint
                              radius: self.bounds.size.width * 0.5
                             options: NSGradientDrawsBeforeStartingLocation | NSGradientDrawsAfterEndingLocation];
            
            [gradient release];
        }
    }
}

@end

@implementation BXLauncherFavoriteView
@end

@implementation BXLauncherHeadingView
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