/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXSession is an NSDocument subclass which encapsulates a single DOS emulation session.
//It manages an underlying BXEmulator (configuring, starting and stopping it), reads and writes
//the gamebox for the session (if any), and creates the various window controllers for the session.

//BXSession is extended by separate categories that encapsulate different aspects of functionality
//(mostly for controlling the emulator.)

#import <Cocoa/Cocoa.h>
#import "BXEmulator.h"

@class BXEmulator;
@class BXSessionWindowController;
@class BXInspectorController;
@class BXPackage;
@class BXFrameBuffer;

@interface BXSession : NSDocument
{
	BXSessionWindowController *mainWindowController;
	
	BXPackage *gamePackage;
	BXEmulator *emulator;
	NSString *targetPath;
	NSString *activeProgramPath;
	BOOL hasConfigured;
	BOOL hasLaunched;
	BOOL showProgramPanelOnReturnToShell;
}


#pragma mark -
#pragma mark Properties

//The main window controller, responsible for the BXSessionWindow that displays this session.
@property (assign) BXSessionWindowController *mainWindowController;

//The underlying emulator process for this session. This is created during [BXSession start].
@property (retain) BXEmulator *emulator;

//The gamebox for this session. BXSession retrieves bundled drives, configuration files and
//target program from this during emulator configuration.
//Will be nil if an executable file or folder was opened outside of a gamebox.
@property (retain) BXPackage *gamePackage;

//The OS X path of the executable to launch (or folder to switch to) when the emulator starts.
@property (copy) NSString *targetPath;

//The OS X path of the currently executing DOS program or batch file. Will be nil if the
//emulator is at the DOS prompt, or when Boxer has no idea what program is running.
@property (copy) NSString *activeProgramPath;

@property (readonly) BOOL hasStarted;	//Whether the emulator session has been started.
@property (readonly) BOOL isEmulating;	//Whether the emulator session is initialized and ready to receive modifications.


#pragma mark -
#pragma mark Methods

//Start up the DOS emulator.
//This is currently called automatically by showWindow, meaning that emulation starts
//as soon as the session window appears.
- (void) start;

//Shut down the DOS emulator.
- (void) cancel;



//Returns a best-guess name for the current game.
//Currently, this means NSDocument displayName minus any ".boxer" extension.
- (NSString *) gameDisplayName;

//Returns a display-ready title for the currently-executing DOS process.
//Returns nil if there is currently no process executing.
- (NSString *) processDisplayName;



//Returns whether this session has a gamebox or not.
//TODO: replace this with just a check against [BXSession gamePackage].
- (BOOL) isGamePackage;

//A 'unique' identifier for the current session, currently equivalent to the gamebox filename.
//This is used to persist gamebox-specific data such as window size.
//TODO: this belongs as a property of the underlying gamebox instead.
- (NSString *) uniqueIdentifier;

//The icon for this DOS session. Currently this corresponds exactly to the gamebox's cover art image.
- (NSImage *)representedIcon;
- (void) setRepresentedIcon: (NSImage *)icon;

//Returns an array of dictionaries describing the available executables in the current gamebox (if any).
//TODO: these are used solely by UI code, and could be replaced instead with value transformers referring
//to properties on the current gamebox
- (NSArray *) executables;

//Returns an array of dictionaries describing the available documentation in the current gamebox (if any).
- (NSArray *) documentation;

@end


//Methods in this category are not intended to be called outside of BXSession.
@interface BXSession (BXSessionInternals)

#pragma mark -
#pragma mark Initializing the DOS session

//Create our BXEmulator instance and starts its main loop.
//Called internally by [BXSession start], deferred to the end of the main thread's event loop to prevent
//DOSBox blocking cleanup code.
- (void) _startEmulator;

//Set up the emulator context with drive mounts and other configuration settings specific to this session.
//Called in response to the BXEmulatorWillLoadConfiguration event, once the emulator is initialised enough
//for us to configure it.
- (void) _configureEmulator;

//Start up the target program for this session (if any) and displays the program panel selector after this
//finishes. Called by runLaunchCommands, once the emulator has finished processing configuration files.
- (void) _launchTarget;

//These are called directly by BXShell in response to DOS shell commands that we ourselves have injected
//into AUTOEXEC.BAT, so that Boxer performs its startup routine at the right moments.
- (void) runPreflightCommands;
- (void) runLaunchCommands;


#pragma mark -
#pragma mark Responding to changes in emulation state

//These are delegate methods called by BXEmulator at various points during the emulator's lifecycle.
- (void) didReturnToShell:		(NSNotification *)notification;
- (void) programWillStart:		(NSNotification *)notification;
- (void) programDidFinish:		(NSNotification *)notification;

- (void) didStartGraphicalContext:	(NSNotification *)notification;
- (void) didEndGraphicalContext:	(NSNotification *)notification;

- (void) didChangeEmulationState:	(NSNotification *)notification;


- (void) frameComplete: (BXFrameBuffer *)frame;
- (NSSize) viewportSize;
- (NSSize) maxFrameSize;
@end