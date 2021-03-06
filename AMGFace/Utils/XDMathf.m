//
//  XDMathf.m
//  AMGFace
//
//  Created by CmST0us on 2020/4/16.
//  Copyright © 2020 hakura. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import <QuartzCore/QuartzCore.h>
#import <simd/simd.h>
#import "math.h"
#import "XDMathf.h"

@implementation XDMathf

+ (double)repeat:(double)t
          length:(double)length {
    return simd_clamp(t - floor(t / length) * length, 0.0, length);
}

+ (double)deltaAngle:(double)current
              target:(double)target {
    double delta = [[self class] repeat:(target - current)
                                 length:360.f];
    if (delta > 180.f) {
        delta -= 360.f;
    }
    return delta;
}

+ (double)smoothDampAngle:(double)current
                   target:(double)target
          currentVelocity:(double *)currentVelocity
               smoothTime:(double)smoothTime
                 maxSpeed:(double)maxSpeed
                deltaTime:(double)deltaTime {
    target = current + [[self class] deltaAngle:current target:target];
    return [[self class] smoothDamp:current
                             target:target
                    currentVelocity:currentVelocity
                         smoothTime:smoothTime
                           maxSpeed:maxSpeed
                          deltaTime:deltaTime];
}

+ (double)smoothDamp:(double)current
              target:(double)target
     currentVelocity:(double *)currentVelocity
          smoothTime:(double)smoothTime
            maxSpeed:(double)maxSpeed
           deltaTime:(double)deltaTime {
    smoothTime = simd_max((double)0.0001f, smoothTime);
    double omega = 2.f / smoothTime;
    
    double x = omega * deltaTime;
    double exp = 1.f / (1.f + x + 0.48f * x * x + 0.235f * x * x * x);
    double change = current - target;
    double originalTo = target;
    
    /// Clamp maximux speed
    double maxChange = maxSpeed * smoothTime;
    change = simd_clamp(change, -maxChange, maxChange);
    target = current - change;
    
    double temp = (*currentVelocity + omega * change) * deltaTime;
    *currentVelocity = (*currentVelocity - omega * temp) * exp;
    double output = target + (change + temp) * exp;
    
    /// Preevent overshooting
    if (originalTo - current > 0.f == output > originalTo) {
        output = originalTo;
        *currentVelocity = (output - originalTo) / deltaTime;
    }
    
    return output;
}

@end
