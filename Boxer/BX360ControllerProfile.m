/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


//Custom controller profile for the wired and wireless 360 controller using Tattiebogle's
//3rd-party driver: http://tattiebogle.net/index.php/ProjectRoot/Xbox360Controller/OsxDriver


#import "BXHIDControllerProfilePrivate.h"
#import "DDHidUsage+ADBUsageExtensions.h"
#import "BXSession+BXUIControls.h"


#pragma mark - Private constants

//These device IDs were cribbed from Tattiebogle's 360 controller driver 0.1.2:
//http://tattiebogle.net/index.php/ProjectRoot/Xbox360Controller/OsxDriver#toc1

static uint16_t _360ControllerDeviceIDs[][2] = {
    {BXHIDVendorIDMicrosoft, 654},      //Microsoft wired 360 controller
    {BXHIDVendorIDMicrosoft, 657},      //Microsoft wireless 360 controller
    {BXHIDVendorIDMicrosoft, 1817},     //Microsoft wireless 360 controller (2)
    
    {BXHIDVendorIDLogitech, 49693},     //Logitech F310 in Xinput mode (q.v. BXDualActionControllerProfile)
    {BXHIDVendorIDLogitech, 49694},     //Logitech F510 in Xinput mode (q.v. BXDualActionControllerProfile)
    {BXHIDVendorIDLogitech, 49730},     //Logitech Chillstream
    
    {BXHIDVendorIDMadCatzAlternate, 64769},     //Mad Catz 360
    {BXHIDVendorIDMadCatzAlternate, 61477},     //Mad Catz Call of Duty Gamepad
    {BXHIDVendorIDMadCatzAlternate, 61473},     //Mad Catz Ghost Recon FS Gamepad
    {BXHIDVendorIDMadCatz, 18230},              //Mad Catz Microcon Gamepad Pro
    {BXHIDVendorIDMadCatzAlternate, 61494},     //Mad Catz Microcon Gamepad Pro (2)
    
    {BXHIDVendorIDMadCatz, 18216},              //Mad Catz Street Fighter IV FightPad
    {BXHIDVendorIDMadCatz, 18200},              //Mad Catz Street Fighter IV FightStick SE
    {BXHIDVendorIDMadCatz, 18232},              //Mad Catz Street Fighter IV FightStick TE
    {BXHIDVendorIDMadCatz, 63288},              //Mad Catz Street Fighter IV FightStick TES
    {BXHIDVendorIDMadCatzAlternate, 61480},     //Mad Catz Street Fighter IV FightPad (2)
    
    {BXHIDVendorIDMadCatzAlternate, 63750},     //Mad Catz Mortal Kombat FightStick
    
    {BXHIDVendorIDMadCatz, 18198},              //Mad Catz Xbox 360 Controller
    {BXHIDVendorIDMadCatz, 18214},              //Mad Catz Xbox 360 Controller (2)
    {BXHIDVendorIDMadCatz, 44879},              //Mad Catz Xbox 360 Controller (3)
    {BXHIDVendorIDMadCatzAlternate, 61462},     //Mad Catz Xbox 360 Controller (4)
    {BXHIDVendorIDMadCatz, 46886},              //Mad Catz Xbox Controller MW2
    {BXHIDVendorIDMadCatz, 52009},              //Mad Catz Aviator
    
    {BXHIDVendorIDMadCatz, 62465},              //Mad Catz Unknown Controller
    {BXHIDVendorIDMadCatzAlternate, 654},       //Mad Catz Unknown Controller (2)
    {BXHIDVendorIDMadCatzAlternate, 64001},     //Mad Catz Unknown Controller (3)
    {BXHIDVendorIDMadCatzAlternate, 63746},     //Mad Catz Unknown Controller (4)
    {BXHIDVendorIDMadCatzAlternate, 21760},     //Mad Catz Unknown Controller (4)
    
    {BXHIDVendorIDMadCatzAlternate, 63745},     //Gamestop 360 Controller
    {BXHIDVendorIDMadCatzAlternate, 63747},     //TRON 360 Controller
    
    {BXHIDVendorIDMadCatz, 51970},              //Saitek Cyborg Rumblepad
    {BXHIDVendorIDMadCatz, 51971},              //Saitek Cyborg P3200 Rumblepad
    
    {BXHIDVendorIDMadCatzAlternate, 62721},     //Hori Pad EX2 Turbo
    {BXHIDVendorIDHori, 10},                    //Hori DOA4 Fightstick
    {BXHIDVendorIDHori, 13},                    //Hori Fighting Stick
    {BXHIDVendorIDHori, 22},                    //Hori Real Arcade Pro EX
    {BXHIDVendorIDMadCatzAlternate, 62724},     //Hori Real Arcade Pro EX (2)
    {BXHIDVendorIDMadCatzAlternate, 62722},     //Hori Real Arcade Pro VX
    
    {BXHIDVendorIDHoriAlternate, 21761},        //Hori Real Arcade Pro VXSA
    {BXHIDVendorIDHoriAlternate, 21766},        //Hori Soul Calibur V Stick
    {BXHIDVendorIDHoriAlternate, 23296},        //Ferrari 458 Racing Wheel (TODO: check if this deserves a custom mapping)
    
    {BXHIDVendorIDRazer, 64768},                //Razer Onza
    {BXHIDVendorIDRazer, 64769},                //Razer Onza Tournament Edition
    
    {BXHIDVendorIDMadCatzAlternate, 61485},     //JoyTek Neo SE
    {BXHIDVendorIDJoyTek, 48879},               //JoyTek Neo SE Take2
    
    {BXHIDVendorIDBigBen, 1537},                //Big Ben 360 controller
    
    {BXHIDVendorIDPDP, 769},                    //PDP 360 gamepad
    {BXHIDVendorIDPDP, 1025},                   //PDP 360 gamepad (2)
    {BXHIDVendorIDPDP, 513},                    //PDP Pelican TSZ 360 gamepad
    
    {BXHIDVendorIDPDP, 287},                    //PDP Rock Candy Gamepad
    {BXHIDVendorIDPDP, 275},                    //PDP Afterglow Gamepad for Xbox 360
    {BXHIDVendorIDPDP, 531},                    //PDP Afterglow Gamepad for Xbox 360 (2)
    {BXHIDVendorIDMadCatzAlternate, 63744},     //PDP Afterglow Gamepad for Xbox 360 (3)
    {BXHIDVendorIDPDPAlternate, 769},           //PDP Afterglow AX.1
    
    {BXHIDVendorIDPDP, 62721},                  //Unknown PDP controller
    {BXHIDVendorIDPDPAlternate, 770},           //Unknown PDP Controller (2)
    
    {BXHIDVendorIDPowerA, 16128},               //Power A Mini Pro Elite
    {BXHIDVendorIDHoriAlternate, 21248},        //Power A Mini Pro Elite Glow
    {BXHIDVendorIDPowerA, 16144},               //Batarang wired controller
    {BXHIDVendorIDPowerA, 16138},               //Airflow wired controller
    
    {0,0} //End-of-list marker
};



