# JWRESTClient
***Objective-C base client for JSON REST APIs***

This is a client class for usage with JSON RESTful APIs.
It supports form data requests, POST, GET, form updloads and many other features.
`JWRESTClient` includes `JWRESTUser` (collection of user properties), singleton support and a delegate protocol.

## Demo
I'll try to provide an example app in the next weeks, since I don't have much time yet.

## Installation
Easily drop the two class files (.h and .m) into jour project and `#import "JWRESTClient"` where you need it.

## Dependencies
- [JWURLConnection][1] (included as submodule)

## Usage (examples)
``` objective-c
- (void)setup {
    [[JWRESTClient sharedClient] setMD5UserCredentials:YES];
    [[JWRESTClient sharedClient] setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [[JWRESTClient sharedClient] serTootURL:[NSURL URLWithString:@"https://api.example.com/"]];
}

- (void)login {
    [[JWRESTClient sharedClient] loginWithUserName:@"anonymous" andPassword:@"•••••••••" sendAdditionalPOSTDate:@{@"timestamp": @1389265265} completion:^(BOOL loggedIn, NSDictionary *userInfo, JWRESTUser *user, NSError *error) {
        if (loggedIn) {
            // user logged in, remove login form
        }
        else {
            // losing fails, additional informations in userInfo and error
        }
    }];
}

- (void)uploadFile {
    [[JWRESTClient sharedClient] executeCommand:@"saveImage" uploadFile:imageData withName:@"1389265265.jpg" forFieldName:@"file_name" andAdditionalPOSTData:@{"exif":@{"aperture":@"2.4"}} getDataWithBlock:^(NSData *data, NSStringEncoding encoding) {
        NSDictionary *response = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments | NSJSONReadingMutableContainers error:nil];
        
        if ([[response objectForKey:@"response_code"] isEqualToString:@"OK"]) {
            // image upload successful
        }
        else {
            // upload failed, additional informations in error
        }
    }];
}
```

## Methods (excerpt, see header file for full list)
``` objective-c
+ (JWRESTClient *)RESTClient;
+ (JWRESTClient *)sharedClient;
+ (JWRESTClient *)RESTClientWithRootURL:(NSURL *)url username:(NSString *)user andPassword:(NSString *)pass;
+ (JWRESTClient *)RESTClientWithRootURL:(NSURL *)url username:(NSString *)user andPassword:(NSString *)pass autoLogin:(BOOL)autoLogin;

- (id)init;
- (id)initWithRootURL:(NSURL *)url username:(NSString *)user andPassword:(NSString *)pass;

- (void)loginWithUserName:(NSString *)username andPassword:(NSString *)password sendAdditionalPOSTData:(NSDictionary *)data completion:(void(^)(BOOL loggedIn, NSDictionary *userInfo, JWRESTUser *user, NSError *error))completion;

- (void)executeCommand:(NSString *)CMD;
- (void)executeCommand:(NSString *)CMD usingHTTPMethod:(JWHTTPMethod)method;

- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data;
- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data usingHTTPMethod:(JWHTTPMethod)method;

- (void)executeCommand:(NSString *)CMD getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void(^)(NSError *error))failBlock;
- (void)executeCommand:(NSString *)CMD getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void(^)(NSError *error))failBlock usingHTTPMethod:(JWHTTPMethod)method;

- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void(^)(NSError *error))failBlock;
- (void)executeCommand:(NSString *)CMD sendData:(NSDictionary *)data getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock usingHTTPMethod:(JWHTTPMethod)method;

- (void)executeCommand:(NSString *)CMD uploadFile:(NSData *)data withName:(NSString *)name forFieldName:(NSString *)fieldName andAdditionalPOSTData:(NSDictionary *)POSTData getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void (^)(NSError *error))failBlock;
- (void)executeCommand:(NSString *)CMD uploadFile:(NSData *)data withName:(NSString *)name forFieldName:(NSString *)fieldName andAdditionalPOSTData:(NSDictionary *)POSTData addToQueue:(JWURLConnectionQueue *)queue getDataWithBlock:(void(^)(NSData *data, NSStringEncoding encoding))dataBlock andFailBlock:(void (^)(NSError *))failBlock;

- (void)logout;
- (NSData *)executeCommandSynchronously:(NSString *)CMD;
```

##Tasks
```
- [x] Form Data (POST)
- [x] File upload
- [x] Form file upload (POST)
- [ ] Check cache sometimes seems buggy (JWURLConnection issue?)
```

## Contact / Reference

Julian Weinert

- https://github.com/julian-weinert
- https://stackoverflow.com/users/1041122/julian

## License

`JWRESTClient ` and `JWURLConnection` are available under the GPL V2 license. See the LICENSE file for more info.

  [1]: https://github.com/julian-weinert/JWURLConnection/ "JWURLConnection"
