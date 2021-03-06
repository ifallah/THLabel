//
//  THLabel.m
//
//  Version 1.0
//
//  Created by Tobias Hagemann on 11/25/12.
//  Copyright (c) 2012 tobiha.de. All rights reserved.
//
//  Original source and inspiration from:
//  FXLabel by Nick Lockwood,
//  https://github.com/nicklockwood/FXLabel
//  KSLabel by Kai Schweiger,
//  http://www.vigorouscoding.com/2012/02/custom-gradient-uilabel-with-an-outline/
//
//  Distributed under the permissive zlib license
//  Get the latest version from here:
//
//  https://github.com/MuscleRumble/THLabel
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import "THLabel.h"

#ifndef NS_ENUM_AVAILABLE_IOS
typedef enum {
	NSTextAlignmentLeft = UITextAlignmentLeft,
	NSTextAlignmentCenter = UITextAlignmentCenter,
	NSTextAlignmentRight = UITextAlignmentRight
} NSTextAlignment;
#endif

@implementation THLabel

@synthesize shadowBlur = _shadowBlur;
@synthesize strokeSize = _strokeSize, strokeColor = _strokeColor;
@synthesize gradientStartColor = _gradientStartColor, gradientEndColor = _gradientEndColor, gradientColors = _gradientColors, gradientStartPoint = _gradientStartPoint, gradientEndPoint = _gradientEndPoint;
@synthesize textInsets = _textInsets;

#pragma mark -
#pragma mark Accessors and Mutators
- (UIColor *)gradientStartColor {
	return [self.gradientColors count] ? [self.gradientColors objectAtIndex:0] : nil;
}

- (void)setGradientStartColor:(UIColor *)color {
	if (color == nil) {
		self.gradientColors = nil;
	} else if ([self.gradientColors count] < 2) {
		self.gradientColors = [NSArray arrayWithObjects:color, color, nil];
	} else if ([self.gradientColors objectAtIndex:0] != color) {
		NSMutableArray *colors = [self.gradientColors mutableCopy];
		[colors replaceObjectAtIndex:0 withObject:color];
		self.gradientColors = colors;
	}
}

- (UIColor *)gradientEndColor {
	return [self.gradientColors lastObject];
}

- (void)setGradientEndColor:(UIColor *)color {
	if (color == nil) {
		self.gradientColors = nil;
	} else if ([self.gradientColors count] < 2) {
		self.gradientColors = [NSArray arrayWithObjects:color, color, nil];
	} else if ([self.gradientColors lastObject] != color) {
		NSMutableArray *colors = [self.gradientColors mutableCopy];
		[colors replaceObjectAtIndex:[colors count] - 1 withObject:color];
		self.gradientColors = colors;
	}
}

- (void)setGradientColors:(NSArray *)colors {
	if (self.gradientColors != colors) {
		_gradientColors = [colors copy];
		[self setNeedsDisplay];
	}
}

- (void)setTextInsets:(UIEdgeInsets)insets {
	if (!UIEdgeInsetsEqualToEdgeInsets(self.textInsets, insets)) {
		_textInsets = insets;
		[self setNeedsDisplay];
	}
}

