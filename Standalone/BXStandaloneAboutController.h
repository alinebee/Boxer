/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXStandaloneAboutController styles and configures an about window suitable for standalone game apps.

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "BXDOSWindowBackgroundView.h"
#import "BXThemedControls.h"
#import "BXThemes.h"

@interface BXStandaloneAboutController : NSWindowController
{
    WebView *_creditsView;
    NSTextField *_appNameField;
    NSButton *_websiteButton;
    NSButton *_acknowledgementsButton;
}

@property (readonly, nonatomic) NSString *appName;
@property (readonly, nonatomic) NSString *copyrightText;
@property (readonly, nonatomic) NSString *shortVersionString;
@property (readonly, nonatomic) NSString *buildNumber;

@property (assign, nonatomic) IBOutlet WebView *creditsView;
@property (assign, nonatomic) IBOutlet NSTextField *appNameField;

@property (assign, nonatomic) IBOutlet NSButton *websiteButton;
@property (assign, nonatomic) IBOutlet NSButton *acknowledgementsButton;

@property (readonly, nonatomic) CGFloat appNameFontSize;

//Provides a singleton instance of the window controller which stays retained for the lifetime
//of the application. BXStandaloneAboutController should always be accessed from this singleton.
+ (id) controller;

//Display the credits and acknowledgements help page
- (IBAction) showAcknowledgements: (id)sender;

@end


#pragma mark -
#pragma mark View and theme classes

//Draws the custom background we use for the about window.
@interface BXStandaloneAboutWindowBackgroundView : BXDOSWindowBackgroundView
@end

@interface BXStandaloneAboutTheme : BXBaseTheme
@end

//Draws the custom styling for our text fields.
@interface BXStandaloneAboutLabel : BXThemedLabel
@end
