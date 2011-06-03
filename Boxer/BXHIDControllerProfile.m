/* 
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXHIDControllerProfile.h"
#import "BXEmulatedJoystick.h"
#import "BXHIDInputBinding.h"
#import "DDHidDevice+BXDeviceExtensions.h"


@interface BXHIDControllerProfile ()


#pragma mark -
#pragma mark Private method declarations

+ (BOOL) _matchesHIDController: (DDHidJoystick *)HIDController;

- (void) _generateBindings;

- (id <BXHIDInputBinding>) _bindingForAxisElement: (DDHidElement *)element;
- (id <BXHIDInputBinding>) _bindingForButtonElement: (DDHidElement *)element;
- (id <BXHIDInputBinding>) _bindingForPOVElement: (DDHidElement *)element;

@end



#pragma mark -
#pragma mark Implementation

@implementation BXHIDControllerProfile
@synthesize HIDController = _HIDController;
@synthesize emulatedJoystick = _emulatedJoystick;
@synthesize bindings = _bindings;

#pragma mark -
#pragma mark Initialization and deallocation

+ (BOOL) _matchesHIDController: (DDHidJoystick *)HIDController
{
	return NO;
}

+ (id) profileForHIDController: (DDHidJoystick *)HIDController
			toEmulatedJoystick: (id <BXEmulatedJoystick>)emulatedJoystick
{
	return [[[self alloc] initWithHIDController: HIDController
							 toEmulatedJoystick: emulatedJoystick] autorelease];
}

- (id) init
{
	if ((self = [super init]))
	{
		_bindings = [[NSMutableDictionary alloc] initWithCapacity: 20];
	}
	return self;
}

- (id) initWithHIDController: (DDHidJoystick *)HIDController
		  toEmulatedJoystick: (id <BXEmulatedJoystick>)emulatedJoystick 
{
	if ((self = [self init]))
	{
		[self setHIDController: HIDController];
		[self setEmulatedJoystick: emulatedJoystick];
	}
	return self;
}

- (void) dealloc
{
	[_bindings release], _bindings = nil;
	[self setHIDController: nil], [_HIDController release];
	[self setEmulatedJoystick: nil], [_emulatedJoystick release];
	[super dealloc];
}

- (void) setHIDController: (DDHidJoystick *)controller
{
	if (![controller isEqual: _HIDController])
	{
		[_HIDController release];
		_HIDController = [controller retain];
		
		[self _generateBindings];
	}
}

- (void) setEmulatedJoystick: (id <BXEmulatedJoystick>)joystick
{
	if (![joystick isEqual: _emulatedJoystick])
	{
		[_emulatedJoystick release];
		_emulatedJoystick = [joystick retain];
		
		[self _generateBindings];
	}
}


#pragma mark -
#pragma mark Binding generation

- (void) _generateBindings
{
	//Clear our existing bindings before we begin
	[[self bindings] removeAllObjects];
	
	//Don't continue if we don't yet know what we're mapping to or from
	if (![self HIDController] || ![self emulatedJoystick]) return;
	
	NSArray *axes			= [[self HIDController] axisElements];
	NSArray *buttons		= [[self HIDController] buttonElements];
	NSArray *POVs			= [[self HIDController] povElements];
	
	id <BXHIDInputBinding> binding;
	
	for (DDHidElement *element in axes)
	{
		binding = [self _bindingForAxisElement: element];
		if (binding) [[self bindings] setObject: binding forKey: [element usage]];
	}
	
	for (DDHidElement *element in buttons)
	{
		binding = [self _bindingForButtonElement: element];
		if (binding) [[self bindings] setObject: binding forKey: [element usage]];
	}
	
	for (DDHidElement *element in POVs)
	{
		binding = [self _bindingForPOVElement: element];
		if (binding) [[self bindings] setObject: binding forKey: [element usage]];
	}
}

- (id <BXHIDInputBinding>) _bindingForButtonElement: (DDHidElement *)element
{
	id binding = [BXButtonToButton binding];
	
	//Disabled for now because it irritates the hell out of me
	BOOL wrapButtons = NO;
	
	NSUInteger numEmulatedButtons = [[self emulatedJoystick] numButtons];
	NSUInteger realButton = [[element usage] usageId];
	
	NSUInteger emulatedButton = realButton;
	if (wrapButtons)
	{
		//Wrap controller buttons so that they'll all fit within the number of emulated buttons
		emulatedButton = ((realButton - 1) % numEmulatedButtons) + 1;
	}
	
	[binding setButton: emulatedButton];
	return binding;
}

- (id <BXHIDInputBinding>) _bindingForAxisElement: (DDHidElement *)element
{
	id <BXEmulatedJoystick> joystick = [self emulatedJoystick];
	
	SEL x			= @selector(xAxisMovedTo:),
		y			= @selector(yAxisMovedTo:),
		x2			= @selector(x2AxisMovedTo:),
		y2			= @selector(y2AxisMovedTo:),
		rudder		= @selector(rudderMovedTo:),
		throttle	= @selector(throttleMovedTo:),
		accelerator = @selector(acceleratorMovedTo:),
		brake		= @selector(brakeMovedTo:);
	
	NSUInteger axis = [[element usage] usageId], normalizedAxis;
	SEL bindAxis = NULL;
	
	//First, normalize the axes to known conventions
	switch (axis)
	{
		case kHIDUsage_GD_Z:
			normalizedAxis = kHIDUsage_GD_Rx;
			break;
			
		case kHIDUsage_GD_Rz:
			//Some joysticks pair Rz with Z, in which case it should be normalized to Ry (with Z as Rx);
			//Otherwise it should be treated as Rx.
			{
				BOOL hasZAxis = [[[self HIDController] axisElementsWithUsageID: kHIDUsage_GD_Z] count] > 0;
				normalizedAxis = (hasZAxis) ? kHIDUsage_GD_Ry : kHIDUsage_GD_Rx;
			}
			break;
		
		case kHIDUsage_GD_Slider:
			normalizedAxis = kHIDUsage_GD_Ry;
			
		default:
			normalizedAxis = axis;
	}

	//Then, assign behaviour based on its normalized position
	switch (normalizedAxis)
	{
		case kHIDUsage_GD_X:
			if ([joystick respondsToSelector: x]) bindAxis = x;
			break;
			
		case kHIDUsage_GD_Y:
			if ([joystick respondsToSelector: y]) bindAxis = y;
			break;
			
		case kHIDUsage_GD_Rx:
			{
				//Loop through these selectors in order of priority,
				//assigning to the first available
				SEL selectors[4] = {rudder, throttle, brake, x2};
				NSUInteger i;
				for (i=0; i<4; i++)
				{
					if ([joystick respondsToSelector: selectors[i]])
					{
						bindAxis = selectors[i];
						break;
					}
				}
			}
			break;
			
		case kHIDUsage_GD_Ry:
			{
				//Loop through these selectors in order of priority,
				//assigning to the first available
				SEL selectors[4] = {throttle, rudder, accelerator, y2};
				NSUInteger i;
				for (i=0; i<4; i++)
				{
					if ([joystick respondsToSelector: selectors[i]])
					{
						bindAxis = selectors[i];
						break;
					}
				}
			}
			break;
	}
	
	if (bindAxis)
	{
		id binding = [BXAxisToAxis binding];
		[binding setAxisSelector: bindAxis];
		return binding;
	}
	else return nil;
}

- (id <BXHIDInputBinding>) _bindingForPOVElement: (DDHidElement *)element
{
	id binding = nil;
	id <BXEmulatedJoystick> joystick = [self emulatedJoystick];
	
	SEL pov = @selector(POVChangedTo:);
	if ([joystick respondsToSelector: pov])
	{
		binding = [BXPOVToPOV binding];
		[binding setPOVSelector: pov];
	}
	else
	{
		SEL x = @selector(xAxisMovedTo:),
			y = @selector(yAxisMovedTo:);
		
		if ([joystick respondsToSelector: x] && [joystick respondsToSelector: y])
		{
			binding = [BXPOVToAxes binding];
			[binding setXAxisSelector: x];
			[binding setYAxisSelector: y];
		}
	}
	return binding;
}


#pragma mark -
#pragma mark Event handling

//Send the event on to the appropriate binding for that element
- (void) dispatchHIDEvent: (BXHIDEvent *)event
{
	DDHidElement *element = [event element];
	DDHidUsage *usage = [element usage];
	id <BXHIDInputBinding> binding = [[self bindings] objectForKey: usage];
	
	[binding processEvent: event forTarget: [self emulatedJoystick]];
}

@end
