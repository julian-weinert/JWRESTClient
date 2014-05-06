//
//  JWRESTClient.m
//
//  Created by Julian Weinert on 06.06.13.
//  Originally created for http://www.csundm.com
//  Copyright (c) 2013 Julian Weinert.
//
//    This program is free software: you can redistribute it and/or modify
//    it under the terms of the GNU General Public License as published by
//    the Free Software Foundation, either version 2 of the License, or
//    (at your option) any later version.
//
//    This program is distributed in the hope that it will be useful,
//    but WITHOUT ANY WARRANTY; without even the implied warranty of
//    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//    GNU General Public License for more details.
//
//    You should have received a copy of the GNU General Public License
//    along with this program.  If not, see <http://www.gnu.org/licenses/>.

/*
 //////////////////////////////////////////////////////////////////////////
 //////////////////////// REST SERVER STATUS CODES ////////////////////////
 //////////////////////////////////////////////////////////////////////////
 
 
 2xxx	GENERIC MESSAGES
 2000	– OK						HTTP 200: OK
 
 
 4xxx	COMMAND ERRORS
 
 4010	– Command requires GET  request			HTTP 406: Not Acceptable
 4011	– Command requires POST request			HTTP 406: Not Acceptable
 4012	– Command requires GET or POST request		HTTP 406: Not Acceptable
 
 4019	- No command provided				HTTP 406: Not Acceptable
 4020	– Command not implemented			HTTP 406: Not Acceptable
 4021	– Missing argument for command			HTTP 406: Not Acceptable
 
 4030	– Incomplete user credentials			HTTP 406: Not Acceptable
 4031	– Wrong user credentials			HTTP 403: Forbidden
 4032	- Not Logged in					HTTP 403: Forbidden
 
 4040	– File does not exist				HTTP 404: Not Found
 4041	– Directory does not exist			HTTP 404: Not Found
 4042	– Directory not writable			HTTP 500: Internal Server Error
 4050	– File already exist				HTTP 409: Conflict
 
 
 5xxx	SERVER ERRORS
 
 5000	– Generic server error				HTTP 500: Internal Server Error
 5010	– MySQL error					HTTP 500: Internal Server Error
*/

#import "JWRESTClient.h"
#import "NSThread+blocks.h"

static JWRESTUser *JWRESTUserZero() {
	JWRESTUser *user = [[JWRESTUser alloc] init];
	[user setRole:JWUserRoleNone];
	return user;
}

@implementation JWRESTUser

- (NSString *)description {
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"hh:MM:ss"];
	
	return [NSString stringWithFormat:@"<JWRESTUser: %p; id = %@; name = %@; role = %@; from = %@; to = %@>", self, [_ID stringValue], _username, NSStringFromJWUserRole(_role), [formatter stringFromDate:_fromTime], [formatter stringFromDate:_toTime]];
}

@end

static JWRESTClient *sharedClient;

@implementation JWRESTClient

+ (JWRESTClient *)sharedClient {
	static dispatch_once_t dispatch;
	
	dispatch_once(&dispatch, ^{
		sharedClient = [JWRESTClient RESTClient];
	});
	
	return sharedClient;
}

+ (JWRESTClient *)RESTClient {
	return [[self alloc] init];
}

+ (JWRESTClient *)RESTClientAutoLogin:(BOOL)autoLogin {
	autoLogin = autoLogin;
	
	JWRESTClient *RESTClient = [[self alloc] init];
	[RESTClient setAutoLogin:autoLogin];
	
	return RESTClient;
}

+ (JWRESTClient *)RESTClientWithRootURL:(NSURL *)url {
	return [[self alloc] initWithURL:url];
}

+ (JWRESTClient *)RESTClientWithRootURL:(NSURL *)url autoLogin:(BOOL)autoLogin {
	autoLogin = autoLogin;
	
	JWRESTClient *RESTClient = [[self alloc] initWithRootURL:url];
	[RESTClient setAutoLogin:autoLogin];
	
	return RESTClient;
}

+ (JWRESTClient *)RESTClientWithRootURL:(NSURL *)url username:(NSString *)user andPassword:(NSString *)pass {
	return [[self alloc] initWithRootURL:url username:user andPassword:pass];
}

