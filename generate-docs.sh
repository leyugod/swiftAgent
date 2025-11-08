#!/bin/bash

# SwiftAgent 文档生成脚本

set -e

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          SwiftAgent - Documentation Generation                ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# 清理旧的文档
echo "🧹 Cleaning old documentation..."
rm -rf .build/documentation
rm -rf docs

# 生成 DocC 文档
echo "📚 Generating DocC documentation..."
swift package --allow-writing-to-directory ./docs \
    generate-documentation \
    --target SwiftAgent \
    --output-path ./docs \
    --transform-for-static-hosting \
    --hosting-base-path swiftAgent

echo ""
echo "✅ Documentation generated successfully!"
echo "📂 Output: ./docs"
echo ""
echo "To view locally:"
echo "  cd docs && python3 -m http.server 8000"
echo "  Open: http://localhost:8000/documentation/swiftagent"
echo ""

