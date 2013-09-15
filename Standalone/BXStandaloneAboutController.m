/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXStandaloneAboutController.h"
#import "BXThemes.h"
#import "NSShadow+ADBShadowExtensions.h"
#import "BXStandaloneAppController.h"
#import "ADBGeometry.h"


#define kAppNameDefaultFontSize 24
#define kAppNameFallbackFontSize 18

@implementation BXStandaloneAboutController
@synthesize creditsView = _creditsView;
@synthesize appNameField = _appNameField;
@synthesize acknowledgementsButton = _acknowledgementsButton;
@synthesize websiteButton = _websiteButton;

+ (id) controller
{
	static id singleton = nil;
    
	if (!singleton)
        singleton = [[self alloc] initWithWindowNibName: @"StandaloneAbout"];
    
	return singleton;
}

- (void) windowDidLoad
{
    [super windowDidLoad];
    
    NSURL *creditsResourceURL = [[NSBundle mainBundle] URLForResource: @"Credits" withExtension: @"html"];
    self.creditsView.mainFrameURL = creditsResourceURL.absoluteString;
    self.creditsView.drawsBackground = NO;
    self.creditsView.shouldUpdateWhileOffscreen = NO;
    self.creditsView.shouldCloseWithWindow = YES;
    
    //Hide the website button and center the acknowledgements button if this app doesn't have a website URL
    NSURL *websiteURL = [BXStandaloneAppController organizationWebsiteURL];
    if (!websiteURL)
    {
        self.websiteButton.hidden = YES;
        NSRect parentBounds = self.acknowledgementsButton.superview.bounds;
        NSRect currentFrame = self.acknowledgementsButton.frame;
        NSRect centeredFrame = alignInRectWithAnchor(currentFrame, parentBounds, NSMakePoint(0.5, 0.5));
        
        self.acknowledgementsButton.frame = centeredFrame;
    }
}

- (void) webView: (WebView *)webView decidePolicyForNavigationAction: (NSDictionary *)actionInformation
         request: (NSURLRequest *)request
           frame: (WebFrame *)frame
decisionListener: (id < WebPolicyDecisionListener >)listener
{
    //Open remote URLs in the standard browser.
    NSString *host = request.URL.host;
    if (host)
    {
        [[NSWorkspace sharedWorkspace] openURL: request.URL];
    }
    else
    {
        [listener use];
    }
}

- (NSString *) copyrightText
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: @"NSHumanReadableCopyright"];
}

- (NSString *) shortVersionString
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleShortVersionString"];
}

- (NSString *) buildNumber
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleVersion"];
}

- (NSString *) appName
{
    return [[NSBundle mainBundle] objectForInfoDictionaryKey: @"CFBundleName"];
}

+ (NSSet *) keyPathsForValuesAffectingAppNameFontSize
{
    return [NSSet setWithObject: @"appName"];
}

- (CGFloat) appNameFontSize
{
    NSDictionary *defaultAttributes = [NSDictionary dictionaryWithObject: [NSFont systemFontOfSize: kAppNameDefaultFontSize]
                                                                  forKey: NSFontAttributeName];
    
    NSSize defaultSize = [self.appName sizeWithAttributes: defaultAttributes];
    
    if (defaultSize.width > self.appNameField.bounds.size.width)
    {
        return kAppNameFallbackFontSize;
    }
    else
    {
        return kAppNameDefaultFontSize;
    }
}

- (IBAction) showAcknowledgements: (id)sender
{
	[[NSApp delegate] showHelpAnchor: @"acknowledgements"];
}

@end


@implementation BXStandaloneAboutWindowBackgroundView

- (void) drawRect: (NSRect)dirtyRect
{
	[NSBezierPath clipRect: dirtyRect];
	
	[self _drawBackgroundInRect: dirtyRect];
	[self _drawLightingInRect: dirtyRect];
}

@end


@implementation BXStandaloneAboutTheme

+ (void) load
{
    [self registerWithName: nil];
}

- (NSColor *) textColor
{
    return [NSColor whiteColor];
}

- (NSShadow *) textShadow
{
    return [NSShadow shadowWithBlurRadius: 3.0
                                   offset: NSMakeSize(0, -1.0f)
                                    color: [NSColor blackColor]];
}

@end

@implementation BXStandaloneAboutLabel

+ (NSString *) defaultThemeKey { return @"BXStandaloneAboutTheme"; }

@end