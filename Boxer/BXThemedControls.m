/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXThemedControls.h"


#pragma mark - Base classes

@implementation BXThemedLabel

#pragma mark - Default theme handling

- (id) initWithCoder: (NSCoder *)coder
{
    self = [super initWithCoder: coder];
    if (self)
    {
        if (![coder containsValueForKey: @"themeKey"])
            self.themeKey = [self.class defaultThemeKey];
    }
    return self;
}


//Fixes a BGHUDLabel/NSTextField bug where toggling enabledness
//won't cause a redraw.
- (void) setEnabled: (BOOL)flag
{
    [super setEnabled: flag];
    //IMPLEMENTATION NOTE: this is the only way I've found to force
    //a proper redraw. setNeedsDisplay: doesn't, nor updateCell: and their ilk.
    self.stringValue = self.stringValue;
}

- (void) setThemeKey: (NSString *)key
{
    [super setThemeKey: key];
    self.stringValue = self.stringValue;
}

@end

@implementation BXThemedCheckboxCell

//Fix for setButtonType: no longer getting called for checkboxes in XIBs (jesus christ)
- (id) initWithCoder: (NSCoder *)aDecoder
{
    if ((self = [super initWithCoder: aDecoder]))
    {
        [self setButtonType: NSSwitchButton];
    }
    return self;
}

@end


@implementation BXThemedRadioCell

//See note above for BXThemedCheckboxCell.
- (id) initWithCoder: (NSCoder *)aDecoder
{
    if ((self = [super initWithCoder: aDecoder]))
    {
        [self setButtonType: NSRadioButton];
    }
    return self;
}

@end


#pragma mark -
#pragma mark Themed versions

@implementation BXHUDLabel

+ (NSString *) defaultThemeKey { return @"BXHUDTheme"; }

@end

@implementation BXHUDButtonCell

+ (NSString *) defaultThemeKey { return @"BXHUDTheme"; }

@end

@implementation BXHUDCheckboxCell

+ (NSString *) defaultThemeKey { return @"BXHUDTheme"; }

@end

@implementation BXHUDSliderCell

+ (NSString *) defaultThemeKey { return @"BXHUDTheme"; }

@end

@implementation BXHUDPopUpButtonCell

+ (NSString *) defaultThemeKey { return @"BXHUDTheme"; }

@end

@implementation BXHUDSegmentedCell

+ (NSString *) defaultThemeKey { return @"BXHUDTheme"; }

@end


@implementation BXBlueprintLabel

+ (NSString *) defaultThemeKey { return @"BXBlueprintTheme"; }

@end

@implementation BXBlueprintHelpTextLabel

+ (NSString *) defaultThemeKey { return @"BXBlueprintHelpTextTheme"; }

@end


@implementation BXIndentedLabel

+ (NSString *) defaultThemeKey { return @"BXIndentedTheme"; }

@end

@implementation BXIndentedHelpTextLabel

+ (NSString *) defaultThemeKey { return @"BXIndentedHelpTextTheme"; }

@end

@implementation BXIndentedCheckboxCell

+ (NSString *) defaultThemeKey { return @"BXIndentedTheme"; }

@end

@implementation BXIndentedSliderCell

+ (NSString *) defaultThemeKey { return @"BXIndentedTheme"; }

@end


@implementation BXAboutLabel

+ (NSString *) defaultThemeKey { return @"BXAboutTheme"; }

@end

@implementation BXAboutDarkLabel

+ (NSString *) defaultThemeKey { return @"BXAboutDarkTheme"; }

@end

@implementation BXAboutLightLabel

+ (NSString *) defaultThemeKey { return @"BXAboutLightTheme"; }

@end
