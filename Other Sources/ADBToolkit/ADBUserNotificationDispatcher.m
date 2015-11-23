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

#import "ADBUserNotificationDispatcher.h"

NSString * const ADBUserNotificationHandlerKey = @"ADBUserNotificationHandler";
NSString * const ADBUserNotificationSenderKey = @"ADBUserNotificationSender";
NSString * const ADBUserNotificationTypeKey = @"ADBUserNotificationType";

@interface ADBUserNotificationDispatcher ()

@property (retain, nonatomic) NSMutableDictionary *activationHandlers;

//Called to remove an activation handler for the specified notification, usually because
//the notification itself is being removed.
- (void) _removeHandlerForNotification: (NSUserNotification *)notification;

//Returns whether the specified notification has the specified sender and/or type.
//Used by removeAllNotificationsFromSender:ofType:
- (BOOL) _notification: (NSUserNotification *)notification matchesSender: (id)sender type: (id)type;

@end

@implementation ADBUserNotificationDispatcher
@synthesize activationHandlers = _activationHandlers;

+ (BOOL) userNotificationsAvailable
{
    return NSClassFromString(@"NSUserNotificationCenter") != nil;
}

+ (ADBUserNotificationDispatcher *)dispatcher
{
    static ADBUserNotificationDispatcher *dispatcher = nil;
    static dispatch_once_t pred;
    
    dispatch_once(&pred, ^{
        if ([self userNotificationsAvailable])
        {
            dispatcher = [[self alloc] init];
            [NSUserNotificationCenter defaultUserNotificationCenter].delegate = dispatcher;
        }
    });
    
    return dispatcher;
}

- (id) init
{
    self = [super init];
    if (self)
    {
        self.activationHandlers = [NSMutableDictionary dictionaryWithCapacity: 2];
    }
    return self;
}

- (void) scheduleNotification: (NSUserNotification *)notification
                       ofType: (id)typeKey
                   fromSender: (id)sender
                 onActivation: (ADBUserNotificationActivationHandler)activationHandler;
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (notification.userInfo)
        [userInfo addEntriesFromDictionary: notification.userInfo];
    
    if (activationHandler != nil)
    {
        activationHandler = [activationHandler copy];
        id handlerKey = @([activationHandler hash]);
        
        [self.activationHandlers setObject: activationHandler forKey: handlerKey];
        
        [userInfo setObject: handlerKey forKey: ADBUserNotificationHandlerKey];
    }
    
    if (typeKey != nil)
    {
        [userInfo setObject: typeKey forKey: ADBUserNotificationTypeKey];
    }
    
    if (sender != nil)
    {
        NSNumber *senderHash = @([sender hash]);
        [userInfo setObject: senderHash forKey: ADBUserNotificationSenderKey];
    }
    
    notification.userInfo = userInfo;
    
    NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
    [center scheduleNotification: notification];
}

- (void) _removeHandlerForNotification: (NSUserNotification *)notification
{
    id handlerKey = [notification.userInfo objectForKey: ADBUserNotificationHandlerKey];
    if (handlerKey)
        [self.activationHandlers removeObjectForKey: handlerKey];
}

- (void) removeNotification: (NSUserNotification *)notification
{
    [self _removeHandlerForNotification: notification];
    
    NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
    
    @synchronized(center)
    {
        NSMutableArray *filteredNotifications = [center.scheduledNotifications mutableCopy];
        [filteredNotifications removeObject: notification];
        center.scheduledNotifications = filteredNotifications;
        
        [center removeDeliveredNotification: notification];
    }
}

- (void) userNotificationCenter: (NSUserNotificationCenter *)center
        didActivateNotification: (NSUserNotification *)notification
{
    id handlerKey = [notification.userInfo objectForKey: ADBUserNotificationHandlerKey];
    ADBUserNotificationActivationHandler handler = [self.activationHandlers objectForKey: handlerKey];
    
    if (handler)
        handler(notification);
}

- (BOOL) _notification: (NSUserNotification *)notification matchesSender: (id)sender type: (id)type
{
    if (sender != nil)
    {
        NSNumber *notificationSenderHash = [notification.userInfo objectForKey: ADBUserNotificationSenderKey];
        if ([sender hash] != [notificationSenderHash unsignedIntegerValue])
            return NO;
    }
    
    if (type != nil)
    {
        NSNumber *notificationType = [notification.userInfo objectForKey: ADBUserNotificationTypeKey];
        if (![type isEqual: notificationType])
            return NO;
    }
    
    return YES;
}

//Remove all scheduled and delivered notifications with the specified type and/or sender.
- (void) removeAllNotificationsOfType: (id)typeKey fromSender: (id)sender
{
    NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
    @synchronized(center)
    {
        NSMutableArray *filteredNotifications = [center.scheduledNotifications mutableCopy];
        for (NSUserNotification *notification in center.scheduledNotifications)
        {
            if ([self _notification: notification matchesSender: sender type: typeKey])
            {
                [self _removeHandlerForNotification: notification];
                [filteredNotifications removeObject: notification];
            }
        }
        center.scheduledNotifications = filteredNotifications;
        
        for (NSUserNotification *notification in center.deliveredNotifications)
        {
            if ([self _notification: notification matchesSender: sender type: typeKey])
            {
                [self _removeHandlerForNotification: notification];
                [center removeDeliveredNotification: notification];
            }
        }
    }
}

//Remove all delivered and scheduled notifications for the entire application.
- (void) removeAllNotifications
{
    [self.activationHandlers removeAllObjects];
    
    NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
    center.scheduledNotifications = [NSArray array];
    [center removeAllDeliveredNotifications];
}

@end
