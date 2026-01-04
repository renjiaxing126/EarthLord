# 产品需求文档 (PRD): 《地球新主》

**文档版本**: 1.0
**项目代号**: EarthLord
**目标平台**: iOS (首发)
**目标阶段**: Phase 1 - 孤独的开拓者 (The Lone Reclaimer)
**最后更新**: 2026年1月

---

## 1. 概述

### 1.1 项目背景

《地球新主》是一款基于GPS的末世题材户外策略游戏。在2048年"终末战争"后的世界,玩家作为幸存者,通过在现实世界中步行来圈占虚拟土地,收集资源,建立定居点,最终重建人类文明。

本文档定义了《地球新主》第一阶段(MVP)的功能需求。此阶段的核心目标是验证游戏**"探索 → 圈地 → 建设 → 生存"**的核心循环。

### 1.2 目标阶段说明

**Phase 1 核心目标**:
- 验证圈地系统的可玩性和公平性
- 建立基础的资源-建造循环
- 实现单人游戏体验的完整闭环
- 为后续多人互动打好技术基础

**不包含** (将在后续Phase实现):
- 联盟系统
- 玩家对玩家(PVP)战斗
- 复杂的社交功能
- 内购系统
- Android版本

### 1.3 成功指标 (KPIs)

| 指标 | 目标值 | 测量方式 |
|------|--------|----------|
| D1留存率 | >35% | Firebase Analytics |
| D7留存率 | >15% | Firebase Analytics |
| 核心循环参与率 | >50% DAU执行过"圈地"操作 | 自定义埋点 |
| 新手转化率 | >70%新用户在3天内成功建造"庇护所" | 漏斗分析 |
| 技术稳定性 | 崩溃率 <0.5% | Xcode Organizer |
| 服务器响应时间 | 圈地验证 <500ms | Supabase Dashboard |

---

## 2. 目标用户与场景

### 2.1 用户画像

#### 用户画像 1: "户外探索者 Alex"
- **年龄**: 28岁
- **职业**: 软件工程师
- **特征**:
  - 喜欢Pokemon GO等LBS游戏
  - 每天步行通勤30分钟
  - 对末世题材有兴趣
- **需求**: 寻找有深度的LBS游戏,不只是简单收集

#### 用户画像 2: "策略游戏爱好者 Sarah"
- **年龄**: 24岁
- **职业**: 设计师
- **特征**:
  - 玩过文明系列、Settlers等建造策略游戏
  - 喜欢有长期发展目标的游戏
  - 愿意为游戏付费
- **需求**: 希望在移动端体验有策略深度的建造游戏

#### 用户画像 3: "健身激励者 Mike"
- **年龄**: 32岁
- **职业**: 市场营销
- **特征**:
  - 希望通过游戏激励自己多运动
  - 喜欢可视化的成就感
  - 社交驱动
- **需求**: 将日常行走转化为游戏成就

### 2.2 核心场景

#### 场景 1: 通勤时圈地
> **场景描述**: Alex每天早上步行20分钟去地铁站。他打开《地球新主》,开启"开拓模式",沿着平时的路线走,并在到达地铁站后绕回起点,形成一个闭环。App验证成功后,这块约0.5平方公里的区域成为了他的领地。

**涉及功能**:
- GPS轨迹记录
- 实时路径预览
- 领地验证
- 地图可视化

#### 场景 2: 周末探索废墟
> **场景描述**: Sarah计划周末去附近的公园探索。她在地图上看到公园内有一个"医院废墟"标记。到达后,她执行"搜刮"操作,获得了"废料x5"和"医疗用品x2"。这些资源将用于建造她的第一个庇护所。

**涉及功能**:
- POI(兴趣点)显示
- 探索/搜刮系统
- 资源获取
- 物品背包管理

#### 场景 3: 建立定居点
> **场景描述**: Mike已经圈了一块0.8平方公里的领地。他打开建造菜单,选择在领地中心放置"庇护所"。系统显示需要"废料x10,木材x5",他的资源足够。建造开始,预计2小时后完成。完成后,庇护所每小时为他生产"水x2"。

**涉及功能**:
- 建筑放置系统
- 资源消耗
- 建造时间机制
- 资源生产系统

---

## 3. 功能需求列表

### 3.1 用户账户系统

**需求ID**: F-001
**优先级**: P0 (必须)

#### 功能描述
提供基于Apple ID和邮箱/密码的注册登录。创建唯一的玩家昵称和基础个人资料。

#### 技术栈
- Supabase Auth
- Apple Sign In (iOS SDK)

#### 详细需求
1. **注册流程**:
   - 支持Apple Sign In(推荐)
   - 支持邮箱+密码注册
   - 用户名唯一性验证(3-20字符,字母数字下划线)
   - 首次登录引导教程

