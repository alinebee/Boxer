/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
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
#define E_Exit(format,...) boxer_die(__PRETTY_FUNCTION__, __FILE__, __LINE__, format, ##__VA_ARGS__)

    
	class DOS_Drive;
	
	Bitu boxer_prepareForFrameSize(Bitu width, Bitu height, Bitu gfx_flags, double scalex, double scaley, GFX_CallBack_t callback);
	bool boxer_startFrame(Bit8u **frameBuffer, Bitu *pitch);
	void boxer_finishFrame(const uint16_t *dirtyBlocks);
	Bitu boxer_idealOutputMode(Bitu flags);
	
	void boxer_applyRenderingStrategy();
	Bitu boxer_getRGBPaletteEntry(Bit8u red, Bit8u green, Bit8u blue);
	void boxer_setPalette(Bitu start,Bitu count,GFX_PalEntry * entries);
	
	//Called from messages.cpp: overrides DOSBox's translation system.
	const char * boxer_localizedStringForKey(char const * key);
	
	//Called from dos_programs.cpp: verifies that DOSBox is allowed to mount the specified folder.
	bool boxer_shouldMountPath(const char *filePath);
	
	//Called from shell.cpp: notifies Boxer when autoexec.bat is run.
	void boxer_autoexecDidStart();
	void boxer_autoexecDidFinish();
	
	//Called from shell.cpp: notifies Boxer when control returns to the DOS prompt.
	void boxer_didReturnToShell();
	
	//Called from shell_cmds.cpp: hooks into shell command processing.
	bool boxer_shouldRunShellCommand(char* cmd, char* args);
	
	//Called from shell_misc.cpp to allow Boxer to inject its own commands at the DOS command line.
	bool boxer_handleCommandInput(char *cmd, Bitu *cursorPosition, bool *executeImmediately);
	
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
    
	//Called from shell_misc.cpp to notify Boxer when a program or batchfile is executed.
	void boxer_willExecuteFileAtDOSPath(const char *dosPath, const char *arguments, DOS_Drive *dosboxDrive);
	void boxer_didExecuteFileAtDOSPath(const char *dosPath, const char *arguments, DOS_Drive *dosboxDrive);
	
	void boxer_handleDOSBoxTitleChange(Bit32s cycles, Bits frameskip, bool paused);
	
	//Called from dosbox.cpp to allow control over the emulation loop.
	void boxer_runLoopWillStartWithContextInfo(void **contextInfo);
	void boxer_runLoopDidFinishWithContextInfo(void *contextInfo);
	bool boxer_runLoopShouldContinue();
	void boxer_processEvents();
	
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
    
    //Returns how many BIOS keycodes Boxer has stored in its internal key buffer.
    Bitu boxer_numKeyCodesInPasteBuffer();
    
    //Populates outKeyCode with the next keycode from Boxer's internal key buffer if available.
    //Returns true if a key code was retrieved, or false otherwise.
    //If consumeKey is true, the key will be removed from the buffer as it is read.
    bool boxer_getNextKeyCodeInPasteBuffer(Bit16u *outKeyCode, bool consumeKey);
    
    
    void boxer_log(char const* format,...);
    void boxer_die(char const *functionName, char const *fileName, int lineNumber, char const* format,...);
    
#if __cplusplus
} //Extern C
#endif

#endif
