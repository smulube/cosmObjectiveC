#import "COSMFeedCollection.h"
#import "COSMFeedModel.h"
#import "AFJSONRequestOperation.h"

@implementation COSMFeedCollection

#pragma mark - Data

@synthesize info;

#pragma mark - Feeds

@synthesize feeds;

#pragma mark - Synchronisation

@synthesize api, delegate;

- (void)fetch {
    NSURL *url = [self.api urlForRoute:@"feeds/" withParameters:self.parameters];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:40.0];
    [request setValue:self.api.versionString forHTTPHeaderField:@"User-Agent"];
    AFJSONRequestOperation *operation = [AFJSONRequestOperation JSONRequestOperationWithRequest:request
        success:^(NSURLRequest *request, NSHTTPURLResponse *response, id JSON) {
            [self parse:JSON];
            if (self.delegate && [self.delegate respondsToSelector:@selector(feedCollectionDidFetch:)]) {
                [self.delegate feedCollectionDidFetch:self];
            }
        } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON) {
            //NSLog(@"Error %@", error);
            if (self.delegate && [self.delegate respondsToSelector:@selector(feedCollectionFailedToFetch:withError:json:)]) {
                [self.delegate feedCollectionFailedToFetch:self withError:error json:JSON];
            }
        }];
    [operation start];
}

- (void)removeDeleted {
    NSMutableArray *deletedItems = [NSMutableArray array];
    COSMFeedModel *feed;
    
    for (feed in feeds) {
        if ([feed isDeletedFromCosm]) {
            [deletedItems addObject:feed];
        }
    }
    
    [feeds removeObjectsInArray:deletedItems];
}

- (void)parse:(id)JSON {
    // create a deep mutable copy
    CFPropertyListRef mutableJSONRef  = CFPropertyListCreateDeepCopy(kCFAllocatorDefault, (CFDictionaryRef)JSON, kCFPropertyListMutableContainers);
    NSMutableDictionary *mutableJSON = (__bridge NSMutableDictionary *)mutableJSONRef;
    if (!mutableJSON) { return; }
    
    [self.feeds removeAllObjects];
    
    NSArray *returnedFeeds = [mutableJSON valueForKeyPath:@"results"];
    NSEnumerator *feedsEnumerator = [returnedFeeds objectEnumerator];
    NSDictionary *feedData;
    while (feedData = [feedsEnumerator nextObject]) {
        COSMFeedModel *feed = [[COSMFeedModel alloc] init];
        [feed parse:feedData];
        [self.feeds addObject:feed];
    }
    
    [mutableJSON removeObjectForKey:@"results"];
    
    self.info = mutableJSON;

    CFRelease(mutableJSONRef);
}

#pragma mark - Lifecycle

- (id)init {
    if (self=[super init]) {
        feeds = [[NSMutableArray alloc] init];
        info = [[NSMutableDictionary alloc] init];
		api = [COSMAPI defaultAPI];
	}
    return self;
}

@end

