/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Foundation/Foundation.h>

@class BXContinuousThread;
@interface BXKeyboardEventTap : NSObject
{
    BXContinuousThread *_tapThread;
    CFMachPortRef _tap;
    BOOL _enabled;
}

//Whether the event tap should suppress system hotkeys.
//Toggling this will attach/detach the event tap.
//Enabling this will have no effect if canTapEvents is NO.
@property (assign, nonatomic, getter=isEnabled) BOOL enabled;

//Whether we our tap is in place and listening for system hotkeys.
@property (readonly, nonatomic) BOOL isTapping;

//Will be YES if the accessibility API is available
//(i.e. "Enable access for assistive devices" is turned on),
//NO otherwise. If NO, then setEnabled will have no effect.
@property (readonly, nonatomic) BOOL canTapEvents;

@end
