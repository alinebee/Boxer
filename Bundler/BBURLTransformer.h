//
//  BBURLTransformer.h
//  Boxer Bundler
//
//  Created by Alun Bestor on 15/08/2012.
//  Copyright (c) 2012 Alun Bestor. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BBURLTransformer : NSValueTransformer

//Register an instance of this transformer under the specified name.
//If name is nil, registers under the name of the class itself.
+ (void) registerWithName: (NSString *)name;

@end


@interface BBFileURLTransformer : BBURLTransformer
@end