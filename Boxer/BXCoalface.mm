/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXCoalface.h"
#import "BXEmulatorPrivate.h"
#import "setup.h"
#import "mapper.h"
#import "cross.h"
#import "shell.h"
#import "ADBFilesystem.h"

#pragma mark - Runloop state functions

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


#pragma mark - Rendering functions

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


#pragma mark - Shell-related functions

void boxer_shellWillStart(DOS_Shell *shell)
{
	[[BXEmulator currentEmulator] _shellWillStart: shell];
}

void boxer_shellDidFinish(DOS_Shell *shell)
{
	[[BXEmulator currentEmulator] _shellDidFinish: shell];
}

bool boxer_shellShouldContinue(DOS_Shell *shell)
{
	return ![BXEmulator currentEmulator].isCancelled;
}

//Catch shell input and send it to our own shell controller - returns YES if we've handled the command,
//NO if we want to let it go through
//This is called by DOS_Shell::DoCommand in DOSBox's shell/shell_cmds.cpp, to allow us to hook into what
//goes on in the shell
bool boxer_shellShouldRunCommand(DOS_Shell *shell, char* cmd, char* args)
{
	NSString *command			= [NSString stringWithCString: cmd	encoding: BXDirectStringEncoding];
	NSString *argumentString	= [NSString stringWithCString: args	encoding: BXDirectStringEncoding];
	
	BXEmulator *emulator = [BXEmulator currentEmulator];
	return ![emulator _handleCommand: command withArgumentString: argumentString];
}

bool boxer_handleShellCommandInput(DOS_Shell *shell, char *cmd, Bitu *cursorPosition, bool *executeImmediately)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    NSString *inOutCommand = [NSString stringWithCString: cmd encoding: BXDirectStringEncoding];
	
    if ([emulator _handleCommandInput: &inOutCommand
                       cursorPosition: (NSUInteger *)cursorPosition
                       executeCommand: (BOOL *)executeImmediately])
	{
		const char *newcmd = [inOutCommand cStringUsingEncoding: BXDirectStringEncoding];
		if (newcmd)
		{
            strlcpy(cmd, newcmd, CMD_MAXLINE);
            return YES;
		}
		else return NO;
	}
	return false;
}

bool boxer_executeNextPendingCommandForShell(DOS_Shell *shell)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
	return [emulator _executeNextPendingCommand];
}

bool boxer_hasPendingCommandsForShell(DOS_Shell *shell)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
	return emulator.commandQueue.count > 0;
}

void boxer_shellWillReadCommandInputFromHandle(DOS_Shell *shell, Bit16u handle)
{
    if (handle == STDIN)
    {
        BXEmulator *emulator = [BXEmulator currentEmulator];
        emulator.waitingForCommandInput = YES;
    }
}
void boxer_shellDidReadCommandInputFromHandle(DOS_Shell *shell, Bit16u handle)
{
    if (handle == STDIN)
    {
        BXEmulator *emulator = [BXEmulator currentEmulator];
        emulator.waitingForCommandInput = NO;
    }
}

void boxer_didReturnToShell(DOS_Shell *shell)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _didReturnToShell];
}

void boxer_shellWillStartAutoexec(DOS_Shell *shell)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
	[emulator _willRunStartupCommands];
}

void boxer_shellWillExecuteFileAtDOSPath(DOS_Shell *shell, const char *path, const char *arguments)
{	
    BXEmulator *emulator = [BXEmulator currentEmulator];
    [emulator _willExecuteFileAtDOSPath: path withArguments: arguments isBatchFile: NO];
}

void boxer_shellDidExecuteFileAtDOSPath(DOS_Shell *shell, const char *path)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    [emulator _didExecuteFileAtDOSPath: path];
}

void boxer_shellWillBeginBatchFile(DOS_Shell *shell, const char *path, const char *arguments)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    [emulator _willExecuteFileAtDOSPath: path withArguments: arguments isBatchFile: YES];
}

void boxer_shellDidEndBatchFile(DOS_Shell *shell, const char *canonicalPath)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    [emulator _didExecuteFileAtDOSPath: canonicalPath];
}

bool boxer_shellShouldDisplayStartupMessages(DOS_Shell *shell)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _shouldDisplayStartupMessagesForShell: shell];
}


#pragma mark - Filesystem functions

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
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _openFileAtLocalPath: path onDOSBoxDrive: drive inMode: mode];
}

bool boxer_removeLocalFile(const char *path, DOS_Drive *drive)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _removeFileAtLocalPath: path onDOSBoxDrive: drive];
}

