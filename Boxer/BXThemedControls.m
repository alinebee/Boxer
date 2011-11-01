/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXThemedControls.h"

#pragma mark -
#pragma mark Base classes

@implementation BXThemedLabel

//Fixes a BGHUDLabel/NSTextField bug where toggling enabledness
//won't cause a redraw.
- (void) setEnabled: (BOOL)flag
{
    [super setEnabled: flag];
    //NOTE: calling setNeedsDisplay: doesn't help; only actually
    //touching the value seems to force a redraw.
    [self setStringValue: [self stringValue]];
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

- (NSString *)themeKey { return @"BXHUDTheme"; }

@end

@implementation BXHUDButtonCell

- (NSString *)themeKey { return @"BXHUDTheme"; }

@end

@implementation BXHUDCheckboxCell

- (NSString *)themeKey { return @"BXHUDTheme"; }

@end

@implementation BXHUDSliderCell

- (NSString *)themeKey { return @"BXHUDTheme"; }

@end

@implementation BXHUDPopUpButtonCell

- (NSString *)themeKey { return @"BXHUDTheme"; }

@end

@implementation BXHUDSegmentedCell

- (NSString *)themeKey { return @"BXHUDTheme"; }

@end


@implementation BXBlueprintLabel

- (NSString *)themeKey { return @"BXBlueprintTheme"; }

@end

@implementation BXBlueprintHelpTextLabel

- (NSString *)themeKey { return @"BXBlueprintHelpTextTheme"; }

@end


@implementation BXIndentedLabel

- (NSString *)themeKey { return @"BXIndentedTheme"; }

@end

@implementation BXIndentedHelpTextLabel

- (NSString *)themeKey { return @"BXIndentedHelpTextTheme"; }

@end

@implementation BXIndentedCheckboxCell

- (NSString *)themeKey { return @"BXIndentedTheme"; }

@end



@implementation BXAboutLabel

- (NSString *)themeKey { return @"BXAboutTheme"; }

@end

@implementation BXAboutDarkLabel

- (NSString *)themeKey { return @"BXAboutDarkTheme"; }

@end

@implementation BXAboutLightLabel

- (NSString *)themeKey { return @"BXAboutLightTheme"; }

@end
