{
  description = "CQ-editor and CadQuery";

  nixConfig = {
    extra-experimental-features = "nix-command flakes";
    extra-substituters = "https://marcus7070.cachix.org";
    extra-trusted-public-keys = "marcus7070.cachix.org-1:JawxHSgnYsgNYJmNqZwvLjI4NcOwrcEZDToWlT3WwXw=";
  };

  inputs = {
    nixpkgs.url = github:NixOS/nixpkgs/nixos-unstable;
    flake-utils.url = "github:numtide/flake-utils";
    cadquery-src = {
      url = "github:CadQuery/cadquery/9ee703da3498ea375fdc6d8054bee1cbcd325535";
      flake = false;
    };
    cq-editor-src = {
      url = "github:CadQuery/CQ-editor/c9f9cbd000496e0045a56763db883211a6f9a5e5";
      flake = false;
    };
    ocp-src = {
      url = "github:cadquery/ocp/74b0dc035d81a4d421673875024016cb5c138398";
      flake = false;
    };
    ocp-stubs-src = {
      url = "github:cadquery/ocp-stubs/e838ff400d5ee2f4a0579d2a713b19311855288f";
      flake = false;
    };
    pywrap-src = {
      url = "github:CadQuery/pywrap/977faad67b813ba08b799af1f43d8ade881e5bc1";
      flake = false;
    };
    pybind11-stubgen-src = {
      url = "github:CadQuery/pybind11-stubgen/e838ff400d5ee2f4a0579d2a713b19311855288f";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, ... } @ inputs:
    let
      # someone else who can do the testing might want to extend this to other systems
      systems = [ "x86_64-linux" ];
    in
      flake-utils.lib.eachSystem systems ( system:
        let
          pkgs = import nixpkgs {
            inherit system;
          };
          nlopt = pkgs.callPackage ./expressions/nlopt.nix { python = pkgs.python311; };
          scotch = pkgs.scotch.overrideAttrs (oldAttrs: {
            buildFlags = ["scotch ptscotch esmumps ptesmumps"];
            installFlags = ["prefix=\${out} scotch ptscotch esmumps ptesmumps" ];
          } );
          mumps = pkgs.callPackage ./expressions/mumps.nix { inherit scotch; };
          casadi = pkgs.callPackage ./expressions/casadi.nix {
            inherit mumps scotch;
            python = pkgs.python311;
          };
          opencascade-occt = pkgs.callPackage ./expressions/opencascade-occt { };
          lib3mf-231 = pkgs.callPackage ./expressions/lib3mf.nix {};
          py-overrides = import expressions/py-overrides.nix {
            inherit (inputs) pywrap-src ocp-src ocp-stubs-src cadquery-src pybind11-stubgen-src;
            inherit (pkgs) fetchFromGitHub;
            # NOTE(vinszent): Latest dev env uses LLVM 15 (https://github.com/CadQuery/OCP/blob/master/environment.devenv.yml)
            llvmPackages = pkgs.llvmPackages_15;
            occt = opencascade-occt;
            nlopt_nonpython = nlopt;
            casadi_nonpython = casadi;
            lib3mf = lib3mf-231;
          };
          python = pkgs.python311.override {
            packageOverrides = py-overrides;
            self = python;
          };
          cq-kit = python.pkgs.callPackage ./expressions/cq-kit {};
          cq-warehouse = python.pkgs.callPackage ./expressions/cq-warehouse.nix { };
        in rec {
          packages = {
            inherit (python.pkgs) cadquery build123d;
            inherit cq-kit cq-warehouse;

            cq-editor = pkgs.libsForQt5.callPackage ./expressions/cq-editor.nix {
              python3Packages = python.pkgs // { inherit cq-kit cq-warehouse; };
              src = inputs.cq-editor-src;
            };
          };

          defaultPackage = packages.cq-editor;
          apps.default = flake-utils.lib.mkApp { drv = defaultPackage; };
        }
      );
}