2. **登录流程**:
   - 自动登录(保持会话)
   - 支持退出登录
   - 密码重置功能

3. **用户资料**:
   - 昵称
   - 头像(初期使用系统默认)
   - 注册时间
   - 最后登录时间

#### 验收标准 (AC)
- [ ] 新用户可以通过Apple ID在30秒内完成注册
- [ ] 用户名重复时显示友好提示
- [ ] 退出后重新打开App自动登录
- [ ] 密码重置邮件5分钟内送达

#### 依赖项
无

---

### 3.2 核心玩法: 圈地与领土系统

**需求ID**: F-002
**优先级**: P0 (必须)

#### 功能描述
玩家通过"开拓模式"记录不自相交的步行闭环路径。服务器验证路径后,生成归属玩家的领地多边形。

#### 技术栈
- 客户端: Core Location (CLLocationManager)
- 服务端: Supabase Edge Function + PostGIS

#### 详细需求

##### 3.2.1 开拓模式启动
- 用户点击"开始开拓"按钮
- App请求"始终允许"位置权限
- 开始记录GPS轨迹点(每5秒一个点)
- 实时在地图上绘制路径线(蓝色)
- 显示当前行走距离、时间、平均速度

##### 3.2.2 路径记录规则
- **采样频率**: 每5秒记录一个GPS点
- **精度要求**: 水平精度 <20米的点才记录
- **速度限制**: 平均速度 <15km/h (防止开车作弊)
- **最小点数**: 至少20个有效点
- **闭环判定**: 起点和终点直线距离 <20米

##### 3.2.3 路径验证 (服务端)
服务器端Edge Function执行以下验证:

1. **自相交检测**: 使用PostGIS `ST_IsSimple()` 检查路径不自相交
2. **领地碰撞检测**: 使用 `ST_Intersects()` 检查是否与现有领地相交
3. **路径碰撞检测**: 检查是否与其他玩家的活跃路径相交
4. **面积限制**:
   - 最小面积: 10,000㎡ (0.01km²)
   - 最大面积: 5,000,000㎡ (5km²)
5. **速度验证**:
   - 计算相邻点间的速度
   - 任一段速度 >30km/h 则拒绝

##### 3.2.4 领地创建
验证通过后:
- 生成 `GEOMETRY(Polygon)` 存入 `territories` 表
- 计算并存储面积(平方米)
- 设置状态为 `pending` (待开发)
- 在地图上高亮显示(金色边界)
- 显示领地详情页面

##### 3.2.5 领地时效性
- **新圈领地**: 状态为 `pending`, 1个月内必须开始开发
- **开发中**: 至少建造1个建筑后, 状态变为 `developing`
- **活跃领地**: 有3个以上建筑, 状态为 `active`
- **回收机制**:
  - `pending` 状态超过30天 → 警告
  - 超过40天 → 自动回收
  - 玩家7天未登录 → 所有领地暂停生产

#### 数据模型

```sql
CREATE TABLE territories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    area GEOMETRY(Polygon, 4326),
    area_sqm FLOAT GENERATED ALWAYS AS (ST_Area(area::geography)) STORED,
    status VARCHAR(20) DEFAULT 'pending', -- pending, developing, active, expired
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    first_developed_at TIMESTAMP WITH TIME ZONE,
    last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_territories_area ON territories USING GIST(area);
CREATE INDEX idx_territories_user_id ON territories(user_id);
```

#### 验收标准 (AC)
- [ ] 用户可以成功圈占一块0.5km²的领地(正常步行)
- [ ] 开车模拟的路径被正确拒绝(速度验证)
- [ ] 与现有领地重叠的路径被拒绝
- [ ] 自相交的路径(8字形)被拒绝
- [ ] 领地在地图上正确显示边界和面积
- [ ] 服务器验证响应时间 <500ms

#### 依赖项
- F-001 用户账户系统
- F-005 地图显示系统

---

### 3.3 探索与搜刮系统

**需求ID**: F-003
**优先级**: P0 (必须)

#### 功能描述
玩家可以探索地图上的POI(废墟),在物理接近后执行"搜刮"操作获得随机资源。

#### 详细需求

##### 3.3.1 POI类型
| POI类型 | 掉落资源 | 稀有度 | 刷新时间 |
|---------|---------|--------|----------|
| 住宅废墟 | 废料, 木材 | 常见 | 6小时 |
| 医院废墟 | 医疗用品, 电子元件 | 稀有 | 12小时 |
| 工厂废墟 | 金属, 电子元件 | 稀有 | 12小时 |
| 超市废墟 | 食物, 水 | 常见 | 6小时 |
| 军事设施废墟 | 高级材料, 武器零件 | 极稀有 | 24小时 |

