/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXInputPanelController manages the mouse and joystick input panel of the Inspector window.
//It is responsible for populating the joystick type menu with known joysticks and
//synchronizing them with the current joystick.

#import <Cocoa/Cocoa.h>

@class BXInputController;

@interface BXInputPanelController : NSViewController
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
< NSMenuDelegate >
#endif
{
	IBOutlet NSPopUpButton *joystickTypeSelector;
	IBOutlet NSObjectController *sessionMediator;
}
@property (retain) NSPopUpButton *joystickTypeSelector; //The joystick type selector we populate.
@property (retain) NSObjectController *sessionMediator;	//The NIB's object-controller proxy for the current session.
@property (readonly) NSArray *joystickTypes; //The available joystick types, used to populate the joystick type selector.

@end