+ (JWRESTClient *)RESTClientWithRootURL:(NSURL *)url username:(NSString *)user andPassword:(NSString *)pass autoLogin:(BOOL)autoLogin {
	autoLogin = autoLogin;
	
	JWRESTClient *RESTClient = [[self alloc] initWithRootURL:url username:user andPassword:pass];
	[RESTClient setAutoLogin:autoLogin];
	
	return RESTClient;
}

- (id)init {
	self = [super init];
	if (self) {
		_defaultTimeout = 10.0;
		_timeoutForNextRequest = 0;
		_cachePolicyForNextRequest = NSUIntegerMax;
		_cachePolicy = NSURLRequestReloadIgnoringCacheData;
	}
	return self;
}

- (id)initWithRootURL:(NSURL *)url {
	self = [super init];
	if (self) {
		_rootURL = url;
		_defaultTimeout = 10.0;
		_timeoutForNextRequest = 0;
		_cachePolicyForNextRequest = NSUIntegerMax;
		_cachePolicy = NSURLRequestReloadIgnoringCacheData;
	}
	return self;
}

- (id)initWithRootURL:(NSURL *)url username:(NSString *)user andPassword:(NSString *)pass {
	self = [super init];
	if (self) {
		_rootURL = url;
		_username = user;
		_password = pass;
		_defaultTimeout = 10.0;
		_timeoutForNextRequest = 0;
		_cachePolicyForNextRequest = NSUIntegerMax;
		_cachePolicy = NSURLRequestReloadIgnoringCacheData;
	}
	return self;
}

- (void)setCachePolicy:(NSURLRequestCachePolicy)cachePolicy {
	_cachePolicy = cachePolicy;
	_cachePolicyForNextRequest = cachePolicy;
}

- (NSURLRequestCachePolicy)getCachePolicy {
	NSURLRequestCachePolicy tempPolicy = _cachePolicy;
	
	if (_cachePolicyForNextRequest != _cachePolicy) {
		tempPolicy = _cachePolicyForNextRequest;
		_cachePolicyForNextRequest = _cachePolicy;
	}
	
	if (_ignoreCachedData) {
		return NSURLRequestReloadIgnoringLocalAndRemoteCacheData;
	}
	
	return tempPolicy;
}

- (void)setDefaultTimeout:(NSTimeInterval)defaultTimeout {
	_defaultTimeout = defaultTimeout;
	_timeoutForNextRequest = defaultTimeout;
}

- (NSTimeInterval)getTimeout {
	NSTimeInterval tempTimeout = _defaultTimeout;
	
	if (_timeoutForNextRequest != _defaultTimeout) {
		tempTimeout = _timeoutForNextRequest;
		_timeoutForNextRequest = _defaultTimeout;
	}
	
	return tempTimeout;
}

