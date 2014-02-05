//
//  JWRESTClient.h
//  TABS BBI
//
//  Created by Julian Weinert on 06.06.13.
//  Copyright (c) 2013 Julian Weinert. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>

#import "JWURLConnection.h"

typedef NS_ENUM(NSUInteger, JWUserRole) {
	JWUserRoleNone,
	JWUserRoleVisitor,
	JWUserRoleUser,
	JWUserRoleInspector,
	JWUserRoleAdmin
};

typedef NS_ENUM(NSUInteger, JWUserState) {
	JWUserStateOffline,
	JWUserStateOnline,
	JWUserStateInactive,
	JWUserStateKicking
};

@interface JWRESTUser : NSObject
@property (nonatomic, retain) NSNumber *ID;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSDate *lastLogout;
@property (nonatomic, retain) NSDate *lastLogin;
@property (nonatomic, retain) NSDate *fromTime;
@property (nonatomic, retain) NSDate *toTime;
@property (nonatomic, assign) JWUserRole role;
@property (nonatomic, assign) JWUserState state;
@end

@protocol JWRESTClientDelegate;

@interface JWRESTClient : NSObject

@property (nonatomic, assign) id delegate;
@property (nonatomic, assign) BOOL autoLogin;
@property (nonatomic, retain) NSURL *rootURL;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;
@property (nonatomic, retain) JWRESTUser *currentUser;
@property (nonatomic, assign) BOOL MD5UserCredentials;
@property (nonatomic, assign) NSTimeInterval defaultTimeout;
@property (nonatomic, assign) NSTimeInterval timeoutForNextRequest;
@property (nonatomic, assign) NSURLRequestCachePolicy cachePolicy;
@property (nonatomic, assign) NSURLRequestCachePolicy cachePolicyForNextRequest;
@property (nonatomic, assign, getter = isLoggingEnabled) BOOL loggingEnabled;
@property (nonatomic, assign, getter = isLoggedIn) BOOL loggedIn;
@property (nonatomic, assign, getter = isIgnoringCachedData) BOOL ignoreCachedData;

@property (nonatomic, retain) JWDeviceInfo *deviceInfo;

@property (nonatomic, assign) SEL valudateServerResponseSelector;
@property (nonatomic, assign) SEL authenticationFailedSelector;

@property (nonatomic, copy) BOOL (^validateLoginServerResponse)(NSDictionary *loginResponse);
@property (nonatomic, copy) void (^authenticationFailed)(NSError *error);
@property (nonatomic, copy) JWRESTUser *(^JWRESTUserForValidatedServerResponse)(NSDictionary *response);

@property (nonatomic, copy) BOOL (^globalResponseProcessingHandler)(NSData *response, NSStringEncoding encoding);

+ (JWRESTClient *)RESTClient;
+ (JWRESTClient *)sharedClient;
+ (JWRESTClient *)RESTClientAutoLogin:(BOOL)autoLogin;
+ (JWRESTClient *)RESTClientWithRootURL:(NSURL *)url;
+ (JWRESTClient *)RESTClientWithRootURL:(NSURL *)url autoLogin:(BOOL)autoLogin;
+ (JWRESTClient *)RESTClientWithRootURL:(NSURL *)url username:(NSString *)user andPassword:(NSString *)pass;
+ (JWRESTClient *)RESTClientWithRootURL:(NSURL *)url username:(NSString *)user andPassword:(NSString *)pass autoLogin:(BOOL)autoLogin;

- (id)init;
- (id)initWithRootURL:(NSURL *)url;
- (id)initWithRootURL:(NSURL *)url username:(NSString *)user andPassword:(NSString *)pass;

- (void)loginWithUserName:(NSString *)username andPassword:(NSString *)password sendAdditionalPOSTData:(NSDictionary *)data completion:(void(^)(BOOL loggedIn, NSDictionary *userInfo, JWRESTUser *user, NSError *error))completion;

- (void)executeCommand:(NSString *)CMD;
- (void)executeCommand:(NSString *)CMD ignoreCachedData:(BOOL)ignoreCache;
- (void)executeCommand:(NSString *)CMD usingHTTPMethod:(JWHTTPMethod)method;
- (void)executeCommand:(NSString *)CMD usingHTTPMethod:(JWHTTPMethod)method ignoreCachedData:(BOOL)ignoreCache;

- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data;
- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data ignoreCachedData:(BOOL)ignoreCache;
- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data usingHTTPMethod:(JWHTTPMethod)method;
- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data usingHTTPMethod:(JWHTTPMethod)method ignoreCachedData:(BOOL)ignoreCache;

- (void)executeCommand:(NSString *)CMD getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void(^)(NSError *error))failBlock;
- (void)executeCommand:(NSString *)CMD getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void(^)(NSError *error))failBlock ignoreCachedData:(BOOL)ignoreCache;
- (void)executeCommand:(NSString *)CMD getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void(^)(NSError *error))failBlock usingHTTPMethod:(JWHTTPMethod)method;
- (void)executeCommand:(NSString *)CMD getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void(^)(NSError *error))failBlock usingHTTPMethod:(JWHTTPMethod)method ignoreCachedData:(BOOL)ignoreCache;

- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void(^)(NSError *error))failBlock;
- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void(^)(NSError *error))failBlock ignoreCachedData:(BOOL)ignoreCache;
- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock usingHTTPMethod:(JWHTTPMethod)method;
- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock usingHTTPMethod:(JWHTTPMethod)method ignoreCachedData:(BOOL)ignoreCache;

- (void)executeCommand:(NSString *)CMD uploadFile:(NSData *)data withName:(NSString *)name forFieldName:(NSString *)fieldName andAdditionalPOSTData:(NSDictionary *)POSTData getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void (^)(NSError *error))failBlock;
- (void)executeCommand:(NSString *)CMD uploadFile:(NSData *)data withName:(NSString *)name forFieldName:(NSString *)fieldName andAdditionalPOSTData:(NSDictionary *)POSTData getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void (^)(NSError *error))failBlock ignoreCachedData:(BOOL)ignoreCache;
- (void)executeCommand:(NSString *)CMD uploadFile:(NSData *)data withName:(NSString *)name forFieldName:(NSString *)fieldName andAdditionalPOSTData:(NSDictionary *)POSTData addToQueue:(JWURLConnectionQueue *)queue getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock;
- (void)executeCommand:(NSString *)CMD uploadFile:(NSData *)data withName:(NSString *)name forFieldName:(NSString *)fieldName andAdditionalPOSTData:(NSDictionary *)POSTData addToQueue:(JWURLConnectionQueue *)queue getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock ignoreCachedData:(BOOL)ignoreCache;

- (void)logout;
- (NSData *)executeCommandSynchronously:(NSString *)CMD;

@end

@protocol JWRESTClientDelegate <NSObject>

- (BOOL)RESTClient:(JWRESTClient *)client validateServerResponse:(NSDictionary *)response;
- (void)RESTClient:(JWRESTClient *)client authenticationFailed:(NSError *)error;
- (JWRESTUser *)JWRESTUserForValidatedServerResponse:(NSDictionary *)response;

@end

@interface NSString (MD5)
+ (NSString *)stringWithMD5FromFile:(NSString *)path;
- (NSString *)MD5Hash;
@end
