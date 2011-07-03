/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXJoypadController.h"
#import "JoypadSDK.h"
#import "BXJoypadController.h"
#import "BXAppController.h"
#import "BXSession.h"
#import "BXDOSWindowController.h"
#import "BXInputController+BXJoypadInput.h"
#import "BX4ButtonJoystickLayout.h"


#pragma mark -
#pragma mark Private method declarations
@interface BXJoypadController ()

@property (readonly, nonatomic) BXInputController *activeWindowController;

@end


@implementation BXJoypadController

@synthesize joypadManager, currentLayout;

#pragma mark -
#pragma mark Initialization and deallocation

//Why don't we just set and get the layout using joypadManager controllerLayout, you ask?
//Because this crashes when you try to use the property accessor.
- (void) setCurrentLayout: (JoypadControllerLayout *)layout
{
    if (currentLayout != layout)
    {
        [currentLayout release];
        currentLayout = [layout retain];
        
        if (layout)
        {
            [joypadManager useCustomLayout: layout];
            
            //Disconnect and reconnect each device to make it notice the new layout
            //(Remove this once Joypad SDK can handle on-the-fly layout changes)
            suppressReconnectionNotifications = YES;
            for (JoypadDevice *device in [joypadManager connectedDevices])
            {
                [device disconnect];
                [joypadManager connectToDevice: device asPlayer: 1];
            }
            suppressReconnectionNotifications = NO;
        }
    }
}

- (void) awakeFromNib
{
    joypadManager = [[JoypadManager alloc] init];
    [joypadManager setDelegate: self];
    //Default to a 4-button layout (this may be overridden by any game the user starts)
    [self setCurrentLayout: [BX4ButtonJoystickLayout layout]];
    [joypadManager startFindingDevices];
    
    [[NSApp delegate] addObserver: self
                       forKeyPath: @"currentSession.DOSWindowController.inputController.currentJoypadLayout"
                          options: NSKeyValueObservingOptionInitial
                          context: nil];
    
    [[NSApp delegate] addObserver: self
                       forKeyPath: @"currentSession.DOSWindowController.inputController"
                          options: NSKeyValueObservingOptionInitial
                          context: nil];
}

- (void) dealloc
{
    [[NSApp delegate] removeObserver: self forKeyPath: @"currentSession.DOSWindowController.inputController.currentJoypadLayout"];
    
    [joypadManager stopFindingDevices];
    [joypadManager release], joypadManager = nil;
    [self setCurrentLayout: nil], [currentLayout release];
    [super dealloc];
}


#pragma mark -
#pragma mark Joypad device monitoring

- (NSArray *) joypadDevices
{
    return [joypadManager connectedDevices];
}

- (BXInputController *) activeWindowController
{
    return [[[[NSApp delegate] currentSession] DOSWindowController] inputController];
}

- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
    //Whenever the joystick type changes, pass the new layout for it to all connected devices
    if ([keyPath isEqualToString: @"currentSession.DOSWindowController.inputController.currentJoypadLayout"])
    {
        JoypadControllerLayout *layout = [[self activeWindowController] currentJoypadLayout];
        [self setCurrentLayout: layout];
    }
    //Whenever the active window or its input controller changes,
    //tell all Joypad devices to send their signal to the new one
    else if ([keyPath isEqualToString: @"currentSession.DOSWindowController.inputController"])
    {
        //Rebind all connected devices to send their messages to the currently active session
        for (JoypadDevice *device in [joypadManager connectedDevices])
        {
            [device setDelegate: [self activeWindowController]];
        }
    }
}

- (void) joypadManager: (JoypadManager *)manager
         didFindDevice: (JoypadDevice *)device 
   previouslyConnected: (BOOL)wasConnected
{
    [joypadManager connectToDevice: device asPlayer: 1];
}

- (void) joypadManager: (JoypadManager *)manager
      deviceDidConnect: (JoypadDevice *)device
                player: (unsigned int)player
{
    [device setDelegate: [self activeWindowController]];
    if (!suppressReconnectionNotifications)
    {
        [self willChangeValueForKey: @"joypadDevices"];
        [self didChangeValueForKey: @"joypadDevices"];
    }
}

- (void) joypadManager: (JoypadManager *)manager
   deviceDidDisconnect: (JoypadDevice *)device
                player: (unsigned int)player
{
    //Avoid spamming observers whenever we disconnect and immediately reconnect a device
    if (!suppressReconnectionNotifications)
    {
        [self willChangeValueForKey: @"joypadDevices"];
        [self didChangeValueForKey: @"joypadDevices"];
    }
}
@end
