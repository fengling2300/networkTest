//
//  HttpManager.m
//  iVMS-8700-MCU
//
//  Created by apple on 15-3-16.
//  Copyright (c) 2015年 HikVision. All rights reserved.
//

#import "HttpManager.h"
#import "AFHTTPSessionManager.h"

@interface HttpManager()

@property(nonatomic,retain)AFHTTPSessionManager *manager;

@end

@implementation HttpManager

+(instancetype)shareHttpManager{
    static dispatch_once_t onece = 0;
    static HttpManager *httpManager = nil;
    dispatch_once(&onece, ^(void){
        httpManager = [[self alloc]init];
    });
    return httpManager;
}

//https访问
-(void)post:(NSString *)url withParameters:(id)parameters success:(void (^)(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure {
    AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];

//    securityPolicy = [AFSecurityPolicy defaultPolicy];
    securityPolicy.allowInvalidCertificates = YES;
    securityPolicy.validatesDomainName = NO;

    _manager = [AFHTTPSessionManager manager];
    _manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    _manager.securityPolicy = securityPolicy;
    //设置超时时间
    [_manager.requestSerializer willChangeValueForKey:@"timeoutinterval"];
    _manager.requestSerializer.timeoutInterval = 20.f;
    [_manager.requestSerializer didChangeValueForKey:@"timeoutinterval"];
    _manager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringCacheData;
//    if (_etag) {
//        [_manager.requestSerializer setValue:_etag forHTTPHeaderField:@"If-None-Match"];
//    } else {
//        [_manager.requestSerializer setValue:@"bb" forHTTPHeaderField:@"If-None-Match"];
//    }
    _manager.responseSerializer.acceptableContentTypes  = [NSSet setWithObjects:@"application/xml",@"text/xml",@"text/plain",@"application/json",nil];
    
    __weak typeof(self) weakSelf = self;
    [_manager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential *__autoreleasing *_credential) {
        
        SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
        /**
         *  导入多张CA证书（Certification Authority，支持SSL证书以及自签名的CA），请替换掉你的证书名称
         */
        NSString *cerPath = [[NSBundle mainBundle] pathForResource:@"ca" ofType:@"cer"];//自签名证书
        NSData* caCert = [NSData dataWithContentsOfFile:cerPath];
        NSArray *cerArray = @[caCert];
        weakSelf.manager.securityPolicy.pinnedCertificates = cerArray;
        
        SecCertificateRef caRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)caCert);
        NSCAssert(caRef != nil, @"caRef is nil");
        
        NSArray *caArray = @[(__bridge id)(caRef)];
        NSCAssert(caArray != nil, @"caArray is nil");
        
        OSStatus status = SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)caArray);
        SecTrustSetAnchorCertificatesOnly(serverTrust,NO);
        NSCAssert(errSecSuccess == status, @"SecTrustSetAnchorCertificates failed");
        
        NSURLSessionAuthChallengeDisposition disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        __autoreleasing NSURLCredential *credential = nil;
        if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
            if ([weakSelf.manager.securityPolicy evaluateServerTrust:challenge.protectionSpace.serverTrust forDomain:challenge.protectionSpace.host]) {
                credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
                if (credential) {
                    disposition = NSURLSessionAuthChallengeUseCredential;
                } else {
                    disposition = NSURLSessionAuthChallengePerformDefaultHandling;
                }
            } else {
                disposition = NSURLSessionAuthChallengeCancelAuthenticationChallenge;
            }
        } else {
            disposition = NSURLSessionAuthChallengePerformDefaultHandling;
        }
        
        return disposition;
    }];
    
    
    [_manager POST:url parameters:parameters success:^(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
        NSDictionary *headDic = response.allHeaderFields;
        NSInteger code = response.statusCode;
        NSLog(@"response statusCode is %zd",code);
//        NSString *etag = headDic[@"Etag"];
//        if (etag) {
//            _etag = etag;
//        }
        NSLog(@"%@",[[NSString alloc]initWithData:responseObject encoding:NSUTF8StringEncoding]);
        NSDictionary *responseDic = [self jsonToDictionary:[[NSString alloc]initWithData:responseObject encoding:NSUTF8StringEncoding]];
        success(task,responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSHTTPURLResponse *response = (NSHTTPURLResponse *)task.response;
        NSDictionary *headDic = response.allHeaderFields;
        NSInteger code = response.statusCode;
        NSLog(@"response statusCode is %zd",code);
        failure(task,error);
    }];
}

- (NSDictionary *)jsonToDictionary:(NSString *)jsonString {
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *jsonError;
    NSDictionary *resultDic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:&jsonError];
    return resultDic;
}

@end
