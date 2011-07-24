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

//XIB view flags for indicating different roles within a bezel
enum {
    BXBezelIcon = 1,          //Decorative icon 
    BXBezelLevel = 2,         //Level indicator
    BXBezelLevelLabel = 3,    //Descriptive label for level indicator
    
    BXBezelDriveLabel = 4,    //Descriptive label for drive
    BXBezelDrivePath = 5      //File path for drive
};

@class BXDrive;
@class BXPackage;
@interface BXBezelController : NSWindowController
{
    IBOutlet NSView *driveAddedBezel;
    IBOutlet NSView *driveRemovedBezel;
    IBOutlet NSView *driveImportedBezel;
    IBOutlet NSView *fullscreenBezel;
    IBOutlet NSView *joystickIgnoredBezel;
    IBOutlet NSView *CPUSpeedBezel;
    IBOutlet NSView *throttleBezel;
    IBOutlet NSView *pauseBezel;
    IBOutlet NSView *playBezel;
    
    BXBezelPriority currentPriority;
}

#pragma mark -
#pragma mark Properties

//The bezel view used for drive inserted/ejected/imported notifications.
@property (retain, nonatomic) NSView *driveAddedBezel;
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

- (void) showDriveAddedBezelForDrive: (BXDrive *)drive;
- (void) showDriveRemovedBezelForDrive: (BXDrive *)drive;
- (void) showDriveImportedBezelForDrive: (BXDrive *)drive
                              toPackage: (BXPackage *)package;

- (void) showPauseBezel;
- (void) showPlayBezel;

- (void) showFullscreenBezel;
- (void) showJoystickIgnoredBezel;

- (void) showCPUSpeedBezelForSpeed: (NSInteger)cpuSpeed;
- (void) showThrottleBezelForValue: (float)throttleValue;


- (void) showBezel: (NSView *)bezel
       forDuration: (NSTimeInterval)duration
          priority: (BXBezelPriority)priority;

- (void) hideBezel;
- (void) centerBezel;

@end
