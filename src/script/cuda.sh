#!/bin/bash

set -e

echo "🚀 最终 CUDA 环境配置..."
echo ""

# 1. 检查 conda 是否初始化
if ! command -v conda &> /dev/null; then
    echo "❌ conda 命令找不到，正在初始化..."
    $HOME/miniforge3/bin/conda init bash
    $HOME/miniforge3/bin/conda init zsh
    source ~/.bashrc
fi

# 2. 确保在 clip 环境
echo "📦 确保 clip 环境..."
conda activate clip 2>/dev/null || {
    echo "⚠️  无法激活 clip，尝试创建..."
    conda create -n clip python=3.10 -y
    conda activate clip
}

# 3. 创建 CUDA 激活脚本
CONDA_ENV=$CONDA_PREFIX
mkdir -p $CONDA_ENV/etc/conda/activate.d
mkdir -p $CONDA_ENV/etc/conda/deactivate.d

echo "📝 创建激活脚本..."

cat > $CONDA_ENV/etc/conda/activate.d/cuda_env.sh << 'SCRIPT'
#!/bin/bash
export CUDA_HOME=$CONDA_PREFIX
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
export CUDA_VISIBLE_DEVICES=0
SCRIPT

cat > $CONDA_ENV/etc/conda/deactivate.d/cuda_env.sh << 'SCRIPT'
#!/bin/bash
unset CUDA_HOME
unset CUDA_VISIBLE_DEVICES
SCRIPT

chmod +x $CONDA_ENV/etc/conda/activate.d/cuda_env.sh
chmod +x $CONDA_ENV/etc/conda/deactivate.d/cuda_env.sh

# 4. 验证 CUDA
echo ""
echo "✅ 验证 CUDA..."
export CUDA_HOME=$CONDA_PREFIX
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

nvcc --version
nvidia-smi -L

# 5. 重装 ONNX Runtime GPU
echo ""
echo "🔄 重装 ONNX Runtime GPU..."
pip uninstall onnxruntime -y
pip install onnxruntime-gpu

# 6. 最终验证
echo ""
echo "✅ 最终验证..."
python << 'PYTHON'
import onnxruntime as ort
import torch

print("\n" + "="*70)
print("🎉 最终配置验证")
print("="*70)

providers = ort.get_available_providers()
print(f"\n✅ ONNX Runtime Providers:")
for p in providers:
    marker = "✅" if "CUDA" in p or "Tensor" in p else "ℹ️"
    print(f"   {marker} {p}")

if torch.cuda.is_available():
    print(f"\n✅ PyTorch GPU:")
    print(f"   GPU: {torch.cuda.get_device_name(0)}")
    print(f"   CUDA: {torch.version.cuda}")
    print(f"   显存: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")

if 'CUDAExecutionProvider' in providers:
    print(f"\n✅ GPU 加速已启用！可以使用诊断脚本了")
else:
    print(f"\n❌ CUDA 提供者仍未启用")

print("="*70)
PYTHON

echo ""
echo "✨ 完成！"