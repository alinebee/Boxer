/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXCoalface.h"
#import "BXEmulatorPrivate.h"
#import "setup.h"
#import "mapper.h"
#import "cross.h"
#import "BXFilesystem.h"

#pragma mark -
#pragma mark Application state functions

//This is called in place of DOSBox's GFX_Events to allow us to process events when the DOSBox
//core runloop gives us time.
void boxer_processEvents()
{
	[[BXEmulator currentEmulator] _processEvents];
}

//Called at the start and end of every iteration of DOSBOX_RunMachine.
void boxer_runLoopWillStartWithContextInfo(void **contextInfo)
{
	[[BXEmulator currentEmulator] _runLoopWillStartWithContextInfo: contextInfo];
}

void boxer_runLoopDidFinishWithContextInfo(void *contextInfo)
{
	[[BXEmulator currentEmulator] _runLoopDidFinishWithContextInfo: contextInfo];
}

//This is called at the start of DOSBox_NormalLoop, and
///allows us to short-circuit the current run loop if needed.
bool boxer_runLoopShouldContinue()
{
	return [[BXEmulator currentEmulator] _runLoopShouldContinue];
}

//Notifies Boxer of changes to title and speed settings
void boxer_handleDOSBoxTitleChange(Bit32s newCycles, Bits newFrameskip, bool newPaused)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _didChangeEmulationState];
}


#pragma mark -
#pragma mark Rendering functions

void boxer_applyRenderingStrategy()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[[emulator videoHandler] applyRenderingStrategy];
}

Bitu boxer_prepareForFrameSize(Bitu width, Bitu height, Bitu gfx_flags, double scalex, double scaley, GFX_CallBack_t callback)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	
	NSSize outputSize	= NSMakeSize((CGFloat)width, (CGFloat)height);
	NSSize scale		= NSMakeSize((CGFloat)scalex, (CGFloat)scaley);
	[[emulator videoHandler] prepareForOutputSize: outputSize atScale: scale withCallback: callback];
	
	return GFX_CAN_32 | GFX_SCALING;
}

Bitu boxer_idealOutputMode(Bitu flags)
{
	//Originally this tested various bit depths to find the most appropriate mode for the chosen scaler.
	//Because OS X always uses a 32bpp context and Boxer always uses RGBA-capable scalers, we ignore the
	//original function's behaviour altogether and just return something that will keep DOSBox happy.
	return GFX_CAN_32 | GFX_SCALING;
}

bool boxer_startFrame(Bit8u **frameBuffer, Bitu *pitch)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [[emulator videoHandler] startFrameWithBuffer: (void **)frameBuffer pitch: (NSUInteger *)pitch];
}

void boxer_finishFrame(const uint16_t *dirtyBlocks)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[[emulator videoHandler] finishFrameWithChanges: dirtyBlocks];	
}

Bitu boxer_getRGBPaletteEntry(Bit8u red, Bit8u green, Bit8u blue)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [[emulator videoHandler] paletteEntryWithRed: red green: green blue: blue];
}

void boxer_setPalette(Bitu start,Bitu count,GFX_PalEntry * entries)
{
	//This replacement DOSBox function does nothing, as the original was intended only for SDL
	//surface palettes which are irrelevant to OpenGL.
	//Furthermore it should never be called: if it does, that means DOSBox thinks it's using
	//surface output and this is a bug.
	NSCAssert(NO, @"boxer_setPalette called. This is a bug and should never happen.");
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
	
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _handleCommand: command withArgumentString: argumentString];
}


//Return a localized string for the given DOSBox translation key
//This is called by MSG_Get in DOSBox's misc/messages.cpp, instead of retrieving strings from its own localisation system
const char * boxer_localizedStringForKey(char const *keyStr)
{
	NSString *theKey			= [NSString stringWithCString: keyStr encoding: BXDirectStringEncoding];
	NSString *localizedString	= [[NSBundle mainBundle]
								   localizedStringForKey: theKey
								   value: @"" //If the key isn't found, display nothing
								   table: @"DOSBox"];
	
	return [localizedString cStringUsingEncoding: BXDisplayStringEncoding];
}

