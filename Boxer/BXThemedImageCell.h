/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXThemeImageCell renders its image as a template using a fill and shadow effects defined in a theme.

#import <Cocoa/Cocoa.h>

@class BGTheme;
@interface BXThemedImageCell : NSImageCell
{
    NSString *_themeKey;
    BOOL _highlighted;
    BOOL _selected;
    BOOL _pushed;
}

@property (copy, nonatomic) NSString *themeKey;
@property (readonly, nonatomic) BGTheme *themeForKey;

//Toggles the highlighted, selected and pushed theme appearances.
@property (assign, nonatomic, getter=isHighlighted) BOOL highlighted;
@property (assign, nonatomic, getter=isSelected) BOOL selected;
@property (assign, nonatomic, getter=isPushed) BOOL pushed;

@end

//A subclass of BXTemplateImageCell intended for HUD windows, that defaults to white with a soft black shadow.
@interface BXHUDImageCell : BXThemedImageCell
@end

//A subclass of BXTemplateImageCell using the indented appearance.
@interface BXIndentedImageCell : BXThemedImageCell
@end