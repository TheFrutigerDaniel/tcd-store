// TCDCatalogue.h
// Thin compatibility shim — delegates to TCDCatalogueManager.
// Kept so existing call sites don't need changing.
#import <Foundation/Foundation.h>

@interface TCDCatalogue : NSObject
+ (NSArray *)allItems;
+ (NSArray *)categories;
@end
