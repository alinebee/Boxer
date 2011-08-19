/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXTemplateImageCell renders its image as a template using a specified color and shadow effect.

#import <Cocoa/Cocoa.h>

@interface BXTemplateImageCell : NSImageCell
{
	NSColor *imageColor;
	NSColor *disabledImageColor;
	NSShadow *imageShadow;
}

@property (copy, nonatomic) NSColor *imageColor;
@property (copy, nonatomic) NSColor *disabledImageColor;
@property (copy, nonatomic) NSShadow *imageShadow;

@end

//A subclass of BXTemplateImageCell intended for HUD windows, that defaults to white with a soft black shadow.
@interface BXHUDImageCell : BXTemplateImageCell
@end