//
//  JoypadConstants.h
//
//  Created by Lou Zell on 6/1/11.
//  Copyright 2011 Joypad Inc. All rights reserved.
//
//  Please email questions to lzell11@gmail.com
//  __________________________________________________________________________
//

typedef struct
{
  float x;
  float y;
  float z;
}JoypadAcceleration;

typedef struct
{
  float angle;    // radians
  float distance;
}JoypadStickPosition;

typedef enum
{
  kJoyInputTypeDpad,
  kJoyInputTypeButton,
  kJoyInputTypeAnalogStick,
  kJoyInputTypeAccelerometer
}JoyInputType;

typedef enum
{
  kJoyDpadButtonUp,
  kJoyDpadButtonRight,
  kJoyDpadButtonDown,
  kJoyDpadButtonLeft
}JoyDpadButton;

typedef enum
{
  kJoyButtonShapeSquare,
  kJoyButtonShapeRound,
  kJoyButtonShapePill
}JoyButtonShape;

typedef enum
{
  kJoyButtonColorBlue,
  kJoyButtonColorBlack
}JoyButtonColor;

typedef enum
{
  kJoyInputDpad1,
  kJoyInputDpad2,
  kJoyInputAnalogStick1,
  kJoyInputAnalogStick2,
  kJoyInputAccelerometer,
  kJoyInputWheel,
  kJoyInputAButton,
  kJoyInputBButton,
  kJoyInputCButton,
  kJoyInputXButton,
  kJoyInputYButton,
  kJoyInputZButton,
  kJoyInputSelectButton,
  kJoyInputStartButton,
  kJoyInputLButton,
  kJoyInputRButton
}JoyInputIdentifier;

typedef enum
{
  kJoyControllerNES,
  kJoyControllerGBA,
  kJoyControllerSNES,
  kJoyControllerGenesis,
  kJoyControllerN64,
  kJoyControllerAnyPreinstalled,
  kJoyControllerCustom
}JoyControllerIdentifier;
