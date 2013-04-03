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
    if ([keyPath isEqualToString: @"executableURLs"])
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
            NSDictionary *groupRow = @{
                                       @"isDriveRow": @(YES),
                                       @"title": driveTitle,
                                       @"URL": drive.sourceURL
                                       };
            
            [mutableRows addObject: groupRow];
            
            //Now, add items for each program on that drive.
            for (NSURL *URL in executableURLsOnDrive)
            {
                NSString *dosPath   = [session.emulator DOSPathForURL: URL onDrive: drive];
                NSString *title     = [programNameFormatter transformedValue: URL.path];
                
                NSDictionary *programRow = @{
                                             @"title": title,
                                             @"URL": URL,
                                             @"dosPath": dosPath
                                             };
                
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
        NSURL *URL          = [launcher objectForKey: BXLauncherURLKey];
        NSString *title     = [launcher objectForKey: BXLauncherTitleKey];
        NSString *arguments = [launcher objectForKey: BXLauncherArgsKey]; //May be nil
        NSString *dosPath   = [session.emulator DOSPathForURL: URL]; //May be nil
        
        //If no title was provided, use the program's filename.
        if (!title.length)
            title = [programNameFormatter transformedValue: URL.path];
        
        NSMutableDictionary *launcherRow = [NSMutableDictionary dictionary];
        
        [launcherRow setObject: URL forKey: @"URL"];
        [launcherRow setObject: title forKey: @"title"];
        
        if (dosPath)
            [launcherRow setObject: dosPath forKey: @"dosPath"];
        
        if (arguments)
            [launcherRow setObject: arguments forKey: @"arguments"];
        
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

@end