enum {
	BX360ControllerLeftStickX		= kHIDUsage_GD_X,
	BX360ControllerLeftStickY		= kHIDUsage_GD_Y,
	BX360ControllerRightStickX		= kHIDUsage_GD_Rx,
	BX360ControllerRightStickY		= kHIDUsage_GD_Ry,
	BX360ControllerLeftTrigger		= kHIDUsage_GD_Z,
	BX360ControllerRightTrigger		= kHIDUsage_GD_Rz
};

enum {
	BX360ControllerAButton			= kHIDUsage_Button_1,
	BX360ControllerBButton,
	BX360ControllerXButton,
	BX360ControllerYButton,
	
	BX360ControllerLeftShoulder,
	BX360ControllerRightShoulder,
	
	BX360ControllerLeftStickClick,
	BX360ControllerRightStickClick,
	
	BX360ControllerStartButton,
	BX360ControllerBackButton,
	BX360ControllerXBoxButton,
	
	BX360ControllerDPadUp,
	BX360ControllerDPadDown,
	BX360ControllerDPadLeft,
	BX360ControllerDPadRight
};



@interface BX360ControllerProfile: BXHIDControllerProfile
@end


@implementation BX360ControllerProfile

+ (void) load
{
	[BXHIDControllerProfile registerProfile: self];
}

+ (BOOL) matchesDevice: (DDHidJoystick *)device
{
    NSUInteger i = 0;
    while (YES)
    {
        long vendorID   = _360ControllerDeviceIDs[i][0];
        long productID  = _360ControllerDeviceIDs[i][1];
        
        //We've reached the end of the ID list
        if (vendorID == 0)
            break;
        
        if (device.vendorId == vendorID && device.productId == productID)
            return YES;
        
        i++;
    };
    
    return NO;
}

