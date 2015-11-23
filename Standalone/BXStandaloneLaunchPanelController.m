/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXStandaloneLaunchPanelController.h"
#import "BXSession+BXFileManagement.h"
#import "BXDrive.h"
#import "BXGamebox.h"
#import "BXEmulator+BXDOSFilesystem.h"
#import "BXValueTransformers.h"
#import "BXCollectionItemView.h"
#import "BXSessionError.h"

#import "BXLaunchPanelController.h"

@interface BXStandaloneLaunchPanelController () <BXLauncherItemDelegate>
@end

@implementation BXStandaloneLaunchPanelController
@synthesize launcherList = _launcherList;
@synthesize displayedRows = _displayedRows;

- (void) awakeFromNib
{
    self.displayedRows = [NSMutableArray array];
}

- (void) setRepresentedObject: (id)representedObject
{
    if (self.representedObject != representedObject)
    {
        if (self.representedObject)
        {
            [self.representedObject removeObserver: self
                                        forKeyPath: @"gamebox.launchers"];
            
            [self.representedObject removeObserver: self
                                        forKeyPath: @"canOpenURLs"];
        }
        
        [super setRepresentedObject: representedObject];
        
        if (self.representedObject)
        {
            [self.representedObject addObserver: self
                                     forKeyPath: @"gamebox.launchers"
                                        options: NSKeyValueObservingOptionInitial
                                        context: nil];
            
            [self.representedObject addObserver: self
                                     forKeyPath: @"canOpenURLs"
                                        options: NSKeyValueObservingOptionInitial
                                        context: nil];
        }
    }
}


#pragma mark -
#pragma mark Populating program lists

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    if ([keyPath isEqualToString: @"gamebox.launchers"])
    {
        [self _syncDisplayedRows];
    }
    else if ([keyPath isEqualToString: @"canOpenURLs"])
    {
        [self _syncLaunchableState];
    }
}

- (void) _syncDisplayedRows
{
    NSMutableArray *mutableRows = [self mutableArrayValueForKey: @"displayedRows"];
    
    [mutableRows removeAllObjects];
    
    BXSession *session = (BXSession *)self.representedObject;
    
    for (NSDictionary *launcher in session.gamebox.launchers)
    {
        NSDictionary *item = [self _listItemForLauncher: launcher];
        [mutableRows addObject: item];
    }
}

- (NSDictionary *) _listItemForLauncher: (NSDictionary *)launcher
{
    BXSession *session = (BXSession *)self.representedObject;
    
    NSURL *URL          = [launcher objectForKey: BXLauncherURLKey];
    NSString *title     = [launcher objectForKey: BXLauncherTitleKey];
    NSString *arguments = [launcher objectForKey: BXLauncherArgsKey]; //May be nil
    
    //If no title was provided, use the program's filename.
    if (!title.length)
    {
        NSValueTransformer *programNameFormatter = [[BXDOSFilenameTransformer alloc] init];
        title = [programNameFormatter transformedValue: URL.path];
    }
    
    NSMutableDictionary *item = [NSMutableDictionary dictionaryWithDictionary: @{
                                                                                 @"isFavorite": @(YES),
                                                                                 @"URL": URL,
                                                                                 @"title": title,
                                                                                 @"launcher": launcher,
                                                                                 }];

    if (arguments)
        [item setObject: arguments forKey: @"arguments"];
    
    return item;
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
            item.launchable = [self canOpenItemInDOS: item];
        }
    }
}

#pragma mark -
#pragma mark Launching programs

- (BOOL) canOpenItemInDOS: (BXLauncherItem *)item
{
    BXSession *session = self.representedObject;
    if (!session.canOpenURLs)
        return NO;
    
    //TODO: check if the specified URL really can actually be opened in DOS
    //(This requires us to check if we can mount a drive for the URL if it's not already accessible, etc.)
    return ([item.representedObject objectForKey: @"URL"] != nil);
}

- (void) openItemInDOS: (BXLauncherItem *)item
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
            [session openURLInDOS: URL
                    withArguments: arguments
                      clearScreen: YES
                     onCompletion: BXSessionShowLauncherOnCompletion
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

- (BOOL) canRevealItemInFinder: (BXLauncherItem *)item
{
    return NO;
}

- (BOOL) canRemoveItem: (BXLauncherItem *)item
{
    return NO;
}

- (void) removeItem: (BXLauncherItem *)item
{
    NSAssert(NO, @"Editing the launcher list is not permitted from a standalone application.");
}

- (void) revealItemInFinder: (BXLauncherItem *)item
{
    NSAssert(NO, @"Showing launcher items in Finder is not permitted from a standalone application.");

}

@end
