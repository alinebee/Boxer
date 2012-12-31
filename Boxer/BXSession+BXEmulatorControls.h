/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXEmulatorControls category is responsible for bridging the session UI with the underlying
//emulator state. Most of its methods are UI-facing.


#import <Cocoa/Cocoa.h>
#import "BXSession.h"


//The speed thresholds used by cpuClassFormatForSpeed: to appropriately describe
//the current emulation speed in terms of CPU class.
enum
{
	BXMaxSpeedThreshold		= 62500,
	BXPentiumSpeedThreshold	= 25000,
	BX486SpeedThreshold		= 10000,
	BX386SpeedThreshold		= 2500,
	BX286SpeedThreshold		= 1000,
	BXMinSpeedThreshold		= 50
};

//The increments used by the  CPU speed slider for the various CPU-class thresholds above.
enum
{
	BXPentiumSpeedIncrement	= 2500,	//25000->62500,	15 increments in band
	BX486SpeedIncrement		= 1000,	//10000->25000,	15 increments in band
	BX386SpeedIncrement		= 500,	//2500->10000,	15 increments in band
	BX286SpeedIncrement		= 100,	//1000->2500,	15 increments in band
	BXMinSpeedIncrement		= 50	//50->1000,		19 increments in band
};

#define BXAutoSpeed -1

//The maximum frameskip level we can set
#define BXMaxFrameskip 9


@class BXEmulator;

@interface BXSession (BXEmulatorControls)

#pragma mark -
#pragma mark Properties

//The number of frames to be skipped for each frame that is played
@property (assign, nonatomic) NSUInteger frameskip;

//The CPU speed, as a fixed cycles number or BXAutoSpeed (if autoSpeed is YES).
@property (assign, nonatomic) NSInteger CPUSpeed;

//Whether the CPU speed is automatically scaled to the maximum possible value.
@property (assign, nonatomic, getter=isAutoSpeed) BOOL autoSpeed;

//The slider speed snaps the CPU speed to fixed increments and automatically bumps
//it to maximum speed if set to the highest limit. Used by speed slider in CPU panel.
@property (assign, nonatomic) NSInteger sliderSpeed;

//Whether the CPU is in dynamic core mode
@property (assign, nonatomic, getter=isDynamic) BOOL dynamic;


//Whether the current frameskip level is at the minimum or maximum bounds.
@property (readonly, nonatomic) BOOL frameskipAtMinimum; 
@property (readonly, nonatomic) BOOL frameskipAtMaximum;

//Whether the current CPU speed is at the minimum or maximum bounds.
@property (readonly, nonatomic) BOOL speedAtMinimum;
@property (readonly, nonatomic) BOOL speedAtMaximum;

//Localised human-readable descriptions of the current CPU speed/frameskip setting.
@property (readonly, nonatomic) NSString *speedDescription;
@property (readonly, nonatomic) NSString *frameskipDescription;


#pragma mark -
#pragma mark Class methods

//Returns the appropriate increment amount for the specified speed (see the speed increment constants above.)
//increasing specifies whether the speed will be increased or decreased, and affects which increment will be
//returned if the speed is exactly at a threshold.
+ (NSInteger) incrementAmountForSpeed: (NSInteger)speed goingUp: (BOOL)increasing;

//Returns a speed snapped to the appropriate increment for whichever CPU range that speed falls into.
+ (NSInteger) snappedSpeed: (NSInteger) rawSpeed;

//Returns a localised human-readable string describing the CPU class (AT, 386, Pentium etc.)
//corresponding to the specified speed.
+ (NSString *) cpuClassFormatForSpeed: (NSInteger)speed;

//Returns a version of the above pre-formatted with the specified speed.
+ (NSString *) descriptionForSpeed: (NSInteger)speed;


#pragma mark -
#pragma mark Interface actions and validation

//Pause/unpause the emulation. Will show a paused/unpaused bezel notification.
- (IBAction) togglePaused: (id)sender;

//Pause the emulation if it was not already paused. Will show a paused bezel
//notification if the emulation was previously running, otherwise will have no effect.
- (IBAction) pause: (id)sender;

//Resume the emulation if it was paused. Will show an unpaused bezel notification
//if the emulation was previously paused, otherwise will have no effect.
- (IBAction) resume: (id)sender;

//Increase/decrease the current frameskip by 1.
- (IBAction) incrementFrameSkip: (id)sender;
- (IBAction) decrementFrameSkip: (id)sender;

//Increase/decrease the CPU speed by an appropriate increment,
//according to incrementAmountForSpeed:goingUp:
- (IBAction) incrementSpeed: (id)sender;	
- (IBAction) decrementSpeed: (id)sender;

//Run the CPU in turbo mode.
- (IBAction) toggleFastForward: (id)sender;
- (IBAction) fastForward: (id)sender;
- (IBAction) releaseFastForward: (id)sender;


//Caps the speed within minimum and maximum limits
- (BOOL) validateCPUSpeed: (id *)ioValue error: (NSError **)outError;

//Caps the frameskip amount within minimum and maximum limits
- (BOOL) validateFrameskip: (id *)ioValue error: (NSError **)outError;

//Snaps the speed to set increments, and switches to auto speed above the maximum speed.
- (BOOL) validateSliderSpeed: (id *)ioValue error: (NSError **)outError;

//Paste data from the clipboard into the DOS session.
- (IBAction) paste: (id)sender;

//Whether we can accept pasted data from the specified pasteboard.
- (BOOL) canPasteFromPasteboard: (NSPasteboard *)pboard;

//Save a screenshot to the desktop.
- (IBAction) saveScreenshot: (id)sender;


//Cycle forward/backward through all drive queues.
- (IBAction) mountNextDrivesInQueues: (id)sender;
- (IBAction) mountPreviousDrivesInQueues: (id)sender;

//Whether we have any drive queues that can be cycled. Used for UI bindings.
- (BOOL) canCycleDrivesInQueues;

//Discard/merge the current game data.
//The game be relaunched after the operation is complete.
- (IBAction) revertShadowedChanges: (id)sender;
- (IBAction) mergeShadowedChanges: (id)sender;

//Import/export the current game data.
//The game will be relaunched after importing is complete.
- (IBAction) importGameState: (id)sender;
- (IBAction) exportGameState: (id)sender;

//Restart the emulation by closing and reopening the document.
//This will show a confirmation first if there are programs running or drives being imported.
- (IBAction) performRestart: (id)sender;
- (IBAction) performRestartAtLaunchPanel: (id)sender;

@end
