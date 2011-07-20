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
    BXBezelPriorityNormal,
    BXBezelPriorityHigh
};
typedef NSUInteger BXBezelPriority;

//XIB view flags for indicating different roles within a bezel
enum {
    BXBezelIcon = 0,          //Decorative icon 
    BXBezelLevel = 1,         //Level indicator
    BXBezelLevelLabel = 2,    //Descriptive label for level indicator
    
    BXBezelDriveLabel = 3,    //Descriptive label for drive
    BXBezelDrivePath = 4      //File path for drive
};

@class BXDrive;
@interface BXBezelController : NSWindowController
{
    IBOutlet NSView *driveAddedBezel;
    IBOutlet NSView *driveRemovedBezel;
    IBOutlet NSView *fullscreenBezel;
    IBOutlet NSView *CPUSpeedBezel;
    IBOutlet NSView *throttleBezel;
    
    BXBezelPriority currentPriority;
}

#pragma mark -
#pragma mark Properties

//The bezel view used for drive inserted/ejected notifications.
@property (retain, nonatomic) NSView *driveAddedBezel;
@property (retain, nonatomic) NSView *driveRemovedBezel;

//The bezel used for fullscreen toggle notifications.
@property (retain, nonatomic) NSView *fullscreenBezel;

//The bezel view used for CPU speed notifications.
@property (retain, nonatomic) NSView *CPUSpeedBezel;

//The bezel view used for flightstick throttle notifications.
@property (retain, nonatomic) NSView *throttleBezel;

//The last bezel that was displayed.
@property (readonly, nonatomic) NSView *currentBezel;

#pragma mark -
#pragma mark Class methods

//The singleton controller to which all bezel requests should be directed.
+ (id) controller;

#pragma mark -
#pragma mark Methods

- (void) showDriveAddedBezelForDrive: (BXDrive *)drive;
- (void) showDriveRemovedBezelForDrive: (BXDrive *)drive;
- (void) showFullscreenBezel;

- (void) showCPUSpeedBezelForSpeed: (NSInteger)cpuSpeed;
- (void) showThrottleBezelForValue: (float)throttleValue;

- (void) showBezel: (NSView *)bezel
       forDuration: (NSTimeInterval)duration
          priority: (BXBezelPriority)priority;

- (void) hideBezel;
- (void) centerBezel;

@end
