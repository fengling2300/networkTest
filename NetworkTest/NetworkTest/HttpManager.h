//
//  HttpManager.h
//  iVMS-8700-MCU
//
//  Created by apple on 15-3-16.
//  Copyright (c) 2015年 HikVision. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HttpManager : NSObject

@property(nonatomic,copy)NSString *etag;

+(instancetype)shareHttpManager;

//https访问
-(void)post:(NSString *)url withParameters:(id)parameters success:(void (^)(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject))success failure:(void (^)(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error))failure;
//注册hpns
//-(void)postHPNS:(NSString *)url withParameters:(id)parameters success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure;
//
//-(void)posthttp:(NSString *)url withParameters:(id)parameters
//        success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
//        failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure;

@end
