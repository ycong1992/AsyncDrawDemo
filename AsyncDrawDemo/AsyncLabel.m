//
//  AsyncLabel.m
//  AsyncDrawDemo
//
//  Created by SZOeasy on 2020/8/10.
//  Copyright © 2020 ycong. All rights reserved.
//

#import "AsyncLabel.h"
#import <CoreText/CoreText.h>
#import <YYAsyncLayer/YYAsyncLayer.h>

@implementation AsyncLabel

/**
 主要处理流程如下：
 1)在主线程的runLoop中注册一个observer，它的优先级要比系统的CATransaction要低，保证系统先做完必须的工作
 2)把需要异步绘制的操作集中起来。比如设置字体、颜色、背景这些，不是设置一个就绘制一个，把他们都收集起来，runloop会在observer需要的时机通知统一处理
 3)处理时机到时，执行异步绘制，并在主线程中把绘制结果传递给layer.contents

 */

- (void)setText:(NSString *)text {
    _text = text.copy;
    [[YYTransaction transactionWithTarget:self selector:@selector(contentsNeedUpdated)] commit];
}

- (void)setFont:(UIFont *)font {
    _font = font;
    [[YYTransaction transactionWithTarget:self selector:@selector(contentsNeedUpdated)] commit];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [[YYTransaction transactionWithTarget:self selector:@selector(contentsNeedUpdated)] commit];
}

- (void)contentsNeedUpdated {
    // do update
    [self.layer setNeedsDisplay];
}

#pragma mark - YYAsyncLayer

+ (Class)layerClass {
    return YYAsyncLayer.class;
}

- (YYAsyncLayerDisplayTask *)newAsyncDisplayTask {
    
    YYAsyncLayerDisplayTask *task = [YYAsyncLayerDisplayTask new];
    task.willDisplay = ^(CALayer *layer) {
        //...
    };
    
    task.display = ^(CGContextRef context, CGSize size, BOOL(^isCancelled)(void)) {
        if (isCancelled()) return;
        if (!self.text.length) return;
        [self draw:context size:size];
//        UIGraphicsBeginImageContextWithOptions(size, NO, [UIScreen mainScreen].scale);
//        CGContextRef context1 = UIGraphicsGetCurrentContext();
//        [self draw:context1 size:size];
    };
    
    task.didDisplay = ^(CALayer *layer, BOOL finished) {
        if (finished) {
            // finished
        } else {
            // cancelled
        }
    };
    
    return task;
}

//- (void)displayLayer:(CALayer *)layer {
//    NSLog(@"Current Thread : %d", [[NSThread currentThread] isMainThread]);
//    // 最好自创队列
//    dispatch_async(dispatch_get_global_queue(0, 0), ^{
//        __block CGSize size = CGSizeZero;
//        __block CGFloat scale = 1.0;
//        dispatch_sync(dispatch_get_main_queue(), ^{
//            size = self.bounds.size;
//            scale = [UIScreen mainScreen].scale;
//        });
//        UIGraphicsBeginImageContextWithOptions(size, NO, scale);
//        CGContextRef context = UIGraphicsGetCurrentContext();
//
//        [self draw:context size:size];
//
//        UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
//        UIGraphicsEndImageContext();
//        dispatch_async(dispatch_get_main_queue(), ^{
//            self.layer.contents = (__bridge id)(image.CGImage);
//       });
//    });
//}

- (void)draw:(CGContextRef)context size:(CGSize)size {
    //将坐标系上下翻转。因为底层坐标系和UIKit的坐标系原点位置不同。
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    CGContextTranslateCTM(context, 0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);

    CGMutablePathRef path = CGPathCreateMutable();
    CGPathAddRect(path, NULL, CGRectMake(0, 0, size.width, size.height));

    //设置内容
    NSMutableAttributedString * attString = [[NSMutableAttributedString alloc] initWithString:self.text];
    //设置字体
    [attString addAttribute:NSFontAttributeName value:self.font range:NSMakeRange(0, self.text.length)];

    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)attString);
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attString.length), path, NULL);

    //把frame绘制到context里
    CTFrameDraw(frame, context);
}

@end
