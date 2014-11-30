/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXCoalface defines C++-facing hooks which Boxer has injected into DOSBox functions to wrest
//control from DOSBox and pass it to Boxer at opportune moments. In many cases these functions
//are 1-to-1 replacements for DOSBox functions, remapped via #defines.


#ifndef BOXER
#define BOXER

#if __cplusplus
extern "C" {
#endif

#import "config.h"
#import "video.h"
#import <stdio.h>
	
//Remapped replacements for DOSBox's old sdlmain functions
#define GFX_Events boxer_processEvents
#define GFX_StartUpdate boxer_startFrame
#define GFX_EndUpdate boxer_finishFrame
#define Mouse_AutoLock boxer_setMouseActive
#define GFX_SetTitle boxer_handleDOSBoxTitleChange
#define GFX_SetSize boxer_prepareForFrameSize
#define GFX_GetRGB boxer_getRGBPaletteEntry
#define GFX_SetPalette boxer_setPalette
#define GFX_GetBestMode boxer_idealOutputMode
#define GFX_ShowMsg boxer_log
#define MIDI_Available boxer_MIDIAvailable
#define OpenCaptureFile boxer_openCaptureFile

#define E_Exit(format,...) boxer_die(__PRETTY_FUNCTION__, __FILE__, __LINE__, format, ##__VA_ARGS__)
	class DOS_Drive;
    class DOS_Shell;
	
#pragma mark - Rendering
	Bitu boxer_prepareForFrameSize(Bitu width, Bitu height, Bitu gfx_flags, double scalex, double scaley, GFX_CallBack_t callback);
	bool boxer_startFrame(Bit8u **frameBuffer, Bitu *pitch);
	void boxer_finishFrame(const uint16_t *dirtyBlocks);
	Bitu boxer_idealOutputMode(Bitu flags);
	
	void boxer_applyRenderingStrategy();
	Bitu boxer_getRGBPaletteEntry(Bit8u red, Bit8u green, Bit8u blue);
	void boxer_setPalette(Bitu start,Bitu count,GFX_PalEntry * entries);
	
    //Defined in vga_other.cpp to give Boxer access to Hercules and CGA graphics mode options.
    Bit8u boxer_herculesTintMode();
    void boxer_setHerculesTintMode(Bit8u tint);
    
    double boxer_CGACompositeHueOffset();
    void boxer_setCGACompositeHueOffset(double hue);
    
    
#pragma mark - Shell
    
    void boxer_shellWillStart(DOS_Shell *shell);
    void boxer_shellDidFinish(DOS_Shell *shell);
    
    //Called from shell.cpp: notifies Boxer when the autoexec is about to be processed.
    void boxer_shellWillStartAutoexec(DOS_Shell *shell);
    
	//Called from shell.cpp: notifies Boxer when control returns to the DOS prompt.
	void boxer_didReturnToShell(DOS_Shell *shell);
    
	//Called from shell_cmds.cpp to let Boxer handle commands on its own.
	bool boxer_shellShouldRunCommand(DOS_Shell *shell, char* cmd, char* args);
    
    //Called from shell_misc.cpp to let Boxer know the shell is waiting for command input.
    void boxer_shellWillReadCommandInputFromHandle(DOS_Shell *shell, Bit16u handle);
    void boxer_shellDidReadCommandInputFromHandle(DOS_Shell *shell, Bit16u handle);
    
	//Called from shell_misc.cpp to let Boxer rewrite or interrupt the shell's input processing.
    //Returns true if Boxer has modified any of the parameters passed by reference.
	bool boxer_handleShellCommandInput(DOS_Shell *shell, char *cmd, Bitu *cursorPosition, bool *executeImmediately);
    
    //Called from shell.cpp to give Boxer a chance to launch any commands of its own.
    bool boxer_hasPendingCommandsForShell(DOS_Shell *shell);
    bool boxer_executeNextPendingCommandForShell(DOS_Shell *shell);
    
    //Called from shell.cpp to let Boxer override the display of the standard startup messages.
	bool boxer_shellShouldDisplayStartupMessages(DOS_Shell *shell);
    
	//Called from shell_misc.cpp to notify Boxer when a program or batchfile is executed.
	void boxer_shellWillExecuteFileAtDOSPath(DOS_Shell *shell, const char *canonicalPath, const char *arguments);
	void boxer_shellDidExecuteFileAtDOSPath(DOS_Shell *shell, const char *canonicalPath);
    
    void boxer_shellWillBeginBatchFile(DOS_Shell *shell, const char *canonicalPath, const char *arguments);
    //Note different signature: some information is not available when finishing a batchfile
    void boxer_shellDidEndBatchFile(DOS_Shell *shell, const char *canonicalPath);
    
    //Return NO to stop shell commandline processing and exit the shell as soon as possible.
	bool boxer_shellShouldContinue(DOS_Shell *shell);
    
    
#pragma mark - Drive and file handling
	
	//Called from dos_programs.cpp: verifies that DOSBox is allowed to mount the specified folder.
	bool boxer_shouldMountPath(const char *filePath);
    
	//Called from drive_cache.cpp: allows Boxer to hide OS X files that DOSBox shouldn't touch.
	bool boxer_shouldShowFileWithName(const char *name);
	
	//Called from drive_local.cpp: allows Boxer to restrict access to files that DOS programs shouldn't write to.
	bool boxer_shouldAllowWriteAccessToPath(const char *filePath, DOS_Drive *dosboxDrive);
	
	//Called from dos_programs.cpp et al: informs Boxer of drive mount/unmount events.
	void boxer_driveDidMount(Bit8u driveIndex);
	void boxer_driveDidUnmount(Bit8u driveIndex);
	
	//Called from drive_local.cpp to notify Boxer when DOSBox has created or deleted a local file.
	void boxer_didCreateLocalFile(const char *path, DOS_Drive *dosboxDrive);
	void boxer_didRemoveLocalFile(const char *path, DOS_Drive *dosboxDrive);
	
    //Called from drive_local.cpp to wrap local file access.
    FILE * boxer_openLocalFile(const char *path, DOS_Drive *drive, const char *mode);
    bool boxer_removeLocalFile(const char *path, DOS_Drive *drive);
    bool boxer_moveLocalFile(const char *fromPath, const char *toPath, DOS_Drive *drive);
    bool boxer_createLocalDir(const char *path, DOS_Drive *drive);
    bool boxer_removeLocalDir(const char *path, DOS_Drive *drive);
    bool boxer_getLocalPathStats(const char *path, DOS_Drive *drive, struct stat *outStatus);
    bool boxer_localDirectoryExists(const char *path, DOS_Drive *drive);
    bool boxer_localFileExists(const char *path, DOS_Drive *drive);
    
    void * boxer_openLocalDirectory(const char *path, DOS_Drive *drive);
    void boxer_closeLocalDirectory(void *handle);
    bool boxer_getNextDirectoryEntry(void *handle, char *outName, bool &isDirectory);
	
    
#pragma mark - Runloop and event loop handling
    
	void boxer_handleDOSBoxTitleChange(Bit32s cycles, Bits frameskip, bool paused);
	
	//Called from dosbox.cpp to allow control over the emulation loop.
	void boxer_runLoopWillStartWithContextInfo(void **contextInfo);
	void boxer_runLoopDidFinishWithContextInfo(void *contextInfo);
	bool boxer_runLoopShouldContinue();
	void boxer_processEvents();
	
    
#pragma mark - Input
    
    void boxer_setJoystickActive(bool joystickActive);
	void boxer_setMouseActive(bool mouseActive);
	void boxer_mouseMovedToPoint(float x, float y);
    
    //Defined in keyboard.cpp to let Boxer see if there's any room left in the keyboard buffer.
    Bitu boxer_keyboardBufferRemaining();
    
    //Defined in dos_keyboard_layout.cpp.
    bool boxer_keyboardLayoutLoaded();
    const char *boxer_keyboardLayoutName();
    bool boxer_keyboardLayoutSupported(const char *code);
    bool boxer_keyboardLayoutActive();
    void boxer_setKeyboardLayoutActive(bool active);
    void boxer_setNumLockActive(bool active);
    void boxer_setCapsLockActive(bool active);
    void boxer_setScrollLockActive(bool active);
    
	//Called from dos_keyboard_layout.cpp: provides the current OS X keyboard layout as a DOSBox layout code.
	const char * boxer_preferredKeyboardLayout();
    
    //Called in bios_keyboard.cpp to allow Boxer to interrupt the INT16 keyboard handling loop.
    //(Used by the DOS prompt, among others.)
    bool boxer_continueListeningForKeyEvents();
    
    //Returns how many BIOS keycodes Boxer has stored in its internal key buffer.
    Bitu boxer_numKeyCodesInPasteBuffer();
    
    //Populates outKeyCode with the next keycode from Boxer's internal key buffer if available.
    //Returns true if a key code was retrieved, or false otherwise.
    //If consumeKey is true, the key will be removed from the buffer as it is read.
    bool boxer_getNextKeyCodeInPasteBuffer(Bit16u *outKeyCode, bool consumeKey);
    
    
#pragma mark - Printer support
    
    //Called from printer_redir.cpp to pass printer instructions to Boxer's virtual printer.
    Bitu boxer_PRINTER_readdata(Bitu port,Bitu iolen);
    void boxer_PRINTER_writedata(Bitu port,Bitu val,Bitu iolen);
    Bitu boxer_PRINTER_readstatus(Bitu port,Bitu iolen);
    void boxer_PRINTER_writecontrol(Bitu port,Bitu val, Bitu iolen);
    Bitu boxer_PRINTER_readcontrol(Bitu port,Bitu iolen);
    
    bool boxer_PRINTER_isInited(Bitu port);
    
    
#pragma mark - Messages, logging and error handling
    
	//Called from messages.cpp: overrides DOSBox's translation system.
	const char * boxer_localizedStringForKey(char const * key);
    
    void boxer_log(char const* format,...);
    void boxer_die(char const *functionName, char const *fileName, int lineNumber, char const* format,...);
    
#if __cplusplus
} //Extern C
#endif

#endif
