//
//  JoypadDevice.h
//  Joypad SDK
//
//  Created by Lou Zell on 2/25/11.
//  Copyright 2011 Hazelmade. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "JoypadManager.h"

@class JoypadDeviceNetworker;
@class JoypadManager;

typedef struct
{
  float x;
  float y;
  float z;
}JoypadAcceleration;

// Angle is in radians.
typedef struct
{
  float angle;
  float distance;
}JoypadStickPosition;

#if TARGET_OS_IPHONE || (MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5)
@interface JoypadDevice : NSObject<NSNetServiceDelegate>
#else
@interface JoypadDevice : NSObject
#endif
{
  NSString *name;
  NSString *ipAddress;
  UInt16 port;
  NSNetService *netService;
  BOOL isConnected;
  BOOL lostConnection;
  unsigned int playerNumber;
  JoypadDeviceNetworker *deviceNetworker;
  JoypadManager *manager;
  NSArray *inputElements;
  
  UInt64 previousState;

  id delegate;
  
  // When the -connect method is called, we must first check to
  // see if the netService has been resolved into an IP and port.
  // If it has not, we set the toConnect flag and resolve the
  // service.  When the service finishes resolving, we connect.
  BOOL toConnect;
}

-(id)initWithManager:(JoypadManager *)manager;

#pragma mark Actions
-(void)connect;
-(void)disconnect;

#pragma mark DeviceNetworker Called Actions
-(void)deviceNetworkerDidConnect:(JoypadDeviceNetworker *)networker;
-(void)deviceNetworkerDidDisconnect:(JoypadDeviceNetworker *)networker;
-(void)deviceNetworker:(JoypadDeviceNetworker *)networker didReceiveNextState:(UInt64)nextState;

#pragma mark Getters
-(NSString *)name;
-(NSString *)ipAddress;
-(UInt16)port;
-(NSNetService *)netService;
-(BOOL)isConnected;
-(BOOL)lostConnection;
-(unsigned int)playerNumber;
-(id)delegate;
-(JoypadManager *)manager;

#pragma mark Setters
-(void)setName:(NSString *)s;
-(void)setIpAddress:(NSString *)s;
-(void)setPort:(UInt16)p;
-(void)setNetService:(NSNetService *)service;
-(void)setLostConnection:(BOOL)yn;
-(void)setPlayerNumber:(unsigned int)player;
-(void)setDelegate:(id)aDelegate;

@end

#pragma mark -
@interface NSObject (JoypadDeviceDelegate)

-(void)joypadDevice:(JoypadDevice *)device didAccelerate:(JoypadAcceleration)accel;
-(void)joypadDevice:(JoypadDevice *)device dPad:(JoyInputIdentifier)dpad buttonUp:(JoyDpadButton)dpadButton;
-(void)joypadDevice:(JoypadDevice *)device dPad:(JoyInputIdentifier)dpad buttonDown:(JoyDpadButton)dpadButton;
-(void)joypadDevice:(JoypadDevice *)device buttonUp:(JoyInputIdentifier)button;
-(void)joypadDevice:(JoypadDevice *)device buttonDown:(JoyInputIdentifier)button;
-(void)joypadDevice:(JoypadDevice *)device analogStick:(JoyInputIdentifier)stick didMove:(JoypadStickPosition)newPosition;

@end
