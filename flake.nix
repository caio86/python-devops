{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          ...
        }:
        let
          inherit (pkgs) lib;

          workspace = inputs.uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

          overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };

          pythonSet =
            (pkgs.callPackage inputs.pyproject-nix.build.packages { python = pkgs.python312; }).overrideScope
              (
                lib.composeManyExtensions [
                  inputs.pyproject-build-systems.overlays.default
                  overlay
                ]
              );
        in
        {
          devShells = {
            impure = pkgs.mkShell {
              packages = with pkgs; [
                python312
                uv
              ];

              env = {
                UV_PYTHON_DOWNLOADS = "never";
                UV_PYTHON = pkgs.python312.interpreter;
              };
            };

            uv2nix =
              let
                virtualEnv = pythonSet.mkVirtualEnv "python-devops-dev-env" workspace.deps.all;
              in
              pkgs.mkShell {
                packages = with pkgs; [
                  virtualEnv
                  uv
                ];

                env = {
                  UV_NO_SYNC = "1";
                  UV_PYTHON_DOWNLOADS = "never";
                  UV_PYTHON = "${virtualEnv}/bin/python";
                };
              };

            default = self'.devShells.uv2nix;
          };

          packages = {
            default = pythonSet.mkVirtualEnv "python-devops-env" workspace.deps.default;

            docker = pkgs.dockerTools.buildImage {
              name = "python-devops";
              config = {
                cmd = [ "${self'.packages.default}/bin/app" ];
              };
            };
          };

          apps = {
            default = {
              type = "app";
              program = "${self'.packages.default}/bin/app";
            };
          };

        };
    };
}
