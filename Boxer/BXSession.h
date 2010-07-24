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
#import "BXEmulatorDelegate.h"

@class BXEmulator;
@class BXPackage;
@class BXGameProfile;
@class BXSessionWindowController;

@interface BXSession : NSDocument <BXEmulatorDelegate>
{	
	BXEmulator *emulator;
	BXPackage *gamePackage;
	BXGameProfile *gameProfile;
	NSMutableDictionary *gameSettings;
	
	NSMutableArray *drives;
	
	BXSessionWindowController *mainWindowController;
	
	NSString *targetPath;
	NSString *activeProgramPath;
	NSString *temporaryFolderPath;
	
	BOOL hasStarted;
	BOOL hasConfigured;
	BOOL hasLaunched;
	BOOL isClosing;
}


#pragma mark -
#pragma mark Properties

//The main window controller, responsible for the BXSessionWindow that displays this session.
@property (retain, nonatomic) BXSessionWindowController *mainWindowController;

//The underlying emulator process for this session. This is created during [BXSession start].
@property (retain, nonatomic) BXEmulator *emulator;

//The gamebox for this session. BXSession retrieves bundled drives, configuration files and
//target program from this during emulator configuration.
//Will be nil if an executable file or folder was opened outside of a gamebox.
@property (retain, nonatomic) BXPackage *gamePackage;

//The autodetected game profile for this session. Used for various emulator configuration tasks.
@property (retain, nonatomic) BXGameProfile *gameProfile;

//A general store of configuration settings for this session.
//These are retrieved and stored in the user defaults system, keyed to each gamebox
//(the settings for 'regular' sessions are not stored).
@property (readonly, retain, nonatomic) NSMutableDictionary *gameSettings;

//The OS X path of the executable to launch (or folder to switch to) when the emulator starts.
@property (copy, nonatomic) NSString *targetPath;

//The OS X path of the currently executing DOS program or batch file. Will be nil if the
//emulator is at the DOS prompt, or when Boxer has no idea what program is running.
@property (readonly, copy, nonatomic) NSString *activeProgramPath;

//A cache of the emulator's drives.
@property (readonly, retain, nonatomic) NSArray *drives;

//Whether the emulator is initialized and ready to receive instructions.
@property (readonly) BOOL isEmulating;

//Whether this session represents a gamebox.
@property (readonly) BOOL isGamePackage;


#pragma mark -
#pragma mark Lifecycle control methods

//Start up the DOS emulator.
//This is currently called automatically by showWindow, meaning that emulation starts
//as soon as the session window appears.
- (void) start;

//Shut down the DOS emulator.
- (void) cancel;

//Save our document-specific settings to disk. Called when the document is closed and when
//the application is quit.
- (void) synchronizeSettings;


//Returns a display-ready title for the currently-executing DOS process.
//Returns nil if there is currently no process executing.
- (NSString *) processDisplayName;


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
