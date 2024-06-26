#import "Xprinter2.h"
#import "POSCommand.h"
#import "POSWIFIManager.h"
#import <UIKit/UIKit.h>


@implementation Xprinter2{
    POSWIFIManager *_wifiManager;
    BOOL _connectionResolveInvoked;
    RCTPromiseResolveBlock _connectionResolve;
    RCTPromiseRejectBlock _connectionReject;
}

RCT_EXPORT_MODULE()

- (instancetype)init {
    self = [super init];
    if (self) {
        // Initialize wifiManager and set its delegate to self
        _wifiManager = [POSWIFIManager sharedInstance];
        _wifiManager.delegate = self;
    }
    return self;
}


RCT_EXPORT_METHOD(connect:(nonnull NSNumber *)connType address:(NSString *)address
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    _connectionResolve = resolve;
    _connectionReject = reject;

    if (_wifiManager.isConnect) {
        [_wifiManager disconnect];
    }

    [_wifiManager connectWithHost:address port:9100];

}

- (void)resetConnectionFlags {
    _connectionResolveInvoked = NO;
    _connectionResolve = nil;
    _connectionReject = nil;
}


//connected success
- (void)POSwifiConnectedToHost:(NSString *)host port:(UInt16)port {
    NSLog(@"connected success");
    if (_connectionResolve && !_connectionResolveInvoked) {
        _connectionResolve(@(YES));
        _connectionResolveInvoked = YES;
        [self resetConnectionFlags];
    }
}

//disconnected
- (void)POSwifiDisconnectWithError:(NSError *)error {
    NSLog(@"disconnected");
    if (error) {
        if (_connectionReject && !_connectionResolveInvoked) {
            _connectionReject(@"0", @"error", error);
            _connectionResolveInvoked = YES;
            [self resetConnectionFlags];
        }
    } else {
        if (_connectionResolve && !_connectionResolveInvoked) {
            _connectionResolve(@(NO));
            _connectionResolveInvoked = YES;
            [self resetConnectionFlags];
        }
    }
}


// Example method
// See // https://reactnative.dev/docs/native-modules-ios
RCT_EXPORT_METHOD(multiply:(double)a
                  b:(double)b
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    NSNumber *result = @(a * b);

    resolve(result);
}

RCT_EXPORT_METHOD(discovery:(nonnull NSNumber *)connType
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    [_wifiManager closeUdpSocket];
    if ([_wifiManager createUdpSocket]) {
        [_wifiManager sendFindCmd:^(PrinterProfile *printer) {
            NSLog(@"printer %@", printer);
        }];
    }
    resolve(@"NO");
}

RCT_EXPORT_METHOD(printerStatus:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    if ([_wifiManager printerIsConnect]) {
        [_wifiManager printerStatus:^(NSData *status) {
            if (status.length == 0) {
                resolve(@"NO");
            } else if (status.length == 1) {
                const Byte *byte = (Byte *)[status bytes];
                unsigned arr = byte[0];

                if (arr == 0x12) {
                    resolve(@"Ready");
                } else if (arr == 0x16) {
                    resolve(@"Cover opened");
                } else if (arr == 0x32) {
                    resolve(@"Paper end");
                } else if (arr == 0x36) {
                    resolve(@"Cover opened & Paper end");
                } else {
                    resolve(@"error");
                }
            }
        }];
    } else {
        resolve(@"NO");
    }
}

RCT_EXPORT_METHOD(isConnect:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
   if ([_wifiManager printerIsConnect]) {
           resolve(@(YES));
       } else {
           resolve(@(NO));
       }
}

RCT_EXPORT_METHOD(setIp:(NSString *)adress
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
    resolve(@(NO));
}

- (UIImage *)imageFromBase64String:(NSString *)base64String {
    // Convert the base64 string to NSData
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64String options:NSDataBase64DecodingIgnoreUnknownCharacters];

    // Create UIImage from NSData
    UIImage *image = [UIImage imageWithData:imageData];

    return image;
}

RCT_EXPORT_METHOD(printBitmap:(NSString *)base64)
{
    UIImage *img = [self imageFromBase64String:base64];

    NSMutableData *dataM = [NSMutableData dataWithData:[POSCommand initializePrinter]];
    [dataM appendData:[POSCommand selectAlignment:1]];
    [dataM appendData:[POSCommand printRasteBmpWithM:RasterNolmorWH andImage:img andType:Dithering]];
    [dataM appendData:[POSCommand printAndFeedForwardWhitN:6]];
    [dataM appendData:[POSCommand selectCutPageModelAndCutpage:1]];
    [_wifiManager writeCommandWithData:dataM];
}

RCT_EXPORT_METHOD(openCashBox)
{
    NSMutableData *dataM = [NSMutableData dataWithData:[POSCommand initializePrinter]];
    [dataM appendData:[POSCommand creatCashBoxContorPulseWithM:0 andT1:30 andT2:255]];
    [_wifiManager writeCommandWithData:dataM];
}


@end
