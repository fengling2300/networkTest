iOS使用自签名证书实现HTTPS请求
由于苹果规定2017年1月1日以后，所有APP都要使用HTTPS进行网络请求，否则无法上架，因此研究了一下在iOS中使用HTTPS请求的实现。相信大家对HTTPS都或多或少有些了解，这里我就不再介绍了，主要功能就是将传输的报文进行加密，提高安全性。

1、证书准备

证书分为两种，一种是花钱向认证的机构购买的证书，服务端如果使用的是这类证书的话，那一般客户端不需要做什么，用HTTPS进行请求就行了，苹果内置了那些受信任的根证书的。另一种是自己制作的证书，使用这类证书的话是不受信任的（当然也不用花钱买），因此需要我们在代码中将该证书设置为信任证书。

我这边使用的是xca来制作了根证书，制作流程请参考http://www.2cto.com/Article/201411/347512.html，由于xca无法导出.jsk的后缀，因此我们只要制作完根证书后以.p12的格式导出就行了，之后的证书制作由命令行来完成。自制一个批处理文件，添加如下命令：


set ip=%1%
md %ip%
keytool -importkeystore -srckeystore ca.p12 -srcstoretype PKCS12 -srcstorepass 123456 -destkeystore ca.jks -deststoretype JKS -deststorepass 123456
keytool -genkeypair -alias server-%ip% -keyalg RSA -keystore ca.jks -storepass 123456 -keypass 123456 -validity 3650 -dname "CN=%ip%, OU=ly, O=hik, L=hz, ST=zj, C=cn"
keytool -certreq -alias server-%ip% -storepass 123456 -file %ip%\server-%ip%.certreq -keystore ca.jks
keytool -gencert -alias ca -storepass 123456 -infile %ip%\server-%ip%.certreq -outfile %ip%\server-%ip%.cer -validity 3650 -keystore ca.jks  
keytool -importcert -trustcacerts -storepass 123456 -alias server-%ip% -file %ip%\server-%ip%.cer -keystore ca.jks
keytool -delete -keystore ca.jks -alias ca -storepass 123456

将上面加粗的ca.p12改成你导出的.p12文件的名称，123456改为你创建证书的密码。

然后在文件夹空白处按住ctrl+shift点击右键，选择在此处打开命令窗口，在命令窗口中输入“start.bat ip/域名”来执行批处理文件，其中start.bat是添加了上述命令的批处理文件，ip/域名即你服务器的ip或者域名。执行成功后会生成一个.jks文件和一个以你的ip或域名命名的文件夹，文件夹中有一个.cer的证书，这边的.jks文件将在服务端使用.cer文件将在客户端使用，到这里证书的准备工作就完成了。

2、服务端配置

由于我不做服务端好多年，只会使用Tomcat，所以这边只讲下Tomcat的配置方法，使用其他服务器的同学请自行查找设置方法。

打开tomcat/conf目录下的server.xml文件将HTTPS的配置打开，并进行如下配置：


<Connector URIEncoding="UTF-8" protocol="org.apache.coyote.http11.Http11NioProtocol" port="8443" maxThreads="200" scheme="https" secure="true" SSLEnabled="true" sslProtocol="TLSv1.2" sslEnabledProtocols="TLSv1.2" keystoreFile="${catalina.base}/ca/ca.jks" keystorePass="123456" clientAuth="false" SSLVerifyClient="off" netZone="你的ip或域名"/>

keystoreFile是你.jks文件放置的目录，keystorePass是你制作证书时设置的密码，netZone填写你的ip或域名。注意苹果要求协议要TLSv1.2以上。

3、iOS端配置

首先把前面生成的.cer文件添加到项目中，注意在添加的时候选择要添加的targets。

1.使用NSURLSession进行请求

代码如下：


NSString *urlString = @"https://xxxxxxx";
NSURL *url = [NSURL URLWithString:urlString];
NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringCacheData timeoutInterval:10.0f];
NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
NSURLSessionDataTask *task = [session dataTaskWithRequest:request];
[task resume];

需要实现NSURLSessionDataDelegate中的URLSession:didReceiveChallenge:completionHandler:方法来进行证书的校验，代码如下：


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


此时即可成功请求到服务端。

注：调用SecTrustSetAnchorCertificates设置可信任证书列表后就只会在设置的列表中进行验证，会屏蔽掉系统原本的信任列表，要使系统的继续起作用只要调用SecTrustSetAnchorCertificates方法，第二个参数设置成NO即可。

2.使用AFNetworking进行请求

AFNetworking首先需要配置AFSecurityPolicy类，AFSecurityPolicy类封装了证书校验的过程。


/**
 AFSecurityPolicy分三种验证模式：
 AFSSLPinningModeNone:只是验证证书是否在信任列表中
 AFSSLPinningModeCertificate：该模式会验证证书是否在信任列表中，然后再对比服务端证书和客户端证书是否一致
 AFSSLPinningModePublicKey：只验证服务端证书与客户端证书的公钥是否一致
*/

AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
securityPolicy.allowInvalidCertificates = YES;//是否允许使用自签名证书
securityPolicy.validatesDomainName = NO;//是否需要验证域名，默认YES

AFHTTPSessionManager *_manager = [AFHTTPSessionManager manager];
_manager.responseSerializer = [AFHTTPResponseSerializer serializer];
_manager.securityPolicy = securityPolicy;
//设置超时
[_manager.requestSerializer willChangeValueForKey:@"timeoutinterval"];
_manager.requestSerializer.timeoutInterval = 20.f;
[_manager.requestSerializer didChangeValueForKey:@"timeoutinterval"];
 _manager.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringCacheData;
_manager.responseSerializer.acceptableContentTypes  = [NSSet setWithObjects:@"application/xml",@"text/xml",@"text/plain",@"application/json",nil];
 
__weak typeof(self) weakSelf = self;
[_manager setSessionDidReceiveAuthenticationChallengeBlock:^NSURLSessionAuthChallengeDisposition(NSURLSession *session, NSURLAuthenticationChallenge *challenge, NSURLCredential *__autoreleasing *_credential) {
        
    SecTrustRef serverTrust = [[challenge protectionSpace] serverTrust];
    /**
     *  导入多张CA证书
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


上述代码通过给AFHTTPSessionManager重新设置证书验证回调来自己验证证书，然后将自己的证书加入到可信任的证书列表中，即可通过证书的校验。

由于服务端使用.jks是一个证书库，客户端获取到的证书可能不止一本，我这边获取到了两本，具体获取到基本可通过SecTrustGetCertificateCount方法获取证书个数，AFNetworking在evaluateServerTrust：forDomain：方法中，AFSSLPinningMode的类型为AFSSLPinningModeCertificate和AFSSLPinningModePublicKey的时候都有校验服务端的证书个数与客户端信任的证书数量是否一样，如果不一样的话无法请求成功，所以这边我就修改他的源码，当有一个校验成功时即算成功。

当类型为AFSSLPinningModeCertificate时


return trustedCertificateCount == [serverCertificates count] - 1;


为AFSSLPinningModePublicKey时


return trustedPublicKeyCount > 0 && ((self.validatesCertificateChain) || (!self.validatesCertificateChain && trustedPublicKeyCount >= 1));


去掉了第二块中的trustedPublicKeyCount == [serverCertificates count]的条件。

这边使用的AFNetworking的版本为2.5.3，如果其他版本有不同之处请自行根据实际情况修改。

