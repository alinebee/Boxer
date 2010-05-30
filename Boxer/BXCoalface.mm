/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXCoalface.h"
#import "BXEmulator+BXRendering.h"
#import "BXEmulator+BXShell.h"
#import "BXEmulator+BXDOSFileSystem.h"
#import "BXInputHandler.h"

#import "video.h"
#import "sdlmain.h"


#pragma mark -
#pragma mark Application state functions

//This is called at the start of GFX_Events in DOSBox's sdlmain.cpp, to allow us to perform initial actions every time the event loop runs. Return YES to skip the event loop.
bool boxer_handleEventLoop()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _handleEventLoop];
}

//This is called at the start of DOSBox_NormalLoop, and allows us to short-circuit the current run loop if needed.
bool boxer_handleRunLoop()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _handleRunLoop];	
}

//Notifies Boxer of changes to title and speed settings
//This is called by GFX_SetTitle in DOSBox's sdlmain.cpp, instead of trying to set the window title through SDL
bool boxer_handleDOSBoxTitleChange(int newCycles, int newFrameskip, bool newPaused)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _syncWithEmulationState];
	return YES;
}

void boxer_applyConfigFiles()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _applyConfiguration];
}

bool boxer_isCancelled()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator isCancelled];	
}


#pragma mark -
#pragma mark Rendering functions

//Applies Boxer's rendering settings when reinitializing the DOSBox renderer
//This is called by RENDER_Reset in DOSBox's gui/render.cpp
void boxer_applyRenderingStrategy()	{ [[BXEmulator currentEmulator] _applyRenderingStrategy]; }

void boxer_prepareForSize(Bitu width, Bitu height, double scalex, double scaley, GFX_CallBack_t callback)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	
	NSSize outputSize	= NSMakeSize((CGFloat)width, (CGFloat)height);
	NSSize scale		= NSMakeSize((CGFloat)scalex, (CGFloat)scaley);
	[emulator _prepareForOutputSize: outputSize atScale: scale];
	
	sdl.draw.callback=callback;
	sdl.desktop.type=SCREEN_OPENGL;
	//TODO: none of these should actually be used by live code anymore.
	//If anywhere is using them, it needs to be excised forthwith.
	sdl.draw.width=width;
	sdl.draw.height=height;
	sdl.draw.scalex=scalex;
	sdl.draw.scaley=scaley;
}

bool boxer_startFrame(Bit8u **frameBuffer, Bitu *pitch)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _startFrameWithBuffer: (void **)frameBuffer pitch: (NSUInteger *)pitch];
}

void boxer_finishFrame(const uint16_t *dirtyBlocks)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _finishFrameWithChanges: dirtyBlocks];	
}


#pragma mark -
#pragma mark Shell-related functions

//Catch shell input and send it to our own shell controller - returns YES if we've handled the command,
//NO if we want to let it go through
//This is called by DOS_Shell::DoCommand in DOSBox's shell/shell_cmds.cpp, to allow us to hook into what
//goes on in the shell
bool boxer_shouldRunShellCommand(char* cmd, char* args)
{
	NSString *command			= [NSString stringWithCString: cmd	encoding: BXDirectStringEncoding];
	NSString *argumentString	= [NSString stringWithCString: args	encoding: BXDirectStringEncoding];
	
	BXEmulator *emulator	= [BXEmulator currentEmulator];
	return [emulator _handleCommand: command withArgumentString: argumentString];
}


//Return a localized string for the given DOSBox translation key
//This is called by MSG_Get in DOSBox's misc/messages.cpp, instead of retrieving strings from its own localisation system
const char * boxer_localizedStringForKey(char const *keyStr)
{
	NSString *theKey			= [NSString stringWithCString: keyStr encoding: BXDirectStringEncoding];
	NSString *localizedString	= [[NSBundle mainBundle]
								   localizedStringForKey: theKey
								   value: nil
								   table: @"DOSBox"];
	
	return [localizedString cStringUsingEncoding: BXDisplayStringEncoding];
}

bool boxer_handleCommandInput(char *cmd, Bitu *cursorPosition, bool *executeImmediately)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	NSString *newCommand = [emulator _handleCommandInput: [NSString stringWithCString: cmd encoding: BXDirectStringEncoding]
										atCursorPosition: cursorPosition
									  executeImmediately: (BOOL *)executeImmediately];
	if (newCommand)
	{
		const char *newcmd = [newCommand cStringUsingEncoding: BXDirectStringEncoding];
		strcpy(cmd, newcmd);
		return YES;
	}
	else return NO;
}

void boxer_didReturnToShell()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _didReturnToShell];
}

void boxer_autoexecDidStart()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _willRunStartupCommands];
}

void boxer_autoexecDidFinish()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _didRunStartupCommands];
}

void boxer_willExecuteFileAtDOSPath(const char *dosPath, Bit8u driveIndex)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _willExecuteFileAtDOSPath: dosPath onDrive: driveIndex];
}

void boxer_didExecuteFileAtDOSPath(const char *dosPath, Bit8u driveIndex)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _didExecuteFileAtDOSPath: dosPath onDrive: driveIndex];
}


#pragma mark -
#pragma mark Filesystem functions

//Whether or not to allow the specified path to be mounted.
//Called by MOUNT::Run in DOSBox's dos/dos_programs.cpp.
bool boxer_shouldMountPath(const char *filePath)
{
	NSString *thePath = [[NSFileManager defaultManager]
						 stringWithFileSystemRepresentation: filePath
						 length: strlen(filePath)];
	
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _shouldMountPath: thePath];
}

//Whether to include a file with the specified name in DOSBox directory listings
bool boxer_shouldShowFileWithName(const char *name)
{
	NSString *fileName = [NSString stringWithCString: name encoding: BXDirectStringEncoding];
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _shouldShowFileWithName: fileName];
}

//Whether to allow write access to the file at the specified path on the local filesystem
bool boxer_shouldAllowWriteAccessToPath(const char *filePath, Bit8u driveIndex)
{
	NSString *thePath	= [[NSFileManager defaultManager]
						   stringWithFileSystemRepresentation: filePath
						   length: strlen(filePath)];
	
	BXEmulator *emulator = [BXEmulator currentEmulator];
	BXDrive *drive = [emulator driveAtLetter: [emulator _driveLetterForIndex: driveIndex]];
	return [emulator _shouldAllowWriteAccessToPath: thePath onDrive: drive];
}

//Tells Boxer to resync its cached drives - called by DOSBox functions that add/remove drives
void boxer_driveDidMount(Bit8u driveIndex)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _syncDriveCache];
}
void boxer_driveDidUnmount(Bit8u driveIndex)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _syncDriveCache];
}


#pragma mark -
#pragma mark Input-related functions

//Returns the DOSBox keyboard code that most closely corresponds to the current OS X keyboard layout
const char * boxer_currentDOSKeyboardLayout()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	NSString *layoutCode = [[emulator inputHandler] keyboardLayoutForCurrentInputMethod];
	return [layoutCode cStringUsingEncoding: BXDirectStringEncoding];
}

void boxer_setMouseActive(bool mouseActive)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[[emulator inputHandler] setMouseActive: mouseActive];
}

void boxer_mouseMovedToPoint(float x, float y)
{
	NSPoint point = NSMakePoint((CGFloat)x, (CGFloat)y);
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[[emulator inputHandler] setMousePosition: point];
}

SDLMod boxer_currentSDLModifiers()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [[emulator inputHandler] currentSDLModifiers];
}
