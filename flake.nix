{
  description = "Flash Attention: Fast and Memory-Efficient Exact Attention";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        system = system;
        config.allowUnfree = true;
        config.rocmSupport = true;
      };

      # Build flash-attention as a Python package
      flash-attention = with pkgs.python3Packages; buildPythonPackage {
        pname = "flash-attn";
        version = "2.7.0"; # TODO: Extract from __init__.py properly
        src = pkgs.fetchFromGitHub {
          owner = "Dao-AILab";
          repo = "flash-attention";
          rev = "c9ab08f708be18a42fa877f667d4d829a48234ef";
          hash = "sha256-Nk8Hk73lGBwWdARo3L3uMjlWof9NSIJLOrPfnDhR9MA=";
          fetchSubmodules = true;
        };
        format = "setuptools";

        # Python dependencies
        propagatedBuildInputs = [
          torch
          einops
          packaging
          psutil
        ];

        nativeBuildInputs = with pkgs; [
          git
          # GCC for HIP compilation
          gcc13
        ];

        buildInputs = with pkgs; [
          # ROCm packages
          rocmPackages.clr
          rocmPackages.rocblas
          rocmPackages.hipblas
          rocmPackages.hipsparse
          rocmPackages.rocsolver
          rocmPackages.hipfft
          rocmPackages.hiprand
          rocmPackages.rccl
          rocmPackages.rocthrust
        ];

        # Set build environment
        env = {
          ROCM_PATH = "${pkgs.rocmPackages.clr}";
          HIP_PATH = "${pkgs.rocmPackages.clr}";
          CC = "${pkgs.gcc13}/bin/gcc";
          CXX = "${pkgs.gcc13}/bin/g++";
          BUILD_TARGET = "rocm";
          FLASH_ATTENTION_TRITON_AMD_ENABLE = "false";
          # Skip CUDA/ROCm builds in nix environment - let downstream pip handle it
          FLASH_ATTENTION_SKIP_CUDA_BUILD = "TRUE";
        };

        # Add ROCm libraries to library path during build
        preBuild = ''
          export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [
            pkgs.rocmPackages.clr
            pkgs.rocmPackages.rocblas
            pkgs.rocmPackages.hipblas
            pkgs.rocmPackages.hipsparse
            pkgs.rocmPackages.rocsolver
            pkgs.rocmPackages.hipfft
            pkgs.rocmPackages.hiprand
          ]}:$LD_LIBRARY_PATH"

          export LIBRARY_PATH="${pkgs.lib.makeLibraryPath [
            pkgs.rocmPackages.clr
          ]}:$LIBRARY_PATH"
        '';

        # Override setup.py to force ROCm build
        postPatch = ''
          substituteInPlace setup.py \
            --replace 'BUILD_TARGET = os.environ.get("BUILD_TARGET", "auto")' \
                      'BUILD_TARGET = os.environ.get("BUILD_TARGET", "rocm")'
        '';

        meta = {
          description = "Flash Attention: Fast and Memory-Efficient Exact Attention";
          homepage = "https://github.com/Dao-AILab/flash-attention";
          license = pkgs.lib.licenses.bsd3;
        };
      };
    in
    {
      packages.${system}.default = flash-attention;

      devShells.${system}.default = pkgs.mkShell rec {
        buildInputs = with pkgs; [
          # Python with dependencies (PyTorch installed via pip)
          (python3.withPackages (
            ps: with ps; [
              pip
              einops
              packaging
              psutil
            ]
          ))

          # Build tools
          ninja
          cmake
          git

          # ROCm runtime and libraries using rocmPackages
          rocmPackages.clr
          rocmPackages.rocblas
          rocmPackages.hipblas
          rocmPackages.hipsparse
          rocmPackages.rocsolver
          rocmPackages.hipfft
          rocmPackages.hiprand
          rocmPackages.rccl
          rocmPackages.rocthrust

          # GCC for HIP compilation compatibility
          gcc13
        ];

        shellHook = ''
          # Install PyTorch with ROCm support via official AMD packages
          if ! python -c "import torch" 2>/dev/null; then
            echo "Installing PyTorch with ROCm support..."
            python -m pip install --break-system-packages --index-url https://rocm.nightlies.amd.com/v2/gfx1151/ --pre torch torchaudio torchvision
          fi

          export ROCM_PATH=${pkgs.rocmPackages.clr}
          export HIP_PATH=${pkgs.rocmPackages.clr}

          # Set CC to GCC 13 for HIP compatibility
          export CC=${pkgs.gcc13}/bin/gcc
          export CXX=${pkgs.gcc13}/bin/g++
          export PATH=${pkgs.gcc13}/bin:$PATH

          # Add necessary paths for dynamic linking
          export LD_LIBRARY_PATH=${
            pkgs.lib.makeLibraryPath ([
              "/run/opengl-driver" # Needed to find libGL.so
              pkgs.rocmPackages.clr
              pkgs.rocmPackages.rocblas
              pkgs.rocmPackages.hipblas
              pkgs.rocmPackages.hipsparse
              pkgs.rocmPackages.rocsolver
              pkgs.rocmPackages.hipfft
              pkgs.rocmPackages.hiprand
            ] ++ buildInputs)
          }:$LD_LIBRARY_PATH

          # Set LIBRARY_PATH to help the linker find the ROCm libraries
          export LIBRARY_PATH=${
            pkgs.lib.makeLibraryPath [
              pkgs.rocmPackages.clr
            ]
          }:$LIBRARY_PATH

          echo "Flash Attention development environment loaded (ROCm)!"
          echo "To initialize submodules, run: git submodule update --init --recursive"
          echo "To build for ROCm, run: FLASH_ATTENTION_TRITON_AMD_ENABLE=false pip install --break-system-packages -e ."
          echo "Or set BUILD_TARGET=rocm before building"
        '';
      };
    };
}