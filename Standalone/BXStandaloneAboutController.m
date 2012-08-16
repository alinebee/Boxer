/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXStandaloneAboutController.h"
#import "BXThemes.h"
#import "NSShadow+BXShadowExtensions.h"
#import "BXBaseAppController.h"


@implementation BXStandaloneAboutController
@synthesize creditsView = _creditsView;

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

- (void) dealloc
{
    self.creditsView = nil;
    [super dealloc];
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

- (NSString *) themeKey { return @"BXStandaloneAboutTheme"; }

@end