{
  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{
    self,
    nixpkgs,
    flake-parts,
    systems,
    poetry2nix,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = import systems;
      perSystem = {
        pkgs,
        lib,
        system,
        self',
        ...
      }: let
        python = pkgs.python311;
        #entrypoint = pkgs.writeShellScriptBin "entrypoint" ''
        #  export LD_PRELOAD=$(${pkgs.busybox}/bin/find /lib/x86_64-linux-gnu -name "libcuda.so.*" -type f 2>/dev/null)
        #  exec ${lib.getExe self'.packages.default} "$@"
        #'';
        inherit (pkgs.callPackage ./. { python3 = python; }) poetryApplication poetryEnv;
      in {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            cudaSupport = true;
          };
          overlays = [poetry2nix.overlays.default];
        };
        #apps = {
        #  default = {
        #    type = "app";
        #    program = lib.getExe (pkgs.writeShellScriptBin "nlp-service" ''
        #      export LD_PRELOAD=/run/opengl-driver/lib/libcuda.so.1
        #      exec ${lib.getExe self'.packages.default} "$@"
        #    '');
        #  };
        #};
        packages = {
          #default = poetryApplication;
          #releaseEnv = pkgs.buildEnv {
          #  name = "release-env";
          #  paths = [poetry python];
          #};
        };
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.nix            # pin nix.
            pkgs.poetry         # python development environment manager.
            python
            #poetryEnv
          ];
          POETRY_VIRTUALENVS_IN_PROJECT = true;
          LD_LIBRARY_PATH = lib.makeLibraryPath [
            pkgs.stdenv.cc.cc
            pkgs.cudatoolkit
            pkgs.zlib
            "/run/opengl-driver"
          ];
          shellHook = ''
            ${lib.getExe pkgs.poetry} env use ${lib.getExe python}
            ${lib.getExe pkgs.poetry} install --all-extras --no-root --sync
            set -a
            source .env 2> /dev/null

            #export CUDA_HOME=${pkgs.cudatoolkit}
            export LD_PRELOAD=/run/opengl-driver/lib/libcuda.so.1
          '';
        };
      };
    };
}