#pragma mark -
#pragma mark Drawing
- (void)drawRect:(CGRect)rect {
	// Get everything ready for drawing.
	CGRect contentRect = [self contentRectFromBounds:self.bounds withInsets:self.textInsets];
	CGFloat fontSize = self.font.pointSize;
	CGRect textRect = [self textRectFromContentRect:contentRect actualFontSize:&fontSize];
	UIFont *font = [self.font fontWithSize:fontSize];
	
	// Determine what has to be drawn.
	BOOL hasShadow = self.shadowColor && ![self.shadowColor isEqual:[UIColor clearColor]] && (self.shadowBlur > 0.0f || !CGSizeEqualToSize(self.shadowOffset, CGSizeZero));
	BOOL hasStroke = self.strokeSize > 0 && ![self.strokeColor isEqual:[UIColor clearColor]];
	BOOL hasGradient = [self.gradientColors count] > 1;
	
	// -------
	// Step 1: Begin new drawing context, where we will apply all our styles.
	// -------
	
	UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
	
	// -------
	// Step 2: Draw text normally or with gradient.
	// -------
	
	CGContextSaveGState(context);
	
	if (hasStroke) {
		// Text needs invisible stroke for consistent character glyph widths.
		CGContextSetTextDrawingMode(context, kCGTextFillStroke);
		
		// Stroke width times 2, because we can only draw a centered stroke. We want outer strokes.
		CGContextSetLineWidth(context, self.strokeSize * 2.0f);
		CGContextSetLineJoin(context, kCGLineJoinRound);
		
		// Set invisible stroke.
		[[UIColor clearColor] setStroke];
	} else {
		CGContextSetTextDrawingMode(context, kCGTextFill);
	}
	
	if (!hasGradient) {
		// Set text fill color.
		[self.textColor setFill];
		
		// Draw text.
		[self drawTextInRect:textRect withFont:font];
	} else {
		// -------
		// Step 2a: Create alpha mask for gradient.
		// -------
		
		// Set white color for gradient alpha mask.
		[[UIColor whiteColor] setFill];
		
		// Draw gradient alpha mask.
		[self drawTextInRect:textRect withFont:font];
		
		// Save gradient alpha mask.
		CGImageRef alphaMask = CGBitmapContextCreateImage(context);
		
		// Clear the content.
		CGContextClearRect(context, contentRect);
		
		// -------
		// Step 2b: Draw gradient in clipped mask.
		// -------
		
		// Invert everything, because CG works with an inverted coordinate system.
		CGContextTranslateCTM(context, 0.0f, contentRect.size.height);
		CGContextScaleCTM(context, 1.0f, -1.0f);
		
		// Clip the current context to gradient alpha mask.
		CGContextClipToMask(context, contentRect, alphaMask);
		
		// Invert back to draw the gradient correctly.
		CGContextTranslateCTM(context, 0.0f, contentRect.size.height);
		CGContextScaleCTM(context, 1.0f, -1.0f);
		
		// Get gradient colors as CGColor.
		NSMutableArray *gradientColors = [NSMutableArray arrayWithCapacity:[self.gradientColors count]];
		
		for (UIColor *color in self.gradientColors) {
			[gradientColors addObject:(__bridge id)color.CGColor];
		}
		
		// Create gradient.
		CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
		CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)gradientColors, NULL);
		CGPoint startPoint = CGPointMake(textRect.origin.x + self.gradientStartPoint.x * textRect.size.width,
										 textRect.origin.y + self.gradientStartPoint.y * textRect.size.height);
		CGPoint endPoint = CGPointMake(textRect.origin.x + self.gradientEndPoint.x * textRect.size.width,
									   textRect.origin.y + self.gradientEndPoint.y * textRect.size.height);
		
		// Draw gradient.
		CGContextDrawLinearGradient(context, gradient, startPoint, endPoint, kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
		
		// Clean up, because ARC doesn't handle CG.
		CGColorSpaceRelease(colorSpace);
		CGGradientRelease(gradient);
		CGImageRelease(alphaMask);
	}
	
	CGContextRestoreGState(context);
	
	// -------
	// Step 3: Draw stroke.
	// -------
	
	if (hasStroke) {
		CGContextSaveGState(context);
		
		CGContextSetTextDrawingMode(context, kCGTextStroke);
		
		// Create an image from the text.
		CGImageRef image = CGBitmapContextCreateImage(context);
		
		// Stroke width times 2, because it's a centered stroke. We want outer strokes.
		CGContextSetLineWidth(context, self.strokeSize * 2.0f);
		CGContextSetLineJoin(context, kCGLineJoinRound);
		
		// Set stroke color.
		[self.strokeColor setStroke];
		
		// Draw stroke.
		[self drawTextInRect:textRect withFont:font];
		
		// Invert everything, because CG works with an inverted coordinate system.
		CGContextTranslateCTM(context, 0.0f, contentRect.size.height);
		CGContextScaleCTM(context, 1.0f, -1.0f);
		
		// Draw the saved image over half of the stroke.
		CGContextDrawImage(context, contentRect, image);
		
		// Clean up, because ARC doesn't handle CG.
		CGImageRelease(image);
		
		CGContextRestoreGState(context);
	}
	
	// -------
	// Step 4: Draw shadow.
	// -------
	
	if (hasShadow) {
		CGContextSaveGState(context);
		
		// Create an image from the text.
		CGImageRef image = CGBitmapContextCreateImage(context);
		
		// Clear the content.
		CGContextClearRect(context, contentRect);
		
		// Invert everything, because CG works with an inverted coordinate system.
		CGContextTranslateCTM(context, 0.0f, contentRect.size.height);
		CGContextScaleCTM(context, 1.0f, -1.0f);
		
		// Set shadow attributes.
		CGContextSetShadowWithColor(context, self.shadowOffset, self.shadowBlur, self.shadowColor.CGColor);
		
		// Draw the saved image, which throws off a shadow.
		CGContextDrawImage(context, contentRect, image);
		
		// Clean up, because ARC doesn't handle CG.
		CGImageRelease(image);
		
		CGContextRestoreGState(context);
	}
	
	// -------
	// Step 5: End drawing context and finally draw the text with all styles.
	// -------
	
	UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
	[image drawInRect:rect];
}

