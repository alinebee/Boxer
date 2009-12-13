/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXShell category extends BXEmulator to wrap DOSBox's shell operations. It intercepts shell
//commands from DOS for processing by Boxer, and can feed new commands directly to the shell.
//It also implements several new DOS commands.

#import <Cocoa/Cocoa.h>
#import "BXEmulator.h"


@interface BXEmulator (BXShell)

//Command processing
//------------------

//Runs the specified command string as if it had been typed on the commandline. Encoding should be either BXDirectStringEncoding or BXDisplayStringEncoding.
- (void) executeCommand: (NSString *)theString
			   encoding: (NSStringEncoding)encoding;

- (void) executeCommand: (NSString *)command
		  withArguments: (NSArray *)arguments
			   encoding: (NSStringEncoding)encoding;

//Launch the program at the specified DOS path.
//If changingDirectory is true, first switches the working directory to the program's containing directory;
//Otherwise the command will be executed as an absolute path, using the current directory as the working directory.
- (void) executeProgramAtPath: (NSString *)dosPath changingDirectory: (BOOL)changeDir;


//Prints the specified string to the DOS stdout, using DOS Latin-1 encoding.
- (void) displayString: (NSString *)theString;

//Returns a quoted escaped string, safe for use in DOS command arguments.
- (NSString *) quotedString: (NSString *)theString;



//DOS environment and configuration variables
//-------------------------------------------
//TODO: handle these internally instead of using shell commands.

//Set a DOS environment variable to the specified value, using the specified encoding.
- (void) setVariable: (NSString *)name
				  to: (NSString *)value
			encoding: (NSStringEncoding)encoding;

//Set a DOS configuration setting to the specified value.
- (void) setConfig:	(NSString *)name to: (NSString *)value;


//Buffering commands
//------------------

//Open and close nested command queues, to execute a series of commands as one batchfile-like operation.
//In practice, this does not execute them as a batch script but merely defers reprinting the command
//prompt until the queue(s) are closed.
- (void) openQueue;
- (void) closeQueue;
- (BOOL) isInQueue;

//Get/set whether the command prompt is 'dirty' and needs redrawing.
//This is called after changing the drive or working directory internally.
- (void) setPromptNeedsDisplay: (BOOL)redraw;
- (BOOL) promptNeedsDisplay;


//Actual shell commands you might want to call
//--------------------------------------------

//Retrieves the localized string for the specified key from Shell.strings and prints it to DOS using displayString:
- (id) displayStringFromKey: (NSString *)theKey;

//Displays the quit confirmation sheet after a game package has exited.
//TODO: move this to BXSession.
- (id) showPackageExitPrompt: (NSString *)argumentString;

//Displays a page of DOS shell commands.
//Call with "commands".
- (id) showShellCommandHelp: (NSString *)argumentString;

//Toggle between fullscreen and windowed mode.
//Call with "fullscreen".
//Accepts an optional argument: 1/0 or "true"/"false", to set fullscreen to a particular value.
//If argument is omitted, simply toggles fullscreen.
- (id) toggleFullScreen: (NSString *)argumentString;

//These commands hook into the AUTOEXEC process to execute Boxer's session commands at suitable points.
//These call corresponding methods on our session delegate.
- (id) runPreflightCommands: (NSString *)argumentString;
- (id) runLaunchCommands: (NSString *)argumentString;

//Lists all available drives, using Boxer's output syntax instead of DOSBox's.
//Call with "boxer_listMounts"
- (id) listMounts: (NSString *)argumentString;
@end


//The methods in this category should not be executed outside BXEmulator.
@interface BXEmulator (BXShellInternals)

//Called by BXEmulator to prepare the shell for shutdown.
- (void) _shutdownShell;

//Routes DOS commands to the appropriate selector according to commandList.
- (BOOL) _handleCommand: (NSString *)command withArgumentString: (NSString *)arguments;

//Runs the specified command string, bypassing the standard parsing and echoing behaviour.
//Used internally for rewriting and chaining commands.
- (void) _substituteCommand: (NSString *)theString encoding: (NSStringEncoding)encoding;


//Reprint the command prompt. Has no effect if called while a process is executing.
- (void) _redrawPrompt;

@end