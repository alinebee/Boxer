//
//  BBAppDelegate+AppExporting.h
//  Boxer Bundler
//
//  Created by Alun Bestor on 25/08/2012.
//  Copyright (c) 2012 Alun Bestor. All rights reserved.
//

#import "BBAppDelegate.h"

@interface BBAppDelegate (AppExporting)

//Begin asynchronously creating a new app at the specified destination URL.
//completionHandler is called upon completion, with the resulting URL and nil (if successful)
//or nil and an error representing the reason for failure (if unsuccessful).
- (void) createAppAtDestinationURL: (NSURL *)destinationURL
                        completion: (void(^)(NSURL *appURL, NSError *error))completionHandler;

//Synchronously create a new app at the specified destination URL, using our current parameters.
//Returns the URL of the generated app, or nil and populates outError upon failure.
//This method can safely overwrite an existing app at destinationURL; if the app creation fails,
//any existing app will be left untouched.
- (NSURL *) createAppAtDestinationURL: (NSURL *)destinationURL
                                error: (NSError **)outError;

@end
