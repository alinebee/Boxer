/*
 Boxer is copyright 2011 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/BoxerHelp/pages/legalese.html, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */

#import "BXUserNotificationDispatcher.h"

NSString * const BXUserNotificationHandlerKey = @"BXUserNotificationHandler";
NSString * const BXUserNotificationSenderKey = @"BXUserNotificationSender";
NSString * const BXUserNotificationTypeKey = @"BXUserNotificationType";

@interface BXUserNotificationDispatcher ()

@property (retain, nonatomic) NSMutableDictionary *activationHandlers;

//Called to remove an activation handler for the specified notification, usually because
//the notification itself is being removed.
- (void) _removeHandlerForNotification: (NSUserNotification *)notification;

//Returns whether the specified notification has the specified sender and/or type.
//Used by removeAllNotificationsFromSender:ofType:
- (BOOL) _notification: (NSUserNotification *)notification matchesSender: (id)sender type: (id)type;

@end

@implementation BXUserNotificationDispatcher
@synthesize activationHandlers = _activationHandlers;

+ (BOOL) userNotificationsAvailable
{
    return NSClassFromString(@"NSUserNotificationCenter") != nil;
}

+ (BXUserNotificationDispatcher *)dispatcher
{
    static BXUserNotificationDispatcher *dispatcher = nil;
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

- (void) dealloc
{
    self.activationHandlers = nil;
    
    [super dealloc];
}

- (void) scheduleNotification: (NSUserNotification *)notification
                       ofType: (id)typeKey
                   fromSender: (id)sender
                 onActivation: (BXUserNotificationActivationHandler)activationHandler;
{
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    if (notification.userInfo)
        [userInfo addEntriesFromDictionary: notification.userInfo];
    
    if (activationHandler != nil)
    {
        activationHandler = [activationHandler copy];
        id handlerKey = @([activationHandler hash]);
        
        [self.activationHandlers setObject: activationHandler forKey: handlerKey];
        [activationHandler release];
        
        [userInfo setObject: handlerKey forKey: BXUserNotificationHandlerKey];
    }
    
    if (typeKey != nil)
    {
        [userInfo setObject: typeKey forKey: BXUserNotificationTypeKey];
    }
    
    if (sender != nil)
    {
        NSNumber *senderHash = @([sender hash]);
        [userInfo setObject: senderHash forKey: BXUserNotificationSenderKey];
    }
    
    notification.userInfo = userInfo;
    
    NSUserNotificationCenter *center = [NSUserNotificationCenter defaultUserNotificationCenter];
    [center scheduleNotification: notification];
}

- (void) _removeHandlerForNotification: (NSUserNotification *)notification
{
    id handlerKey = [notification.userInfo objectForKey: BXUserNotificationHandlerKey];
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
        [filteredNotifications release];
        
        [center removeDeliveredNotification: notification];
    }
}

- (void) userNotificationCenter: (NSUserNotificationCenter *)center
        didActivateNotification: (NSUserNotification *)notification
{
    id handlerKey = [notification.userInfo objectForKey: BXUserNotificationHandlerKey];
    BXUserNotificationActivationHandler handler = [self.activationHandlers objectForKey: handlerKey];
    
    if (handler)
        handler(notification);
}

- (BOOL) _notification: (NSUserNotification *)notification matchesSender: (id)sender type: (id)type
{
    if (sender != nil)
    {
        NSNumber *notificationSenderHash = [notification.userInfo objectForKey: BXUserNotificationSenderKey];
        if ([sender hash] != [notificationSenderHash unsignedIntegerValue])
            return NO;
    }
    
    if (type != nil)
    {
        NSNumber *notificationType = [notification.userInfo objectForKey: BXUserNotificationTypeKey];
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
        [filteredNotifications release];
        
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
