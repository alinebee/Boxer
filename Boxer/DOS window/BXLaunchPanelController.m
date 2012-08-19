/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXLaunchPanelController.h"
#import "BXSession+BXFileManager.h"
#import "BXDrive.h"
#import "BXGamebox.h"
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
                                        forKeyPath: @"gamebox.launchers"];
        }
        
        [super setRepresentedObject: representedObject];

        if (self.representedObject)
        {
            [self.representedObject addObserver: self
                                     forKeyPath: @"executables"
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
        [self _syncAllProgramRows];
    }
    
    else if ([keyPath isEqualToString: @"gamebox.launchers"])
    {
        [self _syncFavoriteProgramRows];
    }
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
            
            NSString *driveTitle = [NSString stringWithFormat: groupRowFormat, drive.letter, drive.title];
            NSDictionary *groupRow = [NSDictionary dictionaryWithObjectsAndKeys:
                                      [NSNumber numberWithBool: YES], @"isDriveRow",
                                      driveTitle, @"title",
                                      drive.path, @"path",
                                      nil];
            
            [mutableRows addObject: groupRow];
            
            //Now, add items for each program on that drive.
            for (NSString *path in executablePathsOnDrive)
            {
                NSString *dosPath   = [session.emulator DOSPathForPath: path onDrive: drive];
                NSString *title     = [programNameFormatter transformedValue: path];
                
                NSDictionary *programRow = [NSDictionary dictionaryWithObjectsAndKeys:
                                            title, @"title",
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
    
    NSValueTransformer *programNameFormatter = [[BXDOSFilenameTransformer alloc] init];
    
    for (NSDictionary *launcher in session.gamebox.launchers)
    {
        NSString *path      = [launcher objectForKey: BXLauncherPathKey];
        NSString *title     = [launcher objectForKey: BXLauncherTitleKey];
        NSString *arguments = [launcher objectForKey: BXLauncherArgsKey];
        NSString *dosPath   = [session.emulator DOSPathForPath: path];
        
        //If no title was provided, use the program's filename.
        if (!title.length)
            title = [programNameFormatter transformedValue: path];
        
        NSDictionary *launcherRow = [NSDictionary dictionaryWithObjectsAndKeys:
                                    title, @"title",
                                    path, @"path",
                                    dosPath, @"dosPath",
                                    arguments, @"arguments",
                                    nil];
        
        [mutableRows addObject: launcherRow];
    }
    
    [programNameFormatter release];
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
    
    NSString *programPath = [programDetails objectForKey: @"path"];
    NSString *arguments = [programDetails objectForKey: @"arguments"];
    
	if (programPath)
    {
        BXSession *session = (BXSession *)self.representedObject;
        [session openFileAtPath: programPath
                  withArguments: arguments
                 clearingScreen: YES];
    }
}

@end