- (void)loginWithUserName:(NSString *)username andPassword:(NSString *)password sendAdditionalPOSTData:(NSDictionary *)data completion:(void (^)(BOOL, NSDictionary *, JWRESTUser *user, NSError *))completion {
	_username = username;
	_password = password;
	
	username = _MD5UserCredentials ? [username MD5Hash] : username;
	password = _MD5UserCredentials ? [password MD5Hash] : password;
	
	if (_loggingEnabled) {
		NSLog(@"JWRESTClient MESSAGE: INITIALIZING LOGIN WITH%@ MD5 HASHING. Username: %@, Password: %@", _MD5UserCredentials ? @"" : @"OUT", username, password);
	}
	
	__block BOOL loginSucceeded = NO;
	__block NSString *errorString;
	__block NSInteger errorCode;
	__block JWRESTUser *user;
	__block NSError *error;
	
	NSMutableDictionary *postData = [NSMutableDictionary dictionaryWithDictionary:@{@"username": username, @"password": password}];
	
	if (data) {
		NSEnumerator *keyEnum = [data keyEnumerator];
		
		for (id<NSCopying> key in keyEnum) {
			if (![postData objectForKey:key]) {
				[postData setObject:[data objectForKey:key] forKey:key];
			}
		}
	}
	
	JWURLConnection *connection = [JWURLConnection connectionWithPOSTRequestToURL:[_rootURL URLByAppendingPathComponent:@"login"] POSTData:postData usingCachePolicy:NSURLRequestReloadIgnoringCacheData andTimeout:[self getTimeout] delegate:nil];
	
	__weak JWURLConnection *connectionBlockCopy = connection;
	
	[connection setFinished:^(NSData *data, NSStringEncoding encoding) {
		if (_globalResponseProcessingHandler) {
			if (!_globalResponseProcessingHandler(data, encoding)) {
				completion(NO, nil, nil, nil);
				return;
			}
		}
	 
		NSError *jsonError;
		NSMutableDictionary *jsonData = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments | NSJSONReadingMutableContainers error:&jsonError];
		
		if (jsonError) {
			errorCode = [jsonError code];
			errorString = [NSString stringWithFormat:@"JSON READING ERROR: %@", [jsonError localizedDescription]];
			error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey: errorString, NSUnderlyingErrorKey: jsonError}];
			NSLog(@"resp: %@", [[NSString alloc] initWithData:data encoding:encoding]);
		}
		
		if (!error && _validateLoginServerResponse) {
			loginSucceeded = _validateLoginServerResponse(jsonData);
		}
		else if (!error && [_delegate respondsToSelector:@selector(RESTClient:validateServerResponse:)]) {
			loginSucceeded = [_delegate RESTClient:self validateServerResponse:jsonData];
		}
		else if (!error) {
			loginSucceeded = ([[jsonData objectForKey:@"result"] isEqualToString:@"OK"] && [[jsonData objectForKey:@"code"] integerValue] == 2000 && [connectionBlockCopy statusCode] == 200);
		}
		
		if (loginSucceeded) {
			if (_JWRESTUserForValidatedServerResponse) {
				user = _JWRESTUserForValidatedServerResponse(jsonData);
			}
			else if ([_delegate respondsToSelector:@selector(JWRESTUserForValidatedServerResponse:)]) {
				user = [_delegate JWRESTUserForValidatedServerResponse:jsonData];
			}
			else if ([[jsonData objectForKey:@"result"] isEqualToString:@"OK"]) {
				NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
				[numberFormatter setNumberStyle:NSNumberFormatterDecimalStyle];
				
				NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
				[dateFormatter setDateFormat:@"HH:mm:ss"];
				
				user = [[JWRESTUser alloc] init];
				[user setRole:(JWUserRole)[[jsonData objectForKey:@"role"] integerValue]];
				[user setState:(JWUserState)[[jsonData objectForKey:@"state"] integerValue]];
				[user setToTime:[dateFormatter dateFromString:[jsonData objectForKey:@"totime"]]];
				[user setFromTime:[dateFormatter dateFromString:[jsonData objectForKey:@"fromtime"]]];
				[user setUsername:[NSString stringWithFormat:@"%@", [jsonData objectForKey:@"username"]]];
				[user setID:[numberFormatter numberFromString:[NSString stringWithFormat:@"%@", [jsonData objectForKey:@"id"]]]];
			}
			
			if (!user) {
				loginSucceeded = NO;
				
				errorString = @"-- the client implementation did not return a valid user --";
				errorCode = 0;
				error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey: errorString}];
			}
		}
		
		if(!loginSucceeded) {
			_username = nil;
			_password = nil;
			
			if (!error) {
				errorString = [jsonData objectForKey:@"message"];
				errorCode = [[jsonData objectForKey:@"code"] integerValue];
				error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey: errorString}];
			}
			
			if (_authenticationFailed) {
				_authenticationFailed(error);
			}
			else if ([_delegate respondsToSelector:@selector(RESTClient:authenticationFailed:)]) {
				[_delegate RESTClient:self authenticationFailed:error];
			}
		}
		
		_loggedIn = YES;
		
		_currentUser = user;
		completion(loginSucceeded, jsonData, user, error);
		
		if (_loggingEnabled) {
			if (!error) {
				errorString = [jsonData objectForKey:@"message"];
				errorCode = [[jsonData objectForKey:@"code"] integerValue] ? [[jsonData objectForKey:@"code"] integerValue] : [connectionBlockCopy statusCode];
			}
			NSLog(@"JWRESTClient MESSAGE: LOGIN %@SUCCESSFUL. Response code: %i, Server message: %@", loginSucceeded ? @"" : @"NOT ", errorCode, errorString);
		}
	}];
	
	[connection setFailed:^(NSError *er) {
		_username = nil;
		_password = nil;
		
		errorCode = [connectionBlockCopy statusCode];
		errorString = [NSString stringWithFormat:@"NETWORK ERROR: %@", [er localizedDescription]];
		
		_loggedIn = NO;
		
		completion(NO, nil, nil, [NSError errorWithDomain:NSPOSIXErrorDomain code:errorCode userInfo:@{NSLocalizedDescriptionKey: errorString, NSUnderlyingErrorKey: er}]);
		
		if (_loggingEnabled) {
			NSLog(@"JWRESTClient MESSAGE: LOGIN %@SUCCESSFUL. Response code: %i, Response message: %@", loginSucceeded ? @"" : @"NOT ", errorCode, errorString);
		}
	}];
	
	[connection setAuthenticateAgainstProtectionSpace:^BOOL(NSURLProtectionSpace *protSpace) {
		return [[protSpace authenticationMethod] isEqualToString:NSURLAuthenticationMethodClientCertificate];
	}];
	
	[connection setReceivedAuthenticationChallenge:^(NSURLAuthenticationChallenge *challenge) {
		if ([[[challenge protectionSpace] authenticationMethod] isEqualToString:NSURLAuthenticationMethodClientCertificate]) {
			NSURLCredential *credential = [NSURLCredential credentialWithIdentity:nil certificates:nil persistence:NSURLCredentialPersistenceNone];
			[[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
		}
	}];
	
	[connection start];
}

- (void)executeCommand:(NSString *)CMD {
	JWURLConnection *connection = [JWURLConnection connectionWithGETRequestToURL:[_rootURL URLByAppendingPathComponent:CMD] usingCachePolicy:[self getCachePolicy] andTimeout:[self getTimeout] delegate:nil startImmediately:NO];
	[connection setFinished:^(NSData *data, NSStringEncoding encoding) {
		if (_globalResponseProcessingHandler) {
			if (!_globalResponseProcessingHandler(data, encoding)) {
				return;
			}
		}
	}];
	[connection start];
}

- (void)executeCommand:(NSString *)CMD ignoreCachedData:(BOOL)ignoreCache {
	if (ignoreCache) {
		[self setCachePolicyForNextRequest:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
	}
	
	[self executeCommand:CMD];
}

- (void)executeCommand:(NSString *)CMD usingHTTPMethod:(JWHTTPMethod)method {
	JWURLConnection *connection = [JWURLConnection connectionWithURL:[_rootURL URLByAppendingPathComponent:CMD] HTTPMethod:method usingCachePolicy:[self getCachePolicy] andTimeout:[self getTimeout] delegate:nil startImmediately:NO];
	[connection setFinished:^(NSData *data, NSStringEncoding encoding) {
		if (_globalResponseProcessingHandler) {
			if (!_globalResponseProcessingHandler(data, encoding)) {
				return;
			}
		}
	}];
	[connection start];
}

- (void)executeCommand:(NSString *)CMD usingHTTPMethod:(JWHTTPMethod)method ignoreCachedData:(BOOL)ignoreCache {
	if (ignoreCache) {
		[self setCachePolicyForNextRequest:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
	}
	
	[self executeCommand:CMD usingHTTPMethod:method];
}

- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data {
	JWURLConnection *connection = [JWURLConnection connectionWithPOSTRequestToURL:[_rootURL URLByAppendingPathComponent:CMD] POSTData:data usingCachePolicy:[self getCachePolicy] andTimeout:[self getTimeout] delegate:nil startImmediately:NO];
	[connection setFinished:^(NSData *data, NSStringEncoding encoding) {
		if (_globalResponseProcessingHandler) {
			if (!_globalResponseProcessingHandler(data, encoding)) {
				return;
			}
		}
	}];
	[connection start];
}

- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data ignoreCachedData:(BOOL)ignoreCache {
	if (ignoreCache) {
		[self setCachePolicyForNextRequest:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
	}
	
	[self executeCommand:CMD sendData:data];
}

- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data usingHTTPMethod:(JWHTTPMethod)method {
	NSMutableString *queryString;
	
	switch (method) {
		case JWHTTPpost:
			[JWURLConnection connectionWithPOSTRequestToURL:[_rootURL URLByAppendingPathComponent:CMD] POSTData:data usingCachePolicy:[self getCachePolicy] andTimeout:[self getTimeout] delegate:nil startImmediately:YES];
			
			break;
		case JWHTTPget:
			queryString = [NSMutableString string];
			
			for (int i = 0; i < [[data allKeys] count]; i++) {
				[queryString appendFormat:@"%@=%@&", [[data allKeys] objectAtIndex:i], [[data allValues] objectAtIndex:i]];
			}
			
			[queryString deleteCharactersInRange:NSMakeRange([queryString length] - 1, 1)];
			
			[JWURLConnection connectionWithGETRequestToURL:[[_rootURL URLByAppendingPathComponent:CMD] URLByAppendingQueryString:queryString] usingCachePolicy:[self getCachePolicy] andTimeout:[self getTimeout] delegate:nil startImmediately:YES];
			
			break;
		case JWHTTPconnect:
		case JWHTTPoptions:
		case JWHTTPdelete:
		case JWHTTPtrace:
		case JWHTTPhead:
		case JWHTTPput:
			if (_loggingEnabled) {
				NSLog(@"JWRESTClient MESSAGE: HTTP Method not suitable for REST request.");
			}
			break;
	}
}

- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data usingHTTPMethod:(JWHTTPMethod)method ignoreCachedData:(BOOL)ignoreCache {
	if (ignoreCache) {
		[self setCachePolicyForNextRequest:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
	}
	
	[self executeCommand:CMD sendData:data usingHTTPMethod:method];
}

- (void)executeCommand:(NSString *)CMD getDataWithBlock:(void (^)(NSData *da, NSStringEncoding))dataBlock andFailBlock:(void (^)(NSError *error))failBlock {
	NSTimeInterval timeOut = [self getTimeout];
	NSURLRequestCachePolicy cachePol = [self getCachePolicy];
	
	JWURLConnection *connection = [JWURLConnection connectionWithGETRequestToURL:[_rootURL URLByAppendingPathComponent:CMD] usingCachePolicy:cachePol andTimeout:timeOut delegate:nil];
	[connection setFinished:^(NSData *data, NSStringEncoding encoding) {
		if (_globalResponseProcessingHandler) {
			if (!_globalResponseProcessingHandler(data, encoding)) {
				return;
			}
		}
		
		if (dataBlock) {
			dataBlock(data, encoding);
		}
	}];
	[connection setFailed:^(NSError *error) {
		if (failBlock) {
			failBlock(error);
		}
		
		if (_loggingEnabled) {
			NSLog(@"JWRESTClient MESSAGE: REST CALL FAILED WITH ERROR: %@", [error localizedDescription]);
		}
	}];
	[connection setWillCacheResponse:^BOOL(JWURLConnection *connection, NSCachedURLResponse *cachedResponse) {
		if ([self getCachePolicy] == NSURLRequestReturnCacheDataElseLoad) {
			return YES;
		}
		
		return NO;
	}];
	[connection setWillCacheResponse:^BOOL(JWURLConnection *connection, NSCachedURLResponse *cachedResponse) {
		if (cachePol == NSURLRequestReturnCacheDataElseLoad) {
			return YES;
		}
		
		return NO;
	}];
	
	[connection start];
}

- (void)executeCommand:(NSString *)CMD getDataWithBlock:(void (^)(NSData *da, NSStringEncoding))dataBlock andFailBlock:(void (^)(NSError *error))failBlock ignoreCachedData:(BOOL)ignoreCache {
	if (ignoreCache) {
		[self setCachePolicyForNextRequest:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
	}
	
	[self executeCommand:CMD getDataWithBlock:dataBlock andFailBlock:failBlock];
}

- (void)executeCommand:(NSString *)CMD getDataWithBlock:(void (^)(NSData *, NSStringEncoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock usingHTTPMethod:(JWHTTPMethod)method {
	NSTimeInterval timeOut = [self getTimeout];
	NSURLRequestCachePolicy cachePol = [self getCachePolicy];
	
	JWURLConnection *connection = [JWURLConnection connectionWithURL:[_rootURL URLByAppendingPathComponent:CMD] HTTPMethod:method usingCachePolicy:cachePol andTimeout:timeOut delegate:nil];
	[connection setFinished:^(NSData *data, NSStringEncoding encoding) {
		if (_globalResponseProcessingHandler) {
			if (!_globalResponseProcessingHandler(data, encoding)) {
				return;
			}
		}
		
		if (dataBlock) {
			dataBlock(data, encoding);
		}
		
	}];
	[connection setFailed:^(NSError *error) {
		if (failBlock) {
			failBlock(error);
		}
		
		if (_loggingEnabled) {
			NSLog(@"JWRESTClient MESSAGE: REST CALL FAILED WITH ERROR: %@", [error localizedDescription]);
		}
	}];
	[connection setWillCacheResponse:^BOOL(JWURLConnection *connection, NSCachedURLResponse *cachedResponse) {
		if (cachePol == NSURLRequestReturnCacheDataElseLoad) {
			return YES;
		}
		
		return NO;
	}];
	
	[connection start];
}

- (void)executeCommand:(NSString *)CMD getDataWithBlock:(void (^)(NSData *, NSStringEncoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock usingHTTPMethod:(JWHTTPMethod)method ignoreCachedData:(BOOL)ignoreCache {
	if (ignoreCache) {
		[self setCachePolicyForNextRequest:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
	}
	
	[self executeCommand:CMD getDataWithBlock:dataBlock andFailBlock:failBlock usingHTTPMethod:method];
}

- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data getDataWithBlock:(void (^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock {
	NSTimeInterval timeOut = [self getTimeout];
	NSURLRequestCachePolicy cachePol = [self getCachePolicy];
	
	JWURLConnection *connection = [JWURLConnection connectionWithPOSTRequestToURL:[_rootURL URLByAppendingPathComponent:CMD] POSTData:data usingCachePolicy:cachePol andTimeout:timeOut delegate:nil];
	[connection setFinished:^(NSData *data, NSStringEncoding encoding) {
		if (_globalResponseProcessingHandler) {
			if (!_globalResponseProcessingHandler(data, encoding)) {
				return;
			}
		}
		
		if (dataBlock) {
			dataBlock(data, encoding);
		}
	}];
	[connection setFailed:^(NSError *error) {
		if (failBlock) {
			failBlock(error);
		}
		
		if (_loggingEnabled) {
			NSLog(@"JWRESTClient MESSAGE: REST CALL FAILED WITH ERROR: %@", [error localizedDescription]);
		}
	}];
	[connection setWillCacheResponse:^BOOL(JWURLConnection *connection, NSCachedURLResponse *cachedResponse) {
		if (cachePol == NSURLRequestReturnCacheDataElseLoad) {
			return YES;
		}
		
		return NO;
	}];
	
	[connection start];
}

- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data getDataWithBlock:(void (^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock ignoreCachedData:(BOOL)ignoreCache {
	if (ignoreCache) {
		[self setCachePolicyForNextRequest:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
	}
	
	[self executeCommand:CMD sendData:data getDataWithBlock:dataBlock andFailBlock:failBlock];
}

- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data getDataWithBlock:(void (^)(NSData *, NSStringEncoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock usingHTTPMethod:(JWHTTPMethod)method {
	NSTimeInterval timeOut = [self getTimeout];
	NSURLRequestCachePolicy cachePol = [self getCachePolicy];
	
	JWURLConnection *connection;
	NSMutableString *queryString;
	
	switch (method) {
		case JWHTTPpost: {
			connection = [JWURLConnection connectionWithPOSTRequestToURL:[_rootURL URLByAppendingPathComponent:CMD] POSTData:data usingCachePolicy:cachePol andTimeout:timeOut delegate:nil];
			[connection setFinished:^(NSData *data, NSStringEncoding encoding) {
				if (_globalResponseProcessingHandler) {
					if (!_globalResponseProcessingHandler(data, encoding)) {
						return;
					}
				}
				
				if (dataBlock) {
					dataBlock(data, encoding);
				}
			}];
			[connection setFailed:^(NSError *error) {
				
				
				if (_loggingEnabled) {
					NSLog(@"JWRESTClient MESSAGE: REST CALL FAILED WITH ERROR: %@", [error localizedDescription]);
				}
			}];
		}
			break;
		case JWHTTPget: {
			queryString = [NSMutableString string];
			
			for (int i = 0; i < [[data allKeys] count]; i++) {
				if (i == 0) {
					[queryString appendFormat:@"?%@=%@", [[data allKeys] objectAtIndex:0], [[data allValues] objectAtIndex:0]];
				}
				else {
					[queryString appendFormat:@"&%@=%@", [[data allKeys] objectAtIndex:i], [[data allValues] objectAtIndex:i]];
				}
			}
			
			[JWURLConnection connectionWithGETRequestToURL:[[_rootURL URLByAppendingPathComponent:CMD] URLByAppendingQueryString:queryString] usingCachePolicy:[self getCachePolicy] andTimeout:[self getTimeout] delegate:nil];
			
			break;
		}
		case JWHTTPconnect:
		case JWHTTPoptions:
		case JWHTTPdelete:
		case JWHTTPtrace:
		case JWHTTPhead:
		case JWHTTPput:
			if (_loggingEnabled) {
				NSLog(@"JWRESTClient MESSAGE: HTTP Method not suitable for REST request.");
			}
			break;
	}
	
	[connection start];
}

- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data getDataWithBlock:(void (^)(NSData *, NSStringEncoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock usingHTTPMethod:(JWHTTPMethod)method ignoreCachedData:(BOOL)ignoreCache {
	if (ignoreCache) {
		[self setCachePolicyForNextRequest:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
	}
	
	[self executeCommand:CMD sendData:data getDataWithBlock:dataBlock andFailBlock:failBlock usingHTTPMethod:method];
}

- (void)executeCommand:(NSString *)CMD uploadFile:(NSData *)data withName:(NSString *)name forFieldName:(NSString *)fieldName andAdditionalPOSTData:(NSDictionary *)POSTData getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock {
	NSURLRequestCachePolicy cachePol = [self getCachePolicy];
	
	JWURLConnection *connection = [JWURLConnection connectionByFormUploadingData:data toURL:[[self rootURL] URLByAppendingPathComponent:CMD] withFileName:name forFieldName:fieldName withAdditionalPOSTData:POSTData delegate:nil];
	[connection setFinished:^(NSData *da, NSStringEncoding encoding) {
		if (_globalResponseProcessingHandler) {
			if (!_globalResponseProcessingHandler(data, encoding)) {
				return;
			}
		}
		
		dataBlock(da, encoding);
	}];
	[connection setFailed:failBlock];
	[connection setWillCacheResponse:^BOOL(JWURLConnection *connection, NSCachedURLResponse *cachedResponse) {
		if (cachePol == NSURLRequestReturnCacheDataElseLoad) {
			return YES;
		}
		
		return NO;
	}];
	
	[connection start];
}

- (void)executeCommand:(NSString *)CMD uploadFile:(NSData *)data withName:(NSString *)name forFieldName:(NSString *)fieldName andAdditionalPOSTData:(NSDictionary *)POSTData getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock ignoreCachedData:(BOOL)ignoreCache {
	if (ignoreCache) {
		[self setCachePolicyForNextRequest:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
	}
	
	[self executeCommand:CMD uploadFile:data withName:name forFieldName:fieldName andAdditionalPOSTData:POSTData getDataWithBlock:dataBlock andFailBlock:failBlock];
}

- (void)executeCommand:(NSString *)CMD uploadFile:(NSData *)data withName:(NSString *)name forFieldName:(NSString *)fieldName andAdditionalPOSTData:(NSDictionary *)POSTData addToQueue:(JWURLConnectionQueue *)queue getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock {
	NSURLRequestCachePolicy cachePol = [self getCachePolicy];
	
	JWURLConnection *connection = [JWURLConnection connectionByFormUploadingData:data toURL:[[self rootURL] URLByAppendingPathComponent:CMD] withFileName:name forFieldName:fieldName withAdditionalPOSTData:POSTData delegate:nil];
	[connection setFinished:^(NSData *data, NSStringEncoding encoding) {
		if (_globalResponseProcessingHandler) {
			if (!_globalResponseProcessingHandler(data, encoding)) {
				return;
			}
		}
		
		dataBlock(data, encoding);
	}];
	[connection setFailed:failBlock];
	[connection setWillCacheResponse:^BOOL(JWURLConnection *connection, NSCachedURLResponse *cachedResponse) {
		if (cachePol == NSURLRequestReturnCacheDataElseLoad) {
			return YES;
		}
		
		return NO;
	}];
	
	[queue addToQueue:connection];
}

- (void)executeCommand:(NSString *)CMD uploadFile:(NSData *)data withName:(NSString *)name forFieldName:(NSString *)fieldName andAdditionalPOSTData:(NSDictionary *)POSTData addToQueue:(JWURLConnectionQueue *)queue getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock ignoreCachedData:(BOOL)ignoreCache {
	if (ignoreCache) {
		[self setCachePolicyForNextRequest:NSURLRequestReloadIgnoringLocalAndRemoteCacheData];
	}
	
	[self executeCommand:CMD uploadFile:data withName:name forFieldName:fieldName andAdditionalPOSTData:POSTData addToQueue:queue getDataWithBlock:dataBlock andFailBlock:failBlock];
}

- (void)logout {
	JWURLConnection *connection = [JWURLConnection connectionWithGETRequestToURL:[_rootURL URLByAppendingPathComponent:@"logout"] usingCachePolicy:NSURLCacheStorageNotAllowed andTimeout:[self getTimeout] delegate:nil];
	__weak JWURLConnection *connectionBlockCopy = connection;
	
	[connection setFinished:^(NSData *data, NSStringEncoding encoding) {
		_username = nil;
		_password = nil;
		_autoLogin = NO;
		
		if (_globalResponseProcessingHandler) {
			if (!_globalResponseProcessingHandler(data, encoding)) {
				return;
			}
		}
		
		if (_loggingEnabled) {
			NSLog(@"JERESTClient MESSAGE: LOGOUT ENDED. Response code: %i, Response message: %@", [connectionBlockCopy statusCode], [[NSString alloc] initWithData:data encoding:encoding]);
		}
	}];
	[connection setFailed:^(NSError *error) {
		if (_loggingEnabled) {
			NSLog(@"JWRESTClient MESSAGE: LOGOUT FAILED. Error: %@", [error localizedDescription]);
		}
	}];
	
	[connection setUseCache:NO];
	[connection start];
}

- (NSData *)executeCommandSynchronously:(NSString *)CMD {
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[[self rootURL] URLByAppendingPathComponent:CMD] cachePolicy:[self getCachePolicy] timeoutInterval:[self getTimeout]];
	
	return [[[JWURLConnection alloc] initWithRequest:request delegate:nil] getDataSynchronously];
}

@end


@implementation NSString (MD5)

+ (NSString *)stringWithMD5FromFile:(NSString *)path {
	NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath: path];
	if (handle == nil) {
		return nil;
	}
	
	CC_MD5_CTX md5;
	CC_MD5_Init(&md5);
	
	BOOL done = NO;
	
	while (!done) {
		NSData *fileData = [[NSData alloc] initWithData:[handle readDataOfLength:4096]];
		CC_MD5_Update(&md5, [fileData bytes], [fileData length]);
		
		if ([fileData length] == 0) {
			done = YES;
		}
	}
	
	unsigned char digest[CC_MD5_DIGEST_LENGTH];
	CC_MD5_Final(digest, &md5);
	NSString *s = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
				   digest[0],  digest[1], digest[2],  digest[3], digest[4],  digest[5], digest[6],  digest[7],
				   digest[8],  digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]];
	
	return s;
}

- (NSString *)MD5Hash {
	CC_MD5_CTX md5;
	CC_MD5_Init(&md5);
	CC_MD5_Update(&md5, [self UTF8String], [self length]);
	
	unsigned char digest[CC_MD5_DIGEST_LENGTH];
	CC_MD5_Final(digest, &md5);
	NSString *s = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
				   digest[0],  digest[1], digest[2],  digest[3], digest[4],  digest[5], digest[6],  digest[7],
				   digest[8],  digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]];
	
	return s;
}

@end
