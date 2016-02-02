//
//  ActivitySequence.h
//  EMBRACE
//
//  Created by aewong on 1/20/16.
//  Copyright © 2016 Andreea Danielescu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ActivityMode.h"

@interface ActivitySequence : NSObject {
    NSString* bookTitle;
    NSMutableArray* modes; //contains ActivityMode objects for chapters in given book
}

@property (nonatomic, strong) NSString* bookTitle;
@property (nonatomic, strong) NSMutableArray* modes;

- (id) initWithValues:(NSString*)title :(NSMutableArray*)modesArray;

- (ActivityMode*) getModeForChapter:(NSString*)title;

@end
