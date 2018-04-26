/*
 *  Copyright (c) 2013, Alun Bestor (alun.bestor@gmail.com)
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *		Redistributions of source code must retain the above copyright notice, this
 *	    list of conditions and the following disclaimer.
 *
 *		Redistributions in binary form must reproduce the above copyright notice,
 *	    this list of conditions and the following disclaimer in the documentation
 *      and/or other materials provided with the distribution.
 *
 *	THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 *	ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 *	WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 *	IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 *	INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
 *	BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 *	OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 *	WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 *	ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 *	POSSIBILITY OF SUCH DAMAGE.
 */


#import <Foundation/Foundation.h>

typedef void(^ADBUserNotificationActivationHandler)(NSUserNotification *notification);

/// \c ADBUserNotificationDispatcher is a delegate for OS X 10.8+'s @c NSUserNotificationCenter delivery mechanism.
/// It allows notifications to be scheduled with blocks that are called when they are clicked on by the
/// user, and allows each notification to be given a type and sender to permit easy cleanup of stale
/// notifications.
@interface ADBUserNotificationDispatcher : NSObject <NSUserNotificationCenterDelegate>
{
    NSMutableDictionary *_activationHandlers;
}

/// Whether user notifications are supported in this version of OS X. Will return NO on OS X < 10.8.
@property (class, readonly) BOOL userNotificationsAvailable;

/// Returns the singleton instance of the notification dispatcher.
@property (class, readonly, strong) ADBUserNotificationDispatcher *dispatcher;

/// Schedules the specified notification for display, giving it the specified type key
/// (which must be an NSString, NSNumber or other plist type) and sender.
/// If activationHandler is specified, it will be called on completion and passed the notification
/// that was activated. Note that any objects referenced in the handler will be retained until
/// the notification for the handler has been removed.
- (void) scheduleNotification: (NSUserNotification *)notification
                       ofType: (id)typeKey
                   fromSender: (id)sender
                 onActivation: (ADBUserNotificationActivationHandler)activationHandler;

/// Remove the specified notification from the user notification panel.
- (void) removeNotification: (NSUserNotification *)notification;

/// Remove all scheduled and delivered notifications from the specified sender and/or type.
/// Pass @c nil as the @c type to remove all notifications from that sender regardless of type.
/// Pass @c nil as the @c sender to remove all notifications of that type regardless of sender.
- (void) removeAllNotificationsOfType: (id)typeKey fromSender: (id)sender;

/// Remove all delivered and scheduled notifications for the entire application.
- (void) removeAllNotifications;

@end
