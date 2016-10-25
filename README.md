# PGFrame
简单App框架
提供一个简单App的设计思路以及功能模块设计。其实完成了以下模块的设计，一个常规的ios app剩下的工作就是根据产品设计稿进行UI布局和一些业务逻辑。
至于UI布局是用手写还是用xib和storyboard，网络上已经有很多介绍了。这里只是介绍app开发过程中一些模块的设计思想。
写的不好的地方，请大神们指导和纠正，一起分享，一起学习，一起进步！！
具体使用介绍请查阅：http://www.jianshu.com/p/2132dc609a86
## 文件结构
http://www.jianshu.com/p/36316b6d7cfa

## 功能使用说明
### 消息弹出提示
```object-c
[self showMsg:@"消息内容"];
```
```object-c
[self showAskAlertTitle:@"标题" message:@"提示的内容" tag:0 action:^(NSInteger alertTag, NSInteger actionIndex) {
        //事件响应
        if(actionIndex == 0) {
            
        } else if(actionIndex == 1) {
            
        }
    } cancelActionTitle:@"取消" otherActionsTitles:@"确定",nil];
```
### 错误提示页面
```object-c
//显示
[self showDataLoadErrorView];
//隐藏
[self hideDataLoadErrorView];
```
```object-c
//显示
[self showNoDataView];
//隐藏
[self hideNoDataRecordView];
```
### 等待框
  可以通过自定义样式，目前只有两种。可以继承PGWaitingView扩展个性化的等待视图。

```object-c
- (void)showWaitingView:(NSString *)text viewStyle:(PGWaitingViewStyle)style {
    if(self.waitingView == nil) {
        if(style == EWaitingViewStyle_Rotation) {
            self.waitingView = [[PGRotaionWaitingView alloc] initWithFrame:CGRectMake(0, 0, PGHeightWith1080(280), PGHeightWith1080(280))];
        } else {
            self.waitingView = [[PGCustomWaitingView alloc] initBgColor:UIColorFromRGBA(0x858585, 0.8) apla:1.0 font:nil textColor:nil activeColor:[UIColor whiteColor]];
            self.waitingView.layer.cornerRadius = 5.0;
        }
    }
    
    UIView *bgView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.viewWidth, self.viewHeight)];
    bgView.backgroundColor = [UIColor clearColor];
    [bgView addSubview:self.waitingView];
    
    [self.view addSubview:bgView];
    
    self.bShowProgressView = YES;
    
    [self.waitingView showText:text];
    self.waitingView.center = self.waitingView.superview.center;
}
```
  调用示例
```object-c  
[self showWaitingView:nil viewStyle:EWaitingViewStyle_Rotation];
```
### 网络请求
    基本上目前市面上所有app都需要有的功能模块，通过网络接口从服务器获取业务数据。
    网络请求模块尽可能与UI界面逻辑分开，在Controller请求数据时尽可能简单。
  * PGHttpClient 封装具体的网络http请求逻辑
  * PGAPI 封装业务相关的接口地址与解析数据入口
  * PGResultObject 接口请求解析完成后返回给View的数据
  * PGEncrypt 封装一些加密操作，如接口签名等
  * PGDataParseManager 接口请求的回来的数据进行解析
  * PGRequestManager 接口请求管理，为所有业务数据请求提供统一的入口

```object-c
  [self showWaitingView:nil viewStyle:EWaitingViewStyle_Rotation];
    
    [PGRequestManager startPostClient:API_TYPE_LOGIN
                                param:@{@"userName":@"name",@"password":@"123456"}
                               target:self
                                  tag:@"login"];
```
  回调处理
```object-c
- (void)dataRequestSuccess:(PGResultObject *)resultObj
{
    [self hideWaitingView];
}

- (void)dataRequestFailed:(PGResultObject *)resultObj
{
    [self hideWaitingView];
    [self showMsg:resultObj.szErrorDes];
}
```

