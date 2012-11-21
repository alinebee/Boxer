/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//BXThemes defines custom UI themes for BGHUDAppKit to customise the appearance of UI elements.
//These are used in Boxer's inspector panel and elsewhere.

#import <Cocoa/Cocoa.h>
#import <BGHUDAppKit/BGHUDAppKit.h>

//Extends BGTheme with more specific overrides.
@interface BGTheme (BXThemeExtensions)

//Registers the theme class with the theme manager,
//keyed under the specific name.
//If name is nil, the classname will be used.
+ (void) registerWithName: (NSString *)name;

//The shadow to draw inside the slider track, on top of the background color.
//Defaults to nil.
- (NSShadow *) sliderTrackInnerShadow;

//The shadow to draw beneath the slider track. Defaults to nil.
- (NSShadow *) sliderTrackShadow;

//The color with which to stroke the slider track. Defaults to strokeColor.
- (NSColor *) sliderTrackStrokeColor;

//The color with which to stroke the disabled slider track. Defaults to disabledStrokeColor.
- (NSColor *) disabledSliderTrackStrokeColor;

//The shadow to draw beneath slider knobs. Defaults to the value of dropShadow.
- (NSShadow *) sliderKnobShadow;

//The color with which to stroke the slider knob. Defaults to strokeColor.
- (NSColor *) sliderKnobStrokeColor;

//The color with which to stroke the slider knob. Defaults to disabledStrokeColor.
- (NSColor *) disabledSliderKnobStrokeColor;


- (NSGradient *) imageFill;
- (NSShadow *) imageInnerShadow;
- (NSShadow *) imageDropShadow;

- (NSGradient *) selectedImageFill;
- (NSShadow *) selectedImageInnerShadow;
- (NSShadow *) selectedImageDropShadow;

- (NSGradient *) disabledImageFill;
- (NSShadow *) disabledImageInnerShadow;
- (NSShadow *) disabledImageDropShadow;

- (NSGradient *) highlightedImageFill;
- (NSShadow *) highlightedImageInnerShadow;
- (NSShadow *) highlightedImageDropShadow;

- (NSGradient *) pushedImageFill;
- (NSShadow *) pushedImageInnerShadow;
- (NSShadow *) pushedImageDropShadow;


@end


//Base class used by all Boxer themes. Currently empty.
@interface BXBaseTheme : BGGradientTheme
@end

//Adds a soft shadow around text.
@interface BXBlueprintTheme : BXBaseTheme
- (NSShadow *) textShadow;
- (NSColor *) textColor;
@end

//Same as above, but paler text.
@interface BXBlueprintHelpTextTheme : BXBlueprintTheme
- (NSColor *) textColor;
@end

//White text, blue highlights and subtle text shadows
//for HUD and bezel panels.
@interface BXHUDTheme : BXBaseTheme
- (NSGradient *) highlightGradient;
- (NSGradient *) pushedGradient;
- (NSGradient *) highlightComplexGradient;
- (NSGradient *) pushedComplexGradient;
- (NSGradient *) highlightKnobColor;
- (NSShadow *) focusRing;
@end

//Lightly indented text for program panels and inspector.
@interface BXIndentedTheme : BXBaseTheme
@end

//Same as above, but paler text.
@interface BXIndentedHelpTextTheme : BXIndentedTheme
@end

//Style used for list items in inspector.
@interface BXInspectorListTheme : BXIndentedTheme
@end

//Style used for selected list items in inspector.
@interface BXInspectorListSelectionTheme : BXBaseTheme
@end

@interface BXInspectorListHelpTextTheme : BXIndentedHelpTextTheme
@end

//Lightly indented medium text for About panel.
@interface BXAboutTheme : BXBaseTheme
@end

//Lightly indented dark text for About panel.
@interface BXAboutDarkTheme : BXAboutTheme
@end

//Lightly indented bright text for About panel.
@interface BXAboutLightTheme : BXAboutTheme
@end


@protocol BXThemable <NSObject>

@required
@property (copy, nonatomic) NSString *themeKey;


//Base implementations for these are provided by BXThemableExtensions,
//so they're automatically available on any object that implement this protocol.
@optional
+ (NSString *) defaultThemeKey;
@property (readonly, nonatomic) BGTheme *themeForKey;

@end


@interface NSObject (BXThemableExtensions)

//The initial theme key for all instances of this object.
+ (NSString *) defaultThemeKey;

@property (readonly, nonatomic) BGTheme *themeForKey;

@end