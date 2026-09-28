// TCDAppItem.m
#import "TCDAppItem.h"

@implementation TCDAppItem

+ (instancetype)itemWithName:(NSString *)name
                   developer:(NSString *)developer
                    category:(NSString *)category
                 accentColor:(NSColor *)color
                    versions:(NSArray *)versions
                 downloadURL:(NSString *)url
{
    TCDAppItem *i      = [[self alloc] init];
    i.name             = name;
    i.developer        = developer;
    i.category         = category;
    i.accentColor      = color;
    i.versions         = versions;
    i.selectedVersion  = versions.firstObject;
    i.downloadURL      = url ?: @"";
    i.downloadState    = TCDDownloadStateIdle;
    i.downloadProgress = 0.0;
    return i;
}

@end
