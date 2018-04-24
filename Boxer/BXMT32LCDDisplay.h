/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

/// BXMT32LCDDisplay imitates, as the name suggests, the LCD display on a Roland MT-32 Sound Module.
/// It is used for displaying messages sent by the games to the emulated MT-32. (Many Sierra games
/// would send cheeky messages to it on startup.)
///
/// This field can only display ASCII characters, as that was all the MT-32's display could handle.
/// Non-ASCII characters will be drawn as empty space.
@interface BXMT32LCDDisplay : NSTextField

/// The image containing glyph data for the pixel font.
- (NSImage *) pixelFont;

/// The mask image to use for the LCD pixel grid.
/// This will be drawn in for 20 character places.
- (NSImage *) pixelGrid;

/// The background color of the field.
- (NSColor *) screenColor;

/// The background color of the LCD pixel grid.
- (NSColor *) gridColor;

/// The colour of lit LCD pixels upon the grid.
- (NSColor *) pixelColor;

/// The inner shadow of the screen. 
- (NSShadow *) innerShadow;

/// The lighting effects applied on top of the screen.
- (NSGradient *) screenLighting;

@end
