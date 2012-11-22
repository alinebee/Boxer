/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXJoystickItem.h"
#import "BXThemes.h"

@interface BXJoystickItem ()

//Apply our selected appearance to our view.
- (void) _syncSelection;

@end

@implementation BXJoystickItem
@synthesize titleLabel = _titleLabel;
@synthesize descriptionLabel = _descriptionLabel;
@synthesize icon = _icon;

- (void) dealloc
{
    self.titleLabel = nil;
    self.descriptionLabel = nil;
    self.icon = nil;
    [super dealloc];
}

- (void) setSelected: (BOOL)selected
{
    [super setSelected: selected];
    [self _syncSelection];
}

- (void) viewDidLoad
{
    [self _syncSelection];
}

- (void) _syncSelection
{
    if (self.isSelected)
    {
        self.titleLabel.themeKey = @"BXInspectorListSelectionTheme";
        self.descriptionLabel.themeKey = @"BXInspectorListSelectionTheme";
        self.icon.themeKey = @"BXInspectorListSelectionTheme";
    }
    else
    {
        self.titleLabel.themeKey = @"BXInspectorListTheme";
        self.descriptionLabel.themeKey = @"BXInspectorListHelpTextTheme";
        self.icon.themeKey = @"BXInspectorListTheme";
    }
}

@end
