/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXScripting category exposes a scripting API on NSApplication for top-level objects.

#import <AppKit/AppKit.h>

@class BXScriptablePreferences;
@class BXScriptableWindow;

@interface NSApplication (BXScripting)

//An Applescript API object for modifying Boxer’s application preferences and accessing the preferences window.
@property (readonly) BXScriptablePreferences *scriptablePreferences;

//An Applescript API object representing the Inspector panel.
@property (readonly) BXScriptableWindow *scriptableInspectorWindow;

@end