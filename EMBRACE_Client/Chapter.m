//
//  Chapter.m
//  EMBRACE_Client
//
//  Created by Andreea Danielescu on 6/5/13.
//  Copyright (c) 2013 Andreea Danielescu. All rights reserved.
//

#import "Chapter.h"

@interface Chapter()

@property (nonatomic, strong) NSMutableDictionary *embraceAudio;
@property (nonatomic, strong) NSMutableDictionary *controlAudio;

@end

@implementation Chapter

@synthesize title;
@synthesize chapterTitlePage;
@synthesize chapterImagePath;
@synthesize chapterId;
@synthesize content;
@synthesize activities;
@synthesize pageNum;

- (id) init {
    if (self = [super init]) {
        activities = [[NSMutableArray alloc] init];
        content = [[NSMutableArray alloc] init];
    }
    
    return self;
}

-(void) addActivity:(Activity*)activity {
    [activities addObject:activity];
}

-(Activity*) getActivityOfType:(Mode) mode {
    for(Activity* activity in activities) {
        if((mode == PM_MODE) && ([activity isKindOfClass:[PhysicalManipulationActivity class]]))
            return activity;
        else if((mode == IM_MODE) && ([activity isKindOfClass:[ImagineManipulationActivity class]]))
            return activity;
    }
    return nil;
}

-(NSString*) getNextPageForMode:(Mode) mode :(NSString*)currentPage {
    for(Activity* activity in activities) {
        if((mode == PM_MODE) && ([activity isKindOfClass:[PhysicalManipulationActivity class]])) {
            return [self getNextPageInActivity:activity :currentPage];
        }
        else if(mode == IM_MODE && ([activity isKindOfClass:[ImagineManipulationActivity class]])) {
            return [self getNextPageInActivity:activity :currentPage];
        }
    }
    
    return nil;
}

-(NSString*) getNextPageInActivity:(Activity* )activity :(NSString* )currentPage {
    NSMutableArray* pages = [activity pages];
    
    //If we're loading the first page.
    if(currentPage == nil) {
        //NSLog(@"current Page is nil");
        return [[pages objectAtIndex:0] pagePath];
    }
    
    //NSLog(@"current page is not nil...looking for next page");
    
    for(int i = 0; i < [pages count]; i ++) {
        Page* page = [pages objectAtIndex:i];
        
        //if we've found the current page, we can return the next page, if there is a next page.
        if([[page pagePath] isEqualToString:currentPage]) {
            if(i < [pages count] - 1)
                return [[pages objectAtIndex:i + 1] pagePath];
        }
    }
    
    return nil;
}


- (void)addEmbraceScript:(ScriptAudio *)script forSentence:(NSString *)sentenceId {
    if (self.embraceAudio == nil) {
        self.embraceAudio = [NSMutableDictionary dictionary];
    }
    [self.embraceAudio setObject:script forKey:sentenceId];
    
}
- (void)addControlScript:(ScriptAudio *)script forSentence:(NSString *)sentenceId {
    if (self.controlAudio == nil) {
        self.controlAudio = [NSMutableDictionary dictionary];
    }
    [self.controlAudio setObject:script forKey:sentenceId];
}

- (ScriptAudio *)embraceScriptFor:(NSString *)sentenceId {
    if (self.embraceAudio) {
        return [self.embraceAudio objectForKey:sentenceId];
    }
    return nil;
}

- (ScriptAudio *)controlScriptFor:(NSString *)sentenceId {
    if (self.controlAudio) {
        return [self.controlAudio objectForKey:sentenceId];
    }
    return nil;
}

@end