- (CGRect)contentRectFromBounds:(CGRect)bounds withInsets:(UIEdgeInsets)insets {
	CGRect contentRect = CGRectMake(0.0f, 0.0f, bounds.size.width, bounds.size.height);
	
	// Apply insets.
	contentRect.origin.x += insets.left;
	contentRect.origin.y += insets.top;
	contentRect.size.width -= insets.left + insets.right;
	contentRect.size.height -= insets.top + insets.bottom;
	
	return contentRect;
}

- (CGRect)textRectFromContentRect:(CGRect)contentRect actualFontSize:(CGFloat *)actualFontSize {
	CGRect textRect = contentRect;
	CGFloat minFontSize;
	
	if ([self respondsToSelector:@selector(minimumScaleFactor)]) {
		minFontSize = self.minimumScaleFactor ? self.minimumScaleFactor * *actualFontSize : *actualFontSize;
	} else {
		minFontSize = self.minimumFontSize ? : *actualFontSize;
	}
	
	// Calculate text rect size.
	if (self.adjustsFontSizeToFitWidth && self.numberOfLines == 1) {
		textRect.size = [self.text sizeWithFont:self.font minFontSize:minFontSize actualFontSize:actualFontSize forWidth:contentRect.size.width lineBreakMode:self.lineBreakMode];
	} else {
		textRect.size = [self.text sizeWithFont:self.font constrainedToSize:contentRect.size lineBreakMode:self.lineBreakMode];
	}
	
	// Horizontal alignment.
	switch (self.textAlignment) {
		case NSTextAlignmentCenter:
			textRect.origin.x = floorf(contentRect.origin.x + (contentRect.size.width - textRect.size.width) / 2.0f);
			break;
			
		case NSTextAlignmentRight:
			textRect.origin.x = floorf(contentRect.origin.x + contentRect.size.width - textRect.size.width);
			break;
			
		default:
			textRect.origin.x = floorf(contentRect.origin.x);
			break;
	}
	
	// Vertical alignment.
	switch (self.contentMode) {
		case UIViewContentModeTop:
		case UIViewContentModeTopLeft:
		case UIViewContentModeTopRight:
			textRect.origin.y = floorf(contentRect.origin.y);
			break;
			
		case UIViewContentModeBottom:
		case UIViewContentModeBottomLeft:
		case UIViewContentModeBottomRight:
			textRect.origin.y = floorf(contentRect.origin.y + contentRect.size.height - textRect.size.height);
			break;
			
		default:
			textRect.origin.y = floorf(contentRect.origin.y + floorf((contentRect.size.height - textRect.size.height) / 2.0f));
			break;
	}
	
	return textRect;
}

- (void)drawTextInRect:(CGRect)rect withFont:(UIFont *)font {
	if (self.adjustsFontSizeToFitWidth && self.numberOfLines == 1 && font.pointSize < self.font.pointSize) {
		CGFloat fontSize = 0.0f;
		[self.text drawAtPoint:rect.origin forWidth:rect.size.width withFont:self.font minFontSize:font.pointSize actualFontSize:&fontSize lineBreakMode:self.lineBreakMode baselineAdjustment:self.baselineAdjustment];
	} else {
		[self.text drawInRect:rect withFont:font lineBreakMode:self.lineBreakMode alignment:self.textAlignment];
	}
}

#pragma mark -
- (void)setDefaults {
	self.gradientStartPoint = CGPointMake(0.5f, 0.2f);
	self.gradientEndPoint = CGPointMake(0.5f, 0.8f);
}

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	
	if (self) {
		self.backgroundColor = [UIColor clearColor];
		
		[self setDefaults];
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	self = [super initWithCoder:aDecoder];
	
	if (self) {
		[self setDefaults];
	}
	
	return self;
}

@end
