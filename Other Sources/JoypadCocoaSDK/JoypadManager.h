//
//  JoypadManager.h
// 
//  Created by Lou Zell on 2/26/11.  
//  Copyright 2011 Joypad Inc. All rights reserved.
// 
//  Please email questions to lzell11@gmail.com
//  __________________________________________________________________________
//


#import <Foundation/Foundation.h>
#import "JoypadConstants.h"

// Forward declarations.
@class JoypadDevice;
@class JoypadControllerLayout;
@protocol JoypadManagerDelegate;

// Exceptions.
extern NSString *const JoypadManagerException;

@interface JoypadManager : NSObject

/**
 * Sets the object that will receive JoypadManager events.
 * See the JoypadManagerDelegate Category at the bottom of this header.
 */
-(void)setDelegate:(id<JoypadManagerDelegate>)aDelegate;

/**
 * Returns the object that will receive JoypadManager events.
 * See the JoypadManagerDelegate Category at the bottom of this header.
 */
-(id<JoypadManagerDelegate>)delegate;

/**
 * Sets the maximum number of Joypads to connect to.  Once the maximum number
 * is hit, Joypad Manager will stop searching for devices.  Defaults to 1.
 */
-(void)setMaxPlayerCount:(NSUInteger)num;
-(NSUInteger)maxPlayerCount;

/**
 * Searches for devices running Joypad.  Call this everytime your game's menu
 * screen becomes active.  If there are already maxPlayerCount players connected,
 * then this method does nothing.  Calling this while the search is already
 * running has no effect.
 */
-(void)startFindingDevices;

/**
 * Stops the search for devices running Joypad.  Calling this while the search
 * is already stopped has no effect.
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
 * Deprecated.
 * Instead, use -setMaxPlayerCount and let the SDK handle connections.
 *
 * An instance of JoypadDevice can be passed to this method to initiate a
 * connection.
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
-(void)connectToDeviceAtHost:(NSString *)host port:(UInt16)port asPlayer:(unsigned int)player;

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
-(NSUInteger)connectedDeviceCount;

/**
 * Deprecated and disabled.
 *
 * Instead, use the JoypadControllerLayout class methods: 
 *   +nesLayout
 *   +gbaLayout
 *   +snesLayout
 * 
 * For example, where you would previously use: 
 *   [joypadManager usePreInstalledLayout:kJoyControllerSNES];
 *
 * you should now use: 
 *   JoypadControllerLayout *layout = [JoypadControllerLayout snesLayout];
 *   [layout setName:@"MyGame"];
 *   [joypadManager setControllerLayout:layout];
 *
 * Please name the layout, as the name is displayed on Joypad once connected.
 * 
 */
-(void)usePreInstalledLayout:(JoyControllerIdentifier)layoutId;

/**
 * Deprecated.  
 * Instead, use -setControllerLayout:
 */
-(void)useCustomLayout:(JoypadControllerLayout *)layout;

/**
 * See the JoypadControllerLayout.h header for instructions on 
 * building a custom layout.
 */
-(void)setControllerLayout:(JoypadControllerLayout *)layout;

/**
 * Returns the controller layout that JoypadManager is currently using. 
 * This is useful if you are creating multiple layouts for your application, 
 * e.g. an emulator may use different layouts for different games.
 */
-(JoypadControllerLayout *)controllerLayout;

@end



#pragma mark JoypadManagerDelegate Protocol
@protocol JoypadManagerDelegate <NSObject>

@required
/**
 * Called when a device running Joypad has connected. At this point you 
 * are ready to receive input from it.
 */
-(void)joypadManager:(JoypadManager *)manager 
    deviceDidConnect:(JoypadDevice *)device 
              player:(unsigned int)player;

@optional

/**
 * Called when a device that you were connected to dropped the connection.
 * You should use this to set the device's delegate to nil.
 */
-(void)joypadManager:(JoypadManager *)manager 
 deviceDidDisconnect:(JoypadDevice *)device 
              player:(unsigned int)player;

/**
 * This is called before establishing a connection to Joypad.  If you implement
 * this and return NO, the connection will be cancelled.
 */
-(BOOL)joypadManager:(JoypadManager *)manager deviceShouldConnect:(JoypadDevice *)device;


@end
