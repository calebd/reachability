//
//  CMDReachability.m
//
//  Created by Caleb Davenport on 3/24/11.
//  Copyright (c) 2012 Caleb Davenport.
//

#import "CMDReachability.h"

#pragma mark - class resources

static NSString * const CMDReachabilityDidChangeNotification = @"CMDReachabilityDidChange";
static NSMutableDictionary *CMDReachabilityObjects = nil;

#pragma mark - reachability callback

void CMDReachabilityDidChangeCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info);

#pragma mark - private interface

@interface CMDReachability () {
    SCNetworkReachabilityRef _reachability;
}

@property (readwrite, assign) SCNetworkReachabilityFlags flags;

@end

#pragma mark - implementation

@implementation CMDReachability

#pragma mark - class methods

+ (void)initialize {
    if (self == [CMDReachability class]) {
        CMDReachabilityObjects = [[NSMutableDictionary alloc] initWithCapacity:1];
    }
}

+ (CMDReachability *)reachabilityForHost:(NSString *)host {
    CMDReachability *reachability = [CMDReachabilityObjects objectForKey:host];
    if (reachability == nil) {
        reachability = [[CMDReachability alloc] initWithHost:host];
        [CMDReachabilityObjects setObject:reachability forKey:host];
    }
    return reachability;
}

#pragma mark - object methods

- (id)initWithHost:(NSString *)host {
    self = [super init];
    if (self) {
        _reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [host UTF8String]);
        _flags = 0;
        if (![self startUpdatingReachability]) {
            NSLog(@"[%@] Unable start updating reachability for host %@",
                  NSStringFromClass([self class]),
                  host);
        }
    }
    return self;
}

- (void)dealloc {
    [self stopUpdatingReachability];
    if (_reachability != NULL) {
        CFRelease(_reachability);
    }
    _reachability = NULL;
}

- (BOOL)startUpdatingReachability {
    BOOL result = NO;
    SCNetworkReachabilityContext context = {0, (__bridge void *)self, NULL, NULL, NULL};
    if (SCNetworkReachabilitySetCallback(_reachability, CMDReachabilityDidChangeCallback, &context)) {
        if (SCNetworkReachabilityScheduleWithRunLoop(_reachability, CFRunLoopGetMain(), kCFRunLoopDefaultMode)) {
            result = YES;
        }
    }
    return result;
}

- (BOOL)stopUpdatingReachability {
    BOOL loop = SCNetworkReachabilityUnscheduleFromRunLoop(_reachability, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    BOOL callback = SCNetworkReachabilitySetCallback(_reachability, NULL, NULL);
    return (loop && callback);
}

- (BOOL)isReachable {
    return (self.status != CMDNotReachable);
}

- (BOOL)isReachableViaWiFi {
    return (self.status == CMDReachableViaWiFi);
}

- (BOOL)isReachableViaWWAN {
    return (self.status == CMDReachableViaWWAN);
}

- (CMDReachabilityStatus)status {

    // get flags
    SCNetworkReachabilityFlags flags = self.flags;

    // check status
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
        return CMDNotReachable;
    }
    CMDReachabilityStatus status = CMDNotReachable;
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
        status = CMDReachableViaWiFi;
    }
    if (((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) ||
        ((flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
            status = CMDReachableViaWiFi;
        }
    }
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
        status = CMDReachableViaWWAN;
    }
    return status;

}

- (void)addObserver:(id)observer selector:(SEL)selector {
    [[NSNotificationCenter defaultCenter]
     addObserver:observer
     selector:selector
     name:CMDReachabilityDidChangeNotification
     object:self];
}

- (void)removeObserver:(id)observer {
    [[NSNotificationCenter defaultCenter]
     removeObserver:observer
     name:CMDReachabilityDidChangeNotification
     object:self];
}

@end

#pragma mark - reachability callbak

void CMDReachabilityDidChangeCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    CMDReachability *reachability = (__bridge id)info;
    reachability.flags = flags;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:CMDReachabilityDidChangeNotification
     object:reachability];
}
