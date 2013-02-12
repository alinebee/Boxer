/*
 Copyright (c) 2013 Alun Bestor and contributors. All rights reserved.
 This source file is released under the GNU General Public License 2.0. A full copy of this license
 can be found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

//BXUserNotificationDispatcher is a delegate for OS X 10.8+'s NSUserNotificationCenter delivery mechanism.
//It allows notifications to be scheduled with blocks that are called when they are clicked on by the
//user, and allows each notification to be given a type and sender to permit easy cleanup of stale
//notifications.

#import <Foundation/Foundation.h>

typedef void(^BXUserNotificationActivationHandler)(NSUserNotification *notification);

@interface BXUserNotificationDispatcher : NSObject <NSUserNotificationCenterDelegate>
{
    NSMutableDictionary *_activationHandlers;
}

//Whether user notifications are supported in this version of OS X. Will return NO on OS X < 10.8.
+ (BOOL) userNotificationsAvailable;

//Returns the singleton instance of the notification dispatcher.
+ (BXUserNotificationDispatcher *) dispatcher;

//Schedules the specified notification for display, giving it the specified type key
//(which must be an NSString, NSNumber or other plist type) and sender.
//If activationHandler is specified, it will be called on completion and passed the notification
//that was activated. Note that any objects referenced in the handler will be retained until
//the notification for the handler has been removed.
- (void) scheduleNotification: (NSUserNotification *)notification
                       ofType: (id)typeKey
                   fromSender: (id)sender
                 onActivation: (BXUserNotificationActivationHandler)activationHandler;

//Remove the specified notification from the user notification panel.
- (void) removeNotification: (NSUserNotification *)notification;

//Remove all scheduled and delivered notifications from the specified sender and/or type.
//Pass nil as the type to remove all notifications from that sender regardless of type.
//Pass nil as the sender to remove all notifications of that type regardless of sender.
- (void) removeAllNotificationsOfType: (id)typeKey fromSender: (id)sender;

//Remove all delivered and scheduled notifications for the entire application.
- (void) removeAllNotifications;

@end
