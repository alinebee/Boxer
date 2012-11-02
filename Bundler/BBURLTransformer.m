//
//  BBURLTransformer.m
//  Boxer Bundler
//
//  Created by Alun Bestor on 15/08/2012.
//  Copyright (c) 2012 Alun Bestor. All rights reserved.
//

#import "BBURLTransformer.h"

@implementation BBURLTransformer

+ (void) registerWithName: (NSString *)name
{
    if (name == nil)
        name = NSStringFromClass(self);
    
    id instance = [[self alloc] init];
    [NSValueTransformer setValueTransformer: instance forName: name];
}

+ (Class) transformedValueClass { return [NSString class]; }
+ (BOOL) allowsReverseTransformation { return YES; }

- (NSString *) transformedValue: (NSURL *)value
{
    return value.absoluteString;
}

- (NSURL *) reverseTransformedValue: (NSString *)value
{
    return [NSURL URLWithString: value];
}

@end


@implementation BBFileURLTransformer

- (NSString *) transformedValue: (NSURL *)value
{
    return value.path;
}

- (NSURL *) reverseTransformedValue: (NSString *)value
{
    return [NSURL fileURLWithPath: value];
}

@end
