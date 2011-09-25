/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXEmulatorDelegate is a protocol declaring the interface necessary for delegates of BXEmulator.
//(In practice the only implementor of this protocol is BXSession, but defining a protocol with
//the delegate methods BXEmulator needs keeps everyone's responsibilities clear.)


#pragma mark -
#pragma mark Notification constants

extern NSString * const BXEmulatorWillStartNotification;
extern NSString * const BXEmulatorDidInitializeNotification;
extern NSString * const BXEmulatorWillRunStartupCommandsNotification;
extern NSString * const BXEmulatorDidRunStartupCommandsNotification;
extern NSString * const BXEmulatorDidFinishNotification;

extern NSString * const BXEmulatorWillStartProgramNotification;
extern NSString * const BXEmulatorDidFinishProgramNotification;
extern NSString * const BXEmulatorDidReturnToShellNotification;

extern NSString * const BXEmulatorDidChangeEmulationStateNotification;

extern NSString * const BXEmulatorDidBeginGraphicalContextNotification;
extern NSString * const BXEmulatorDidFinishGraphicalContextNotification;

extern NSString * const BXEmulatorDidCreateFileNotification;
extern NSString * const BXEmulatorDidRemoveFileNotification;

extern NSString * const BXEmulatorDidDisplayMT32MessageNotification;



//TODO: define and document user info dictionary keys for each of these notifications.


#pragma mark -
#pragma mark Protocol

@class BXFrameBuffer;
@class BXEmulator;
@protocol BXEmulatorDelegate <NSObject>

#pragma mark -
#pragma mark Delegate methods

//These are only sent to the emulator delegate and are required to be implemented.

//Requests the current viewport and maximum frame size.
//Used for decisions about scaler rendering.
- (NSSize) viewportSizeForEmulator: (BXEmulator *)emulator;
- (NSSize) maxFrameSizeForEmulator: (BXEmulator *)emulator;

//Tells the delegate that the specified frame has finished rendering.
- (void) emulator: (BXEmulator *)emulator didFinishFrame: (BXFrameBuffer *)frame;

//Called at the start of AUTOEXEC.BAT to let the delegate run any DOS commands
//it needs to configure the emulation state.
- (void) runPreflightCommandsForEmulator: (BXEmulator *)emulator;

//Called at the end of AUTOEXEC.BAT to let the delegate run any DOS commands
//it wants to with the fully-prepared session.
- (void) runLaunchCommandsForEmulator: (BXEmulator *)emulator;

//Called when the emulator is ready to process events for the current
//iteration of its run loop.
- (void) processEventsForEmulator: (BXEmulator *)emulator;

//Called whenever the emulator starts/finishes one iteration of its run loop.
- (void) emulatorWillStartRunLoop: (BXEmulator *)emulator;
- (void) emulatorDidFinishRunLoop: (BXEmulator *)emulator;

//Called whenever a path is mounted from the DOS MOUNT command.
//Return NO to prevent the mount.
- (BOOL) emulator: (BXEmulator *)emulator shouldMountDriveFromShell: (NSString *)drive;

//Return the filesystem paths for the ROMs that the emulator should use.
- (NSString *) pathToMT32ControlROMForEmulator: (BXEmulator *)emulator;
- (NSString *) pathToMT32PCMROMForEmulator: (BXEmulator *)emulator;


#pragma mark -
#pragma mark Lifecycle notifications


//These are sent to the emulator delegate if defined, and posted on the default notification center.
@optional

//Posted when the emulator is about to start up.
- (void) emulatorWillStart: (NSNotification *)notification;

//Posted when the emulator has finished parsing configuration files and applying its initial settings.
- (void) emulatorDidInitialize: (NSNotification *)notification;

//Posted when the emulator is about to start processing AUTOEXEC.BAT.
- (void) emulatorWillRunStartupCommands: (NSNotification *)notification;

//Posted when the emulator has just finished processing AUTOEXEC.BAT.
- (void) emulatorDidRunStartupCommands: (NSNotification *)notification;

//Posted when the emulator shuts down.
- (void) emulatorDidFinish:	(NSNotification *)notification;


//Posted when the emulator is about to start a program.
- (void) emulatorWillStartProgram: (NSNotification *)notification;

//Posted when a program has just exited.
- (void) emulatorDidFinishProgram: (NSNotification *)notification;

//Posted when the emulator has returned control to the DOS prompt.
- (void) emulatorDidReturnToShell: (NSNotification *)notification;

//Posted when the emulator has switched from a text mode to a graphics mode and vice-versa.
- (void) emulatorDidBeginGraphicalContext:	(NSNotification *)notification;
- (void) emulatorDidFinishGraphicalContext:	(NSNotification *)notification;

//Posted when CPU emulation settings may have been changed by DOSBox.
//(Currently no information is provided about what, if anything, has changed.)
- (void) emulatorDidChangeEmulationState:	(NSNotification *)notification;

//Posted whenever a game tells the MT-32 to display an LCD message.
- (void) emulatorDidDisplayMT32Message: (NSNotification *)notification;

@end


#pragma mark -
#pragma mark Additional filesystem-related delegate methods

@protocol BXEmulatorFileSystemDelegate <NSObject>

@optional
//Notifies the delegate that a DOS drive has been added/removed.
- (void) emulatorDidMountDrive:		(NSNotification *)notification;
- (void) emulatorDidUnmountDrive:	(NSNotification *)notification;

//Notifies the delegate that Boxer created/deleted a file.
- (void) emulatorDidCreateFile:		(NSNotification *)notification;
- (void) emulatorDidRemoveFile:		(NSNotification *)notification;

@end