##### 3.3.2 POI生成规则
- 基于真实世界POI数据(Apple Maps POI)
- 服务器在初始化时为每个城市生成固定POI
- POI位置不变,但资源会刷新

##### 3.3.3 搜刮流程
1. **发现**: 玩家在地图上看到POI图标(不同类型不同图标)
2. **接近**: 物理距离 <50米时,"搜刮"按钮激活
3. **搜刮**: 点击按钮,播放3秒动画
4. **奖励**: 随机获得2-5个物品
5. **冷却**: 该POI进入冷却期(根据类型6-24小时)

##### 3.3.4 掉落机制
- 使用加权随机算法
- 基础掉落率: 常见资源70%, 稀有资源25%, 极稀有5%
- 掉落数量: 2-5个物品(正态分布,均值3.5)

##### 3.3.5 每日探索限制
- 免费用户: 每天20次搜刮机会
- 订阅用户: 无限次(后续Phase)

#### 数据模型

```sql
CREATE TABLE ruins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ruin_type VARCHAR(50), -- residence, hospital, factory, etc.
    location GEOMETRY(Point, 4326),
    name VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE scavenge_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    ruin_id UUID REFERENCES ruins(id),
    scavenged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    items_gained JSONB -- [{item_id: "scrap", quantity: 5}, ...]
);

CREATE INDEX idx_scavenge_log_user_ruin ON scavenge_log(user_id, ruin_id);
```

#### 验收标准 (AC)
- [ ] 玩家可以在地图上看到附近1km内的所有POI
- [ ] 距离>50米时,"搜刮"按钮显示为灰色
- [ ] 距离<50米时,"搜刮"按钮激活,点击后成功获得物品
- [ ] 搜刮后该POI在冷却期内显示倒计时
- [ ] 达到每日限制后显示友好提示
- [ ] 掉落物品自动加入背包

#### 依赖项
- F-001 用户账户系统
- F-004 物品与背包系统
- F-005 地图显示系统

---

### 3.4 物品与背包系统

**需求ID**: F-004
**优先级**: P0 (必须)

#### 功能描述
管理玩家的所有资源和物品,提供查看、使用、丢弃功能。

#### 详细需求

##### 3.4.1 物品类型

**基础资源** (用于建造):
- 废料 (Scrap)
- 木材 (Wood)
- 金属 (Metal)
- 电子元件 (Electronics)
- 医疗用品 (Medical Supplies)
- 食物 (Food)
- 水 (Water)

**高级材料** (Phase 2):
- 稀有金属
- 芯片
- 燃料

##### 3.4.2 背包容量
- 免费用户: 100格
- 订阅用户: 200格 (Phase 2)
- 单格可堆叠: 相同物品最多堆叠999

##### 3.4.3 背包界面
- 列表视图: 显示所有物品,数量,图标
- 筛选功能: 按类型筛选(资源/消耗品/材料)
- 排序功能: 按名称/数量/获得时间
- 详情页面: 点击物品查看描述和用途

##### 3.4.4 物品操作
- **使用**: 消耗品可直接使用(Phase 2)
- **丢弃**: 长按物品 → 选择数量 → 确认丢弃
- **转移**: 建造时自动从背包扣除

#### 数据模型

```sql
CREATE TABLE items (
    id VARCHAR(50) PRIMARY KEY, -- scrap, wood, metal, etc.
    name VARCHAR(100),
    description TEXT,
    category VARCHAR(50), -- resource, consumable, material
    icon_url VARCHAR(255),
    max_stack INT DEFAULT 999
);

CREATE TABLE user_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    item_id VARCHAR(50) REFERENCES items(id),
    quantity INT DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, item_id)
);

CREATE INDEX idx_user_inventory_user ON user_inventory(user_id);
```

#### 验收标准 (AC)
- [ ] 玩家可以在背包中查看所有物品和数量
- [ ] 筛选和排序功能正常工作
- [ ] 物品超过背包容量时无法拾取,显示提示
- [ ] 丢弃物品后数量正确减少
- [ ] 建造建筑时资源正确扣除

#### 依赖项
- F-001 用户账户系统

---

### 3.5 地图显示系统

**需求ID**: F-005
**优先级**: P0 (必须)

#### 功能描述
使用Apple MapKit显示真实世界地图,叠加游戏元素(领地、POI、建筑等)。

#### 技术栈
- Apple MapKit
- 自定义Overlay和Annotation

#### 详细需求

##### 3.5.1 地图样式
- **基础地图**: Apple Maps标准地图
- **地图模式**:
  - 标准模式(默认)
  - 卫星模式
  - 混合模式
- **末日滤镜**: 降低饱和度20%,增加灰度感

