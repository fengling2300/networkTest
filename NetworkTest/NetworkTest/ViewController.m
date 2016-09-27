//
//  ViewController.m
//  NetworkTest
//
//  Created by apple on 16/9/21.
//  Copyright © 2016年 hikvision. All rights reserved.
//

#import "ViewController.h"
#import "HttpManager.h"

@interface ViewController ()<NSURLSessionDataDelegate>

@property(nonatomic,copy)NSString *etag;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIButton *btn = [[UIButton alloc]initWithFrame:CGRectMake(100, 100, 200, 100)];
    [btn setTitle:@"AFNetworking" forState:UIControlStateNormal];
    [btn setBackgroundColor:[UIColor redColor]];
    [btn addTarget:self action:@selector(btnClicked) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    
    UIButton *sessionBtn = [[UIButton alloc]initWithFrame:CGRectMake(100, 300, 200, 100)];
    [sessionBtn setTitle:@"NSUrlSession" forState:UIControlStateNormal];
    [sessionBtn setBackgroundColor:[UIColor redColor]];
    [sessionBtn addTarget:self action:@selector(sessionBtnClicked) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:sessionBtn];
}

- (void)btnClicked {
    NSString *urlString = @"https://10.20.129.25:8443/dreamVideo/restful/show";
    HttpManager *httpManager = [HttpManager shareHttpManager];
    [httpManager post:urlString withParameters:nil success:^(NSURLSessionDataTask *task, id responseObject) {
        NSLog(@"success");
    } failure:^(NSURLSessionDataTask *task, NSError *error) {
        NSLog(@"failure");
    }];
}

- (void)sessionBtnClicked {
    NSString *urlString = @"https://10.20.129.25:8443/dreamVideo/restful/show";
    NSURL *url = [NSURL URLWithString:urlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.0f];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
    [task resume];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    NSLog(@"接收到服务器响应");
    //注意：这里需要使用completionHandler回调告诉系统应该如何处理服务器返回的数据
    //默认是取消
    /**
     NSURLSessionResponseCancel = 0,            默认的处理方式，取消
     NSURLSessionResponseAllow = 1,             接收服务器返回的数据
     NSURLSessionResponseBecomeDownload = 2,    变成一个下载请求
     NSURLSessionResponseBecomeStream           变成一个流
     */
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data {
    NSLog(@"获取到服务段数据");
    NSLog(@"%@",[self jsonToDictionary:data]);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    NSLog(@"请求完成");
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {
    NSLog(@"证书认证");
    if ([[[challenge protectionSpace] authenticationMethod] isEqualToString: NSURLAuthenticationMethodServerTrust]) {
        do
        {
            SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
            NSCAssert(serverTrust != nil, @"serverTrust is nil");
            if(nil == serverTrust)
                break; /* failed */
            /**
             *  导入多张CA证书（Certification Authority，支持SSL证书以及自签名的CA），请替换掉你的证书名称
             */
            NSString *cerPath = [[NSBundle mainBundle] pathForResource:@"ca" ofType:@"cer"];//自签名证书
            NSData* caCert = [NSData dataWithContentsOfFile:cerPath];

            NSCAssert(caCert != nil, @"caCert is nil");
            if(nil == caCert)
                break; /* failed */
            
            SecCertificateRef caRef = SecCertificateCreateWithData(NULL, (__bridge CFDataRef)caCert);
            NSCAssert(caRef != nil, @"caRef is nil");
            if(nil == caRef)
                break; /* failed */
            
            //可以添加多张证书
            NSArray *caArray = @[(__bridge id)(caRef)];
            
            NSCAssert(caArray != nil, @"caArray is nil");
            if(nil == caArray)
                break; /* failed */
            
            //将读取的证书设置为服务端帧数的根证书
            OSStatus status = SecTrustSetAnchorCertificates(serverTrust, (__bridge CFArrayRef)caArray);
            NSCAssert(errSecSuccess == status, @"SecTrustSetAnchorCertificates failed");
            if(!(errSecSuccess == status))
                break; /* failed */
            
            SecTrustResultType result = -1;
            //通过本地导入的证书来验证服务器的证书是否可信
            status = SecTrustEvaluate(serverTrust, &result);
            if(!(errSecSuccess == status))
                break; /* failed */
            NSLog(@"stutas:%d",(int)status);
            NSLog(@"Result: %d", result);
            
            BOOL allowConnect = (result == kSecTrustResultUnspecified) || (result == kSecTrustResultProceed);
            if (allowConnect) {
                NSLog(@"success");
            }else {
                NSLog(@"error");
            }

            /* kSecTrustResultUnspecified and kSecTrustResultProceed are success */
            if(! allowConnect)
            {
                break; /* failed */
            }
            
#if 0
            /* Treat kSecTrustResultConfirm and kSecTrustResultRecoverableTrustFailure as success */
            /*   since the user will likely tap-through to see the dancing bunnies */
            if(result == kSecTrustResultDeny || result == kSecTrustResultFatalTrustFailure || result == kSecTrustResultOtherError)
                break; /* failed to trust cert (good in this case) */
#endif
            
            // The only good exit point
            NSLog(@"信任该证书");
            
            NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            completionHandler(NSURLSessionAuthChallengeUseCredential,credential);
            return [[challenge sender] useCredential: credential
                          forAuthenticationChallenge: challenge];
            
        }
        while(0);
    }
    
    // Bad dog
    NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
    completionHandler(NSURLSessionAuthChallengeCancelAuthenticationChallenge,credential);
    return [[challenge sender] cancelAuthenticationChallenge: challenge];
}

- (NSDictionary *)jsonToDictionary:(NSData *)jsonData {
    NSError *jsonError;
    NSDictionary *resultDic = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableLeaves error:&jsonError];
    return resultDic;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