- (BXControllerStyle) controllerStyle { return BXControllerStyleGamepad; }

- (NSDictionary *) DPadElementsFromButtons: (NSArray *)buttons
{
	NSMutableDictionary *padElements = [NSMutableDictionary dictionaryWithCapacity: 4];
	
	for (DDHidElement *element in buttons)
	{
		switch (element.usage.usageId)
		{
			case BX360ControllerDPadUp:
				[padElements setObject: element forKey: BXControllerProfileDPadUp];
				break;
				
			case BX360ControllerDPadDown:
				[padElements setObject: element forKey: BXControllerProfileDPadDown];
				break;
				
			case BX360ControllerDPadLeft:
				[padElements setObject: element forKey: BXControllerProfileDPadLeft];
				break;
			
			case BX360ControllerDPadRight:
				[padElements setObject: element forKey: BXControllerProfileDPadRight];
				break;
		}
		//Stop looking once we've found all the D-pad buttons
		if (padElements.count == 4) break;
	}
	
	return padElements;
}


//Custom binding for 360 shoulder buttons: bind to buttons 3 & 4 for regular joysticks
//(where the triggers are buttons 1 & 2), or to 1 & 2 for wheel emulation (where the
//triggers are the pedals).
- (id <BXHIDInputBinding>) generatedBindingForButtonElement: (DDHidElement *)element
{
	id <BXHIDInputBinding> binding = nil;
	BOOL isWheel =	[self.emulatedJoystick conformsToProtocol: @protocol(BXEmulatedWheel)];

	switch (element.usage.usageId)
	{
		case BX360ControllerLeftShoulder:
            binding = [self bindingFromButtonElement: element
                                            toButton: (isWheel ? BXEmulatedJoystickButton2 : BXEmulatedJoystickButton4)];
			break;
            
		case BX360ControllerRightShoulder:
			binding = [self bindingFromButtonElement: element
                                            toButton: (isWheel ? BXEmulatedJoystickButton1 : BXEmulatedJoystickButton3)];
			break;
            
        case BX360ControllerBackButton:
            binding = [self bindingFromButtonElement: element toKeyCode: KBD_esc];
            break;
        
        case BX360ControllerStartButton:
            binding = [self bindingFromButtonElement: element toTarget: nil action: @selector(togglePaused:)];
            break;
            
        default:
            binding = [super generatedBindingForButtonElement: element];
	}
		
	return binding;
}

//Bind triggers to buttons 1 & 2 for regular joystick emulation.
- (id <BXHIDInputBinding>) generatedBindingForAxisElement: (DDHidElement *)element
{
	id <BXHIDInputBinding> binding = nil;
	
	switch (element.usage.usageId)
	{
		case BX360ControllerLeftTrigger:
            binding = [self bindingFromTriggerElement: element toButton: BXEmulatedJoystickButton2];
			break;
		
		case BX360ControllerRightTrigger:
            binding = [self bindingFromTriggerElement: element toButton: BXEmulatedJoystickButton1];
			break;
			
		default:
			binding = [super generatedBindingForAxisElement: element];
	}
	return binding;
}

//Bind triggers to brake/accelerator for wheel emulation.
- (void) bindAxisElementsForWheel: (NSArray *)elements
{
    for (DDHidElement *element in elements)
    {
        id <BXHIDInputBinding> binding;
        switch (element.usage.usageId)
        {
            case BX360ControllerLeftStickX:
                binding = [self bindingFromAxisElement: element toAxis: BXAxisWheel];
                break;
                
            case BX360ControllerRightStickY:
                binding = [self bindingFromAxisElement: element
                                        toPositiveAxis: BXAxisBrake
                                          negativeAxis: BXAxisAccelerator];
                break;
                
            case BX360ControllerLeftTrigger:
                binding = [self bindingFromTriggerElement: element toAxis: BXAxisBrake];
                break;
                
            case BX360ControllerRightTrigger:
                binding = [self bindingFromTriggerElement: element toAxis: BXAxisAccelerator];
                break;
                
            default:
                binding = nil;
        }
        
        if (binding)
            [self setBinding: binding forElement: element];
    }
}

@end