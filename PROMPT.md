# Flash Attention Nix Flake Setup

## Overview
This flake provides a reproducible development environment and build system for Flash Attention (https://github.com/Dao-AILab/flash-attention) with ROCm support, following AMD's recommendations for AI/ML workloads.

## Requirements
- **Hardware**: AMD GPU with ROCm support
- **Platform**: Linux (x86_64-linux)
- **ROCm**: Must follow AMD's installation recommendations from https://rocm.docs.amd.com/en/latest/how-to/rocm-for-ai/inference-optimization/model-acceleration-libraries.html
- **Downstream Integration**: Designed to work with NixLLM flake (https://github.com/thecodenomad/NixLLM)

## Implementation Details

### Flake Outputs
1. **devShells.${system}.default**: Development environment with all dependencies
2. **packages.${system}.default**: Built flash-attention Python package

### Key Features
- ROCm support using rocmPackages from nixpkgs
- PyTorch installed via AMD's official nightlies index
- Proper HIP/ROCm environment variables
- Git submodule initialization for composable_kernel
- Forced ROCm build target (BUILD_TARGET=rocm)
- Triton AMD disabled (FLASH_ATTENTION_TRITON_AMD_ENABLE=false)

### Dependencies
**Python Dependencies:**
- einops
- packaging
- psutil

**Build Tools:**
- ninja
- cmake
- git
- gcc13

**ROCm Libraries:**
- rocmPackages.clr (ROCm runtime)
- rocmPackages.rocblas
- rocmPackages.hipblas
- rocmPackages.hipsparse
- rocmPackages.rocsolver
- rocmPackages.hipfft
- rocmPackages.hiprand
- rocmPackages.rccl
- rocmPackages.rocthrust

## Usage

### Development Shell
```bash
nix develop
# This provides the environment with PyTorch and all dependencies
# Submodules are initialized automatically in the package build
```

### Building the Package
```bash
nix build .#packages.x86_64-linux.default
# This builds flash-attention as a Nix package with ROCm support
```

### Downstream Integration
In your downstream flake.nix:
```nix
{
  inputs = {
    flash-attention.url = "path/to/this/flake";
    # or
    flash-attention.url = "github:Dao-AILab/flash-attention/your-branch";
  };

  # Use the package
  environment.systemPackages = [
    inputs.flash-attention.packages.${system}.default
  ];

  # Or use the devShell
  devShells.${system}.default = inputs.flash-attention.devShells.${system}.default;
}
```

## Build Process
1. Initialize git submodules (composable_kernel, cutlass)
2. Set ROCm environment variables (ROCM_PATH, HIP_PATH)
3. Configure GCC 13 for HIP compatibility
4. Force BUILD_TARGET=rocm in setup.py
5. Build with ninja/cmake
6. Install as Python package

## Environment Variables
- `ROCM_PATH`: Path to ROCm installation
- `HIP_PATH`: Path to HIP runtime
- `CC/CXX`: GCC 13 for compatibility
- `BUILD_TARGET`: Set to "rocm"
- `FLASH_ATTENTION_TRITON_AMD_ENABLE`: Set to "false"

## Testing
```bash
# Test PyTorch ROCm support
python -c "import torch; print(torch.cuda.is_available())"

# Test flash-attention import
python -c "import flash_attn; print('Flash attention imported successfully')"
```

## Notes
- PyTorch is installed via pip from AMD nightlies, not nixpkgs
- Submodules must be available (git clone with --recursive or manual init)
- GCC 13 is used for HIP compatibility (CUDA requires older GCC, HIP allows newer)
- Designed to work with AMD's TheRock package ecosystem</content>
<parameter name="filePath">PROMPT.md