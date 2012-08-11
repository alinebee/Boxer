/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXLaunchPanelController.h"
#import "BXSession+BXFileManager.h"
#import "BXDrive.h"
#import "BXEmulator+BXDOSFilesystem.h"
#import "BXValueTransformers.h"
#import "BXCollectionItemView.h"

@interface BXLaunchPanelController ()


@end

@implementation BXLaunchPanelController
@synthesize tabView = _tabView;
@synthesize tabSelector = _tabSelector;
@synthesize allProgramsList = _allProgramsList;
@synthesize favoriteProgramsList = _favoriteProgramsList;
@synthesize allProgramRows = _allProgramRows;
@synthesize favoriteProgramRows = _favoriteProgramRows;

- (void) awakeFromNib
{
    self.allProgramRows = [NSMutableArray array];
    self.favoriteProgramRows = [NSMutableArray array];
    
    self.representedObject = [self.view.window.windowController document];
}

- (void) setRepresentedObject: (id)representedObject
{
    if (self.representedObject != representedObject)
    {
        if (self.representedObject)
        {
            [self.representedObject removeObserver: self
                                        forKeyPath: @"executables"];
            
            [self.representedObject removeObserver: self
                                        forKeyPath: @"gamePackage"];
        }
        
        [super setRepresentedObject: representedObject];

        if (self.representedObject)
        {
            [self.representedObject addObserver: self
                                     forKeyPath: @"executables"
                                        options: NSKeyValueObservingOptionInitial
                                        context: nil];
            
            [self.representedObject addObserver: self
                                     forKeyPath: @"gamePackage"
                                        options: NSKeyValueObservingOptionInitial
                                        context: nil];
        }
    }
}

- (void) dealloc
{
    self.tabView = nil;
    self.tabSelector = nil;
    self.allProgramsList = nil;
    self.favoriteProgramsList = nil;
    self.allProgramRows = nil;
    self.favoriteProgramRows = nil;
    
    [super dealloc];
}


#pragma mark -
#pragma mark Populating program lists

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    if ([keyPath isEqualToString: @"executables"])
    {
        [self _syncFavoriteProgramRows];
        //[self _syncAllProgramRows];
    }
    
    /*
    else if ([keyPath isEqualToString: @"gamePackage"])
    {
        [self _syncFavoriteProgramRows];
    }
     */
}

- (void) _syncAllProgramRows
{
    NSMutableArray *mutableRows = [self mutableArrayValueForKey: @"allProgramRows"];
    
    [mutableRows removeAllObjects];

    BXSession *session = (BXSession *)self.representedObject;
    
    NSDictionary *executablePathsByDrive = session.executables;
    NSArray *sortedLetters = [executablePathsByDrive.allKeys sortedArrayUsingSelector: @selector(compare:)];
    
    NSValueTransformer *programNameFormatter = [[BXDOSFilenameTransformer alloc] init];
    
    for (NSString *driveLetter in sortedLetters)
    {
        BXDrive *drive = [session.emulator driveAtLetter: driveLetter];
        NSArray *executablePathsOnDrive = [executablePathsByDrive objectForKey: driveLetter];
        
        if (drive && executablePathsOnDrive.count)
        {
            //First, prepare a group row for this drive.
            NSString *groupRowFormat = NSLocalizedString(@"Drive %1$@ (%2$@)",
                                                   @"Format for grouping rows in All Programs list. %1$@ is the drive letter, and %2$@ is the drive's title.");
            
            NSString *title = [NSString stringWithFormat: groupRowFormat, drive.letter, drive.title];
            NSDictionary *groupRow = [NSDictionary dictionaryWithObjectsAndKeys:
                                      title, @"title",
                                      drive.path, @"path",
                                      [NSNumber numberWithBool: YES], @"isDriveRow",
                                      nil];
            
            [mutableRows addObject: groupRow];
            
            //Now, add items for each program on that drive.
            for (NSString *path in executablePathsOnDrive)
            {
                NSString *dosPath = [session.emulator DOSPathForPath: path onDrive: drive];
                NSString *programTitle = [programNameFormatter transformedValue: path];
                NSDictionary *programRow = [NSDictionary dictionaryWithObjectsAndKeys:
                                            programTitle, @"title",
                                            path, @"path",
                                            dosPath, @"dosPath",
                                            nil];
                [mutableRows addObject: programRow];
            }
        }
    }
    
    [programNameFormatter release];
}

- (void) _syncFavoriteProgramRows
{
    NSMutableArray *mutableRows = [self mutableArrayValueForKey: @"favoriteProgramRows"];
    
    [mutableRows removeAllObjects];
    
    BXSession *session = (BXSession *)self.representedObject;
    
    NSDictionary *executablePathsByDrive = session.executables;
    NSArray *sortedLetters = [executablePathsByDrive.allKeys sortedArrayUsingSelector: @selector(compare:)];
    
    NSValueTransformer *programNameFormatter = [[BXDOSFilenameTransformer alloc] init];
    
    for (NSString *driveLetter in sortedLetters)
    {
        BXDrive *drive = [session.emulator driveAtLetter: driveLetter];
        NSArray *executablePathsOnDrive = [executablePathsByDrive objectForKey: driveLetter];
        
        if (drive && executablePathsOnDrive.count)
        {
            //Now, add items for each program on that drive.
            for (NSString *path in executablePathsOnDrive)
            {
                NSString *dosPath = [session.emulator DOSPathForPath: path onDrive: drive];
                NSString *programTitle = [programNameFormatter transformedValue: path];
                NSDictionary *programRow = [NSDictionary dictionaryWithObjectsAndKeys:
                                            programTitle, @"title",
                                            path, @"path",
                                            dosPath, @"dosPath",
                                            nil];
                [mutableRows addObject: programRow];
            }
        }
    }
    
    [programNameFormatter release];
}


#pragma mark -
#pragma mark Launching programs

+ (NSSet *) keyPathsForValuesAffectingCanLaunchPrograms
{
    return [NSSet setWithObject: @"representedObject.isAtPrompt"];
}

- (BOOL) canLaunchPrograms
{
    BXSession *session = self.representedObject;
    return session.emulator.isAtPrompt;
}

- (IBAction) launchFavoriteProgram: (NSButton *)sender
{
    NSCollectionViewItem *item = [(BXCollectionItemView *)sender.superview delegate];
    
    //The collection view item's represented object is expected to be a dictionary
    //containing details of the program to launch.
    NSDictionary *programDetails = item.representedObject;
    
    NSString *programPath = [programDetails objectForKey: @"path"];
    
	if (programPath)
    {
        BXSession *session = (BXSession *)self.representedObject;
        [session openFileAtPath: programPath];
    }
}

@end
