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
#import "BXGameProfile.h"

@class BXEmulator;
@class BXPackage;
@class BXDOSWindowController;
@class UKFileWatcher;

@interface BXSession : NSDocument <BXEmulatorDelegate>
{	
	BXEmulator *emulator;
	BXPackage *gamePackage;
	BXGameProfile *gameProfile;
	NSMutableDictionary *gameSettings;
	
	NSMutableArray *drives;
	NSMutableDictionary *executables;
	NSMutableArray *documentation;
	
	BXDOSWindowController *DOSWindowController;
	
	NSString *targetPath;
	NSString *activeProgramPath;
	NSString *temporaryFolderPath;
	
	BOOL hasStarted;
	BOOL hasConfigured;
	BOOL hasLaunched;
	BOOL isClosing;
	BOOL emulating;
	BOOL showDriveNotifications;
	BOOL userToggledProgramPanel;
	
	NSOperationQueue *importQueue;
	
	UKFileWatcher *watcher;
}


#pragma mark -
#pragma mark Properties

//The main window controller, responsible for the BXDOSWindow that displays this session.
@property (retain, nonatomic) BXDOSWindowController *DOSWindowController;

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

//A cache of the designated executables, organised by drive.
@property (readonly, retain, nonatomic) NSDictionary *executables;

//A cache of the documentation found in this session's gamebox.
@property (readonly, retain, nonatomic) NSArray *documentation;

//Whether the emulator is initialized and ready to receive instructions.
@property (readonly, assign, nonatomic, getter=isEmulating) BOOL emulating;

//Whether this session represents a gamebox.
@property (readonly, nonatomic) BOOL isGamePackage;

//Whether the document should be closed when the emulator process finishes.
//Normally YES, may be overridden by BXSession subclasses. 
@property (readonly, nonatomic) BOOL shouldCloseOnEmulatorExit;

//The display-ready title for the currently-executing DOS process.
//Will be nil if there is currently no process executing.
@property (readonly, nonatomic) NSString *processDisplayName;

//The icon for this DOS session, which corresponds to the icon of the session's gamebox.
@property (copy, nonatomic) NSImage *representedIcon;

//Whether the user has manually toggled the program panel this session.
//BXSession uses this to finesse when it should auto-show/auto-hide the
//program panel in response to leaving/returning to the DOS prompt.
@property (assign) BOOL userToggledProgramPanel;


#pragma mark -
#pragma mark Helper class methods

//Autodetects and returns a profile for the specified path, using BXSession's rules
//for autodetection (q.v. BXFileManager gameDetectionPointForPath:shouldRecurse:)
+ (BXGameProfile *) profileForPath: (NSString *)path;

//Generates and returns a new bootleg cover-art image for the specified package,
//using the specified game era. If era is BXUnknownEra, a suitable era will be
//autodetected based on the size and age of the game's files.
+ (NSImage *) bootlegCoverArtForGamePackage: (BXPackage *)package
									withEra: (BXGameEra)era;


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

@end
