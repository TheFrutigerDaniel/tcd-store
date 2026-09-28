// TCDCatalogue.m
#import "TCDCatalogue.h"
#import "TCDCatalogueManager.h"

@implementation TCDCatalogue

+ (NSArray *)allItems   { return [TCDCatalogueManager sharedManager].items; }
+ (NSArray *)categories { return [[TCDCatalogueManager sharedManager] categories]; }

@end