bool boxer_moveLocalFile(const char *fromPath, const char *toPath, DOS_Drive *drive)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _moveLocalPath: fromPath toLocalPath: toPath onDOSBoxDrive: drive];
}

bool boxer_createLocalDir(const char *path, DOS_Drive *drive)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _createDirectoryAtLocalPath: path onDOSBoxDrive: drive];
}

bool boxer_removeLocalDir(const char *path, DOS_Drive *drive)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _removeDirectoryAtLocalPath: path onDOSBoxDrive: drive];
}

bool boxer_getLocalPathStats(const char *path, DOS_Drive *drive, struct stat *outStatus)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _getStats: outStatus forLocalPath: path onDOSBoxDrive: drive];
}

bool boxer_localDirectoryExists(const char *path, DOS_Drive *drive)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _localDirectoryExists: path onDOSBoxDrive: drive];
}

bool boxer_localFileExists(const char *path, DOS_Drive *drive)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    return [emulator _localFileExists: path onDOSBoxDrive: drive];
}

#pragma mark Directory enumeration

void *boxer_openLocalDirectory(const char *path, DOS_Drive *drive)
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    id <ADBFilesystemFileURLEnumeration> enumerator = [emulator _directoryEnumeratorForLocalPath: path
                                                                                        onDOSBoxDrive: drive];
    
    NSCAssert1(enumerator != nil, @"No enumerator found for %s", path);
    
    //Our own enumerators don't include directory entries for . and ..,
    //which are expected by DOSBox. So, we insert them ourselves during iteration.
    NSMutableArray *fakeEntries = [NSMutableArray arrayWithObjects: @".", @"..", nil];
    
    //The dictionary will be released when the calling context calls boxer_closeLocalDirectory() with the pointer to the dictionary.
    NSDictionary *enumeratorInfo = @{ @"enumerator": enumerator, @"fakeEntries": fakeEntries };
    
    return (__bridge void *)[enumeratorInfo retain];
}

void boxer_closeLocalDirectory(void *handle)
{
    NSDictionary *enumeratorInfo = (__bridge NSDictionary *)handle;
    [enumeratorInfo release];
}

bool boxer_getNextDirectoryEntry(void *handle, char *outName, bool &isDirectory)
{
    NSDictionary *enumeratorInfo = (__bridge NSDictionary *)handle;
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
        id <ADBFilesystemFileURLEnumeration> enumerator = [enumeratorInfo objectForKey: @"enumerator"];
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


#pragma mark - Input functions

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

bool boxer_continueListeningForKeyEvents()
{
    BXEmulator *emulator = [BXEmulator currentEmulator];
    if (emulator.isCancelled || (emulator.isWaitingForCommandInput && emulator.commandQueue.count))
    {
        return false;
    }
    return true;
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


#pragma mark - Printer functions

Bitu boxer_PRINTER_readdata(Bitu port,Bitu iolen)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    return emulator.printer.dataRegister;
}

void boxer_PRINTER_writedata(Bitu port,Bitu val,Bitu iolen)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    emulator.printer.dataRegister = val;
}

Bitu boxer_PRINTER_readstatus(Bitu port,Bitu iolen)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    return emulator.printer.statusRegister;
}

void boxer_PRINTER_writecontrol(Bitu port,Bitu val, Bitu iolen)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    emulator.printer.controlRegister = val;
}

Bitu boxer_PRINTER_readcontrol(Bitu port,Bitu iolen)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    return emulator.printer.controlRegister;
}

bool boxer_PRINTER_isInited(Bitu port)
{
	BXEmulator *emulator = [BXEmulator currentEmulator];
    //Tell the emulator we actually want a printer
    [emulator _didRequestPrinterOnLPTPort: port];
    return emulator.printer != nil;
}

#pragma mark - Helper functions

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
    char errorReason[1024];
	va_list params;
	va_start(params, format);
	vsnprintf(errorReason, sizeof(errorReason), format, params);
	va_end(params);
    
    throw boxer_emulatorException(errorReason, fileName, functionName, lineNumber);
}


#pragma mark - No-ops

//These used to be defined in sdl_mapper.cpp, which we no longer include in Boxer.
void MAPPER_AddHandler(MAPPER_Handler * handler,MapKeys key,Bitu mods,char const * const eventname,char const * const buttonname) {}
void MAPPER_Init(void) {}
void MAPPER_StartUp(Section * sec) {}
void MAPPER_Run(bool pressed) {}
void MAPPER_RunInternal() {}
void MAPPER_LosingFocus(void) {}