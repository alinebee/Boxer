/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXEmulatorController category is responsible for bridging the session UI with the underlying
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


@class BXEmulator;

@interface BXSession (BXEmulatorController)

//Class methods
//-------------

//Sets up the emulator's value transformers.
+ (void) initialize;

//Returns the appropriate increment amount for the specified speed (see the speed increment constants above.)
//increasing specifies whether the speed will be increased or decreased, and affects which increment will be
//returned if the speed is exactly at a threshold.
+ (NSInteger) incrementAmountForSpeed: (NSInteger)speed goingUp: (BOOL)increasing;

//Returns a speed snapped to the appropriate increment for whichever CPU range that speed falls into.
+ (NSInteger) snappedSpeed: (NSInteger) rawSpeed;

//Returns a localised human-readable string describing the CPU class corresponding to the specified speed.
+ (NSString *) cpuClassFormatForSpeed: (NSInteger)speed;


//Responding to interface actions and validation 
//----------------------------------------------

- (IBAction) takeScreenshot:		(id)sender;	//Saves a PNG snapshot of the emulator output to the desktop.
- (IBAction) toggleRecordingVideo:	(id)sender;	//Starts/stops recording the emulator output to AVI.
//(This also checks whether the movie at the specified path could be played: if not,
//shows a BXVideoFormatAlert dialog advising the user to download the Perian codec pack.
//TODO: this has absolutely no place here and should be moved upstream.)


- (IBAction) incrementFrameSkip:	(id)sender;	//Increases the current frameskip by 1.
- (IBAction) decrementFrameSkip:	(id)sender;	//Decreases the current frameskip by 1.

- (IBAction) incrementSpeed:		(id)sender;	//Increases the CPU speed by an appropriate increment, according to incrementAmountForSpeed:.
- (IBAction) decrementSpeed:		(id)sender;	//Decreases the CPU speed by an appropriate decrement.
												
//Returns whether the current frameskip level is at the minimum or maximum bounds.
- (BOOL) frameskipAtMinimum; 
- (BOOL) frameskipAtMaximum;

//Returns whether the current CPU speed is at the minimum or maximum bounds.
- (BOOL) speedAtMinimum;
- (BOOL) speedAtMaximum;


//Keyboard events
//---------------

//Sends the appropriate keystroke to the emulator.
//These will be replaced in future with a single method that uses the represented object or IB tag of the sender. 
- (IBAction) sendEnter: (id)sender;
- (IBAction) sendF1:	(id)sender;
- (IBAction) sendF2:	(id)sender;
- (IBAction) sendF3:	(id)sender;
- (IBAction) sendF4:	(id)sender;
- (IBAction) sendF5:	(id)sender;
- (IBAction) sendF6:	(id)sender;
- (IBAction) sendF7:	(id)sender;
- (IBAction) sendF8:	(id)sender;
- (IBAction) sendF9:	(id)sender;
- (IBAction) sendF10:	(id)sender;


//Handling paste
//--------------

- (IBAction) paste: (id)sender;
- (BOOL) canPaste;

//Mouse-lock state wrapper
//------------------------

//Toggle whether the mouse is locked to the DOS window.
//Locking and unlocking the mouse will be accompanied by a UI sound effect.
- (void) setMouseLocked: (BOOL)lock;
- (BOOL) mouseLocked;


//Speed state wrapper
//-------------------

//Used by UI speed sliders to set the CPU speed. These snap the speed to appropriate increments.
- (void) setSliderSpeed: (NSInteger)speed;
- (NSInteger) sliderSpeed;


//Descriptions of emulation settings
//----------------------------------

//Returns a localised human-readable description of the current CPU speed setting.
- (NSString *) speedDescription;

//Returns a localised human-readable description of the frameskip setting.
- (NSString *) frameskipDescription;

@end