##### 3.5.2 地图图层 (从下到上)
1. **基础地图层**: Apple Maps
2. **其他玩家领地层**: 半透明灰色多边形
3. **当前玩家领地层**: 金色边界,半透明填充
4. **POI标记层**: 不同类型不同图标
5. **建筑标记层**: 玩家建筑图标
6. **当前路径层**: 实时绘制的蓝色轨迹线

##### 3.5.3 交互功能
- **缩放**: 支持双指缩放(最大缩放到建筑级别)
- **平移**: 支持拖动
- **定位**: "定位"按钮,回到当前GPS位置
- **图层切换**: 可以隐藏/显示不同图层
- **点击事件**:
  - 点击领地 → 显示领地详情
  - 点击POI → 显示POI信息和搜刮按钮
  - 点击建筑 → 显示建筑详情

##### 3.5.4 性能优化
- 只加载可视区域的领地和POI
- 缩放级别较小时合并显示密集POI
- 使用Overlay而非大量Annotation

#### 验收标准 (AC)
- [ ] 地图流畅加载,无明显卡顿
- [ ] 玩家领地正确显示边界和填充
- [ ] POI图标清晰可辨,点击响应正常
- [ ] 开拓模式下实时路径绘制流畅
- [ ] 定位功能准确(<50米误差)

#### 依赖项
- F-002 圈地系统(提供领地数据)
- F-003 探索系统(提供POI数据)
- F-006 建造系统(提供建筑数据)

---

### 3.6 建造系统

**需求ID**: F-006
**优先级**: P0 (必须)

#### 功能描述
玩家在自己的领地内放置建筑,消耗资源并等待建造时间,建筑完成后提供各种增益。

#### 详细需求

##### 3.6.1 建筑类型 (Phase 1)

| 建筑名称 | 所需资源 | 建造时间 | 功能 | 占地面积 |
|---------|---------|---------|------|----------|
| 庇护所 | 废料x10, 木材x5 | 2小时 | 提供基础居住,生产水x2/小时 | 100㎡ |
| 仓库 | 木材x15, 金属x5 | 3小时 | 背包容量+50 | 200㎡ |
| 工作台 | 废料x20, 金属x10 | 4小时 | 解锁物品合成功能 | 50㎡ |
| 发电机 | 金属x30, 电子元件x10 | 6小时 | 提供电力,加快其他建筑速度+20% | 150㎡ |
| 瞭望塔 | 木材x25, 金属x15 | 5小时 | POI探索范围+500米 | 50㎡ |

##### 3.6.2 建造流程
1. **选择位置**:
   - 只能在自己的领地内建造
   - 点击地图空白处,选择"放置建筑"
   - 位置不能与现有建筑重叠
   - 显示建筑占地预览(半透明圆形)

2. **选择建筑类型**:
   - 弹出建筑菜单
   - 显示每种建筑的图标、名称、所需资源、建造时间
   - 灰显资源不足的建筑

3. **确认建造**:
   - 显示确认对话框
   - 扣除资源
   - 开始倒计时

4. **建造中**:
   - 地图上显示"建造中"图标(灰色+进度条)
   - 可以在建筑详情页查看剩余时间
   - Phase 2支持加速(消耗道具或付费)

5. **建造完成**:
   - 推送通知提醒
   - 图标变为彩色完整图标
   - 开始发挥功能

##### 3.6.3 建筑升级 (Phase 2)
- 每个建筑可升级到3级
- 升级提升产出或效果

##### 3.6.4 建筑拆除
- 长按建筑 → 拆除
- 返还50%资源
- 立即完成

#### 数据模型

```sql
CREATE TABLE building_types (
    id VARCHAR(50) PRIMARY KEY, -- shelter, warehouse, etc.
    name VARCHAR(100),
    description TEXT,
    required_resources JSONB, -- [{item_id: "scrap", quantity: 10}, ...]
    build_time_seconds INT,
    production JSONB, -- [{item_id: "water", quantity: 2, per_hours: 1}, ...]
    effect JSONB, -- {type: "inventory_boost", value: 50}
    area_sqm FLOAT
);

CREATE TABLE buildings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    territory_id UUID REFERENCES territories(id),
    building_type_id VARCHAR(50) REFERENCES building_types(id),
    location GEOMETRY(Point, 4326),
    status VARCHAR(20) DEFAULT 'building', -- building, active, destroyed
    level INT DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    last_collected_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_buildings_territory ON buildings(territory_id);
CREATE INDEX idx_buildings_user ON buildings(user_id);
```

#### 验收标准 (AC)
- [ ] 玩家可以在自己的领地内成功放置建筑
- [ ] 资源不足时无法建造,显示提示
- [ ] 建筑位置重叠时无法放置
- [ ] 建造倒计时准确显示
- [ ] 建造完成后建筑正常发挥功能(如庇护所生产水)
- [ ] 拆除建筑正确返还资源

