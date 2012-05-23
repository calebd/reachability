//
//  CMDReachability.m
//
//  Created by Caleb Davenport on 3/24/11.
//  Copyright (c) 2012 Caleb Davenport.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

// reachability status
enum {
    GCNotReachable,
    GCReachableViaWiFi,
    GCReachableViaWWAN
};
typedef NSUInteger GCReachabilityStatus;

// reachability api wrapper
@interface CMDReachability : NSObject

// properties
@property (atomic, readonly, assign) SCNetworkReachabilityFlags flags;
@property (nonatomic, readonly, getter = isReachable) BOOL reachable;
@property (nonatomic, readonly, getter = isReachableViaWiFi) BOOL reachableViaWiFi;
@property (nonatomic, readonly, getter = isReachableViaWWAN) BOOL reachableViaWWAN;
@property (nonatomic, readonly) GCReachabilityStatus status;

/*
 
 Fetch a reachability object configured to watch the given host.
 
 */
+ (CMDReachability *)reachabilityForHost:(NSString *)host;

/*
 
 Register the given observer for notifications about reachability changes.
 These notifications are posted using NSNotificationCenter on the main thread.
 
 */
- (void)addObserver:(id)observer selector:(SEL)selector;

/*
 
 Remove the given observer from the notification dispatch table.
 
 */
- (void)removeObserver:(id)observer;

@end
