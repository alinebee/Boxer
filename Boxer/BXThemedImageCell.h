/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>
#import "BXThemes.h"

@class BGTheme;

/// \c BXThemeImageCell renders its image as a template using a fill and shadow effects defined in a theme.
@interface BXThemedImageCell : NSImageCell <BXThemable>

/// The current theme key.
@property (copy, nonatomic) NSString *themeKey;

@end

/// A subclass of \c BXTemplateImageCell intended for HUD windows, that defaults to white with a soft black shadow.
@interface BXHUDImageCell : BXThemedImageCell
@end

/// A subclass of \c BXTemplateImageCell using the indented appearance.
@interface BXIndentedImageCell : BXThemedImageCell
@end