#### 依赖项
- F-002 圈地系统(提供领地)
- F-004 物品系统(资源消耗和生产)
- F-005 地图系统(建筑显示)

---

### 3.7 资源生产与收集系统

**需求ID**: F-007
**优先级**: P1 (重要)

#### 功能描述
某些建筑(如庇护所、发电机)可以持续生产资源,玩家需要定期收集。

#### 详细需求

##### 3.7.1 生产机制
- 每个生产建筑有独立的生产队列
- 按小时计算产出
- 最多储存24小时产出(超过则停止生产)

##### 3.7.2 收集流程
- 点击建筑 → 查看可收集资源
- 点击"收集"按钮 → 资源加入背包
- 显示"已收集"动画

##### 3.7.3 离线生产
- 玩家离线期间建筑继续生产
- 最多累计24小时
- 登录时自动计算并显示"离线收益"

#### 验收标准 (AC)
- [ ] 建筑完成后立即开始生产
- [ ] 产出计算准确(如庇护所2小时产4个水)
- [ ] 24小时上限正确生效
- [ ] 离线收益计算准确

#### 依赖项
- F-006 建造系统

---

### 3.8 新手引导系统

**需求ID**: F-008
**优先级**: P0 (必须)

#### 功能描述
首次登录的新用户通过分步教程学习核心玩法。

#### 详细需求

##### 3.8.1 引导流程
1. **欢迎动画**: 播放末世背景故事(30秒,可跳过)
2. **教程步骤**:
   - 步骤1: 了解地图界面
   - 步骤2: 开启开拓模式,完成第一次圈地(引导去附近公园绕一圈)
   - 步骤3: 探索一个POI,获得第一批资源
   - 步骤4: 在领地内建造第一个庇护所
   - 步骤5: 收集庇护所产出的水
3. **完成奖励**: 赠送"新手礼包"(废料x50, 木材x30, 医疗用品x5)

##### 3.8.2 UI引导
- 使用高亮蒙版突出当前操作区域
- 箭头指示和文字说明
- 用户完成操作后自动进入下一步
- 右上角"跳过"按钮(仅限老玩家)

#### 验收标准 (AC)
- [ ] 100%新用户触发引导
- [ ] 引导步骤逻辑清晰,不会卡住
- [ ] 跳过后不再显示
- [ ] 完成引导后解锁成就"幸存者的第一步"

#### 依赖项
- F-002, F-003, F-004, F-005, F-006 (所有核心系统)

---

### 3.9 通讯系统 (无线电)

**需求ID**: F-009
**优先级**: P1 (重要)

#### 功能描述
玩家可以通过"无线电"功能与附近玩家或全频道玩家交流。

#### 详细需求

##### 3.9.1 频道类型
- **本地频道**: 3km范围内的玩家
- **区域频道**: 30km范围内(订阅用户解锁)
- **全球频道**: 所有玩家(Phase 2)

##### 3.9.2 消息功能
- 文字消息(最多200字符)
- 预设快捷语句("需要帮助", "这里有资源", "小心附近")
- 位置标记分享(可选)

##### 3.9.3 反作弊与审核
- 敏感词过滤
- 举报功能
- 频率限制(10秒内最多1条消息)

#### 数据模型

```sql
CREATE TABLE radio_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id),
    channel VARCHAR(50), -- local, regional, global
    message TEXT,
    location GEOMETRY(Point, 4326), -- 发送者位置
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_radio_messages_channel_time ON radio_messages(channel, created_at DESC);
CREATE INDEX idx_radio_messages_location ON radio_messages USING GIST(location);
```

#### 验收标准 (AC)
- [ ] 玩家可以在本地频道看到3km内其他玩家消息
- [ ] 发送消息成功,实时显示
- [ ] 敏感词被正确过滤
- [ ] 频率限制正常工作

#### 依赖项
- F-001 用户系统
- F-005 地图系统(位置标记)

---

### 3.10 成就系统

**需求ID**: F-010
**优先级**: P2 (可选)

#### 功能描述
追踪玩家的里程碑,解锁成就获得奖励。

#### 详细需求

##### 3.10.1 成就类别

**探索类**:
- "幸存者的第一步": 完成第一次圈地
- "开拓先锋": 累计圈地面积达到10km²
- "废土行者": 步行累计100km

**建造类**:
- "重建之始": 建造第一个庇护所
- "城市建设者": 拥有10个建筑
- "文明之光": 建造所有类型建筑各1个

**探索类**:
- "拾荒者": 搜刮100次POI
- "宝藏猎人": 获得极稀有物品

##### 3.10.2 奖励
- 称号(显示在昵称旁)
- 资源奖励
- 解锁特殊建筑皮肤(Phase 2)

