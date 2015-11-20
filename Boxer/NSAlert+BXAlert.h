/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//The BXAlert category provides some convenience methods for alerts.

#import <Cocoa/Cocoa.h>

@interface NSAlert (BXAlert)

//Returns a non-retained NSAlert instance.
+ (instancetype) alert;

//Set the alert's icon to the represented icon of the specified window.
//Returns YES if the window had a specific icon, NO otherwise.
- (BOOL) adoptIconFromWindow: (NSWindow *)window;

@end
