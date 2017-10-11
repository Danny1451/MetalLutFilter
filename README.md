# MetalDemo

> 语言 Objective-C

**注意的 Metal 必须在真机上运行，并且至少要是 A7 处理器，就是 5s 或者以上。**

该 Demo 为简单的视频实时滤镜，点击右下角 video 按钮开启摄像头，上面两个按钮切换滤镜，手指滑动屏幕控制滤镜范围。

详见

- [1. Metal 基本介绍]()
- [2. Metal 渲染流程]()
- [3. Metal 图像滤镜]()
- [4. Metal 优化最佳实践]()


在 VC 的如下方法中，切换是否自己控制加完滤镜后的渲染。

```
- (void)drawInMTKView:(MTKView *)view{

    

    if (self.videoTexture != nil) {

        

        //custm render

        [self render:self.videoTexture];

        //metalview  render

//        [self systemDrawableRender:self.videoTexture];

    }

}

```