#### 验收标准 (AC)
- [ ] 成就解锁时显示庆祝动画
- [ ] 可以在个人页面查看所有成就和进度
- [ ] 奖励正确发放

#### 依赖项
- 各核心系统

---

## 4. 技术规格

### 4.1 客户端技术栈

| 技术 | 版本 | 用途 |
|------|------|------|
| **平台** | iOS 15.0+ | 目标平台 |
| **语言** | Swift 5.9+ | 开发语言 |
| **UI框架** | SwiftUI | 用户界面 |
| **地图** | Apple MapKit | 地图显示和位置服务 |
| **本地缓存** | SwiftData | 离线数据缓存 |
| **网络库** | Supabase Swift SDK | 后端通信 |
| **图片加载** | Kingfisher | 图片缓存(后续) |
| **分析** | Firebase Analytics | 用户行为分析 |

### 4.2 后端技术栈

| 技术 | 用途 |
|------|------|
| **平台** | Supabase |
| **数据库** | PostgreSQL 15+ with PostGIS extension |
| **认证** | Supabase Auth (支持Apple Sign In, Email/Password) |
| **服务端逻辑** | Supabase Edge Functions (Deno/TypeScript) |
| **实时通信** | Supabase Realtime (WebSocket) |
| **文件存储** | Supabase Storage (Phase 2) |

### 4.3 核心数据库表设计

#### 表结构总览

```sql
-- 用户表
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    avatar_url VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_login_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 领地表
CREATE TABLE territories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    area GEOMETRY(Polygon, 4326) NOT NULL,
    area_sqm FLOAT GENERATED ALWAYS AS (ST_Area(area::geography)) STORED,
    status VARCHAR(20) DEFAULT 'pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    first_developed_at TIMESTAMP WITH TIME ZONE,
    last_active_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_territories_area ON territories USING GIST(area);
CREATE INDEX idx_territories_user_id ON territories(user_id);

-- 废墟/POI表
CREATE TABLE ruins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ruin_type VARCHAR(50) NOT NULL,
    location GEOMETRY(Point, 4326) NOT NULL,
    name VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_ruins_location ON ruins USING GIST(location);

-- 搜刮记录表
CREATE TABLE scavenge_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    ruin_id UUID REFERENCES ruins(id) ON DELETE CASCADE,
    scavenged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    items_gained JSONB
);

CREATE INDEX idx_scavenge_log_user_ruin ON scavenge_log(user_id, ruin_id);

-- 物品表
CREATE TABLE items (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    icon_url VARCHAR(255),
    max_stack INT DEFAULT 999
);

-- 用户背包表
CREATE TABLE user_inventory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    item_id VARCHAR(50) REFERENCES items(id),
    quantity INT DEFAULT 0 CHECK (quantity >= 0),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, item_id)
);

CREATE INDEX idx_user_inventory_user ON user_inventory(user_id);

-- 建筑类型表
CREATE TABLE building_types (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    required_resources JSONB,
    build_time_seconds INT,
    production JSONB,
    effect JSONB,
    area_sqm FLOAT
);

-- 建筑实例表
CREATE TABLE buildings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    territory_id UUID REFERENCES territories(id) ON DELETE CASCADE,
    building_type_id VARCHAR(50) REFERENCES building_types(id),
    location GEOMETRY(Point, 4326) NOT NULL,
    status VARCHAR(20) DEFAULT 'building',
    level INT DEFAULT 1,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    last_collected_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_buildings_territory ON buildings(territory_id);
CREATE INDEX idx_buildings_user ON buildings(user_id);

-- 无线电消息表
CREATE TABLE radio_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    channel VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    location GEOMETRY(Point, 4326),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_radio_messages_channel_time ON radio_messages(channel, created_at DESC);
CREATE INDEX idx_radio_messages_location ON radio_messages USING GIST(location);

-- 成就表
CREATE TABLE achievements (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    requirement JSONB,
    reward JSONB
);

-- 用户成就表
CREATE TABLE user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    achievement_id VARCHAR(50) REFERENCES achievements(id),
    unlocked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, achievement_id)
);

CREATE INDEX idx_user_achievements_user ON user_achievements(user_id);
```

### 4.4 关键API端点设计

#### 4.4.1 领地相关API

```typescript
// Edge Function: validate-territory
POST /functions/v1/validate-territory
Request Body:
{
  "path_points": [
    {"lat": 39.9042, "lng": 116.4074, "timestamp": "2026-01-03T10:00:00Z"},
    ...
  ],
  "user_id": "uuid"
}

Response:
{
  "valid": true,
  "territory_id": "uuid",
  "area_sqm": 523000,
  "reason": null  // 失败时说明原因
}
```

#### 4.4.2 搜刮相关API

