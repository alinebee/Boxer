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
	NSGradient *_imageFill;
	NSGradient *_disabledImageFill;
	NSShadow *_dropShadow;
	NSShadow *_innerShadow;
}

@property (copy, nonatomic) NSGradient *imageFill;
@property (copy, nonatomic) NSGradient *disabledImageFill;
@property (copy, nonatomic) NSShadow *dropShadow;
@property (copy, nonatomic) NSShadow *innerShadow;

+ (NSGradient *) defaultImageFill;
+ (NSGradient *) defaultDisabledImageFill;
+ (NSShadow *) defaultDropShadow;
+ (NSShadow *) defaultInnerShadow;

@end

//A subclass of BXTemplateImageCell intended for HUD windows, that defaults to white with a soft black shadow.
@interface BXHUDImageCell : BXTemplateImageCell
@end

//A subclass of BXTemplateImageCell using the indented appearance.
@interface BXIndentedImageCell : BXTemplateImageCell
@end