bool boxer_handleCommandInput(char *cmd, Bitu *cursorPosition, bool *executeImmediately)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	NSString *oldCommandLine = [NSString stringWithCString: cmd encoding: BXDirectStringEncoding];
	NSString *newCommandLine = [emulator _handleCommandInput: oldCommandLine
											atCursorPosition: (NSUInteger *)cursorPosition
										  executeImmediately: (BOOL *)executeImmediately];
	if (newCommandLine)
	{
		const char *newcmd = [newCommandLine cStringUsingEncoding: BXDirectStringEncoding];
		if (newcmd)
		{
			strcpy(cmd, newcmd);
			return YES;
		}
		else return NO;
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

void boxer_willExecuteFileAtDOSPath(const char *path, const char *arguments, DOS_Drive *dosboxDrive)
{
	NSArray *argList = nil;
    if (strlen(arguments) > 0)
    {
        NSString *stringArgs = [[NSString stringWithCString: arguments encoding: BXDirectStringEncoding] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
        if (stringArgs.length)
            argList = [stringArgs componentsSeparatedByString: @" "];
    }
	
    BXEmulator *emulator = [BXEmulator currentEmulator];
    [emulator _willExecuteFileAtDOSPath: path onDOSBoxDrive: dosboxDrive withArguments: argList];
}

void boxer_didExecuteFileAtDOSPath(const char *path, const char *arguments, DOS_Drive *dosboxDrive)
{
	NSArray *argList = nil;
    if (strlen(arguments) > 0)
    {
        NSString *stringArgs = [[NSString stringWithCString: arguments encoding: BXDirectStringEncoding] stringByTrimmingCharactersInSet: [NSCharacterSet whitespaceCharacterSet]];
        if (stringArgs.length)
            argList = [stringArgs componentsSeparatedByString: @" "];
    }
	
    BXEmulator *emulator = [BXEmulator currentEmulator];
    [emulator _didExecuteFileAtDOSPath: path onDOSBoxDrive: dosboxDrive withArguments: argList];
}


#pragma mark -
#pragma mark Filesystem functions

#define boxer_pathFromCPath(path) ([[NSFileManager defaultManager] stringWithFileSystemRepresentation: path length: strlen(path)])

//Whether or not to allow the specified path to be mounted.
//Called by MOUNT::Run in DOSBox's dos/dos_programs.cpp.
bool boxer_shouldMountPath(const char *path)
{
	NSString *localPath = boxer_pathFromCPath(path);
	
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _shouldMountPath: localPath];
}

//Whether to include a file with the specified name in DOSBox directory listings
bool boxer_shouldShowFileWithName(const char *name)
{
	NSString *fileName = [NSString stringWithCString: name encoding: BXDirectStringEncoding];
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _shouldShowFileWithName: fileName];
}

//Whether to allow write access to the file at the specified path on the local filesystem
bool boxer_shouldAllowWriteAccessToPath(const char *path, DOS_Drive *dosboxDrive)
{
	NSString *localPath = boxer_pathFromCPath(path);
	
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _shouldAllowWriteAccessToPath: localPath onDOSBoxDrive: dosboxDrive];
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

void boxer_didCreateLocalFile(const char *path, DOS_Drive *dosboxDrive)
{
	NSString *localPath = boxer_pathFromCPath(path);	

	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _didCreateFileAtPath: localPath onDOSBoxDrive: dosboxDrive];
}

void boxer_didRemoveLocalFile(const char *path, DOS_Drive *dosboxDrive)
{
	NSString *localPath = boxer_pathFromCPath(path);
	
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _didRemoveFileAtPath: localPath onDOSBoxDrive: dosboxDrive];
}