```typescript
// Edge Function: scavenge-ruin
POST /functions/v1/scavenge-ruin
Request Body:
{
  "user_id": "uuid",
  "ruin_id": "uuid",
  "user_location": {"lat": 39.9042, "lng": 116.4074}
}

Response:
{
  "success": true,
  "items": [
    {"item_id": "scrap", "quantity": 5},
    {"item_id": "electronics", "quantity": 2}
  ],
  "next_available_at": "2026-01-03T16:00:00Z"
}
```

#### 4.4.3 建造相关API

```typescript
// Edge Function: build-structure
POST /functions/v1/build-structure
Request Body:
{
  "user_id": "uuid",
  "territory_id": "uuid",
  "building_type_id": "shelter",
  "location": {"lat": 39.9042, "lng": 116.4074}
}

Response:
{
  "success": true,
  "building_id": "uuid",
  "completion_time": "2026-01-03T14:00:00Z",
  "resources_consumed": [
    {"item_id": "scrap", "quantity": 10},
    {"item_id": "wood", "quantity": 5}
  ]
}
```

### 4.5 客户端架构设计

#### 4.5.1 MVVM + Repository模式

```
Views/
├── Map/
│   ├── MapView.swift
│   ├── TerritoryOverlayView.swift
│   └── POIAnnotationView.swift
├── Territory/
│   ├── TerritoryListView.swift
│   └── TerritoryDetailView.swift
├── Resources/
│   ├── InventoryView.swift
│   └── ItemDetailView.swift
├── Profile/
│   ├── ProfileView.swift
│   └── AchievementsView.swift
└── Communication/
    └── RadioView.swift

ViewModels/
├── MapViewModel.swift
├── TerritoryViewModel.swift
├── InventoryViewModel.swift
├── BuildingViewModel.swift
├── ProfileViewModel.swift
└── RadioViewModel.swift

Managers/ (业务逻辑层)
├── AuthManager.swift
├── LocationManager.swift
├── TerritoryManager.swift
├── ScavengeManager.swift
├── BuildingManager.swift
├── InventoryManager.swift
├── RadioManager.swift
└── AchievementManager.swift

Repositories/ (数据层)
├── TerritoryRepository.swift
├── RuinRepository.swift
├── InventoryRepository.swift
├── BuildingRepository.swift
└── UserRepository.swift

Services/
├── SupabaseService.swift
├── LocationService.swift
└── NotificationService.swift

Models/
├── Territory.swift
├── Ruin.swift
├── Building.swift
├── Item.swift
├── User.swift
└── RadioMessage.swift
```

#### 4.5.2 Manager职责说明

| Manager | 职责 |
|---------|------|
| AuthManager | 用户注册、登录、会话管理 |
| LocationManager | GPS定位、轨迹记录、地理围栏 |
| TerritoryManager | 领地计算、验证、管理 |
| ScavengeManager | POI搜刮逻辑、冷却管理 |
| BuildingManager | 建筑放置、建造、生产收集 |
| InventoryManager | 背包管理、物品增删 |
| RadioManager | 无线电消息发送接收 |
| AchievementManager | 成就解锁检测、奖励发放 |

### 4.6 第三方服务

| 服务 | 用途 | 费用 |
|------|------|------|
| Supabase | 后端即服务 | 免费层(开发) / $25/月(生产) |
| Firebase Analytics | 用户行为分析 | 免费 |
| Apple Maps | 地图显示 | 免费 |
| Apple Push Notification | 推送通知 | 免费 |
| 阿里千问 API | AI生成内容(Phase 2) | 按调用计费 |

---

## 5. 范围之外 (Out of Scope for Phase 1)

以下功能将在后续Phase实现,**不包含在MVP中**:

### 5.1 Phase 2功能 (多人互动)
- [ ] 联盟系统
- [ ] 玩家好友系统
- [ ] 领地争夺战(PVP)
- [ ] 交易市场
- [ ] 公会建筑

### 5.2 Phase 3功能 (深度内容)
- [ ] 世界事件(动态任务)
- [ ] PVE战斗(怪物)
- [ ] 任务系统(NPC任务)
- [ ] 科技树系统
- [ ] 稀有装备系统

### 5.3 Phase 4功能 (商业化)
- [ ] 内购系统(资源包、订阅)
- [ ] 广告系统
- [ ] 季卡/月卡
- [ ] 限时活动

### 5.4 技术相关
- [ ] Android版本
- [ ] Web管理后台
- [ ] AI生成NPC对话
- [ ] 语音聊天

---

## 6. 里程碑与迭代计划

### 6.1 开发时间线 (使用AI辅助)

