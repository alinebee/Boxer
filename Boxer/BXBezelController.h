/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXBezelController is a singleton that manages a translucent notification bezel.


#import <Cocoa/Cocoa.h>

#pragma mark -
#pragma mark Constants

enum {
    BXBezelPriorityLow,
    BXBezelPriorityNormal,
    BXBezelPriorityHigh
};
typedef NSUInteger BXBezelPriority;

//XIB view flags for indicating different view roles within a bezel
enum {
    BXBezelMessage          = 7,    //Message imparted by the bezel
    BXBezelIcon             = 1,    //Decorative icon for the bezel
    BXBezelLevel            = 2,    //Level indicator
    BXBezelLevelStatus      = 3,    //Label describing the status indicated in the level indicator
    
    BXBezelDriveAction      = 4,    //Label describing what's happening to the drive
    BXBezelDriveTitle       = 5,    //Display title of the drive
    
    BXBezelDriveFromIcon    = 1,    //The icon of the drive we are switching from
    BXBezelDriveToIcon      = 6     //The icon of the drive we are switching to
};

@class BXDrive;
@class BXPackage;
@interface BXBezelController : NSWindowController
{
    IBOutlet NSView *driveAddedBezel;
    IBOutlet NSView *driveSwappedBezel;
    IBOutlet NSView *driveRemovedBezel;
    IBOutlet NSView *driveImportedBezel;
    IBOutlet NSView *fullscreenBezel;
    IBOutlet NSView *joystickIgnoredBezel;
    IBOutlet NSView *CPUSpeedBezel;
    IBOutlet NSView *throttleBezel;
    IBOutlet NSView *pauseBezel;
    IBOutlet NSView *playBezel;
    IBOutlet NSView *MT32MessageBezel;
    
    BXBezelPriority currentPriority;
}

#pragma mark -
#pragma mark Properties

//The bezel view used for drive inserted/ejected/imported notifications.
@property (retain, nonatomic) NSView *driveAddedBezel;
@property (retain, nonatomic) NSView *driveSwappedBezel;
@property (retain, nonatomic) NSView *driveRemovedBezel;
@property (retain, nonatomic) NSView *driveImportedBezel;

//The bezel used for fullscreen toggle notifications.
@property (retain, nonatomic) NSView *fullscreenBezel;

//The bezel used for notifying the user that the joystick is being ignored.
@property (retain, nonatomic) NSView *joystickIgnoredBezel;

//The bezel view used for CPU speed notifications.
@property (retain, nonatomic) NSView *CPUSpeedBezel;

//The bezel view used for flightstick throttle notifications.
@property (retain, nonatomic) NSView *throttleBezel;

//The bezel view used for MT-32 LCD messages.
@property (retain, nonatomic) NSView *MT32MessageBezel;

//Pause/play bezel views.
@property (retain, nonatomic) NSView *pauseBezel;
@property (retain, nonatomic) NSView *playBezel;


//The last bezel that was displayed.
@property (readonly, nonatomic) NSView *currentBezel;

#pragma mark -
#pragma mark Class methods

//The singleton controller to which all bezel requests should be directed.
+ (id) controller;

//Returns the icon image to use for representing the specified drive.
+ (NSImage *) bezelIconForDrive: (BXDrive *)drive;

#pragma mark -
#pragma mark Methods

//Whether to show or suppress drive notifications.
//Currently this always returns YES.
- (BOOL) shouldShowDriveNotifications;

- (void) showDriveAddedBezelForDrive: (BXDrive *)drive;
- (void) showDriveRemovedBezelForDrive: (BXDrive *)drive;
- (void) showDriveSwappedBezelFromDrive: (BXDrive *)fromDrive
                                toDrive: (BXDrive *)toDrive;
- (void) showDriveImportedBezelForDrive: (BXDrive *)drive
                              toPackage: (BXPackage *)package;

- (void) showPauseBezel;
- (void) showPlayBezel;

- (void) showFullscreenBezel;
- (void) showJoystickIgnoredBezel;

- (void) showMT32BezelForMessage: (NSString *)message;

- (void) showCPUSpeedBezelForSpeed: (NSInteger)cpuSpeed;
- (void) showThrottleBezelForValue: (float)throttleValue;


- (void) showBezel: (NSView *)bezel
       forDuration: (NSTimeInterval)duration
          priority: (BXBezelPriority)priority;

- (void) hideBezel;
- (void) centerBezel;

@end