FILE * boxer_openLocalFile(const char *path, DOS_Drive *drive, const char *mode)
{
    NSString *localPath = boxer_pathFromCPath(path);
    
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _openFileAtLocalPath: localPath onDOSBoxDrive: drive inMode: mode];
}

bool boxer_removeLocalFile(const char *path, DOS_Drive *drive)
{
    NSString *localPath = boxer_pathFromCPath(path);
    
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _removeFileAtLocalPath: localPath onDOSBoxDrive: drive];
}

bool boxer_moveLocalFile(const char *fromPath, const char *toPath, DOS_Drive *drive)
{
    NSString *localFromPath = boxer_pathFromCPath(fromPath);
    NSString *localToPath = boxer_pathFromCPath(toPath);
    
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _moveLocalPath: localFromPath toLocalPath: localToPath onDOSBoxDrive: drive];   
}

bool boxer_createLocalDir(const char *path, DOS_Drive *drive)
{
    NSString *localPath = boxer_pathFromCPath(path);
    
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _createDirectoryAtLocalPath: localPath onDOSBoxDrive: drive];
}

bool boxer_removeLocalDir(const char *path, DOS_Drive *drive)
{
    NSString *localPath = boxer_pathFromCPath(path);
    
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _removeDirectoryAtLocalPath: localPath onDOSBoxDrive: drive];
}

bool boxer_getLocalPathStats(const char *path, DOS_Drive *drive, struct stat *outStatus)
{
    NSString *localPath = boxer_pathFromCPath(path);
    
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _getStats: outStatus forLocalPath: localPath onDOSBoxDrive: drive];
}

bool boxer_localDirectoryExists(const char *path, DOS_Drive *drive)
{
    NSString *localPath = boxer_pathFromCPath(path);
    
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _localDirectoryExists: localPath onDOSBoxDrive: drive];
}

bool boxer_localFileExists(const char *path, DOS_Drive *drive)
{
    NSString *localPath = boxer_pathFromCPath(path);
    
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _localFileExists: localPath onDOSBoxDrive: drive];
}

#pragma mark -
#pragma mark Directory enumeration

void *boxer_openLocalDirectory(const char *path, DOS_Drive *drive)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    NSString *localPath = boxer_pathFromCPath(path);
    id <BXFilesystemEnumerator> enumerator = [emulator _directoryEnumeratorForLocalPath: localPath onDOSBoxDrive: drive];
    
    //Our fancy Cocoa enumerator doesn't include directory entries for . and ..,
    //which are expected by DOSBox. So, we insert them ourselves during iteration.
    NSMutableArray *fakeEntries = [NSMutableArray arrayWithObjects: @".", @"..", nil];
    
    //The dictionary will be released when the calling context calls boxer_closeLocalDirectory() with the pointer to the dictionary.
    NSDictionary *enumeratorInfo = [[NSDictionary alloc] initWithObjectsAndKeys:
                                    enumerator, @"enumerator",
                                    fakeEntries, @"fakeEntries",
                                    nil];
    
    return enumeratorInfo;
}

void boxer_closeLocalDirectory(void *handle)
{
    NSDictionary *enumeratorInfo = (NSDictionary *)handle;
    [enumeratorInfo release];
}

bool boxer_getNextDirectoryEntry(void *handle, char *outName, bool &isDirectory)
{
    NSDictionary *enumeratorInfo = (NSDictionary *)handle;
    NSMutableArray *fakeEntries = [enumeratorInfo objectForKey: @"fakeEntries"];
    
    if (fakeEntries.count)
    {
        const char *nextFakeEntry = [[fakeEntries objectAtIndex: 0] fileSystemRepresentation];
        strlcpy(outName, nextFakeEntry, CROSS_LEN);
        
        [fakeEntries removeObjectAtIndex: 0];
        isDirectory = YES;
        return true;
    }
    else
    {
        id <BXFilesystemEnumerator> enumerator = [enumeratorInfo objectForKey: @"enumerator"];
        NSURL *nextURL = enumerator.nextObject;
        if (nextURL != nil)
        {
            NSNumber *directoryFlag = nil;
            NSString *fileName = nil;
            BOOL hasDirFlag = [nextURL getResourceValue: &directoryFlag forKey: NSURLIsDirectoryKey error: NULL];
            BOOL hasNameFlag = [nextURL getResourceValue: &fileName forKey: NSURLNameKey error: NULL];
            
            NSCAssert(hasNameFlag && hasDirFlag, @"Enumerator is missing directory and/or filename resources.");
            
            isDirectory = directoryFlag.boolValue;
            const char *nextEntry = fileName.fileSystemRepresentation;
            
            strlcpy(outName, nextEntry, CROSS_LEN);
            return true;
        }
        else return false;
    }
}