| 里程碑 | 时间 | 关键交付物 | 验收标准 |
|--------|------|-----------|----------|
| **M1: 项目初始化** | Week 1 | - Xcode项目搭建<br>- Supabase配置<br>- 基础UI框架 | - 项目编译通过<br>- 数据库连接成功 |
| **M2: 核心系统开发** | Week 2-4 | - 用户认证<br>- 圈地系统<br>- 地图显示 | - 可以注册登录<br>- 完成一次圈地 |
| **M3: 探索与建造** | Week 5-6 | - 探索系统<br>- 背包系统<br>- 建造系统 | - 搜刮POI获得物品<br>- 建造第一个庇护所 |
| **M4: 辅助功能** | Week 7-8 | - 通讯系统<br>- 成就系统<br>- 新手引导 | - 发送无线电消息<br>- 解锁第一个成就 |
| **M5: 测试与优化** | Week 9-10 | - 单元测试<br>- 性能优化<br>- Bug修复 | - 崩溃率<0.5%<br>- 所有核心流程通过测试 |
| **M6: 上架准备** | Week 11-12 | - App图标<br>- 截图和描述<br>- 隐私政策 | - TestFlight测试通过<br>- 提交App Store审核 |

### 6.2 MVP验收标准

Phase 1完成的标志:

**功能完整性**:
- [ ] 新用户可以完成完整的"注册→圈地→探索→建造→收集"循环
- [ ] 所有P0功能100%可用,P1功能80%可用
- [ ] 新手引导流畅,无卡点

**技术稳定性**:
- [ ] 崩溃率 <0.5% (Xcode Organizer数据)
- [ ] 圈地验证响应时间 <500ms
- [ ] 地图加载流畅,无明显卡顿
- [ ] 后台定位稳定,不会意外终止

**用户体验**:
- [ ] 界面符合iOS Human Interface Guidelines
- [ ] 无明显UI错误(文字截断、对齐问题等)
- [ ] 支持iPhone 12及以上机型
- [ ] 支持浅色/深色模式

**数据指标** (TestFlight测试):
- [ ] D1留存率 >30%
- [ ] 新手完成率 >60%
- [ ] 平均会话时长 >15分钟

---

## 7. 风险与对策

| 风险 | 影响 | 概率 | 对策 |
|------|------|------|------|
| **GPS定位不准确** | 圈地失败,用户流失 | 中 | - 使用多传感器融合(GPS+加速度计)<br>- 容错机制(允许20米误差)<br>- 真机户外测试 |
| **服务器碰撞检测性能问题** | 验证超时,用户体验差 | 高 | - 使用PostGIS空间索引<br>- 只检测附近10km领地<br>- 负载测试和优化 |
| **用户作弊(GPS模拟器)** | 游戏公平性破坏 | 高 | - 速度检测<br>- 加速度计验证<br>- 异常行为封号 |
| **电池消耗过大** | 用户投诉 | 中 | - 优化定位频率(5秒采样)<br>- 后台定位使用低功耗模式<br>- Instruments能耗测试 |
| **App Store审核拒绝** | 延迟上线 | 中 | - 提前准备完善隐私政策<br>- 充分测试避免崩溃<br>- 遵循HIG设计指南 |
| **Supabase免费额度不足** | 服务中断 | 低 | - 监控用量<br>- 准备升级到Pro计划($25/月) |

---

## 8. 附录

### 8.1 术语表

| 术语 | 英文 | 说明 |
|------|------|------|
| 圈地 | Territory Claiming | 通过GPS轨迹圈占土地的行为 |
| 开拓模式 | Exploration Mode | 记录GPS轨迹的状态 |
| POI | Point of Interest | 兴趣点,即废墟 |
| 搜刮 | Scavenge | 在POI获得物品的行为 |
| 领地 | Territory | 玩家拥有的土地区域 |
| 定居点 | Settlement | 有建筑的领地 |
| 庇护所 | Shelter | 基础建筑 |

### 8.2 参考资料

- [Apple MapKit Documentation](https://developer.apple.com/documentation/mapkit)
- [Supabase Documentation](https://supabase.com/docs)
- [PostGIS Documentation](https://postgis.net/docs/)
- [iOS Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)

### 8.3 设计资产需求

**App图标**:
- 尺寸: 1024x1024px
- 风格: 末世+希望朋克
- 元素: 地球、废墟、新芽

**App Store截图** (需要准备):
- 6.7寸 (iPhone 15 Pro Max): 1290 x 2796 px
- 6.5寸 (iPhone 14 Plus): 1284 x 2778 px
- 5.5寸 (iPhone 8 Plus): 1242 x 2208 px

---

## 9. 批准与签署

| 角色 | 姓名 | 签名 | 日期 |
|------|------|------|------|
| 产品经理 | | | |
| 技术负责人 | | | |
| UI/UX设计师 | | | |

---

**文档变更历史**:

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|---------|------|
| 1.0 | 2026-01-03 | 初始版本,定义Phase 1功能 | |

---

**END OF PRD**
