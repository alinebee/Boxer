/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import <Cocoa/Cocoa.h>

/// \c BXAboutController is a simple window controller which styles and displays the About Boxer panel.
@interface BXAboutController : NSWindowController
{
	NSTextField *_version;
}
@property (strong, nonatomic) IBOutlet NSTextField *version;

/// Provides a singleton instance of the window controller which stays retained for the lifetime
/// of the application. BXAboutController should always be accessed from this singleton.
@property (class, readonly, strong) id controller;

//Display the credits and acknowledgements help page
- (IBAction) showAcknowledgements: (id)sender;

@end


/// Simple view to draw the custom About window background.
@interface BXAboutBackgroundView : NSView
@end