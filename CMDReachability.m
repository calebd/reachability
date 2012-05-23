//
//  CMDReachability.m
//
//  Created by Caleb Davenport on 3/24/11.
//  Copyright (c) 2012 Caleb Davenport.
//

#import "CMDReachability.h"

#if __has_feature(objc_arc)
#error This class cannot be compiled with ARC
#endif

#pragma mark - class resources

static NSString * const GCReachabilityDidChangeNotification = @"GCReachabilityDidChange";
static NSMutableDictionary *CMDReachabilityObjects = nil;

#pragma mark - reachability callback

void GCReachabilityDidChangeCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info);

#pragma mark - private interface

@interface CMDReachability () {
@private
    SCNetworkReachabilityRef reachability;
}

@property (readwrite, assign) SCNetworkReachabilityFlags flags;

- (id)initWithHost:(NSString *)host;

- (BOOL)startUpdatingReachability;

- (BOOL)stopUpdatingReachability;


@end

#pragma mark - implementation

@implementation CMDReachability

@synthesize flags = _flags;

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
#if !__has_feature(objc_arc)
        [reachability release];
#endif
    }
    return reachability;
}

#pragma mark - object methods

- (id)initWithHost:(NSString *)host {
    self = [super init];
    if (self) {
        reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [host UTF8String]);
        self.flags = 0;
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
    if (reachability != NULL) {
        CFRelease(reachability);
    }
    reachability = NULL;
    [super dealloc];
}

- (BOOL)startUpdatingReachability {
    BOOL result = NO;
    SCNetworkReachabilityContext context = {0, self, NULL, NULL, NULL};
    if (SCNetworkReachabilitySetCallback(reachability, GCReachabilityDidChangeCallback, &context)) {
        if (SCNetworkReachabilityScheduleWithRunLoop(reachability, CFRunLoopGetMain(), kCFRunLoopDefaultMode)) {
            result = YES;
        }
    }
    return result;
}

- (BOOL)stopUpdatingReachability {
    BOOL loop = SCNetworkReachabilityUnscheduleFromRunLoop(reachability, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    BOOL callback = SCNetworkReachabilitySetCallback(reachability, NULL, NULL);
    return (loop && callback);
}

- (BOOL)isReachable {
    return (self.status != GCNotReachable);
}

- (BOOL)isReachableViaWiFi {
    return (self.status == GCReachableViaWiFi);
}

- (BOOL)isReachableViaWWAN {
    return (self.status == GCReachableViaWWAN);
}

- (GCReachabilityStatus)status {
    
    // get flags
    SCNetworkReachabilityFlags flags = self.flags;
    
    // check status
    if ((flags & kSCNetworkReachabilityFlagsReachable) == 0) {
        return GCNotReachable;
    }
    GCReachabilityStatus status = GCNotReachable;
    if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0) {
        status = GCReachableViaWiFi;
    }
    if (((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) ||
        ((flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0)) {
        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0) {
            status = GCReachableViaWiFi;
        }
    }
    if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
		status = GCReachableViaWWAN;
	}
    return status;
    
}

- (void)addObserver:(id)observer selector:(SEL)selector {
    [[NSNotificationCenter defaultCenter]
     addObserver:observer
     selector:selector
     name:GCReachabilityDidChangeNotification
     object:self];
}

- (void)removeObserver:(id)observer {
    [[NSNotificationCenter defaultCenter]
     removeObserver:observer
     name:GCReachabilityDidChangeNotification
     object:self];
}

@end

#pragma mark - reachability callbak

void GCReachabilityDidChangeCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void *info) {
    CMDReachability *reachability = (id)info;
    reachability.flags = flags;
    [[NSNotificationCenter defaultCenter]
     postNotificationName:GCReachabilityDidChangeNotification
     object:reachability];
}
