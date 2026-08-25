# AI 定制训练计划可互动肌肉图文件说明

## 1. 功能入口

AI 定制训练计划页面使用的组件引用位于：

`E:/gymsys/miniprogram/pages/member/ai-generator`

页面文件：

- `index.wxml`：在第二步训练档案中引入 `<muscle-selector>` 组件。
- `index.json`：注册组件 `muscle-selector`。

## 2. 可互动肌肉图组件

组件目录：

`E:/gymsys/miniprogram/components/muscle-selector`

主要文件：

- `index.js`：互动逻辑。根据点击坐标读取蒙版，判断所选肌群，并触发 `change` 事件。
- `index.wxml`：人体图、正面/背面切换、肌群选中状态等界面结构。
- `index.wxss`：人体图和选择器的样式。
- `index.json`：组件配置。

## 3. 肌肉图 SVG 资源

资源目录：

`E:/gymsys/miniprogram/assets/muscle-selector`

该目录包含：

- 男女正面基础图：`male-front-base.svg`、`female-front-base.svg`
- 男女背面基础图：`male-back-base.svg`、`female-back-base.svg`
- 各肌群叠加图：胸部、腹部、背部、三角肌、肱二头肌、肱三头肌、前臂、股四头肌、腘绳肌、小腿、臀部等 SVG 文件
- `manifest.js`：基础图和各肌群叠加图的文件映射配置
- `masks.js`：点击区域蒙版数据，用于判断用户点击的人体部位

组件通过以下路径加载资源：

`/assets/muscle-selector/<文件名>`


## 5. 肌群名称和业务映射

肌群中文名称及训练计划使用的标识定义在：

`E:/gymsys/miniprogram/utils/training-profile.js`

互动组件通过该文件中的 `MUSCLE_LABELS` 过滤和显示可选肌群。

## 6. 文件关系

```text
pages/member/ai-generator/index.wxml
              │
              └── components/muscle-selector/index
                            │
                            ├── assets/muscle-selector/manifest.js
                            ├── assets/muscle-selector/masks.js
                            └── assets/muscle-selector/*.svg
                                         │
                                         └── utils/training-profile.js
                                             （肌群名称和业务标识）
```

如果要修改可点击区域，优先修改 `masks.js`；如果要替换人体图或肌群选中效果，修改 `assets/muscle-selector` 下对应的 SVG 和 `manifest.js`；如果要修改选择交互逻辑，修改 `components/muscle-selector/index.js`。