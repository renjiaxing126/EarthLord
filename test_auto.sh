#!/bin/bash

# 自动化圈地测试脚本
# 模拟一个正方形圈地轨迹

echo "🚀 开始自动化圈地测试..."
echo ""
echo "⚠️  请确保："
echo "   1. 模拟器已经在运行 EarthLord App"
echo "   2. 已经点击了「开始圈地」按钮"
echo "   3. 打开了「圈地功能测试」日志界面"
echo ""
read -p "准备好了吗？按回车键继续..."

# 获取模拟器 ID
SIMULATOR_ID=$(xcrun simctl list devices | grep "Booted" | grep -oE '[A-F0-9-]{36}' | head -1)

if [ -z "$SIMULATOR_ID" ]; then
    echo "❌ 错误：找不到正在运行的模拟器"
    echo "请先运行 App 到模拟器"
    exit 1
fi

echo "✅ 找到模拟器: $SIMULATOR_ID"
echo ""

# 定义轨迹点（正方形，边长约 40 米）
POINTS=(
    "39.9042,116.4074"      # 起点（西南角）
    "39.90434,116.4074"     # 向北
    "39.90448,116.4074"     # 向北
    "39.90462,116.4074"     # 西北角
    "39.90462,116.40754"    # 向东
    "39.90462,116.40768"    # 东北角
    "39.90448,116.40768"    # 向南
    "39.90434,116.40768"    # 向南
    "39.9042,116.40768"     # 东南角
    "39.9042,116.40754"     # 向西
    "39.9042,116.40741"     # 回到起点附近（闭环）
)

POINT_NAMES=(
    "起点（西南角）"
    "向北移动"
    "继续向北"
    "西北角"
    "向东移动"
    "东北角"
    "向南移动"
    "继续向南"
    "东南角"
    "向西移动"
    "回到起点（闭环）"
)

# 遍历每个点
for i in "${!POINTS[@]}"; do
    POINT="${POINTS[$i]}"
    NAME="${POINT_NAMES[$i]}"

    # 解析经纬度
    LAT=$(echo $POINT | cut -d',' -f1)
    LON=$(echo $POINT | cut -d',' -f2)

    echo "📍 点 $((i+1))/${#POINTS[@]}: $NAME"
    echo "   坐标: $LAT, $LON"

    # 设置模拟器位置
    xcrun simctl location "$SIMULATOR_ID" set "$LAT" "$LON"

    # 等待 3 秒（确保定时器触发）
    if [ $i -lt $((${#POINTS[@]}-1)) ]; then
        echo "   等待 3 秒..."
        sleep 3
        echo ""
    fi
done

echo ""
echo "✅ 轨迹播放完成！"
echo ""
echo "📊 预期结果："
echo "   - 已记录 11 个点"
echo "   - 距离约 160 米"
echo "   - 面积约 1600 平方米"
echo "   - 应该显示绿色横幅：「圈地成功！领地面积: 1600m²」"
echo ""
echo "🔍 请检查："
echo "   1. App 地图上是否显示完整的正方形轨迹"
echo "   2. 日志界面是否有完整的验证过程"
echo "   3. 是否显示绿色成功横幅"
echo ""
