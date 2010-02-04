/* 
 Boxer is copyright 2009 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXSessionWindow is the main window for a DOS session. This class is heavily reliant on
//BXSessionWindowController and exists mainly just to override NSWindow's default window sizing
//and constraining methods.

#import <Cocoa/Cocoa.h>

@class BXSessionWindowController;

@interface BXSessionWindow : NSWindow

- (BXSessionWindowController *) windowController;

@end