#pragma mark -
#pragma mark Input-related functions

const char * boxer_preferredKeyboardLayout()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	NSString *layoutCode = emulator.keyboard.preferredLayout;
    
    if (layoutCode)
        return [layoutCode cStringUsingEncoding: BXDirectStringEncoding];
    else return NULL;
}

Bitu boxer_numKeyCodesInPasteBuffer()
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    return emulator.keyBuffer.count;
}

bool boxer_getNextKeyCodeInPasteBuffer(Bit16u *outKeyCode, bool consumeKey)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    
    [emulator _polledBIOSKeyBuffer];
    
    UInt16 keyCode = (consumeKey) ? emulator.keyBuffer.nextKey : emulator.keyBuffer.currentKey;
    if (keyCode != BXNoKey)
    {
        *outKeyCode = keyCode;
        return true;
    }
    else return false;
}

void boxer_setMouseActive(bool mouseActive)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	emulator.mouse.active = mouseActive;
}

void boxer_setJoystickActive(bool joystickActive)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	emulator.joystickActive = joystickActive;
}

void boxer_mouseMovedToPoint(float x, float y)
{
	NSPoint point = NSMakePoint((CGFloat)x, (CGFloat)y);
	BXEmulator *emulator = [BXEmulator currentEmulator];
	emulator.mouse.position = point;
}

void boxer_setCapsLockActive(bool active)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    emulator.keyboard.capsLockEnabled = active;
}

void boxer_setNumLockActive(bool active)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    emulator.keyboard.numLockEnabled = active;
}

void boxer_setScrollLockActive(bool active)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    emulator.keyboard.scrollLockEnabled = active;
}

#pragma mark -
#pragma mark Helper functions

void boxer_log(char const* format,...)
{
#ifdef BOXER_DEBUG
	//Copypasta from sdlmain.cpp
	char buf[512];
	va_list msg;
	va_start(msg,format);
	vsprintf(buf,format,msg);
	strcat(buf,"\n");
	va_end(msg);
	printf("%s",buf);
#endif
}

void boxer_die(const char *functionName, const char *fileName, int lineNumber, const char * format,...)
{
	char err[512];
	va_list params;
	va_start(params, format);
	vsprintf(err, format, params);
	va_end(params);

    [[NSAssertionHandler currentHandler] handleFailureInFunction: [NSString stringWithCString: functionName encoding: NSASCIIStringEncoding]
                                                            file: [NSString stringWithCString: fileName encoding: NSASCIIStringEncoding]
                                                      lineNumber: lineNumber
                                                     description: [NSString stringWithCString: err encoding: NSASCIIStringEncoding], nil];
}


double boxer_realTime()
{
	return CFAbsoluteTimeGetCurrent();
}


#pragma mark -
#pragma mark No-ops

//These used to be defined in sdl_mapper.cpp, which we no longer include in Boxer.
void MAPPER_AddHandler(MAPPER_Handler * handler,MapKeys key,Bitu mods,char const * const eventname,char const * const buttonname) {}
void MAPPER_Init(void) {}
void MAPPER_StartUp(Section * sec) {}
void MAPPER_Run(bool pressed) {}
void MAPPER_RunInternal() {}
void MAPPER_LosingFocus(void) {}