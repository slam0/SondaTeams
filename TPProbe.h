#import <Foundation/Foundation.h>

/* Silnik testu: wykonuje po kolei zapytania HTTPS i zbiera raport tekstowy. */

typedef void (^TPLogBlock)(NSString *text);     /* wywoływane na głównym wątku, dopisuje fragment raportu */
typedef void (^TPDoneBlock)(void);

@interface TPProbe : NSObject
- (void)runWithLog:(TPLogBlock)log done:(TPDoneBlock)done;
@property (nonatomic, readonly) BOOL running;
@end
