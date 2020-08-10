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
 https://www.jianshu.com/p/6634dbdf2964
 https://www.jianshu.com/p/154451e4bd42
 核心思想：
 CoreGraphics 框架可以通过图片上下文将绘制内容制作为一张位图，并且这个操作可以在非主线程执行。那么，当有 n 个绘制任务时，可以开辟多个线程在后台异步绘制，绘制成功拿到位图回到主线程赋值给 CALayer 的寄宿图属性。

 主要处理流程如下：
 1)在主线程的runLoop中注册一个observer，它的优先级要比系统的CATransaction要低，保证系统先做完必须的工作
 2)把需要异步绘制的操作集中起来。比如设置字体、颜色、背景这些，不是设置一个就绘制一个，把他们都收集起来，runloop会在observer需要的时机通知统一处理(通过NSMutableSet存储对应的view或layer对象，对同一对象的字体颜色等设置时，由于是同一对象，所以会被集中成一个)
 3)处理时机到时，执行异步绘制，并在主线程中把绘制结果传递给layer.contents

 备注：
 1）YYTransaction 类重写了 hash 算法，将_selector和_target的内存地址进行一个位异或处理，意味着只要_selector和_target地址都相同时，hash 值就相同。这样做的原因是避免重复，将同一runloop周期内的target和selector统一为一个处理
 2）在绘制每一行文本前，都会调用 isCancelled() 来进行判断，保证被取消的任务能及时退出，不至于影响后续操作(在提交重绘请求时，计数器加一)
 3）YYAsyncLayer使用YYDispatchQueuePool为不同优先级创建和 CPU 数量相同的 serial queue，每次从 pool 中获取 queue 时，会轮询返回其中一个 queue。我把 App 内所有异步操作，包括图像解码、对象释放、异步绘制等，都按优先级不同放入了全局的 serial queue 中执行，这样尽量避免了过多线程导致的性能问题。
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
