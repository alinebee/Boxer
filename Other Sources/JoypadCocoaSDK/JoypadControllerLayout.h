//
//  JoypadControllerLayout.h
//
//  Created by Lou Zell on 3/14/11.
//  Copyright 2011 Joypad Inc. All rights reserved.
//
//  Please email questions to lzell11@gmail.com
//  __________________________________________________________________________
//
//  Examples of several custom controllers can be found in MyJoypadLayout.m in 
//  the JoypadiOSSample project that comes with the SDK download.
//
//  This is the class that you will use to create a custom layout for your
//  application.  Each method listed in the Public API section below adds
//  one component to your controller.  Currently, you can add: 
//
//       * Analog sticks
//       * Re-centering analog sticks
//       * Dpads
//       * Buttons
//       * Accelerometer Data (this components doesn't add a view)
//
//  See the comments at the top of each method for instructions on using it.

#import <Foundation/Foundation.h>
#if TARGET_OS_IPHONE
#import <CoreGraphics/CGGeometry.h>
#endif
#import "JoypadConstants.h"

@interface JoypadControllerLayout : NSObject

/**
 * Returns a new autoreleased layout:
 *   JoypadControllerLayout *myLayout = [JoypadControllerLayout layout];
 */
+(JoypadControllerLayout *)layout;

/**
 * Set the name of this layout.  This name will be displayed in the Connection Modal on Joypad
 * when a connection occurs.
 */
-(void)setName:(NSString *)layoutName;
-(NSString *)name;

/**
 * This is the simplest method to add a button.  It adds a blue square button with
 * no label.  You pass in a JoyInputIdentifier (found in JoypadConstants.h) that you 
 * will use later to identify when this button is being pressed.  When you press and
 * release buttons on Joypad, your implementations of the following delegate
 * methods are called: 
 *
 *  -(void)joypadDevice:(JoypadDevice *)device buttonUp:(JoyInputIdentifier)button;
 *  -(void)joypadDevice:(JoypadDevice *)device buttonDown:(JoyInputIdentifier)button;
 *
 * As you can see, a JoyInputIdentifier is passed as a parameter to these methods.
 */
-(void)addButtonWithFrame:(CGRect)rect identifier:(JoyInputIdentifier)inputId;

/**
 * More options than the method above.  See JoypadConstants.h for JoyButtonShape
 * and JoyButtonColor enums.
 */
-(void)addButtonWithFrame:(CGRect)rect label:(NSString *)label fontSize:(unsigned int)fontSize shape:(JoyButtonShape)shape color:(JoyButtonColor)color identifier:(JoyInputIdentifier)inputId;

/**
 * Adds a dpad with the specified frame, and automatically places its origin at the
 * center of the frame. This is the quickest way to drop a dpad down.  However, 
 * we recommend using -addDpadWithFrame:dpadOrigin:identifier, described next.
 */
-(void)addDpadWithFrame:(CGRect)rect identifier:(JoyInputIdentifier)inputId;

/**
 * Adds a dpad with the origin somewhere other than the center of the frame. This is
 * useful for giving your user more play around the edge of the dpad.  For example,
 * if you specified an origin and frame as follows, you would give your users a larger
 * hit area to the right side of the dpad: 
 *
 *    +----------+
 *    |          |
 *    |   *      |
 *    |          |
 *    +----------+
 *
 * Users tend to have a good grasp of where the edge of the device is, so the area to the
 * left of the dpad can be less than the right.  The dpad image itself is 180x180.  We find 
 * that extending the touch area past the edge of the dpad on the top, right, and bottom is
 * very beneficial to the experience. As a starting point, try: 
 *  
 *   [customLayout addDpadWithFrame:CGRectMake(0, 44, 280, 256) dpadOrigin:CGPointMake(110, 182) identifier:kJoyInputDpad1];
 *
 * These are the dimensions that we use for the pre-installed controllers.
 */
-(void)addDpadWithFrame:(CGRect)rect dpadOrigin:(CGPoint)origin identifier:(JoyInputIdentifier)inputId;

/**
 * Get accelerometer data from the device running Joypad.  Does not add a view.
 */
-(void)addAccelerometer;

/**
 * Adds an analog stick with origin at the center of the frame.  This stick does not
 * recenter around the initial touch point.  See the next method for more flexibility.
 */
-(void)addAnalogStickWithFrame:(CGRect)rect identifier:(JoyInputIdentifier)inputId;

/**
 * Same as above with an extra parameter to specify if the analog stick should recenter at the 
 * initial touch down point.  This gives it a hybrid feel between an analog stick and trackpad.
 * Recentering analog sticks are ideal for camera movement in a FPS.  For player movement, 
 * it is best to stick with a stationary analog stick (i.e. pass NO as the last argument).
 */
-(void)addAnalogStickWithFrame:(CGRect)rect identifier:(JoyInputIdentifier)inputId recentering:(BOOL)recentering;

/**
 * Pre-installed layouts to get you started.  Note that even when using these
 * built in layouts, you should still name the layout after your game (this name
 * is displayed on Joypad when a connection occurs).  Also, if you use one of 
 * these, then the built in skins can be applied over your controller.   
 */
+(JoypadControllerLayout *)nesLayout;
+(JoypadControllerLayout *)gbaLayout;
+(JoypadControllerLayout *)snesLayout;

@end
