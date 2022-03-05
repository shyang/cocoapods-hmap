//
//  ViewController.m
//  Example
//
//  Created by shaohua on 2022/3/5.
//

#import <Masonry/Masonry.h>

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.greenColor;

    [self.view mas_makeConstraints:^(MASConstraintMaker *make) {
    }];
}


@end
