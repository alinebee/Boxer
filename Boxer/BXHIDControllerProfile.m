/* 
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHIDControllerProfilePrivate.h"
#import "BXBezelController.h"
#import "DDHIDUsage+ADBUsageExtensions.h"


@implementation BXHIDControllerProfile

#pragma mark -
#pragma mark Constants

NSString * const BXControllerProfileDPadLeft	= @"BXControllerProfileDPadLeft";
NSString * const BXControllerProfileDPadRight	= @"BXControllerProfileDPadRight";
NSString * const BXControllerProfileDPadUp		= @"BXControllerProfileDPadUp";
NSString * const BXControllerProfileDPadDown	= @"BXControllerProfileDPadDown";


#pragma mark -
#pragma mark Locating custom profiles

static NSMutableArray *_profileClasses = nil;

//Keep a record of every BXHIDControllerProfile subclass that comes along
+ (void) registerProfile: (Class)profile
{
	if (!_profileClasses)
		_profileClasses = [[NSMutableArray alloc] initWithCapacity: 10];
	
	[_profileClasses addObject: profile];
}

+ (NSArray *)matchedIDs
{
    return [NSArray array];
}

+ (NSDictionary *) matchForVendorID: (long)vendorID
                          productID: (long)productID
{
    return [NSDictionary dictionaryWithObjectsAndKeys:
            [NSNumber numberWithLong: vendorID], @"vendorID",
            [NSNumber numberWithLong: productID], @"productID",
    nil];
}

+ (BOOL) matchesDevice: (DDHidJoystick *)device
{
    for (NSDictionary *pairs in [self matchedIDs])
    {
        long vendorID = [(NSNumber *)[pairs objectForKey: @"vendorID"] longValue],
            productID = [(NSNumber *)[pairs objectForKey: @"productID"] longValue];
        
        if (device.vendorId == vendorID && device.productId == productID)
            return YES;
    }
    return NO;
}

+ (Class) profileClassForDevice: (DDHidJoystick *)device
{	
	//Find a subclass that identifies with this device,
	//falling back on a generic profile if none was found.
	for (Class profileClass in _profileClasses)
	{
		if ([profileClass matchesDevice: device])
            return profileClass;
	}
	
	return self;
}


#pragma mark -
#pragma mark Initialization and deallocation

+ (id) profileForHIDDevice: (DDHidJoystick *)device
          emulatedJoystick: (id <BXEmulatedJoystick>)joystick
                  keyboard: (BXEmulatedKeyboard *)keyboard
{
	Class profileClass = [self profileClassForDevice: device];
	
	return [[profileClass alloc] initWithHIDDevice: device
                                   emulatedJoystick: joystick
                                           keyboard: keyboard];
}


- (id) init
{
    self = [super init];
	if (self)
    {
        self.controllerStyle = BXControllerStyleUnknown;
		self.bindings = [NSMutableDictionary dictionaryWithCapacity: 20];
	}
	return self;
}

- (id) initWithHIDDevice: (DDHidJoystick *)device
        emulatedJoystick: (id <BXEmulatedJoystick>)joystick
                keyboard: (BXEmulatedKeyboard *)keyboard
{
    self = [self init];
	if (self)
	{
        self.device = device;
        self.emulatedJoystick = joystick;
        self.emulatedKeyboard = keyboard;
        
        [self generateBindings];
	}
	return self;
}


#pragma mark -
#pragma mark Property accessors

- (void) setBinding: (id <BXHIDInputBinding>)binding
		 forElement: (DDHidElement *)element
{
	DDHidUsage *key = element.usage;
	if (binding == nil) [self.bindings removeObjectForKey: key];
	else [self.bindings setObject: binding forKey: key];
}

- (id <BXHIDInputBinding>) bindingForElement: (DDHidElement *)element
{
	return [self.bindings objectForKey: element.usage];
}


#pragma mark -
#pragma mark Binding generation

- (void) generateBindings
{
	//Clear our existing bindings before we begin
	[self.bindings removeAllObjects];
	
	//Don't continue if we don't yet know what we're mapping to or from
	if (!self.device || !self.emulatedJoystick) return;
	
	NSArray *axes       = self.device.axisElements;
	NSArray *buttons	= self.device.buttonElements;
	NSArray *POVs		= self.device.povElements;
    
    for (DDHidElement *element in axes)
    {
        NSLog(@"Axis: %@ Properties: %@", element.usage.usageName, element.properties);
	}
    
	//If the controller has a D-pad, then bind it separately from the other buttons
	NSDictionary *dPad = [self DPadElementsFromButtons: buttons];
	if (dPad.count)
	{
		NSMutableArray *filteredButtons = [NSMutableArray arrayWithArray: buttons];
		[filteredButtons removeObjectsInArray: dPad.allValues];
		buttons = filteredButtons;
	}
	
	if (axes.count)		[self bindAxisElements: axes];
	if (buttons.count)	[self bindButtonElements: buttons];
	if (POVs.count)		[self bindPOVElements: POVs];
	if (dPad.count)		[self bindDPadElements: dPad];
}

- (void) bindAxisElements: (NSArray *)elements
{
    //Sort the elements by usage, in case the device enumerates them in a funny order.
    //TWEAK: we also filter out axes with duplicate usages, so that each usage will only appear once.
    NSMutableDictionary *elementsByUsage = [NSMutableDictionary dictionaryWithCapacity: elements.count];
    for (DDHidElement *element in elements)
    {
        if ([elementsByUsage objectForKey: element.usage] == nil)
            [elementsByUsage setObject: element forKey: element.usage];
    }
    
    NSArray *sortedElements = [elementsByUsage.allValues sortedArrayUsingSelector: @selector(compareByUsage:)];
    
    //Custom binding logic for wheels, as each axis's role depends on what other axes are available
    if ([self.emulatedJoystick conformsToProtocol: @protocol(BXEmulatedWheel)])
    {
        [self bindAxisElementsForWheel: sortedElements];
    }
    else
    {
        for (DDHidElement *element in sortedElements)
        {
            id <BXHIDInputBinding> binding = [self generatedBindingForAxisElement: element];
            [self setBinding: binding forElement: element];
        }
    }
}

- (void) bindAxisElementsForWheel: (NSArray *)elements
{
    //Unlike regular axis mapping, wheel axis mapping doesn't check the axis types of individual
    //axis elements. Instead it sorts all the axes by usage ID and maps them to the wheel based
    //on that enumeration order.
    
    //We take this approach instead of mapping based on usage, because wheel controllers have not
    //been tested extensively and I don't know which axis usages are commonly used for pedals.
    //Instead we just assume that e.g. on a 3-axis wheel controller, the 2nd axis will be brake
    //and the 3rd will be accelerator (regardless of their respective usages).
    
    DDHidElement *wheel, *accelerator, *brake;
    
    NSUInteger numAxes = elements.count;
    //There's nothing we can do with a single-axis controller.
    if (numAxes < 2)
        return;
    
    //Decide what to do with the axis elements based on what kind of controller we're dealing with.
    BXControllerStyle style = self.controllerStyle;
    
    //If we don't know what kind of controller we are yet, then guess based on how many axes are available.
    if (style == BXControllerStyleUnknown)
    {
        switch (numAxes)
        {
            case 2:
                //Assume this is a 2-axis joystick.
                style = BXControllerStyleJoystick;
                break;
            case 3:
                //Assume this is a 3-axis wheel with pedals on individual axes.
                //(There's a good chance it's actually a flightstick instead, in which case this
                //will be completely wrong; but a flightstick would suck for wheel control anyway.)
                style = BXControllerStyleWheel;
                break;
            case 4:
            default:
                //Assume this is a twin-stick gamepad. (It may also be an advanced flightstick, but see above.)
                style = BXControllerStyleGamepad;
                break;
        }
    }

    switch (style)
    {
        case BXControllerStyleGamepad:
            wheel = [elements objectAtIndex: 0];
            
            //For twin-stick gamepads, map the steering to the left stick and the accelerator/brake
            //to the right stick. This is because steering control sucks if they're all on one axis.
            if (numAxes >= 4)
            {
                accelerator = brake = [elements objectAtIndex: 3];
            }
            else
            {
                accelerator = brake = [elements objectAtIndex: 1];
            }
            break;
            
        case BXControllerStyleWheel:
            wheel = [elements objectAtIndex: 0];
            
            //For wheels that have 3 or more axes, assume the accelerator and brake are on separate axes.
            if (numAxes >= 3)
            {
                brake       = [elements objectAtIndex: 1];
                accelerator = [elements objectAtIndex: 2];
            }
            else
            {   
                accelerator = brake = [elements objectAtIndex: 1];
            }
            break;
        
        //For everything else, only use the first two axes.
        case BXControllerStyleJoystick:
        case BXControllerStyleFlightstick:
        default:
            wheel = [elements objectAtIndex: 0];
            accelerator = brake = [elements objectAtIndex: 1];
            break;
    }
    
    BXHIDAxisBinding *wheelBinding = [self bindingFromAxisElement: wheel toAxis: BXAxisWheel];
    [self setBinding: wheelBinding forElement: wheel];
    
    //If the same input is used for both brake and accelerator, map them as a split axis binding.
    if (brake == accelerator)
    {
        BXHIDAxisBinding *splitBinding = [self bindingFromAxisElement: accelerator
                                                       toPositiveAxis: BXAxisBrake
                                                         negativeAxis: BXAxisAccelerator];
        
        [self setBinding: splitBinding forElement: accelerator];
    }
    //Otherwise map them to the individual axis elements as unidirectional inputs.
    else
    {
        BXHIDAxisBinding *acceleratorBinding    = [self bindingFromTriggerElement: accelerator toAxis: BXAxisAccelerator];
        BXHIDAxisBinding *brakeBinding          = [self bindingFromTriggerElement: brake toAxis: BXAxisBrake];
        
        [self setBinding: acceleratorBinding forElement: accelerator];
        [self setBinding: brakeBinding forElement: brake];
    }
}


- (void) bindButtonElements: (NSArray *)elements
{
	for (DDHidElement *element in elements)
	{
		id <BXHIDInputBinding> binding = [self generatedBindingForButtonElement: element];
		[self setBinding: binding forElement: element];
	}
}

- (void) bindPOVElements: (NSArray *)elements
{
	for (DDHidElement *element in elements)
	{
		id <BXHIDInputBinding> binding = [self generatedBindingForPOVElement: element];
		[self setBinding: binding forElement: element];
	}
}

- (id <BXHIDInputBinding>) generatedBindingForButtonElement: (DDHidElement *)element
{	
    //Only assign buttons up to 8. Buttons 1-4 are usually face buttons,
    //and 5-8 are usually front buttons (on gamepads) or base buttons (on joysticks.)
    //Once we get above 8 however, we're into the realm of start/select buttons and
    //thumbstick-clicks, and we don't want to bind those automatically.
	NSUInteger maxButtons = 8;
	
	NSUInteger numEmulatedButtons = [self.emulatedJoystick.class numButtons];
	NSUInteger realButton = element.usage.usageId;
    
	//Wrap controller buttons so that they'll fit within the number of emulated buttons
	if (realButton <= maxButtons)
	{
		BXEmulatedJoystickButton emulatedButton = ((realButton - 1) % numEmulatedButtons) + 1;
        
        return [self bindingFromButtonElement: element toButton: emulatedButton];
	}
	else return nil;
}

- (id <BXHIDInputBinding>) generatedBindingForAxisElement: (DDHidElement *)element
{
	NSUInteger axis = element.usage.usageId, normalizedAxis;
	
	//First, normalize the axes to known conventions
	switch (axis)
	{
		case kHIDUsage_GD_Z:
			normalizedAxis = kHIDUsage_GD_Rx;
			break;
			
		case kHIDUsage_GD_Rz:
			//Some joysticks pair Rz with Z, in which case it should be normalized to Ry (with Z as Rx);
			//Others pair it with Slider, in which case it should be treated as Rx.
			{
				BOOL hasZAxis = [self.device axisElementWithUsageID: kHIDUsage_GD_Z] != nil;
                normalizedAxis = (hasZAxis) ? kHIDUsage_GD_Ry : kHIDUsage_GD_Rx;
			}
			break;
		
		case kHIDUsage_GD_Dial:
			//Only seen once, and that was paired with Slider.
			normalizedAxis = kHIDUsage_GD_Rx;
			break;
			
		case kHIDUsage_GD_Slider:
			normalizedAxis = kHIDUsage_GD_Ry;
			break;
			
		default:
			normalizedAxis = axis;
	}

    BXHIDAxisBinding *axisBinding = nil;
	//Then, assign behaviour based on its normalized position
	switch (normalizedAxis)
	{
		case kHIDUsage_GD_X:
			if ([self.emulatedJoystick supportsAxis: BXAxisX])
                axisBinding = [self bindingFromAxisElement: element toAxis: BXAxisX];
            
			break;
			
		case kHIDUsage_GD_Y:
			if ([self.emulatedJoystick supportsAxis: BXAxisY])
                axisBinding = [self bindingFromAxisElement: element toAxis: BXAxisY];
            
			break;
			
		case kHIDUsage_GD_Rx:
            if ([self.emulatedJoystick supportsAxis: BXAxisRudder])
                axisBinding = [self bindingFromAxisElement: element toAxis: BXAxisRudder];
            
            else if ([self.emulatedJoystick supportsAxis: BXAxisX2])
                axisBinding = [self bindingFromAxisElement: element toAxis: BXAxisX2];
            
        	break;
			
		case kHIDUsage_GD_Ry:
            if ([self.emulatedJoystick supportsAxis: BXAxisThrottle])
            {
                //If we know the HID device is a flightstick, assume that
                //any throttle it has will not spring back to center and
                //can be mapped directly to the emulated throttle.
                if (self.controllerStyle == BXControllerStyleFlightstick)
                {
                    axisBinding = [self bindingFromAxisElement: element toAxis: BXAxisThrottle];
                }
                //Otherwise, use an additive axis instead of an absolute one.
                //This works best for axes that spring back to center:
                //pushing the device axis up will gradually increase the emulated
                //axis value and pushing it down will gradually decrease the value,
                //while returning the device axis to center will stop the change.
                else
                {
                    axisBinding = [self bindingFromAxisElement: element toAdditiveThrottleAxis: BXAxisThrottle];
                }
            }
            else if ([self.emulatedJoystick supportsAxis: BXAxisY2])
                axisBinding = [self bindingFromAxisElement: element toAxis: BXAxisY2];
            
			break;
	}
    
    return axisBinding;
}

- (id <BXHIDInputBinding>) generatedBindingForPOVElement: (DDHidElement *)element
{
	id <BXHIDInputBinding> binding = nil;
    NSLog(@"Binding POV element: %@", element);
	
    //Map POV directly to POV on emulated joystick, if available
	if ([self.emulatedJoystick conformsToProtocol: @protocol(BXEmulatedFlightstick)])
	{
		binding = [self bindingFromPOVElement: element toPOV: 0];
	}
    //TWEAK: Don't map hat-switches on flightstick-style controllers to act as X/Y/wheel axes.
    //This would be inappropriate for an actual hat-switch; the behaviour is only intended for D-pads.
	else if (self.controllerStyle != BXControllerStyleFlightstick)
	{
        //Otherwise, map the POV's left and right directions to the wheel axis if available
		if ([self.emulatedJoystick supportsAxis: BXAxisWheel])
		{
			binding = [self bindingFromPOVElement: element toHorizontalAxis: BXAxisWheel verticalAxis: nil];
		}
        
        //Otherwise, map the POV to the X and Y axes if available
		else if ([self.emulatedJoystick supportsAxis: BXAxisX] &&
                 [self.emulatedJoystick supportsAxis: BXAxisY])
		{
            binding = [self bindingFromPOVElement: element toHorizontalAxis: BXAxisX verticalAxis: BXAxisY];
		}
	}
    
	return binding;
}


#pragma mark - Binding generation helpers

- (id <BXHIDInputBinding>) bindingFromAxisElement: (DDHidElement *)element
                                           toAxis: (NSString *)axisName
{
    return [self bindingFromAxisElement: element toPositiveAxis: axisName negativeAxis: axisName];
}

- (id <BXHIDInputBinding>) bindingFromAxisElement: (DDHidElement *)element
                                   toPositiveAxis: (NSString *)positiveAxisName
                                     negativeAxis: (NSString *)negativeAxisName
{
    id positiveBinding = [BXEmulatedJoystickAxisBinding bindingWithJoystick: self.emulatedJoystick
                                                                       axis: positiveAxisName
                                                                   polarity: kBXAxisPositive];
    
    id negativeBinding = [BXEmulatedJoystickAxisBinding bindingWithJoystick: self.emulatedJoystick
                                                                       axis: negativeAxisName
                                                                   polarity: kBXAxisNegative];
    
    return [BXHIDAxisBinding bindingWithPositiveBinding: positiveBinding negativeBinding: negativeBinding];
}

- (id <BXHIDInputBinding>) bindingFromButtonElement: (DDHidElement *)element
                                           toButton: (BXEmulatedJoystickButton)button
{
    id outputBinding = [BXEmulatedJoystickButtonBinding bindingWithJoystick: self.emulatedJoystick button: button];
    return [BXHIDButtonBinding bindingWithOutputBinding: outputBinding];
}

- (id <BXHIDInputBinding>) bindingFromButtonElement: (DDHidElement *)element
                                             toAxis: (NSString *)axisName
                                           polarity: (BXAxisPolarity)polarity
{
    id outputBinding = [BXEmulatedJoystickAxisBinding bindingWithJoystick: self.emulatedJoystick axis: axisName polarity: polarity];
    return [BXHIDButtonBinding bindingWithOutputBinding: outputBinding];
}

- (id <BXHIDInputBinding>) bindingFromButtonElement: (DDHidElement *)element
                                              toPOV: (NSUInteger)POVNumber
                                          direction: (BXEmulatedPOVDirection)direction
{
    id outputBinding = [BXEmulatedJoystickPOVDirectionBinding bindingWithJoystick: self.emulatedJoystick POV: POVNumber direction: direction];
    return [BXHIDButtonBinding bindingWithOutputBinding: outputBinding];
}

- (id <BXHIDInputBinding>) bindingFromTriggerElement: (DDHidElement *)element
                                              toAxis: (NSString *)axisName
{
    id positiveBinding = [BXEmulatedJoystickAxisBinding bindingWithJoystick: self.emulatedJoystick
                                                                       axis: axisName
                                                                   polarity: kBXAxisPositive];
    
    BXHIDAxisBinding *binding = [BXHIDAxisBinding bindingWithPositiveBinding: positiveBinding negativeBinding: nil];
    binding.unidirectional = YES;
    binding.deadzone = BXHIDControllerProfileTriggerAxisDeadzone;
    return binding;
}

- (id <BXHIDInputBinding>) bindingFromTriggerElement: (DDHidElement *)element
                                            toButton: (BXEmulatedJoystickButton)button
{
    id positiveBinding = [BXEmulatedJoystickButtonBinding bindingWithJoystick: self.emulatedJoystick
                                                                       button: button];
    
    BXHIDAxisBinding *binding = [BXHIDAxisBinding bindingWithPositiveBinding: positiveBinding negativeBinding: nil];
    binding.unidirectional = YES;
    binding.deadzone = BXHIDControllerProfileTriggerAxisDeadzone;
    return binding;
}

- (id <BXHIDInputBinding>) bindingFromAxisElement: (DDHidElement *)element
                           toAdditiveThrottleAxis: (NSString *)axisName
{
    BXEmulatedJoystickAxisAdditiveBinding *positiveBinding = [BXEmulatedJoystickAxisAdditiveBinding bindingWithJoystick: self.emulatedJoystick
                                                                                                                   axis: axisName
                                                                                                                   rate: BXHIDControllerProfileAdditiveThrottleRate];
    
    BXEmulatedJoystickAxisAdditiveBinding *negativeBinding = [BXEmulatedJoystickAxisAdditiveBinding bindingWithJoystick: self.emulatedJoystick
                                                                                                                   axis: axisName
                                                                                                                   rate: -BXHIDControllerProfileAdditiveThrottleRate];
    
    positiveBinding.delegate = self;
    positiveBinding.outputThreshold = BXHIDControllerProfileAdditiveThrottleSnapThreshold;
    negativeBinding.delegate = self;
    negativeBinding.outputThreshold = BXHIDControllerProfileAdditiveThrottleSnapThreshold;
    
    return [BXHIDAxisBinding bindingWithPositiveBinding: positiveBinding negativeBinding: negativeBinding];
}

- (id <BXHIDInputBinding>) bindingFromPOVElement: (DDHidElement *)element toPOV: (NSUInteger)POVNumber
{
    BXHIDPOVSwitchBinding *binding = [BXHIDPOVSwitchBinding binding];
    
    ADBHIDPOVSwitchDirection from[8] = {
        ADBHIDPOVNorth,
        ADBHIDPOVNorthEast,
        ADBHIDPOVEast,
        ADBHIDPOVSouthEast,
        ADBHIDPOVSouth,
        ADBHIDPOVSouthWest,
        ADBHIDPOVWest,
        ADBHIDPOVNorthWest,
    };
    
    BXEmulatedPOVDirection to[8] = {
        BXEmulatedPOVNorth,
        BXEmulatedPOVNorthEast,
        BXEmulatedPOVEast,
        BXEmulatedPOVSouthEast,
        BXEmulatedPOVSouth,
        BXEmulatedPOVSouthWest,
        BXEmulatedPOVWest,
        BXEmulatedPOVNorthWest,
    };
    
    @autoreleasepool {
    for (NSUInteger i=0; i<8; i++)
    {
        id outputBinding = [BXEmulatedJoystickPOVDirectionBinding bindingWithJoystick: self.emulatedJoystick
                                                                                  POV: POVNumber
                                                                            direction: to[i]];
        
        [binding setBinding: outputBinding forDirection: from[i]];
    }
    }
    
    return binding;
}

- (id <BXHIDInputBinding>) bindingFromPOVElement: (DDHidElement *)element
                                toHorizontalAxis: (NSString *)horizAxis
                                    verticalAxis: (NSString *)vertAxis
{
    BXHIDPOVSwitchBinding *binding = [BXHIDPOVSwitchBinding binding];
    
    if (horizAxis)
    {
        [binding setBinding: [BXEmulatedJoystickAxisBinding bindingWithJoystick: self.emulatedJoystick axis: horizAxis polarity: kBXAxisNegative]
               forDirection: ADBHIDPOVWest];
        
        [binding setBinding: [BXEmulatedJoystickAxisBinding bindingWithJoystick: self.emulatedJoystick axis: horizAxis polarity: kBXAxisPositive]
               forDirection: ADBHIDPOVEast];
    }
    
    if (vertAxis)
    {
        [binding setBinding: [BXEmulatedJoystickAxisBinding bindingWithJoystick: self.emulatedJoystick axis: vertAxis polarity: kBXAxisNegative]
               forDirection: ADBHIDPOVNorth];
        
        [binding setBinding: [BXEmulatedJoystickAxisBinding bindingWithJoystick: self.emulatedJoystick axis: vertAxis polarity: kBXAxisPositive]
               forDirection: ADBHIDPOVSouth];
    }
    
    return binding;
}

- (id <BXHIDInputBinding>) bindingFromButtonElement: (DDHidElement *)element toKeyCode: (BXDOSKeyCode)keyCode
{
    id outputBinding = [BXEmulatedKeyboardKeyBinding bindingWithKeyboard: self.emulatedKeyboard keyCode: keyCode];
    
    return [BXHIDButtonBinding bindingWithOutputBinding: outputBinding];
}

- (id <BXHIDInputBinding>) bindingFromTriggerElement: (DDHidElement *)element toKeyCode: (BXDOSKeyCode)keyCode
{
    id positiveBinding = [BXEmulatedKeyboardKeyBinding bindingWithKeyboard: self.emulatedKeyboard keyCode: keyCode];
    
    BXHIDAxisBinding *binding = [BXHIDAxisBinding bindingWithPositiveBinding: positiveBinding negativeBinding: nil];
    binding.unidirectional = YES;
    binding.deadzone = BXHIDControllerProfileTriggerAxisDeadzone;
    return binding;
}

- (id <BXHIDInputBinding>) bindingFromButtonElement: (DDHidElement *)element
                                           toTarget: (id)target
                                             action: (SEL)action
{
    id positiveBinding = [BXTargetActionBinding bindingWithTarget: target pressedAction: action releasedAction: NULL];
    return [BXHIDButtonBinding bindingWithOutputBinding: positiveBinding];
}

- (id <BXHIDInputBinding>) bindingFromTriggerElement: (DDHidElement *)element
                                            toTarget: (id)target
                                              action: (SEL)action
{
    id positiveBinding = [BXTargetActionBinding bindingWithTarget: target pressedAction: action releasedAction: NULL];
    
    BXHIDAxisBinding *binding = [BXHIDAxisBinding bindingWithPositiveBinding: positiveBinding negativeBinding: nil];
    binding.unidirectional = YES;
    binding.deadzone = BXHIDControllerProfileTriggerAxisDeadzone;
    return binding;
}

#pragma mark - Event handling

//Overridden in subclasses where necessary
- (BOOL) shouldDispatchHIDEvent: (ADBHIDEvent *)event
{
    return YES;
}

//Send the event on to the appropriate binding for that element
- (void) dispatchHIDEvent: (ADBHIDEvent *)event
{
    if ([self shouldDispatchHIDEvent: event])
    {
        id <BXHIDInputBinding> binding = [self bindingForElement: event.element];
        
        [binding processEvent: event];
    }
}

- (void) outputBindingDidUpdate: (BXEmulatedJoystickAxisAdditiveBinding *)binding
{
    //Display a notification bezel showing the current state of any additive throttle axis.
    if ([binding isKindOfClass: [BXEmulatedJoystickAxisAdditiveBinding class]] && [binding.axisName isEqualToString: BXAxisThrottle])
    {
        float throttleValue = [(id <BXEmulatedFlightstick>)binding.joystick throttleAxis];
        [[BXBezelController controller] showThrottleBezelForValue: throttleValue];
    }
}
                   

@end


@implementation BXHIDControllerProfile (BXDPadBindings)

//Override me in subclasses!
- (NSDictionary *) DPadElementsFromButtons: (NSArray *)buttons
{
	return nil;
}

- (void) bindDPadElements: (NSDictionary *)padElements
{
	//Map the D-pad to a POV switch if the joystick has one
	if ([self.emulatedJoystick conformsToProtocol: @protocol(BXEmulatedFlightstick)])
	{
		[self bindDPadElements: padElements toPOV: 0];
	}
	//Otherwise, map it to the X and Y axes or wheel
	else
	{
		if ([self.emulatedJoystick supportsAxis: BXAxisX] && [self.emulatedJoystick supportsAxis: BXAxisY])
		{
			[self bindDPadElements: padElements toHorizontalAxis: BXAxisX verticalAxis: BXAxisY];
		}
        
        else if ([self.emulatedJoystick supportsAxis: BXAxisWheel])
        {
            [self bindDPadElements: padElements toHorizontalAxis: BXAxisWheel verticalAxis: nil];
        }
	}
}

- (void) bindDPadElements: (NSDictionary *)padElements
					toPOV: (NSUInteger)POVNumber
{
	for (NSString *key in padElements.keyEnumerator)
	{
		DDHidElement *element = [padElements objectForKey: key];
        BXEmulatedPOVDirection direction = BXEmulatedPOVCentered;
		
		//Oh for a switch statement
		if ([key isEqualToString: BXControllerProfileDPadUp])
		{
            direction = BXEmulatedPOVNorth;
		}
		else if ([key isEqualToString: BXControllerProfileDPadDown])
		{
            direction = BXEmulatedPOVSouth;
		}
		else if ([key isEqualToString: BXControllerProfileDPadLeft])
		{
            direction = BXEmulatedPOVWest;
		}
		else if ([key isEqualToString: BXControllerProfileDPadRight])
		{
            direction = BXEmulatedPOVEast;
		}
		
		if (direction != BXEmulatedPOVCentered)
		{
			id <BXHIDInputBinding> binding = [self bindingFromButtonElement: element toPOV: POVNumber direction: direction];
            [self setBinding: binding forElement: element];
		}
	}
}

- (void) bindDPadElements: (NSDictionary *)padElements
		 toHorizontalAxis: (NSString *)xAxis
			 verticalAxis: (NSString *)yAxis
{
	for (NSString *key in padElements.keyEnumerator)
	{
		DDHidElement *element = [padElements objectForKey: key];
		
		NSString *axis = nil;
        BXAxisPolarity polarity = kBXAxisPositive;
		
		//Oh for a switch statement
		if ([key isEqualToString: BXControllerProfileDPadUp])
		{
			axis = yAxis;
            polarity = kBXAxisNegative;
		}
		else if ([key isEqualToString: BXControllerProfileDPadDown])
		{
			axis = yAxis;
            polarity = kBXAxisPositive;
		}
		else if ([key isEqualToString: BXControllerProfileDPadLeft])
		{
			axis = xAxis;
            polarity = kBXAxisNegative;
		}
		else if ([key isEqualToString: BXControllerProfileDPadRight])
		{
			axis = xAxis;
            polarity = kBXAxisPositive;
		}
		
		if (axis)
		{
            id <BXHIDInputBinding> binding = [self bindingFromButtonElement: element toAxis: axis polarity: polarity];
			[self setBinding: binding forElement: element];
		}
	}
}

- (NSString *) description
{
    NSMutableString *desc = [NSMutableString stringWithCapacity: 500];
    
    [desc appendFormat: @"Controller profile of type: %@\n", self.class];
    [desc appendFormat: @"From controller: %@\n", self.device];
    [desc appendFormat: @"To emulated joystick: %@\n", self.emulatedJoystick.class];
    
    //Print out all buttons on the controller.
    [desc appendFormat: @"Buttons: %@\n", self.device.buttonElements];
    
    //Print out a breakdown of each stick's axes and POV elements.
    NSUInteger stickIndex = 0;
    for (DDHidJoystickStick *stick in self.device.sticks)
    {
        NSString *indentedStickDesc = [stick.description stringByReplacingOccurrencesOfString: @"\n"
                                                                                   withString: @"\n\t"];
        [desc appendFormat: @"Stick %lu:\n\t%@\n", (long)stickIndex, indentedStickDesc];
        stickIndex++;
    }
    
    //Print out the properties of each individual axis.
    [desc appendString: @"Axis properties: {\n"];
    for (DDHidElement *axis in self.device.axisElements)
    {
        [desc appendFormat: @"\t%@ = %@,\n", axis.usage.usageName, [axis.properties descriptionWithLocale: nil indent: 1]];
    }
    [desc appendString: @"}\n"];
    
    //Print out our dictionary of usage->binding mappings.
    //IMPLEMENTATION NOTE: we sort this by usage to group similar usages (axes, buttons etc.) together.
    NSArray *sortedKeys = [self.bindings.allKeys sortedArrayUsingSelector: @selector(compare:)];
    [desc appendString: @"Bindings: {\n"];
    for (DDHidUsage *key in sortedKeys)
    {
        id value = [self.bindings objectForKey: key];
        [desc appendFormat: @"\t%@ = %@,\n", key.usageName, value];
    }
    [desc appendString: @"}\n"];
    
    return desc;
}
@end
