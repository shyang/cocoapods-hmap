
## cocoapods-hmap-simple plugin

本插件对`Pods/Target Support Files/*/*.xcconfig` 中的 `HEADER_SEARCH_PATHS` 进行精简：将 `"${PODS_ROOT}/Headers/Public/*"` 合并为一个 hmap 文件。(不包括 `${PODS_ROOT}/Headers/Public` 本身)

前后对比：

![](images/1.png)

对于使用大量 Pod 的项目的编译性能有提升，对于简单项目区别极小。



https://github.com/milend/hmap

```shell
$ hmap print Pods/Headers/hmap/e7b40053fb8fd961c29a9876ca5205e0.hmap
WBHttpRequest.h -> /Users/foo/Example/Pods/Headers/Public/Weibo_SDK/WBHttpRequest.h
WeiboSDK.h -> /Users/foo/Example/Pods/Headers/Public/Weibo_SDK/WeiboSDK.h
```

### 使用

1. 添加 `cocoapods-hmap-simple`
2. Gemfile 添加 `gem 'cocoapods-hmap-simple', :path => 'cocoapods-hmap-simple'`

### tree
```
cocoapods-hmap-simple
├── cocoapods-hmap-simple.gemspec
└── lib
    ├── cocoapods_plugin.rb
    ├── hmap                    (https://github.com/milend/hmap)
    └── hmap_optimize.rb        (hmap generating and injecting)
```

