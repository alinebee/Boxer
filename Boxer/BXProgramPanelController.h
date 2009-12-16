/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXProgramPanelController manages the program picker panel inside the session window. It is
//responsible for populating the program selection and toggling which picker interface is shown
//(picker, default program toggle, no programs notice) based on the state of the emulator session.

#import <Cocoa/Cocoa.h>

@class BXSession;

@interface BXProgramPanelController : NSViewController
{
	IBOutlet NSView *programList;
	IBOutlet NSView *defaultTargetToggle;
	IBOutlet NSView *noProgramsNotice;
}
@property (retain) NSView *programList;				//The program picker view.
@property (retain) NSView *defaultTargetToggle;		//The default program toggle view.
@property (retain) NSView *noProgramsNotice;		//The no-programs-found notice view.

//Returns the localised display string used for the "open this program every time" checkbox toggle.
- (NSString *) labelForToggle;

//Set/get whether the session's currently executing program is the default program for its gamebox.
//Used by the default program toggle view.

- (BOOL) activeProgramIsDefault;
- (void) setActiveProgramIsDefault: (BOOL) isDefault;

- (void) syncActiveView;
@end