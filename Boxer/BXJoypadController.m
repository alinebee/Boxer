/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXJoypadController.h"
#import "JoypadSDK.h"
#import "BXJoypadController.h"
#import "BXBaseAppController.h"
#import "BXSession.h"
#import "BXDOSWindowController.h"
#import "BXInputController+BXJoypadInput.h"
#import "BX4ButtonJoystickLayout.h"


#pragma mark -
#pragma mark Private method declarations
@interface BXJoypadController ()

@property (readwrite, nonatomic) BOOL hasJoypadDevices;
@property (readonly, nonatomic) BXInputController *activeWindowController;

@end


@implementation BXJoypadController

@synthesize joypadManager, currentLayout, hasJoypadDevices;

#pragma mark -
#pragma mark Initialization and deallocation

- (void) setCurrentLayout: (JoypadControllerLayout *)layout
{
    if (currentLayout != layout)
    {
        currentLayout = layout;
        
        if (layout)
        {
            [joypadManager setControllerLayout: layout];
        }
    }
}

- (void) awakeFromNib
{
    joypadManager = [[JoypadManager alloc] init];
    [joypadManager setDelegate: self];
    [joypadManager setMaxPlayerCount: 1];
    
    //Default to a 4-button layout (this may be overridden by any game the user starts)
    [self setCurrentLayout: [BX4ButtonJoystickLayout layout]];
    [joypadManager startFindingDevices];
    
    BXBaseAppController *appController = (BXBaseAppController *)[NSApp delegate];
    [appController addObserver: self
                    forKeyPath: @"currentSession.DOSWindowController.inputController.currentJoypadLayout"
                       options: NSKeyValueObservingOptionInitial
                       context: nil];
    
    [appController addObserver: self
                    forKeyPath: @"currentSession.DOSWindowController.inputController"
                       options: NSKeyValueObservingOptionInitial
                       context: nil];
}

- (void) dealloc
{
    BXBaseAppController *appController = (BXBaseAppController *)[NSApp delegate];
    [appController removeObserver: self forKeyPath: @"currentSession.DOSWindowController.inputController.currentJoypadLayout"];
    [appController removeObserver: self forKeyPath: @"currentSession.DOSWindowController.inputController"];
    
    [joypadManager stopFindingDevices];
}


#pragma mark -
#pragma mark Joypad device monitoring

- (NSArray *) joypadDevices
{
    return [joypadManager connectedDevices];
}

- (BXInputController *) activeWindowController
{
    return [[[(BXBaseAppController *)[NSApp delegate] currentSession] DOSWindowController] inputController];
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
        if (layout) [self setCurrentLayout: layout];
    }
    //Whenever the active window or its input controller changes,
    //tell all Joypad devices to send their signal to the new one
    else if ([keyPath isEqualToString: @"currentSession.DOSWindowController.inputController"])
    {
        //Rebind all connected devices to send their messages to the currently active session
        for (JoypadDevice *device in [self joypadDevices])
        {
            [device setDelegate: [self activeWindowController]];
        }
    }
}

//Called when JoypadManager discovers a device, but before any connection attempts are made:
//we flag at this point that we have joypad devices available, so that joystick emulation
//will be enabled as early as possible.
- (BOOL) joypadManager: (JoypadManager *)manager deviceShouldConnect: (JoypadDevice *)device
{
    [self setHasJoypadDevices: YES];
    return YES;
}

- (void) joypadManager: (JoypadManager *)manager
      deviceDidConnect: (JoypadDevice *)device
                player: (unsigned int)player
{
    BXInputController *delegate = [self activeWindowController];
    [device setDelegate: delegate];
    
    [self setHasJoypadDevices: YES];
        
    [self willChangeValueForKey: @"joypadDevices"];
    [self didChangeValueForKey: @"joypadDevices"];
    
    //Let the delegate know that the device has been connected
    [delegate joypadManager: manager
           deviceDidConnect: device
                     player: player];
}

- (void) joypadManager: (JoypadManager *)manager
   deviceDidDisconnect: (JoypadDevice *)device
                player: (unsigned int)player
{   
    BOOL devicesRemaining = [manager connectedDeviceCount] > 0;
    [self setHasJoypadDevices: devicesRemaining];
        
    [self willChangeValueForKey: @"joypadDevices"];
    [self didChangeValueForKey: @"joypadDevices"];
    
    BXInputController *delegate = (BXInputController *)[device delegate];
    
    //Let the device's delegate know that the device has been disconnected
    [delegate joypadManager: manager deviceDidDisconnect: device player: player];
    
    [device setDelegate: nil];
}
@end
