//
//  JoypadManager.h
//  Joypad SDK
//
//  Created by Lou Zell on 2/26/11.
//  Copyright 2011 Hazelmade. All rights reserved.
//
//  Please email questions to me, Lou, at lzell11@gmail.com
//

#import <Foundation/Foundation.h>
#import "JoypadConstants.h"

@class JoypadDevice;
@class JoypadControllerLayout;


@interface JoypadManager : NSObject

/**
 * Sets the object that will receive JoypadManager events.
 * See the JoypadManagerDelegate Category at the bottom of this header.
 */
-(void)setDelegate:(id)aDelegate;

/**
 * Returns the object that will receive JoypadManager events.
 * See the JoypadManagerDelegate Category at the bottom of this header.
 */
-(id)delegate;

/**
 * Searches for devices running Joypad.  As devices on the network open 
 * and close Joypad, the following delegate methods will be called:
 *
 *      -joypadManager:didFindDevice:previouslyConnected:
 *      -joypadManager:didLoseDevice:
 *
 */
-(void)startFindingDevices;

/**
 * Stops the search for devices running Joypad. 
 *
 *  +----------------------------- IMPORTANT -----------------------------+ 
 *  | You MUST call this method before starting gameplay. We recommend    |
 *  | searching for Joypad only during menu and pause screens. Customers  |
 *  | may experience significant lag while using Joypad if the search for |
 *  | devices is left running.                                            |
 *  +---------------------------------------------------------------------+
 */
-(void)stopFindingDevices;

/**
 * An instance of JopyadDevice can be passed to this method to initiate a
 * connection.  If you would like to auto-connect to the first Joypad that
 * is found on the network (to avoid adding any menu elements to your app),
 * call this method from your implementation of:
 *
 *      -joypadManager:didFindDevice:previouslyConnected:
 */
-(void)connectToDevice:(JoypadDevice *)device asPlayer:(unsigned int)player;

/**
 * The following two methods can be used to manually connect to a device 
 * that could not be discovered automatically on the network.  The Joypad
 * app has a settings page that displays a Manual Connection Address.
 * This address can be passed to either of these methods.  The first expects
 * addrStr to have the format: @"x.x.x.x:port".  The second expects the IP string
 * to be separated from the port.
 */
-(void)connectToDeviceAtAddress:(NSString *)addrStr asPlayer:(unsigned int)player;
-(void)connectToDeviceAtIp:(NSString *)ipAddr port:(UInt16)port asPlayer:(unsigned int)player;

/**
 * Contains all devices that are currently connected.  You can receive events 
 * from connected devices.  Make sure to set a delegate object for each device
 * that you are interested in receiving events from.  This could be done
 * in your implementation of -joypadManager:deviceDidConnect:player:.  
 * For example: 
 *
 *    -(void)joypadManager:(JoypadManager *)manager 
 *        deviceDidConnect:(JoypadDevice *)device 
 *                  player:(unsigned int)player
 *    {
 *      [device setDelegate:self];
 *    }
 *
 */
-(NSMutableArray *)connectedDevices;

/**
 * The Joypad app comes pre-installed with six generic layouts.  To use one
 * of these instead of building a custom layout, pass one of the 
 * values in the JoyControllerIdentifier enum found in JoypadConstants.h.
 * For example, to use the generic SNES layout, you would do this:
 *
 *    JoypadManager *joypadManager = [[JoypadManager alloc] init];
 *    [joypadManager setDelegate:self];
 *    [joypadManager usePreInstalledLayout:kJoyControllerSNES];
 *    [joypadManager startFindingDevices];
 * 
 */
-(void)usePreInstalledLayout:(JoyControllerIdentifier)layoutId;

/**
 * See the JoypadControllerLayout.h header for instructions on 
 * building a custom layout.
 */
-(void)useCustomLayout:(JoypadControllerLayout *)layout;

/**
 * Returns the controller layout that JoypadManager is currently using. 
 * This is useful if you are creating multiple layouts for your application, 
 * e.g. an emulator may use different layouts for different games.
 */
-(JoypadControllerLayout *)controllerLayout;

@end


#pragma mark JoypadManager Delegate Methods

/**
 
 Implement the methods below in the class that you would like to receive
 Joypad connection status updates in.  For example, if you would like an
 instance of MyClass to be notified when a device running Joypad is found,
 you would implement something like this in MyClass: 
 
 +--------------------------------------------------------------+
 | @implementation MyClass                                      |
 |                                                              |
 | -(void)joypadManager:(JoypadManager *)manager                |
 |        didFindDevice:(JoypadDevice *)device                  |
 |  previouslyConnected:(BOOL)prev                              |
 | {                                                            |
 |   NSLog(@"Found a device named: %@", [device name]);         |
 | }                                                            |
 |                                                              |
 | @end                                                         |
 +--------------------------------------------------------------+
 
 Please see the sample project that comes with the SDK download 
 for more examples.
 */
@interface NSObject (JoypadManagerDelegate)

/**
 * The following two methods are called when devices on the network open
 * and close the Joypad app.
 */
-(void)joypadManager:(JoypadManager *)manager 
       didFindDevice:(JoypadDevice *)device
 previouslyConnected:(BOOL)prev;

-(void)joypadManager:(JoypadManager *)manager 
       didLoseDevice:(JoypadDevice *)device;

/**
 * Called when a device running Joypad has connected. At this point you 
 * are ready to receive input from it.
 */
-(void)joypadManager:(JoypadManager *)manager 
    deviceDidConnect:(JoypadDevice *)device 
              player:(unsigned int)player;

/**
 * Called when a device that you were connected to dropped the connection.
 */
-(void)joypadManager:(JoypadManager *)manager 
 deviceDidDisconnect:(JoypadDevice *)device 
              player:(unsigned int)player;


@end
