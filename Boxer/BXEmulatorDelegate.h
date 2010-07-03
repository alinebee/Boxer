/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXEmulatorDelegate is a protocol declaring the interface necessary for delegates of BXEmulator.
//(In practice the only implementor of this protocol is BXSession, but defining a protocol with
//the delegate methods BXEmulator needs keeps everyone's responsibilities clear.)


@class BXFrameBuffer;
@protocol BXEmulatorDelegate <NSObject>

#pragma mark -
#pragma mark Delegate methods

//Called at the start of AUTOEXEC.BAT to let the delegate run any DOS commands
//it needs to configure the emulation state.
- (void) runPreflightCommands;

//Called at the end of AUTOEXEC.BAT to let the delegate run any DOS commands
//it wants to with the fully-prepared session.
- (void) runLaunchCommands;

//Tells the delegate that the specified frame has finished rendering.
- (void) frameComplete: (BXFrameBuffer *)frame;

//Asks the delegate for the current viewport and maximum frame size.
//Used for decisions about scaler rendering.
- (NSSize) viewportSize;
- (NSSize) maxFrameSize;


#pragma mark -
#pragma mark Notifications

//Notifies the delegate that the emulator is about to start a program.
- (void) programWillStart: (NSNotification *)notification;

//Notifies the delegate that a program has just exited.
- (void) programDidFinish: (NSNotification *)notification;

//Notifies the delegate that the emulator has returned control to the DOS prompt.
- (void) didReturnToShell: (NSNotification *)notification;

//Notifies the delegate that the emulator has switched into/out of a graphics mode.
- (void) didStartGraphicalContext:	(NSNotification *)notification;
- (void) didEndGraphicalContext:	(NSNotification *)notification;

//Called whenever the CPU emulation settings have been changed by DOSBox.
- (void) didChangeEmulationState:	(NSNotification *)notification;

@end